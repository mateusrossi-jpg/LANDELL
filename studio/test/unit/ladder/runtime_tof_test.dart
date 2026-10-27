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
  // Helper to build a minimal project with a TOF timer
  LadderRuntime setupRuntime({required int presetMs, required bool inputInitially}) {
    final tagInput = Tag(id: 'T_IN', name: 'Input', type: TagType.bool, initialValue: TagValue.boolean(inputInitially));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

    final nodeNO = LadderNode(id: 'N1', type: NodeType.contactNO, config: NodeConfig(tagId: 'T_IN'));
    final nodeTOF = LadderNode(id: 'N2', type: NodeType.timerTOF, config: NodeConfig(presetValue: TagValue.integer(presetMs)));
    final nodeCoil = LadderNode(id: 'N3', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));

    final conn1 = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');
    final conn2 = LadderConnection(id: 'C2', fromNodeId: 'N2', fromPort: 'out', toNodeId: 'N3', toPort: 'in');

    final network = LadderNetwork(id: 'NW1', nodes: [nodeNO, nodeTOF, nodeCoil], connections: [conn1, conn2]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);

    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));
    return runtime;
  }

  test('TOF is immediately true when input is true', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'TOF output should turn true immediately on input');
  });

  test('TOF stays true after input becomes false for less than preset', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);

    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(50);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'TOF output should stay true for 100ms after input is removed');
  });

  test('TOF becomes false after preset duration expires', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: true);
    runtime.singleScan(10);
    
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(50);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    
    runtime.singleScan(50); // Total 100ms
    expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: 'TOF output should turn false after preset duration expires');
  });

  test('TOF resets delay timer if input becomes true again', () {
    final runtime = setupRuntime(presetMs: 100, inputInitially: true);
    runtime.singleScan(10);
    
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(60);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    
    // Set input true again
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue);
    
    // Set input false again, should need another 100ms
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(60);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'Timer should have reset and still be true');
    
    runtime.singleScan(45); // Total 105ms
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
  });
}
