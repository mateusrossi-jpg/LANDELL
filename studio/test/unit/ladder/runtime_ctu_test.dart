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
  LadderRuntime setupRuntime({required int preset, required bool inputInitially}) {
    final tagInput = Tag(id: 'T_IN', name: 'Input', type: TagType.bool, initialValue: TagValue.boolean(inputInitially));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));
    final nodeNO = LadderNode(id: 'N1', type: NodeType.contactNO, config: NodeConfig(tagId: 'T_IN'));
    final nodeCTU = LadderNode(id: 'N2', type: NodeType.counterCTU, config: NodeConfig(presetValue: TagValue.integer(preset)));
    final nodeCoil = LadderNode(id: 'N3', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
    final conn1 = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');
    final conn2 = LadderConnection(id: 'C2', fromNodeId: 'N2', fromPort: 'out', toNodeId: 'N3', toPort: 'in');
    final network = LadderNetwork(id: 'NW1', nodes: [nodeNO, nodeCTU, nodeCoil], connections: [conn1, conn2]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);
    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));
    return runtime;
  }

  test('CTU does not trigger before preset', () {
    final runtime = setupRuntime(preset: 3, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
  });

  test('CTU counts only rising edge', () {
    final runtime = setupRuntime(preset: 3, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(10);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
  });

  test('CTU accumulates multiple rising edges and triggers at preset', () {
    final runtime = setupRuntime(preset: 3, inputInitially: false);
    for (int i = 0; i < 3; i++) {
      runtime.tagStore.setBool('T_IN', true);
      runtime.singleScan(10);
      runtime.tagStore.setBool('T_IN', false);
      runtime.singleScan(10);
    }
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
  });

  test('CTU output stays true after reaching preset', () {
    final runtime = setupRuntime(preset: 3, inputInitially: false);
    for (int i = 0; i < 3; i++) {
      runtime.tagStore.setBool('T_IN', true);
      runtime.singleScan(10);
      runtime.tagStore.setBool('T_IN', false);
      runtime.singleScan(10);
    }
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
  });

  test('CTU reset clears count and output', () {
    final runtime = setupRuntime(preset: 3, inputInitially: false);
    for (int i = 0; i < 3; i++) {
      runtime.tagStore.setBool('T_IN', true);
      runtime.singleScan(10);
      runtime.tagStore.setBool('T_IN', false);
      runtime.singleScan(10);
    }
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    final nodeCTU = runtime.project.networks.first.nodes.firstWhere((n) => n.type == NodeType.counterCTU);
    nodeCTU.config.resetTagId = 'T_IN';
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
  });
}
