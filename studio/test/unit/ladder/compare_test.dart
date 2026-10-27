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
  group('Comparison Nodes Symbol Tests', () {
    test('Correct symbols for EQU, GRT, LES', () {
      final nodeEqu = LadderNode(
        id: 'N1',
        type: NodeType.compareEqual,
        config: NodeConfig(tagId: 'T_A', presetValue: TagValue.integer(10)),
      );
      final nodeGrt = LadderNode(
        id: 'N2',
        type: NodeType.compareGreater,
        config: NodeConfig(tagId: 'T_A', presetValue: TagValue.real(5.5)),
      );
      final nodeLes = LadderNode(
        id: 'N3',
        type: NodeType.compareLess,
        config: NodeConfig(tagId: 'T_A', presetValue: TagValue.string('T_B')),
      );

      expect(nodeEqu.symbol, equals('[ EQU T_A 10 ]'));
      expect(nodeGrt.symbol, equals('[ GRT T_A 5.5 ]'));
      expect(nodeLes.symbol, equals('[ LES T_A T_B ]'));
    });
  });

  group('Comparison Nodes Evaluation Tests', () {
    test('EQU tag vs constant', () {
      final tagA = Tag(id: 'T_A', name: 'Tag A', type: TagType.int, initialValue: TagValue.integer(10));
      final tagOut = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

      final nodeEqu = LadderNode(id: 'N1', type: NodeType.compareEqual, config: NodeConfig(tagId: 'T_A', presetValue: TagValue.integer(10)));
      final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
      final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

      final network = LadderNetwork(id: 'NW1', nodes: [nodeEqu, nodeCoil], connections: [conn]);
      final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_A': tagA, 'T_OUT': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: '10 == 10 should be true');

      runtime.tagStore.setValue('T_A', TagValue.integer(5));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: '5 == 10 should be false');
    });

    test('GRT tag vs tag', () {
      final tagA = Tag(id: 'T_A', name: 'Tag A', type: TagType.real, initialValue: TagValue.real(15.5));
      final tagB = Tag(id: 'T_B', name: 'Tag B', type: TagType.real, initialValue: TagValue.real(10.0));
      final tagOut = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

      final nodeGrt = LadderNode(id: 'N1', type: NodeType.compareGreater, config: NodeConfig(tagId: 'T_A', presetValue: TagValue.string('T_B')));
      final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
      final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

      final network = LadderNetwork(id: 'NW1', nodes: [nodeGrt, nodeCoil], connections: [conn]);
      final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_A': tagA, 'T_B': tagB, 'T_OUT': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: '15.5 > 10.0 should be true');

      runtime.tagStore.setValue('T_B', TagValue.real(20.0));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: '15.5 > 20.0 should be false');
    });

    test('LES tag vs constant', () {
      final tagA = Tag(id: 'T_A', name: 'Tag A', type: TagType.int, initialValue: TagValue.integer(5));
      final tagOut = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

      final nodeLes = LadderNode(id: 'N1', type: NodeType.compareLess, config: NodeConfig(tagId: 'T_A', presetValue: TagValue.integer(10)));
      final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
      final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

      final network = LadderNetwork(id: 'NW1', nodes: [nodeLes, nodeCoil], connections: [conn]);
      final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_A': tagA, 'T_OUT': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: '5 < 10 should be true');

      runtime.tagStore.setValue('T_A', TagValue.integer(10));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: '10 < 10 should be false');
    });

    test('Boolean type coercion comparison', () {
      final tagA = Tag(id: 'T_A', name: 'Tag A', type: TagType.bool, initialValue: TagValue.boolean(true));
      final tagOut = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

      // true (1) == 1
      final nodeEqu = LadderNode(id: 'N1', type: NodeType.compareEqual, config: NodeConfig(tagId: 'T_A', presetValue: TagValue.integer(1)));
      final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
      final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

      final network = LadderNetwork(id: 'NW1', nodes: [nodeEqu, nodeCoil], connections: [conn]);
      final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_A': tagA, 'T_OUT': tagOut}, networks: [network]);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'true (1) == 1 should be true');
    });
  });
}
