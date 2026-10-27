import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/runtime/node_runtime_state.dart';
import 'package:endap_studio/ladder/runtime/tag_state_store.dart';

abstract class NodeEvaluator {
  /// Retorna o fluxo de energia resultante que sai deste no.
  /// [inPowerFlow] indica se ha energia chegando as portas de entrada.
  bool evaluate(
    LadderNode node, 
    NodeRuntimeState state, 
    bool inPowerFlow, 
    TagStateStore tagStore, 
    int deltaTimeMs
  );
}
