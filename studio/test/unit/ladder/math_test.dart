import 'package:endap_studio/ladder/validation/executable_graph.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_connection.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  group('Math Nodes Symbol Tests', () {
    test('Correct symbols for ADD, SUB, MUL, DIV', () {
      final nodeAdd = LadderNode(
        id: 'N1',
        type: NodeType.mathADD,
        config: NodeConfig(tagId: 'VAL_A', presetValue: TagValue.integer(10)),
      );
      final nodeSub = LadderNode(
        id: 'N2',
        type: NodeType.mathSUB,
        config: NodeConfig(tagId: 'VAL_A', presetValue: TagValue.real(5.5)),
      );
      final nodeMul = LadderNode(
        id: 'N3',
        type: NodeType.mathMUL,
        config: NodeConfig(tagId: 'VAL_A', presetValue: TagValue.integer(2)),
      );
      final nodeDiv = LadderNode(
        id: 'N4',
        type: NodeType.mathDIV,
        config: NodeConfig(tagId: 'VAL_A', presetValue: TagValue.integer(4)),
      );

      expect(nodeAdd.symbol, equals('[ ADD VAL_A 10 ]'));
      expect(nodeSub.symbol, equals('[ SUB VAL_A 5.5 ]'));
      expect(nodeMul.symbol, equals('[ MUL VAL_A 2 ]'));
      expect(nodeDiv.symbol, equals('[ DIV VAL_A 4 ]'));
    });
  });

  group('Math Nodes Evaluation Tests', () {
    test('ADD tag + constant -> in-place tag update', () {
      final tagA = Tag(id: 'VAL_A', name: 'Val A', type: TagType.int, initialValue: TagValue.integer(20));
      final tagOut = Tag(id: 'OUT_BOOL', name: 'Out Bool', type: TagType.bool, initialValue: TagValue.boolean(false));

      final nodeAdd = LadderNode(
        id: 'N1',
        type: NodeType.mathADD,
        config: NodeConfig(tagId: 'VAL_A', presetValue: TagValue.integer(15)),
      );
      final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'OUT_BOOL'));
      final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

      final network = LadderNetwork(id: 'NW1', nodes: [nodeAdd, nodeCoil], connections: [conn]);
      final project = LadderProject(id: 'P1', name: 'Test Math', tags: {'VAL_A': tagA, 'OUT_BOOL': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getValue('VAL_A')?.intValue, equals(35), reason: '20 + 15 = 35');
      expect(runtime.tagStore.getBool('OUT_BOOL'), isTrue, reason: 'Power flow passes through math node');
    });

    test('SUB tag - tag -> explicit target tag update', () {
      final tagA = Tag(id: 'VAL_A', name: 'Val A', type: TagType.int, initialValue: TagValue.integer(50));
      final tagB = Tag(id: 'VAL_B', name: 'Val B', type: TagType.int, initialValue: TagValue.integer(18));
      final tagRes = Tag(id: 'VAL_RES', name: 'Result', type: TagType.int, initialValue: TagValue.integer(0));

      final nodeSub = LadderNode(
        id: 'N1',
        type: NodeType.mathSUB,
        config: NodeConfig(
          tagId: 'VAL_A',
          presetValue: TagValue.string('VAL_B'),
          resetTagId: 'VAL_RES',
        ),
      );

      final network = LadderNetwork(id: 'NW1', nodes: [nodeSub]);
      final project = LadderProject(id: 'P1', name: 'Test Sub', tags: {'VAL_A': tagA, 'VAL_B': tagB, 'VAL_RES': tagRes}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getValue('VAL_RES')?.intValue, equals(32), reason: '50 - 18 = 32');
    });

    test('MUL and DIV evaluation', () {
      final tagA = Tag(id: 'VAL_A', name: 'Val A', type: TagType.real, initialValue: TagValue.real(12.0));
      final tagOut = Tag(id: 'OUT_MUL', name: 'Out Mul', type: TagType.real, initialValue: TagValue.real(0.0));

      final nodeMul = LadderNode(
        id: 'N1',
        type: NodeType.mathMUL,
        config: NodeConfig(
          tagId: 'VAL_A',
          presetValue: TagValue.real(2.5),
          resetTagId: 'OUT_MUL',
        ),
      );

      final network = LadderNetwork(id: 'NW1', nodes: [nodeMul]);
      final project = LadderProject(id: 'P1', name: 'Test Mul', tags: {'VAL_A': tagA, 'OUT_MUL': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getValue('OUT_MUL')?.realValue, equals(30.0), reason: '12.0 * 2.5 = 30.0');
    });
  });
}
