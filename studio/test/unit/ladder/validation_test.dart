import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

void main() {
  group('GraphValidator pipeline', () {
    test('Valid: NO -> COIL', () {
      final network = LadderNetwork(id: 'net1');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'START'),
      ));
      network.addNode(LadderNode(
        id: 'node2',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR'),
      ));

      final project = LadderProject(id: 'p1', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isTrue);
      expect(result.executableGraph, isNotNull);
    });

    test('Valid: NO -> TON -> COIL', () {
      final network = LadderNetwork(id: 'net2');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'START'),
      ));
      network.addNode(LadderNode(
        id: 'node2',
        type: NodeType.timerTON,
        config: NodeConfig(tagId: 'TIMER', presetValue: TagValue.integer(5000)),
      ));
      network.addNode(LadderNode(
        id: 'node3',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR'),
      ));

      final project = LadderProject(id: 'p2', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isTrue);
      expect(result.executableGraph, isNotNull);
    });

    test('Valid: NO -> CTU -> TON -> COIL', () {
      final network = LadderNetwork(id: 'net3');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'START'),
      ));
      network.addNode(LadderNode(
        id: 'node2',
        type: NodeType.counterCTU,
        config: NodeConfig(tagId: 'CTU', presetValue: TagValue.integer(10)),
      ));
      network.addNode(LadderNode(
        id: 'node3',
        type: NodeType.timerTON,
        config: NodeConfig(tagId: 'TON', presetValue: TagValue.integer(5000)),
      ));
      network.addNode(LadderNode(
        id: 'node4',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR'),
      ));

      final project = LadderProject(id: 'p3', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isTrue);
      expect(result.executableGraph, isNotNull);
    });

    test('Invalid: TON alone (no input)', () {
      final network = LadderNetwork(id: 'net4');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.timerTON,
        config: NodeConfig(tagId: 'TON', presetValue: TagValue.integer(5000)),
      ));

      final project = LadderProject(id: 'p4', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('Invalid: COIL alone (no input)', () {
      final network = LadderNetwork(id: 'net5');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR'),
      ));

      final project = LadderProject(id: 'p5', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('Invalid: two NO nodes (no output)', () {
      final network = LadderNetwork(id: 'net6');
      network.addNode(LadderNode(
        id: 'node1',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'A'),
      ));
      network.addNode(LadderNode(
        id: 'node2',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'B'),
      ));

      final project = LadderProject(id: 'p6', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('Invalid: empty rung', () {
      final network = LadderNetwork(id: 'net7');

      final project = LadderProject(id: 'p7', name: 'proj', networks: [network]);
      final result = GraphValidator().validate(project);
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });
   group('LadderProject Serialization', () {
      test('Serialize and Deserialize Project', () {
        final project = LadderProject(id: 'serialized_proj', name: 'Test Serialization');
        final network = LadderNetwork(id: 'net_1', name: 'Rung 1');
        network.addNode(LadderNode(
          id: 'node_1',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'START'),
        ));
        network.addNode(LadderNode(
          id: 'node_2',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'MOTOR'),
        ));
        project.networks.add(network);

        final json = project.toJson();
        final deserialized = LadderProject.fromJson(json);

        expect(deserialized.id, equals(project.id));
        expect(deserialized.name, equals(project.name));
        expect(deserialized.networks.length, equals(1));
        expect(deserialized.networks.first.nodes.length, equals(2));
        expect(deserialized.networks.first.nodes[0].config.tagId, equals('START'));
        expect(deserialized.networks.first.nodes[1].config.tagId, equals('MOTOR'));
      });
    });
  });
}
