import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class CoilEvaluator implements NodeEvaluator {
  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    state.energized = inPowerFlow;

    final tagId = node.config.tagId;
    if (tagId != null) {
      if (node.type == NodeType.coil) {
        tagStore.setBool(tagId, inPowerFlow);
      } else if (node.type == NodeType.coilSet && inPowerFlow) {
        tagStore.setBool(tagId, true);
      } else if (node.type == NodeType.coilReset && inPowerFlow) {
        tagStore.setBool(tagId, false);
        tagStore.setBool('$tagId.DN', false);
        tagStore.setBool('$tagId.TT', false);
        tagStore.setBool('$tagId.EN', false);
        tagStore.setBool('$tagId.CU', false);
        tagStore.setBool('$tagId.CD', false);
        tagStore.setInt('$tagId.CV', 0);
        tagStore.setInt('$tagId.ACC', 0);
      }
    }

    return inPowerFlow; // A energia sempre atravessa a bobina para o barramento direito
  }
}
