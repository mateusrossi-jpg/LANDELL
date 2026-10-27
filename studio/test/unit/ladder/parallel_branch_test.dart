import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

void main() {
  group('Parallel Branch Evaluation Tests', () {
    test('OR Logic: parallel branch with two paths activates output coil if either is true', () {
      final project = LadderProject(id: 'test_proj', name: 'Test Parallel');

      // Setup tags
      project.tags['I0.0'] = Tag(id: 'I0.0', name: 'I0.0', type: TagType.bool, initialValue: TagValue.boolean(false));
      project.tags['I0.1'] = Tag(id: 'I0.1', name: 'I0.1', type: TagType.bool, initialValue: TagValue.boolean(false));
      project.tags['O0.0'] = Tag(id: 'O0.0', name: 'O0.0', type: TagType.bool, initialValue: TagValue.boolean(false));

      // Parallel node
      final parallelNode = LadderNode(
        id: 'parallel_block',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [
            LadderNode(id: 'branch1_contact', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')),
          ],
          [
            LadderNode(id: 'branch2_contact', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.1')),
          ],
        ],
      );

      final coilNode = LadderNode(id: 'coil_output', type: NodeType.coil, config: NodeConfig(tagId: 'O0.0'));

      final network = LadderNetwork(id: 'net_1', nodes: [parallelNode, coilNode]);
      network.rebuildConnections();
      project.networks.add(network);

      final validator = GraphValidator();
      final validationResult = validator.validate(project);
      expect(validationResult.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validationResult.executableGraph!);

      // Scenario 1: Both inputs false -> output false
      runtime.tagStore.setBool('I0.0', false);
      runtime.tagStore.setBool('I0.1', false);
      runtime.singleScan(0);
      expect(runtime.tagStore.getBool('O0.0'), isFalse);

      // Scenario 2: First input true -> output true
      runtime.tagStore.setBool('I0.0', true);
      runtime.tagStore.setBool('I0.1', false);
      runtime.singleScan(0);
      expect(runtime.tagStore.getBool('O0.0'), isTrue);

      // Scenario 3: Second input true -> output true
      runtime.tagStore.setBool('I0.0', false);
      runtime.tagStore.setBool('I0.1', true);
      runtime.singleScan(0);
      expect(runtime.tagStore.getBool('O0.0'), isTrue);
    });
  });
}
