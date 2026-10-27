import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class ContactEvaluator implements NodeEvaluator {
  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    if (!inPowerFlow) {
      state.energized = false;
      return false;
    }

    final tagId = node.config.tagId;
    if (tagId == null) {
      state.energized = false;
      return false; // Sem tag, circuito aberto
    }

    final tagValue = tagStore.getBool(tagId);
    
    if (node.type == NodeType.contactNO) {
      state.energized = tagValue;
    } else if (node.type == NodeType.contactNC) {
      state.energized = !tagValue;
    }

    return state.energized;
  }
}
