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
  test('Contador CTU liga a bobina apos 3 pulsos de borda de subida', () {
    final tagInput = Tag(id: 'T_IN', name: 'Input', type: TagType.bool, initialValue: TagValue.boolean(false));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false));

    final nodeNO = LadderNode(id: 'N1', type: NodeType.contactNO, config: NodeConfig(tagId: 'T_IN'));
    // Preset de 3
    final nodeCTU = LadderNode(id: 'N2', type: NodeType.counterCTU, config: NodeConfig(presetValue: TagValue.integer(3)));
    final nodeCoil = LadderNode(id: 'N3', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));

    // N1 -> N2 -> N3
    final conn1 = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');
    final conn2 = LadderConnection(id: 'C2', fromNodeId: 'N2', fromPort: 'out', toNodeId: 'N3', toPort: 'in');

    final network = LadderNetwork(id: 'NW1', nodes: [nodeNO, nodeCTU, nodeCoil], connections: [conn1, conn2]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);

    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));

    // Pulso 1
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(10); // Desce a borda

    // Pulso 2
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse);
    runtime.tagStore.setBool('T_IN', false);
    runtime.singleScan(10); 

    // Pulso 3
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'No 3o pulso o contador deve ligar a bobina');
  });
}
