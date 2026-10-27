import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../node_runtime_state.dart';
import '../tag_state_store.dart';
import 'node_evaluator.dart';
import 'contact_evaluator.dart';
import 'coil_evaluator.dart';
import 'timer_evaluator.dart';
import 'counter_evaluator.dart';
import 'compare_evaluator.dart';

class ParallelEvaluator implements NodeEvaluator {
  final Map<NodeType, NodeEvaluator> _localRegistry = {
    NodeType.contactNO: ContactEvaluator(),
    NodeType.contactNC: ContactEvaluator(),
    NodeType.coil: CoilEvaluator(),
    NodeType.coilSet: CoilEvaluator(),
    NodeType.coilReset: CoilEvaluator(),
    NodeType.timerTON: TimerEvaluator(),
    NodeType.timerTOF: TimerEvaluator(),
    NodeType.counterCTU: CounterEvaluator(),
    NodeType.counterCTD: CounterEvaluator(),
    NodeType.compareEqual: CompareEvaluator(),
    NodeType.compareGreater: CompareEvaluator(),
    NodeType.compareLess: CompareEvaluator(),
  };

  @override
  bool evaluate(LadderNode node, NodeRuntimeState state, bool inPowerFlow, TagStateStore tagStore, int deltaTimeMs) {
    if (node.branches == null || node.branches!.isEmpty) {
      state.energized = inPowerFlow;
      return inPowerFlow;
    }

    if (!inPowerFlow) {
      state.energized = false;
      // If there is no incoming power flow, all branches are de-energized
      for (int b = 0; b < node.branches!.length; b++) {
        final branch = node.branches![b];
        for (final child in branch) {
          final childStateId = '${node.id}_b${b}_${child.id}';
          final childState = state.subNodeStates.putIfAbsent(
            childStateId,
            () => NodeRuntimeState(nodeId: child.id),
          );
          final evaluator = _localRegistry[child.type];
          if (evaluator != null) {
            evaluator.evaluate(child, childState, false, tagStore, deltaTimeMs);
          }
          child.isEnergized = false;
        }
      }
      return false;
    }

    bool anyBranchConducts = false;

    for (int b = 0; b < node.branches!.length; b++) {
      final branch = node.branches![b];
      bool currentPower = true; // Each branch starts energized by the left rail of the parallel block

      for (final child in branch) {
        final childStateId = '${node.id}_b${b}_${child.id}';
        final childState = state.subNodeStates.putIfAbsent(
          childStateId,
          () => NodeRuntimeState(nodeId: child.id),
        );
        final evaluator = _localRegistry[child.type];
        if (evaluator != null) {
          currentPower = evaluator.evaluate(child, childState, currentPower, tagStore, deltaTimeMs);
        } else {
          currentPower = false;
        }
        child.isEnergized = currentPower;
      }

      if (currentPower) {
        anyBranchConducts = true;
      }
    }

    state.energized = anyBranchConducts;
    return anyBranchConducts;
  }
}
