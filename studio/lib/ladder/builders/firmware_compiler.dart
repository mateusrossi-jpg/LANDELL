import '../models/ladder_network.dart';
import '../models/ladder_node.dart';
import '../models/enums.dart';

/// Extensão para compilar nós individuais em expressões lógicas.
extension LadderNodeCompiler on LadderNode {
  /// Identifica se o nó atua como uma ação (direita do rung) ou condição (esquerda do rung)
  bool get isOutputAction =>
      type == NodeType.coil ||
      type == NodeType.coilSet ||
      type == NodeType.coilReset ||
      type == NodeType.timerTON ||
      type == NodeType.timerTOF ||
      type == NodeType.counterCTU ||
      type == NodeType.counterCTD;

  /// Compila a expressão booleana do nó (Condições)
  String get ruleExpression {
    if (type == NodeType.parallel) {
      if (branches == null || branches!.isEmpty) return 'TRUE';

      final branchExpressions = branches!.map((branch) {
        final seriesCondition = branch.map((node) => node.ruleExpression).join(' AND ');
        return '($seriesCondition)';
      });

      return '(${branchExpressions.join(' OR ')})';
    }

    final tag = config.tagId;
    if (tag == null || tag.isEmpty) return 'TRUE';

    switch (type) {
      case NodeType.contactNO:
        return '$tag == ON';
      case NodeType.contactNC:
        return '$tag == OFF';
      case NodeType.compareEqual:
        return '$tag == ${_getPresetString()}';
      case NodeType.compareGreater:
        return '$tag > ${_getPresetString()}';
      case NodeType.compareLess:
        return '$tag < ${_getPresetString()}';
      default:
        return 'TRUE';
    }
  }

  /// Compila a atribuição matemática do nó (Ações/Saídas)
  String get actionExpression {
    final tag = config.tagId;
    if (tag == null || tag.isEmpty) return '';

    switch (type) {
      case NodeType.coil:
        return '$tag = ON';
      case NodeType.coilSet:
        return 'LATCH_SET($tag)';
      case NodeType.coilReset:
        return 'LATCH_RESET($tag)';
      case NodeType.timerTON:
        return 'TON($tag, ${_getPresetString()})';
      case NodeType.timerTOF:
        return 'TOF($tag, ${_getPresetString()})';
      case NodeType.counterCTU:
        return 'CTU($tag, ${_getPresetString()})';
      case NodeType.counterCTD:
        return 'CTD($tag, ${_getPresetString()})';
      default:
        return '';
    }
  }

  String _getPresetString() {
    final preset = config.presetValue;
    if (preset == null) return '0';
    final val = preset.boolValue ?? preset.intValue ?? preset.realValue ?? preset.stringValue ?? '0';
    return val.toString();
  }
}

/// Extensão para compilar a rede inteira (LadderNetwork)
extension LadderNetworkCompiler on LadderNetwork {
  /// Transpila a rede atual para a sintaxe do Motor de Regras do Firmware ENDAP
  String compileToFirmwareRule() {
    final conditionNodes = nodes.where((n) => !n.isOutputAction).toList();
    final outputNodes = nodes.where((n) => n.isOutputAction).toList();

    if (outputNodes.isEmpty) {
      throw Exception("Erro de Compilação: O Rung [$id] não possui uma bobina ou ação de saída.");
    }

    final conditionsStr = conditionNodes
        .map((n) => n.ruleExpression)
        .where((s) => s != 'TRUE')
        .join(' AND ');

    final actionsStr = outputNodes
        .map((n) => n.actionExpression)
        .where((s) => s.isNotEmpty)
        .join(' AND ');

    final finalConditions = conditionsStr.isEmpty ? 'TRUE' : conditionsStr;

    if (actionsStr.isEmpty) {
      throw Exception("Erro de Compilação: Ação de saída inválida ou sem tag no Rung [$id].");
    }

    return 'IF $finalConditions THEN $actionsStr';
  }
}
