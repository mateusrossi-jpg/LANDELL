import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../../models/tag_value.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class MathEvaluator implements NodeEvaluator {
  @override
  bool evaluate(
    LadderNode node, 
    NodeRuntimeState state, 
    bool inPowerFlow, 
    TagStateStore tagStore, 
    int deltaTimeMs
  ) {
    if (!inPowerFlow) {
      state.energized = false;
      return false;
    }

    final tagAId = node.config.tagId;
    if (tagAId == null || tagAId.isEmpty) {
      state.energized = false;
      return false;
    }

    final valAObj = tagStore.getValue(tagAId);
    final num? numA = _extractNum(valAObj);
    if (numA == null) {
      state.energized = false;
      return false;
    }

    final preset = node.config.presetValue;
    num? numB;
    if (preset != null) {
      if (preset.stringValue != null) {
        final valBObj = tagStore.getValue(preset.stringValue!);
        numB = _extractNum(valBObj);
      } else {
        numB = _extractNum(preset);
      }
    }

    if (numB == null) {
      state.energized = false;
      return false;
    }

    final targetTag = (node.config.outputTagId != null && node.config.outputTagId!.isNotEmpty)
        ? node.config.outputTagId!
        : ((node.config.resetTagId != null && node.config.resetTagId!.isNotEmpty)
            ? node.config.resetTagId!
            : tagAId);

    num result = 0;
    bool isDoubleResult = (numA is double) || (numB is double);

    switch (node.type) {
      case NodeType.mathADD:
        result = numA + numB;
        break;
      case NodeType.mathSUB:
        result = numA - numB;
        break;
      case NodeType.mathMUL:
        result = numA * numB;
        break;
      case NodeType.mathDIV:
        if (numB == 0) {
          result = 0;
        } else {
          result = numA / numB;
          isDoubleResult = true;
        }
        break;
      default:
        state.energized = false;
        return false;
    }

    final TagValue resultTagValue = isDoubleResult
        ? TagValue.real(result.toDouble())
        : TagValue.integer(result.toInt());

    tagStore.setValue(targetTag, resultTagValue);
    state.energized = true;
    return true;
  }

  num? _extractNum(TagValue? val) {
    if (val == null) return null;
    if (val.intValue != null) return val.intValue;
    if (val.realValue != null) return val.realValue;
    if (val.boolValue != null) return val.boolValue! ? 1 : 0;
    if (val.stringValue != null) return num.tryParse(val.stringValue!);
    return null;
  }
}
