import 'graph_validation_error.dart';
import 'executable_graph.dart';

class GraphValidationResult {
  final bool isValid;
  final List<GraphValidationError> errors;
  final List<String> warnings;
  final ExecutableGraph? executableGraph;

  GraphValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.executableGraph,
  });
}
