class SimulationResult {
  final bool success;
  final Map<String, bool> outputs;
  final List validationErrors;
  final Duration executionTime;
  final String summary;

  const SimulationResult({
    required this.success,
    required this.outputs,
    required this.validationErrors,
    required this.executionTime,
    required this.summary,
  });
}
