/// Mantem o estado vital do ciclo atual do CLP sem poluir o modelo do projeto.
class NodeRuntimeState {
  final String nodeId;

  // O no esta energizado nesta varredura?
  bool energized;

  // Controle de tempo (Para TON, TOF, etc)
  int lastScanTimestampMs;
  int accumulatedTimeMs;

  // Controle de contagem (Para CTU, CTD)
  int counterValue;

  final Map<String, NodeRuntimeState> subNodeStates = {};
  Map<String, bool> runtimeFlags;

  NodeRuntimeState({
    required this.nodeId,
    this.energized = false,
    this.lastScanTimestampMs = 0,
    this.accumulatedTimeMs = 0,
    this.counterValue = 0,
    Map<String, bool>? runtimeFlags,
  }) : runtimeFlags = runtimeFlags ?? {};
}
