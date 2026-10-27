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

    // Pre-calcula mapa de conexoes sainte -> entrantes para ordenacao topologica eficiente
    final Map<String, List<String>> outgoingConnections = {};
    for (var conn in network.connections) {
      if (inDegree.containsKey(conn.toNodeId)) {
        inDegree[conn.toNodeId] = inDegree[conn.toNodeId]! + 1;
      }
      outgoingConnections.putIfAbsent(conn.fromNodeId, () => []).add(conn.toNodeId);
    }

    // Fila para nos sem entrada (conectados direto ao barramento)
    final queue = <String>[];
    for (var id in inDegree.keys) {
      if (inDegree[id] == 0) {
        queue.add(id);
      }
    }

    // Ordenacao topologica (Kahn) em O(V + E)
    while (queue.isNotEmpty) {
      final currId = queue.removeAt(0);
      plan.add(nodeMap[currId]!);
      
      final outgoing = outgoingConnections[currId];
      if (outgoing != null) {
        for (var targetId in outgoing) {
          if (inDegree.containsKey(targetId)) {
            inDegree[targetId] = inDegree[targetId]! - 1;
            if (inDegree[targetId] == 0) {
              queue.add(targetId);
            }
          }
        }
      }
    }

    return plan;
  }

  void executeScan(LadderNetwork network, List<LadderNode> plan, Map<String, NodeRuntimeState> states, TagStateStore tagStore, int deltaTimeMs) {
    final Map<String, bool> nodeOutputPower = {};

    // Bolt Optimization: Pre-index incoming connection source node IDs per target node.
    // Eliminates O(E) linear search over network.connections on every node execution step in the scan loop.
    final Map<String, List<String>> incomingSources = {};
    for (var conn in network.connections) {
      incomingSources.putIfAbsent(conn.toNodeId, () => []).add(conn.fromNodeId);
    }

    for (var node in plan) {
      // Cria estado se nao existir
      states.putIfAbsent(node.id, () => NodeRuntimeState(nodeId: node.id));
      final state = states[node.id]!;

      // Calcula entrada de energia. Se nao ha conexao de entrada, e true (ligado direto no barramento)
      bool inPower = false;
      final sources = incomingSources[node.id];
      
      if (sources == null || sources.isEmpty) {
        inPower = true;
      } else {
        // OR logico das entradas em O(in-degree) em vez de O(all connections)
        for (var sourceId in sources) {
          if (nodeOutputPower[sourceId] == true) {
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
