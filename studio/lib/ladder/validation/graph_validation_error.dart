enum GraphErrorType {
  cycleDetected,
  invalidConnection,
  missingNode,
  invalidPort,
  duplicateConnection,
  unconfiguredNode,
  emptyParallel
}

class GraphValidationError {
  final GraphErrorType type;
  final String message;
  final String? networkId;
  final List<String> affectedNodeIds;
  final List<String> affectedConnectionIds;

  GraphValidationError({
    required this.type,
    required this.message,
    this.networkId,
    this.affectedNodeIds = const [],
    this.affectedConnectionIds = const [],
  });
}
