import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class TimerEvaluator implements NodeEvaluator {
  /// Converte qualquer representação de tempo (ex: "3s", "3000ms", "3", 3000, 3.5s) em milissegundos
  static int parsePreset(dynamic value, {int defaultPreset = 3000}) {
    if (value == null) return defaultPreset;
    if (value is int) {
      if (value <= 0) return defaultPreset;
      // Se for <= 30 (ex: 3), o usuário quase certamente digitou em segundos no editor
      if (value <= 30) return value * 1000;
      return value;
    }
    if (value is double) {
      if (value <= 0) return defaultPreset;
      if (value <= 30.0) return (value * 1000).round();
      return value.round();
    }
    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty) return defaultPreset;
    if (str.endsWith('ms')) {
      final parsed = int.tryParse(str.replaceAll('ms', '').trim());
      if (parsed != null && parsed > 0) return parsed;
    } else if (str.endsWith('s')) {
      final clean = str.replaceAll('s', '').replaceAll('t#', '').trim();
      final sec = double.tryParse(clean);
      if (sec != null && sec > 0) return (sec * 1000).round();
    } else {
      final parsed = int.tryParse(str);
      if (parsed != null && parsed > 0) {
        if (parsed <= 30) return parsed * 1000;
        return parsed;
      }
    }
    return defaultPreset;
  }

  /// Resolve o preset efetivo em milissegundos de um nó de temporização
  static int resolveNodePreset(LadderNode node, TagStateStore? tagStore, {int defaultPreset = 3000}) {
    final pv = node.config.presetValue;
    if (pv != null) {
      if (pv.intValue != null && pv.intValue! > 0) {
        return parsePreset(pv.intValue!, defaultPreset: defaultPreset);
      }
      if (pv.realValue != null && pv.realValue! > 0) {
        return parsePreset(pv.realValue!, defaultPreset: defaultPreset);
      }
      if (pv.stringValue != null && pv.stringValue!.trim().isNotEmpty) {
        return parsePreset(pv.stringValue!, defaultPreset: defaultPreset);
      }
    }
    final tagId = node.config.tagId;
    if (tagStore != null && tagId != null && tagId.isNotEmpty) {
      final pt = tagStore.getInt('$tagId.PT');
      if (pt > 0) return pt;
      final direct = tagStore.getInt(tagId);
      if (direct > 0) return direct;
    }
    return defaultPreset;
  }

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    state.energized = inPowerFlow;
    final preset = resolveNodePreset(node, tagStore);

    final tagId = node.config.tagId;
    if (node.type == NodeType.timerTON) {
      if (inPowerFlow) {
        state.runtimeFlags['EN'] = true;
        state.accumulatedTimeMs += deltaTimeMs;
        if (state.accumulatedTimeMs < preset) {
          state.runtimeFlags['TT'] = true;
          state.runtimeFlags['DN'] = false;
        } else {
          state.accumulatedTimeMs = preset;
          state.runtimeFlags['TT'] = false;
          state.runtimeFlags['DN'] = true;
        }
      } else {
        state.runtimeFlags['EN'] = false;
        state.runtimeFlags['TT'] = false;
        state.runtimeFlags['DN'] = false;
        state.accumulatedTimeMs = 0;
      }
      if (tagId != null && tagId.isNotEmpty) {
        tagStore.setBool(tagId, state.runtimeFlags['DN'] ?? false);
        tagStore.setBool('$tagId.EN', state.runtimeFlags['EN'] ?? false);
        tagStore.setBool('$tagId.IN', state.runtimeFlags['EN'] ?? false);
        tagStore.setBool('$tagId.TT', state.runtimeFlags['TT'] ?? false);
        tagStore.setBool('$tagId.DN', state.runtimeFlags['DN'] ?? false);
        tagStore.setBool('$tagId.Q', state.runtimeFlags['DN'] ?? false);
        tagStore.setInt('$tagId.PT', preset);
        tagStore.setInt('$tagId.ACC', state.accumulatedTimeMs);
        tagStore.setInt('$tagId.ET', state.accumulatedTimeMs);
      }
      return state.runtimeFlags['DN'] ?? false;
    } else if (node.type == NodeType.timerTOF) {
      if (inPowerFlow) {
        state.runtimeFlags['EN'] = true;
        state.runtimeFlags['TT'] = false;
        state.runtimeFlags['DN'] = true;
        state.accumulatedTimeMs = 0;
      } else {
        state.runtimeFlags['EN'] = false;
        if (state.runtimeFlags['DN'] == true) {
          state.accumulatedTimeMs += deltaTimeMs;
          if (state.accumulatedTimeMs < preset) {
            state.runtimeFlags['TT'] = true;
          } else {
            state.accumulatedTimeMs = preset;
            state.runtimeFlags['TT'] = false;
            state.runtimeFlags['DN'] = false;
          }
        }
      }
      if (tagId != null && tagId.isNotEmpty) {
        tagStore.setBool(tagId, state.runtimeFlags['DN'] ?? false);
        tagStore.setBool('$tagId.EN', state.runtimeFlags['EN'] ?? false);
        tagStore.setBool('$tagId.IN', state.runtimeFlags['EN'] ?? false);
        tagStore.setBool('$tagId.TT', state.runtimeFlags['TT'] ?? false);
        tagStore.setBool('$tagId.DN', state.runtimeFlags['DN'] ?? false);
        tagStore.setBool('$tagId.Q', state.runtimeFlags['DN'] ?? false);
        tagStore.setInt('$tagId.PT', preset);
        tagStore.setInt('$tagId.ACC', state.accumulatedTimeMs);
        tagStore.setInt('$tagId.ET', state.accumulatedTimeMs);
      }
      return state.runtimeFlags['DN'] ?? false;
    }
    return false;
  }
}
