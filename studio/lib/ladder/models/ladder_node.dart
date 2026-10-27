import 'enums.dart';
import 'node_config.dart';

/// Representa apenas a essencia instrucional. Nenhuma coordenada visual permitida.
class LadderNode {
  final String id;
  final NodeType type;
  NodeConfig config;
  bool isEnergized = false;
  bool isConducting = false;
  List<List<LadderNode>>? branches;

  LadderNode({
    required this.id,
    required this.type,
    required this.config,
    this.branches,
  });

  String get symbol {
    final tag = config.tagId;
    final preset = config.presetValue?.intValue;
    switch (type) {
      case NodeType.contactNO:
        return tag != null && tag.isNotEmpty ? '[ NO $tag ]' : '[ NO ]';
      case NodeType.contactNC:
        return tag != null && tag.isNotEmpty ? '[ NC $tag ]' : '[ NC ]';
      case NodeType.coil:
        return tag != null && tag.isNotEmpty ? '( $tag )' : '( COIL )';
      case NodeType.coilSet:
        return tag != null && tag.isNotEmpty ? '( S $tag )' : '( SET )';
      case NodeType.coilReset:
        return tag != null && tag.isNotEmpty ? '( R $tag )' : '( RESET )';
      case NodeType.timerTON:
      case NodeType.timerTOF:
        final prefix = type == NodeType.timerTON ? 'TON' : 'TOF';
        if (tag != null && tag.isNotEmpty) {
          if (preset != null) {
            return '[ $prefix $tag ${preset}ms ]';
          }
          return '[ $prefix $tag ]';
        }
        if (preset != null) {
          return '[ $prefix ${preset}ms ]';
        }
        return '[ $prefix ]';
      case NodeType.counterCTU:
      case NodeType.counterCTD:
        final prefix = type == NodeType.counterCTU ? 'CTU' : 'CTD';
        if (tag != null && tag.isNotEmpty) {
          if (preset != null) {
            return '[ $prefix $tag $preset ]';
          }
          return '[ $prefix $tag ]';
        }
        if (preset != null) {
          return '[ $prefix $preset ]';
        }
        return '[ $prefix ]';
      case NodeType.compareEqual:
        return _formatCompareSymbol('EQU');
      case NodeType.compareGreater:
        return _formatCompareSymbol('GRT');
      case NodeType.compareLess:
        return _formatCompareSymbol('LES');
      case NodeType.mathADD:
        return _formatCompareSymbol('ADD');
      case NodeType.mathSUB:
        return _formatCompareSymbol('SUB');
      case NodeType.mathMUL:
        return _formatCompareSymbol('MUL');
      case NodeType.mathDIV:
        return _formatCompareSymbol('DIV');
      case NodeType.pid:
        final sp = config.setpointTagId ?? 'SP';
        final pv = config.tagId ?? 'PV';
        final mv = config.outputTagId ?? 'MV';
        return '[ PID SP:$sp PV:$pv -> $mv ]';
      case NodeType.parallel:
        return '[ PARALLEL ]';
    }
  }

  String _formatCompareSymbol(String op) {
    final tag = config.tagId;
    final preset = config.presetValue;
    if (tag != null && tag.isNotEmpty) {
      if (preset != null) {
        final val = preset.boolValue ?? preset.intValue ?? preset.realValue ?? preset.stringValue ?? '';
        return '[ $op $tag $val ]';
      }
      return '[ $op $tag ]';
    }
    return '[ $op ]';
  }

  LadderNode clone() {
    return LadderNode(
      id: id,
      type: type,
      config: config.clone(),
      branches: branches?.map((list) => list.map((node) => node.clone()).toList()).toList(),
    )
      ..isEnergized = isEnergized
      ..isConducting = isConducting;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'config': config.toJson(),
        if (branches != null) 'branches': branches!.map((list) => list.map((node) => node.toJson()).toList()).toList(),
      };

  factory LadderNode.fromJson(Map<String, dynamic> json) => LadderNode(
        id: json['id'] as String,
        type: NodeType.values.byName(json['type'] as String),
        config: NodeConfig.fromJson(json['config'] as Map<String, dynamic>),
        branches: json['branches'] != null
            ? (json['branches'] as List<dynamic>)
                .map((list) => (list as List<dynamic>)
                    .map((item) => LadderNode.fromJson(item as Map<String, dynamic>))
                    .toList())
                .toList()
            : null,
      );
}
