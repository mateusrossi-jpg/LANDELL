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
  test('Contato Normalmente Aberto (NO) energiza a bobina quando a tag eh verdadeira', () {
    // 1. Criar Tags
    final tagInput = Tag(id: 'T_IN', name: 'Input 1', type: TagType.bool, initialValue: TagValue.boolean(false));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output 1', type: TagType.bool, initialValue: TagValue.boolean(false));

    // 2. Criar Nodes
    final nodeNO = LadderNode(id: 'N1', type: NodeType.contactNO, config: NodeConfig(tagId: 'T_IN'));
    final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));

    // 3. Criar Conexoes (N1 -> N2)
    final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

    // 4. Montar a Network e o Projeto
    final network = LadderNetwork(id: 'NW1', nodes: [nodeNO, nodeCoil], connections: [conn]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);

    // 5. Inicializar Runtime
    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));

    // Scan Inicial (T_IN = false)
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: 'A bobina deve estar desligada');

    // Atualiza Entrada e roda novo Scan
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'A bobina deve estar ligada');
  });

  test('Contato Normalmente Fechado (NC) energiza a bobina quando a tag eh falsa', () {
    final tagInput = Tag(id: 'T_IN', name: 'Input 1', type: TagType.bool, initialValue: TagValue.boolean(false));
    final tagOutput = Tag(id: 'T_OUT', name: 'Output 1', type: TagType.bool, initialValue: TagValue.boolean(false));

    final nodeNC = LadderNode(id: 'N1', type: NodeType.contactNC, config: NodeConfig(tagId: 'T_IN'));
    final nodeCoil = LadderNode(id: 'N2', type: NodeType.coil, config: NodeConfig(tagId: 'T_OUT'));
    final conn = LadderConnection(id: 'C1', fromNodeId: 'N1', fromPort: 'out', toNodeId: 'N2', toPort: 'in');

    final network = LadderNetwork(id: 'NW1', nodes: [nodeNC, nodeCoil], connections: [conn]);
    final project = LadderProject(id: 'P1', name: 'Test', tags: {'T_IN': tagInput, 'T_OUT': tagOutput}, networks: [network]);

    final runtime = LadderRuntime();
    runtime.loadProject(ExecutableGraph.validated(project));

    // Scan Inicial (T_IN = false, NC entao passa energia)
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isTrue, reason: 'NC com entrada falsa deve ligar a bobina');

    // Atualiza Entrada
    runtime.tagStore.setBool('T_IN', true);
    runtime.singleScan(10);
    expect(runtime.tagStore.getBool('T_OUT'), isFalse, reason: 'NC com entrada verdadeira deve desligar a bobina');
  });
}
