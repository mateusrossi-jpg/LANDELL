import '../models/ladder_network.dart';
import '../models/ladder_node.dart';
import 'evaluator_registry.dart';
import 'node_runtime_state.dart';
import 'tag_state_store.dart';

import '../models/enums.dart';

class ScanEngine {
  final EvaluatorRegistry registry;

  ScanEngine(this.registry);

  Set<LadderNode> _getAllNodes(List<LadderNode> nodes) {
    final result = <LadderNode>{};
    for (var node in nodes) {
      result.add(node);
      if (node.type == NodeType.parallel && node.branches != null) {
        for (var branch in node.branches!) {
          result.addAll(_getAllNodes(branch));
        }
      }
    }
    return result;
  }

  /// Constroi o plano de execucao resolvendo a ordem topologica.
  List<LadderNode> buildExecutionPlan(LadderNetwork network) {
    final allNodes = _getAllNodes(network.nodes);
    final List<LadderNode> plan = [];
    final Map<String, int> inDegree = {};
    final Map<String, LadderNode> nodeMap = {for (var n in allNodes) n.id: n};

    // Inicializa graus de entrada
    for (var node in allNodes) {
      inDegree[node.id] = 0;
    }

    // Calcula graus de entrada
    for (var conn in network.connections) {
      if (inDegree.containsKey(conn.toNodeId)) {
        inDegree[conn.toNodeId] = inDegree[conn.toNodeId]! + 1;
      }
    }

    // Fila para nos sem entrada (conectados direto ao barramento)
    final queue = <String>[];
    for (var id in inDegree.keys) {
      if (inDegree[id] == 0) {
        queue.add(id);
      }
    }

    // Ordenacao topologica (Kahn)
    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      plan.add(nodeMap[currId]!);
      
      for (var conn in network.connections.where((c) => c.fromNodeId == currId)) {
        inDegree[conn.toNodeId] = inDegree[conn.toNodeId]! - 1;
        if (inDegree[conn.toNodeId] == 0) {
          queue.add(conn.toNodeId);
        }
      }
    }

    return plan;
  }

  void executeScan(LadderNetwork network, List<LadderNode> plan, Map<String, NodeRuntimeState> states, TagStateStore tagStore, int deltaTimeMs) {
    final Map<String, bool> nodeOutputPower = {};

    for (var node in plan) {
      // Cria estado se nao existir
      states.putIfAbsent(node.id, () => NodeRuntimeState(nodeId: node.id));
      final state = states[node.id]!;

      // Calcula entrada de energia. Se nao ha conexao de entrada, e true (ligado direto no barramento)
      bool inPower = false;
      final incomingConns = network.connections.where((c) => c.toNodeId == node.id).toList();
      
      if (incomingConns.isEmpty) {
        inPower = true;
      } else {
        // OR logico das entradas
        for (var conn in incomingConns) {
          if (nodeOutputPower[conn.fromNodeId] == true) {
            inPower = true;
            break;
          }
        }
      }

      final evaluator = registry.getEvaluator(node.type);
      if (evaluator != null) {
        nodeOutputPower[node.id] = evaluator.evaluate(node, state, inPower, tagStore, deltaTimeMs);
      } else {
        nodeOutputPower[node.id] = false;
      }
    }
  }
}
