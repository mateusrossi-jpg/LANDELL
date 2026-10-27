import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class CounterEvaluator implements NodeEvaluator {
  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    state.energized = inPowerFlow;
    final preset = node.config.presetValue?.intValue ?? 0;
    
    // Detector de borda de subida manual (o runtime puro nao acessa memoria de varredura passada sem flag)
    final lastState = state.runtimeFlags['LAST_IN'] ?? false;
    final risingEdge = inPowerFlow && !lastState;
    state.runtimeFlags['LAST_IN'] = inPowerFlow;

    // Check for reset input if configured
    final resetTagId = node.config.resetTagId;
    if (resetTagId != null) {
      final resetActive = tagStore.getBool(resetTagId);
      if (resetActive) {
        state.counterValue = 0;
        state.runtimeFlags['DN'] = false;
        // clear previous input to avoid false edge after reset
        state.runtimeFlags['LAST_IN'] = false;
        // after reset, no counting this scan
        return false;
      }
    }
      final tagId = node.config.tagId;
      if (node.type == NodeType.counterCTU) {
        if (risingEdge && state.counterValue < preset) {
          state.counterValue++;
        }
        state.runtimeFlags['CU'] = inPowerFlow;
        state.runtimeFlags['DN'] = state.counterValue >= preset;
        if (tagId != null && tagId.isNotEmpty) {
          tagStore.setBool(tagId, state.runtimeFlags['DN'] ?? false);
          tagStore.setBool('$tagId.CU', state.runtimeFlags['CU'] ?? false);
          tagStore.setBool('$tagId.DN', state.runtimeFlags['DN'] ?? false);
          tagStore.setBool('$tagId.Q', state.runtimeFlags['DN'] ?? false);
          tagStore.setInt('$tagId.CV', state.counterValue);
        }
        return state.runtimeFlags['DN'] ?? false;
      } else if (node.type == NodeType.counterCTD) {
        if (risingEdge) {
          state.counterValue--;
        }
        state.runtimeFlags['CD'] = inPowerFlow;
        state.runtimeFlags['DN'] = state.counterValue <= preset;
        if (tagId != null && tagId.isNotEmpty) {
          tagStore.setBool(tagId, state.runtimeFlags['DN'] ?? false);
          tagStore.setBool('$tagId.CD', state.runtimeFlags['CD'] ?? false);
          tagStore.setBool('$tagId.DN', state.runtimeFlags['DN'] ?? false);
          tagStore.setBool('$tagId.Q', state.runtimeFlags['DN'] ?? false);
          tagStore.setInt('$tagId.CV', state.counterValue);
        }
        return state.runtimeFlags['DN'] ?? false;
      }
      return false;
  }
}
