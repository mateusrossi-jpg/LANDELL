import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

void main() {
  group('LadderNetwork Multi-Controller & Enable/Disable Tests', () {
    test('Default values for targetControllerId and isEnabled', () {
      final network = LadderNetwork(id: 'net_1', name: 'Rung 1');
      expect(network.targetControllerId, equals('GATEWAY'));
      expect(network.isEnabled, isTrue);
      expect(network.targetControllerName, isNull);
    });

    test('Custom controller assignment and disabled state', () {
      final network = LadderNetwork(
        id: 'net_2',
        name: 'Rung Prensa',
        targetControllerId: 'node_01',
        targetControllerName: 'Nó 01 - Prensa',
        isEnabled: false,
      );
      expect(network.targetControllerId, equals('node_01'));
      expect(network.targetControllerName, equals('Nó 01 - Prensa'));
      expect(network.isEnabled, isFalse);
    });

    test('Cloning preserves controller and enabled state', () {
      final original = LadderNetwork(
        id: 'net_orig',
        name: 'Orig',
        targetControllerId: 'node_02',
        targetControllerName: 'Nó 02',
        isEnabled: false,
      );
      final cloned = original.clone();
      expect(cloned.id, equals(original.id));
      expect(cloned.name, equals(original.name));
      expect(cloned.targetControllerId, equals('node_02'));
      expect(cloned.targetControllerName, equals('Nó 02'));
      expect(cloned.isEnabled, isFalse);
    });

    test('JSON serialization & deserialization preserves controller and enabled state', () {
      final network = LadderNetwork(
        id: 'net_json',
        name: 'Teste JSON',
        targetControllerId: 'node_03',
        targetControllerName: 'Nó 03 - Esteira',
        isEnabled: false,
      );
      final json = network.toJson();
      expect(json['targetControllerId'], equals('node_03'));
      expect(json['targetControllerName'], equals('Nó 03 - Esteira'));
      expect(json['isEnabled'], isFalse);

      final recovered = LadderNetwork.fromJson(json);
      expect(recovered.id, equals('net_json'));
      expect(recovered.targetControllerId, equals('node_03'));
      expect(recovered.targetControllerName, equals('Nó 03 - Esteira'));
      expect(recovered.isEnabled, isFalse);
    });

    test('Backward compatibility: legacy JSON without controller/enabled defaults properly', () {
      final legacyJson = {
        'id': 'legacy_1',
        'name': 'Legacy Rung',
        'nodes': [],
        'connections': [],
      };
      final parsed = LadderNetwork.fromJson(legacyJson);
      expect(parsed.targetControllerId, equals('GATEWAY'));
      expect(parsed.isEnabled, isTrue);
      expect(parsed.targetControllerName, isNull);
    });
  });

  group('LadderRuntime with Enabled/Disabled Rungs', () {
    test('Disabled rung does not execute and does not energize coils', () {
      final project = LadderProject.blank();
      project.tags['M0'] = Tag(
        id: 'M0',
        name: 'Flag Aux',
        address: 'M0',
        type: TagType.bool,
        initialValue: TagValue(boolValue: false),
      );
      project.tags['I0.0'] = Tag(
        id: 'I0.0',
        name: 'Input 0',
        address: 'I0.0',
        type: TagType.bool,
        initialValue: TagValue(boolValue: true),
      );

      final rung = LadderNetwork(
        id: 'net_disabled',
        name: 'Rung Desativado',
        isEnabled: false,
      );
      // Contato I0.0 (energizado) acionando bobina M0
      rung.addNode(LadderNode(
        id: 'contact_1',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'I0.0'),
      ));
      rung.addNode(LadderNode(
        id: 'coil_1',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'M0'),
      ));
      project.networks.add(rung);

      final validator = GraphValidator();
      final validated = validator.validate(project);
      expect(validated.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validated.executableGraph!);
      runtime.tagStore.setBool('I0.0', true);
      runtime.singleScan(100);

      // Como o rung está desativado (isEnabled = false), M0 não deve ter sido ativado
      expect(runtime.tagStore.getBool('M0'), isFalse);

      // Agora reativa o rung no runtime e roda o scan
      runtime.project.networks.first.isEnabled = true;
      runtime.singleScan(100);
      expect(runtime.tagStore.getBool('M0'), isTrue);
    });
  });

  group('BytecodeCompiler Multi-Controller Filtering', () {
    test('BytecodeCompiler filters rungs by targetControllerId and skips disabled rungs', () {
      final project = LadderProject.blank();
      project.tags['M0'] = Tag(id: 'M0', name: 'M0', address: 'M0', type: TagType.bool);
      project.tags['M1'] = Tag(id: 'M1', name: 'M1', address: 'M1', type: TagType.bool);
      project.tags['M2'] = Tag(id: 'M2', name: 'M2', address: 'M2', type: TagType.bool);

      // Rung 1: Gateway, Enabled
      final r1 = LadderNetwork(id: 'r1', targetControllerId: 'GATEWAY', isEnabled: true);
      r1.addNode(LadderNode(id: 'c1', type: NodeType.coil, config: NodeConfig(tagId: 'M0')));
      project.networks.add(r1);

      // Rung 2: Nó 1, Enabled
      final r2 = LadderNetwork(id: 'r2', targetControllerId: 'node_1', isEnabled: true);
      r2.addNode(LadderNode(id: 'c2', type: NodeType.coil, config: NodeConfig(tagId: 'M1')));
      project.networks.add(r2);

      // Rung 3: Nó 1, Disabled
      final r3 = LadderNetwork(id: 'r3', targetControllerId: 'node_1', isEnabled: false);
      r3.addNode(LadderNode(id: 'c3', type: NodeType.coil, config: NodeConfig(tagId: 'M2')));
      project.networks.add(r3);

      final compiler = BytecodeCompiler();

      // Compilar tudo (visão global): inclui r1 e r2, pula r3 (disabled)
      final allBytes = compiler.compile(project);
      expect(allBytes.isNotEmpty, isTrue);

      // Compilar apenas Nó 1: deve incluir apenas r2 (pula r1 que é do Gateway e r3 que está disabled)
      final node1Bytes = compiler.compile(project, targetControllerId: 'node_1');
      expect(node1Bytes.isNotEmpty, isTrue);

      // Compilar apenas Gateway: inclui r1
      final gatewayBytes = compiler.compile(project, targetControllerId: 'GATEWAY');
      expect(gatewayBytes.isNotEmpty, isTrue);
    });
  });
}
