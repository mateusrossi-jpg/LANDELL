import 'package:endap_studio/ladder/validation/executable_graph.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  test('A Bobina (Coil) copia o fluxo de energia da porta de entrada e escreve na Tag', () {
    final tagOutput = Tag(id: 'T_OUT', name: 'Output 1', type: TagType.bool, initialValue: TagValue.boolean(false));

    // A bobina conectada diretamente ao barramento esquerdo (sem nenhum nó antes dela) recebe powerFlow = true
    final nodeCoil = LadderNode(id: 'N1', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));

    final network = LadderNetwork(id: 'NW1', nodes: [nodeCoil], connections: []);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_OUT': tagOutput}, networks: [network]);

    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));

    expect(runtime.tagStore.getBool('T_OUT'), isFalse);

    // Scan Inicial. Como N1 nao tem input connections, inPowerFlow = true
    runtime.singleScan(10);
    
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'A bobina deve ser ativada e alterar a Tag');
  });
}
