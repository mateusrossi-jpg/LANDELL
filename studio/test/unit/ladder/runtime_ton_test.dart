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
  // Helper to build a minimal project with a TON timer
  LadderRuntime setupRuntime({required int presetMs, required bool inputInitially}) {
    final tagInput = Tag(id: 'T_IN', name: 'Input', type: TagType.bool, initialValue: TagValue.boolean(inputInitially));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

    final nodeNO = LadderNode(id: 'N1', type: NodeType.contactNO, config: NodeConfig(tagId: 'T_IN'));
    final nodeTON = LadderNode(id: 'N2', type: NodeType.timerTON, config: NodeConfig(presetValue: TagValue.integer(presetMs)));
    final nodeCoil = LadderNode(id: 'N3', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));

    final conn1 = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');
    final conn2 = LadderConnection(id: 'C2', fromNodeId: 'N2', fromPort: 'out', toNodeId: 'N3', toPort: 'in');

    final network = LadderNetwork(id: 'NW1', nodes: [nodeNO, nodeTON, nodeCoil], connections: [conn1, conn2]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);

    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));
    return runtime;
  }

  test('TON does not trigger before preset', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(50);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: 'Should not be true before 100ms');
  });

  test('TON triggers exactly at preset', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'Should be true at 100ms');
  });

  test('TON remains energized after preset while input stays true', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(120);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    runtime.singleScan(30);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'Output should stay true while input stays energized');
  });

  test('TON resets when input becomes false', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(120);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: 'Output should reset when input is cleared');
  });

  test('TON accumulates correctly over multiple small scans', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: false);
    runtime.tagStore.setBool('T_IN', true);
    for (int i = 0; i < 5; i++) {
      runtime.singleScan(20);
    }
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'Accumulated 5 * 20ms should reach preset');
  });
}
