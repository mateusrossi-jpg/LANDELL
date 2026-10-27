import '../../runtime/node_runtime_state.dart';

class RenderContext {
  final bool isSelected;
  final NodeRuntimeState? runtimeState;
  final bool isSimulationRunning;

  const RenderContext({
    required this.isSelected,
    this.runtimeState,
    this.isSimulationRunning = false,
  });
}
