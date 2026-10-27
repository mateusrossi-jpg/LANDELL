import '../models/enums.dart';
import 'evaluators/node_evaluator.dart';
import 'evaluators/contact_evaluator.dart';
import 'evaluators/coil_evaluator.dart';
import 'evaluators/timer_evaluator.dart';
import 'evaluators/counter_evaluator.dart';
import 'evaluators/compare_evaluator.dart';
import 'evaluators/math_evaluator.dart';
import 'evaluators/pid_evaluator.dart';
import 'evaluators/parallel_evaluator.dart';

class EvaluatorRegistry {
  final Map<NodeType, NodeEvaluator> _registry = {};

  EvaluatorRegistry() {
    _registerDefaults();
  }

  void _registerDefaults() {
    final contactEval = ContactEvaluator();
    register(NodeType.contactNO, contactEval);
    register(NodeType.contactNC, contactEval);

    final coilEval = CoilEvaluator();
    register(NodeType.coil, coilEval);
    register(NodeType.coilSet, coilEval);
    register(NodeType.coilReset, coilEval);

    final timerEval = TimerEvaluator();
    register(NodeType.timerTON, timerEval);
    register(NodeType.timerTOF, timerEval);

    final counterEval = CounterEvaluator();
    register(NodeType.counterCTU, counterEval);
    register(NodeType.counterCTD, counterEval);

    final compareEval = CompareEvaluator();
    register(NodeType.compareEqual, compareEval);
    register(NodeType.compareGreater, compareEval);
    register(NodeType.compareLess, compareEval);

    final mathEval = MathEvaluator();
    register(NodeType.mathADD, mathEval);
    register(NodeType.mathSUB, mathEval);
    register(NodeType.mathMUL, mathEval);
    register(NodeType.mathDIV, mathEval);

    register(NodeType.pid, PidEvaluator());
    register(NodeType.parallel, ParallelEvaluator());
  }

  void register(NodeType type, NodeEvaluator evaluator) {
    _registry[type] = evaluator;
  }

  NodeEvaluator? getEvaluator(NodeType type) {
    return _registry[type];
  }
}
