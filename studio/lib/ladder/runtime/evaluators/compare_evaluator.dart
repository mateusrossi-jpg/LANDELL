import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../../models/tag_value.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';

class CompareEvaluator implements NodeEvaluator {
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

    final tagId = node.config.tagId;
    if (tagId == null) {
      state.energized = false;
      return false; 
    }

    final valA = tagStore.getValue(tagId);
    if (valA == null) {
      state.energized = false;
      return false; 
    }

    final preset = node.config.presetValue;
    if (preset == null) {
      state.energized = false;
      return false; 
    }

    TagValue valB = preset;
    if (preset.stringValue != null) {
      final otherTagValue = tagStore.getValue(preset.stringValue!);
      if (otherTagValue != null) {
        valB = otherTagValue;
      }
    }

    final cmpA = _toComparable(valA);
    final cmpB = _toComparable(valB);

    if (cmpA == null || cmpB == null) {
      state.energized = false;
      return false;
    }

    bool result = false;
    
    if (cmpA is num && cmpB is num) {
      result = _compareNums(node.type, cmpA, cmpB);
    } else if (cmpA is String && cmpB is String) {
      result = _compareStrings(node.type, cmpA, cmpB);
    } else if (cmpA is bool && cmpB is bool) {
      result = _compareBools(node.type, cmpA, cmpB);
    } else {
      num? numA = cmpA is num ? cmpA : (cmpA is String ? num.tryParse(cmpA) : (cmpA is bool ? (cmpA ? 1 : 0) : null));
      num? numB = cmpB is num ? cmpB : (cmpB is String ? num.tryParse(cmpB) : (cmpB is bool ? (cmpB ? 1 : 0) : null));
      if (numA != null && numB != null) {
        result = _compareNums(node.type, numA, numB);
      } else {
        if (node.type == NodeType.compareEqual) {
          result = cmpA == cmpB;
        } else {
          result = false;
        }
      }
    }

    state.energized = result;
    return result;
  }

  dynamic _toComparable(TagValue val) {
    if (val.boolValue != null) return val.boolValue;
    if (val.intValue != null) return val.intValue;
    if (val.realValue != null) return val.realValue;
    if (val.stringValue != null) return val.stringValue;
    return null;
  }

  bool _compareNums(NodeType type, num a, num b) {
    switch (type) {
      case NodeType.compareEqual:
        return a == b;
      case NodeType.compareGreater:
        return a > b;
      case NodeType.compareLess:
        return a < b;
      default:
        return false;
    }
  }

  bool _compareStrings(NodeType type, String a, String b) {
    switch (type) {
      case NodeType.compareEqual:
        return a == b;
      case NodeType.compareGreater:
        return a.compareTo(b) > 0;
      case NodeType.compareLess:
        return a.compareTo(b) < 0;
      default:
        return false;
    }
  }

  bool _compareBools(NodeType type, bool a, bool b) {
    switch (type) {
      case NodeType.compareEqual:
        return a == b;
      case NodeType.compareGreater:
        return (a ? 1 : 0) > (b ? 1 : 0);
      case NodeType.compareLess:
        return (a ? 1 : 0) < (b ? 1 : 0);
      default:
        return false;
    }
  }
}
