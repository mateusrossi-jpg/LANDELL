import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class CoilEvaluator implements NodeEvaluator {
  static List<String> _resolveAliases(String tagId) {
    final clean = tagId.trim();
    final upper = clean.toUpperCase();
    final aliases = <String>{clean, upper};
    if (upper.startsWith('Q0.') && upper.length == 4) {
      aliases.add('Y${upper.substring(3)}');
    } else if (upper.startsWith('Y') && upper.length == 2) {
      aliases.add('Q0.${upper.substring(1)}');
    } else if (upper.startsWith('I0.') && upper.length == 4) {
      aliases.add('X${upper.substring(3)}');
    } else if (upper.startsWith('X') && upper.length == 2) {
      aliases.add('I0.${upper.substring(1)}');
    }
    return aliases.toList();
  }

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    state.energized = inPowerFlow;

    final tagId = node.config.tagId;
    if (tagId != null && tagId.isNotEmpty) {
      final aliases = _resolveAliases(tagId);
      if (node.type == NodeType.coil) {
        for (final a in aliases) {
          tagStore.setBool(a, inPowerFlow);
        }
      } else if (node.type == NodeType.coilSet && inPowerFlow) {
        for (final a in aliases) {
          tagStore.setBool(a, true);
        }
      } else if (node.type == NodeType.coilReset && inPowerFlow) {
        for (final a in aliases) {
          tagStore.setBool(a, false);
          tagStore.setBool('$a.DN', false);
          tagStore.setBool('$a.Q', false);
          tagStore.setBool('$a.TT', false);
          tagStore.setBool('$a.EN', false);
          tagStore.setBool('$a.CU', false);
          tagStore.setBool('$a.CD', false);
          tagStore.setInt('$a.CV', 0);
          tagStore.setInt('$a.ACC', 0);
          tagStore.setInt('$a.ET', 0);
          tagStore.setBool('$a.__reset_pending', true);
        }
      }
    }

    return inPowerFlow; // A energia sempre atravessa a bobina para o barramento direito
  }
}
