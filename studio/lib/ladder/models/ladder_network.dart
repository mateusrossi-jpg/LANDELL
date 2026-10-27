import 'ladder_node.dart';
import 'ladder_connection.dart';
import 'enums.dart';

class LadderNetwork {
  final String id;
  String name;
  String targetControllerId;
  String? targetControllerName;
  bool isEnabled;
  List<LadderNode> nodes;
  List<LadderConnection> connections;

  LadderNetwork({
    required this.id,
    this.name = '',
    this.targetControllerId = 'GATEWAY',
    this.targetControllerName,
    this.isEnabled = true,
    List<LadderNode>? nodes,
    List<LadderConnection>? connections,
  })  : nodes = nodes ?? [],
        connections = connections ?? [];

  LadderNetwork clone({
    String? newId,
    String? newName,
    String? targetControllerId,
    String? targetControllerName,
    bool? isEnabled,
  }) {
    return LadderNetwork(
      id: newId ?? id,
      name: newName ?? name,
      targetControllerId: targetControllerId ?? this.targetControllerId,
      targetControllerName: targetControllerName ?? this.targetControllerName,
      isEnabled: isEnabled ?? this.isEnabled,
      nodes: nodes.map((n) => n.clone()).toList(),
      connections: connections.map((c) => c.clone()).toList(),
    );
  }

  static int _idCounter = 0;
  static String _generateId() {
    _idCounter++;
    return 'node_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void addNode(LadderNode node) {
    nodes.add(node);
    rebuildConnections();
  }

  void insertNode(LadderNode node, int index) {
    nodes.insert(index, node);
    rebuildConnections();
  }

  void removeNodeAt(int index) {
    if (index >= 0 && index < nodes.length) {
      nodes.removeAt(index);
      rebuildConnections();
    }
  }

  void duplicateNode(int index) {
    if (index >= 0 && index < nodes.length) {
      final source = nodes[index];
      final newNode = LadderNode(
        id: _generateId(),
        type: source.type,
        config: source.config.clone(),
      )..isEnergized = source.isEnergized;
      nodes.insert(index + 1, newNode);
      rebuildConnections();
    }
  }

  void moveNodeLeft(int index) {
    if (index > 0 && index < nodes.length) {
      final node = nodes.removeAt(index);
      nodes.insert(index - 1, node);
      rebuildConnections();
    }
  }

  void moveNodeRight(int index) {
    if (index >= 0 && index < nodes.length - 1) {
      final node = nodes.removeAt(index);
      nodes.insert(index + 1, node);
      rebuildConnections();
    }
  }

  void rebuildConnections() {
    connections.clear();
    _buildListConnections(nodes, null, null);
  }

  void _buildListConnections(List<LadderNode> list, String? previousId, String? nextId) {
    if (list.isEmpty) {
      // Se a lista esta vazia mas temos previous e next, conectamos direto
      if (previousId != null && nextId != null) {
        connections.add(LadderConnection(
          id: 'conn_${id}_${DateTime.now().microsecondsSinceEpoch}_empty',
          fromNodeId: previousId,
          fromPort: 'out',
          toNodeId: nextId,
          toPort: 'in',
        ));
      }
      return;
    }
    
    // Conecta o anterior ao primeiro
    if (previousId != null) {
      connections.add(LadderConnection(
        id: 'conn_${id}_${DateTime.now().microsecondsSinceEpoch}_in',
        fromNodeId: previousId,
        fromPort: 'out',
        toNodeId: list.first.id,
        toPort: 'in',
      ));
    }

    for (int i = 0; i < list.length; i++) {
      final node = list[i];
      final isLast = (i == list.length - 1);
      final currentNextId = isLast ? nextId : list[i + 1].id;

      if (node.type == NodeType.parallel) {
        // Parallel node just passes power. Connect its out to its next.
        if (currentNextId != null) {
          connections.add(LadderConnection(
            id: 'conn_${id}_${DateTime.now().microsecondsSinceEpoch}_$i',
            fromNodeId: node.id,
            fromPort: 'out',
            toNodeId: currentNextId,
            toPort: 'in',
          ));
        }
        
        // Connect its inPower to the first nodes of all its branches
        // and connect the last nodes of its branches to the currentNextId
        if (node.branches != null) {
          for (var branch in node.branches!) {
            _buildListConnections(branch, node.id, currentNextId);
          }
        }
      } else {
        if (currentNextId != null) {
          connections.add(LadderConnection(
            id: 'conn_${id}_${DateTime.now().microsecondsSinceEpoch}_$i',
            fromNodeId: node.id,
            fromPort: 'out',
            toNodeId: currentNextId,
            toPort: 'in',
          ));
        }
      }
    }
  }

  String get visualRepresentation {
    if (nodes.isEmpty) return '[]';
    return nodes.map((n) => n.symbol).join(' → ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetControllerId': targetControllerId,
        if (targetControllerName != null) 'targetControllerName': targetControllerName,
        'isEnabled': isEnabled,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'connections': connections.map((c) => c.toJson()).toList(),
      };

  factory LadderNetwork.fromJson(Map<String, dynamic> json) => LadderNetwork(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        targetControllerId: json['targetControllerId'] as String? ?? 'GATEWAY',
        targetControllerName: json['targetControllerName'] as String?,
        isEnabled: json['isEnabled'] as bool? ?? true,
        nodes: (json['nodes'] as List<dynamic>?)
                ?.map((e) => LadderNode.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        connections: (json['connections'] as List<dynamic>?)
                ?.map((e) => LadderConnection.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
