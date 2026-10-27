import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class PidEvaluator implements NodeEvaluator {
  final Map<String, double> _integralAccumulators = {};
  final Map<String, double> _lastErrors = {};

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    state.runtimeFlags['EN'] = inPowerFlow;

    if (!inPowerFlow) {
      _integralAccumulators[node.id] = 0.0;
      _lastErrors[node.id] = 0.0;
      final mvTag = node.config.outputTagId ?? 'MV_PID';
      tagStore.setReal(mvTag, 0.0);
      tagStore.setInt(mvTag, 0);
      state.runtimeFlags['DN'] = false;
      state.energized = false;
      return false;
    }

    String pvTagId = (node.config.tagId ?? 'AI0.0').trim();
    final spTagId = (node.config.setpointTagId ?? '50').trim();
    String mvTagId = (node.config.outputTagId ?? 'MV_PID').trim();

    if ((pvTagId.startsWith('Q') || pvTagId.startsWith('Y')) &&
        (mvTagId.startsWith('AI') || mvTagId.startsWith('%IW') || mvTagId == 'UMID_SOLO')) {
      pvTagId = 'AI0.0';
      mvTagId = 'MV_PID';
    } else if (mvTagId.startsWith('AI') || mvTagId.startsWith('%IW') || mvTagId == 'UMID_SOLO') {
      mvTagId = 'MV_PID';
    }
    if (pvTagId == 'UMID_SOLO') pvTagId = 'AI0.0';

    // Lê PV (Process Variable)
    double pv = tagStore.getReal(pvTagId) != 0.0
        ? tagStore.getReal(pvTagId)
        : tagStore.getInt(pvTagId).toDouble();
    if (pv == 0.0 && pvTagId != 'AI0.0') {
      final fallbackPv = tagStore.getReal('AI0.0') != 0.0
          ? tagStore.getReal('AI0.0')
          : tagStore.getInt('AI0.0').toDouble();
      if (fallbackPv > 0.0) pv = fallbackPv;
    }

    // Lê SP (Setpoint)
    double sp = 50.0;
    if (spTagId.isNotEmpty) {
      final parsed = double.tryParse(spTagId);
      if (parsed != null) {
        sp = parsed;
        if (sp > 100.0 && sp <= 4095.0) {
          if (sp >= 3800.0) {
            sp = 5.0;
          } else if (sp <= 1500.0) {
            sp = 95.0;
          } else {
            sp = ((3800.0 - sp) * 100.0) / (3800.0 - 1500.0);
          }
        }
        sp = sp.clamp(1.0, 100.0);
      } else {
        final tagSp = tagStore.getReal(spTagId) != 0.0
            ? tagStore.getReal(spTagId)
            : tagStore.getInt(spTagId).toDouble();
        sp = (tagSp > 5.0 && tagSp <= 100.0) ? tagSp : 50.0;
      }
    }

    final double kp = node.config.kp ?? 2.5;
    final double ki = node.config.ki ?? 0.5;
    final double kd = node.config.kd ?? 0.1;

    final double error = sp - pv;
    final double dt = (deltaTimeMs > 0 ? deltaTimeMs : 50) / 1000.0; // segundos

    // Termo Proporcional
    final double pTerm = kp * error;

    // Termo Integral com Anti-Windup e descarga imediata ao atingir Setpoint (error <= 0)
    double integral;
    if (error <= 0.0) {
      integral = 0.0;
    } else {
      integral = (_integralAccumulators[node.id] ?? 0.0) + (error * dt);
      if (integral > 200.0) integral = 200.0;
      if (integral < 0.0) integral = 0.0;
    }
    _integralAccumulators[node.id] = integral;
    final double iTerm = ki * integral;

    // Termo Derivativo
    final double lastError = _lastErrors[node.id] ?? error;
    final double derivative = dt > 0 ? (error - lastError) / dt : 0.0;
    _lastErrors[node.id] = error;
    final double dTerm = kd * derivative;

    // Saída MV clampada 0..100
    double mv = pTerm + iTerm + dTerm;
    if (mv < 0.0) mv = 0.0;
    if (mv > 100.0) mv = 100.0;

    tagStore.setReal(mvTagId, mv);
    tagStore.setInt(mvTagId, mv.round());
    if (mvTagId != 'MV_PID') {
      tagStore.setReal('MV_PID', mv);
      tagStore.setInt('MV_PID', mv.round());
    }
    if (mvTagId == 'MV_PID' || mvTagId == 'AO0.0') {
      tagStore.setReal('AO0.0', mv);
      tagStore.setInt('AO0.0', mv.round());
    }

    // O pino ENO do bloco PID conduz energia quando MV > 20% (precisa irrigar) e desativa quando MV <= 20% (úmido/água)
    final bool isActive = mv > 20.0;
    state.runtimeFlags['DN'] = isActive;
    state.energized = isActive;
    return isActive;
  }
}
