import '../../models/ladder_node.dart';
import '../../models/node_config.dart';
import '../node_runtime_state.dart';
import '../pid_math.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

/// Avaliador do bloco PID industrial. Usa [PidMath], espelho do firmware
/// (`ladder_pid.c`), portanto a simulação reproduz exatamente o CLP:
/// amostragem fixa de 100 ms, ação reversa/direta, derivada sobre PV filtrada,
/// anti-windup, banda morta, modo manual com transferência sem solavanco,
/// saída segura e ENO com histerese.
class PidEvaluator implements NodeEvaluator {
  final Map<String, PidState> _states = {};
  final Map<String, int> _accMs = {};

  /// Monta os parâmetros do bloco a partir da configuração (padrões industriais).
  static PidParams paramsFromConfig(NodeConfig c) {
    int pct(int? v, int def) => (v ?? def).clamp(0, 100);
    return PidParams(
      kpX100: (((c.kp ?? 2.5) * 100).round()).clamp(0, 0xFFFF),
      kiX100: (((c.ki ?? 0.5) * 100).round()).clamp(0, 0xFFFF),
      kdX100: (((c.kd ?? 0.1) * 100).round()).clamp(0, 0xFFFF),
      direct: c.pidDirect ?? NodeConfig.defaultPidDirect,
      derivativeOnError: c.pidDerivativeOnError ?? NodeConfig.defaultPidDerivativeOnError,
      manualEnable: (c.pidManualTagId ?? '').trim().isNotEmpty,
      outMin: pct(c.pidOutMin, NodeConfig.defaultPidOutMin),
      outMax: pct(c.pidOutMax, NodeConfig.defaultPidOutMax),
      deadbandX10: (((c.pidDeadband ?? NodeConfig.defaultPidDeadband) * 10).round()).clamp(0, 250),
      enoThreshold: pct(c.pidEnoThreshold, NodeConfig.defaultPidEnoThreshold),
      enoHysteresis: pct(c.pidEnoHysteresis, NodeConfig.defaultPidEnoHysteresis),
      safeOut: pct(c.pidSafeOut, NodeConfig.defaultPidSafeOut),
    );
  }

  /// Saída digital Qx.y / Yx: o PID atua como liga/desliga pelo ENO.
  static bool isDigitalOutputTag(String id) {
    final t = id.trim().toUpperCase();
    return RegExp(r'^[QY]\d+(\.\d+)?$').hasMatch(t);
  }

  static int _readPct(TagStateStore store, String tagId) {
    final real = store.getReal(tagId);
    final v = real != 0.0 ? real : store.getInt(tagId).toDouble();
    return v.round();
  }

  /// Lê um valor em % que pode ser literal numérico ("50", "50%") ou uma tag.
  static int readPercentOperand(TagStateStore store, String operand, {int fallback = 0}) {
    final clean = operand.replaceAll('%', '').trim();
    if (clean.isEmpty) return fallback;
    final literal = double.tryParse(clean);
    if (literal != null) return literal.round().clamp(0, 100);
    return _readPct(store, clean);
  }

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow,
      TagStateStore tagStore, int deltaTimeMs) {
    final cfg = node.config;
    final params = paramsFromConfig(cfg);
    final ps = _states.putIfAbsent(node.id, () => PidState());
    final pvTag = (cfg.tagId ?? '').trim();
    final mvTag = (cfg.outputTagId ?? 'MV_PID').trim();

    state.runtimeFlags['EN'] = inPowerFlow;

    if (!inPowerFlow) {
      PidMath.disable(params, ps);
      _accMs[node.id] = 0;
      state.runtimeFlags['MAN'] = false;
      state.runtimeFlags['DN'] = false;
      state.energized = false;
      _writeOutput(tagStore, mvTag, ps);
      return false;
    }

    final dt = deltaTimeMs > 0 ? deltaTimeMs : PidMath.sampleMs;
    final acc = (_accMs[node.id] ?? 0) + dt;

    bool manual = false;
    final manTag = (cfg.pidManualTagId ?? '').trim();
    if (manTag.isNotEmpty) {
      manual = tagStore.getBool(manTag) || tagStore.getInt(manTag) > 0;
    }
    state.runtimeFlags['MAN'] = manual && params.manualEnable;

    if (!ps.initialized || acc >= PidMath.sampleMs) {
      final stepMs = (!ps.initialized || acc > 1000) ? PidMath.sampleMs : acc;
      _accMs[node.id] = 0;
      final pv = pvTag.isEmpty ? 0 : _readPct(tagStore, pvTag);
      final sp = readPercentOperand(tagStore, cfg.setpointTagId ?? '50', fallback: 50);
      final manOut = readPercentOperand(tagStore, cfg.pidManualOut ?? '0');
      PidMath.step(params, ps,
          pvPct: pv, spPct: sp, manual: manual, manPct: manOut, dtMs: stepMs);
    } else {
      _accMs[node.id] = acc;
    }

    _writeOutput(tagStore, mvTag, ps);
    state.runtimeFlags['DN'] = ps.eno;
    state.energized = ps.eno;
    return ps.eno;
  }

  void _writeOutput(TagStateStore store, String mvTag, PidState ps) {
    if (isDigitalOutputTag(mvTag)) {
      store.setBool(mvTag, ps.eno);
    } else {
      store.setReal(mvTag, ps.mvPercent.toDouble());
      store.setInt(mvTag, ps.mvPercent);
    }
  }
}
