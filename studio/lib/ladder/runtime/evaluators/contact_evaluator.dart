import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class ContactEvaluator implements NodeEvaluator {
  static bool _readTagBoolWithAliases(TagStateStore tagStore, String tagId) {
    final clean = tagId.trim();
    if (tagStore.getBool(clean)) return true;
    final upper = clean.toUpperCase();
    if (tagStore.getBool(upper)) return true;
    if (upper.startsWith('Q0.') && upper.length == 4) {
      return tagStore.getBool('Y${upper.substring(3)}');
    } else if (upper.startsWith('Y') && upper.length == 2) {
      return tagStore.getBool('Q0.${upper.substring(1)}');
    } else if (upper.startsWith('I0.') && upper.length == 4) {
      return tagStore.getBool('X${upper.substring(3)}');
    } else if (upper.startsWith('X') && upper.length == 2) {
      return tagStore.getBool('I0.${upper.substring(1)}');
    }
    return false;
  }

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    if (!inPowerFlow) {
      state.energized = false;
      return false;
    }

    final tagId = node.config.tagId;
    if (tagId == null || tagId.trim().isEmpty) {
      state.energized = false;
      return false; // Sem tag, circuito aberto
    }

    final tagValue = _readTagBoolWithAliases(tagStore, tagId);
    
    if (node.type == NodeType.contactNO) {
      state.energized = tagValue;
    } else if (node.type == NodeType.contactNC) {
      state.energized = !tagValue;
    }

    return state.energized;
  }
}
