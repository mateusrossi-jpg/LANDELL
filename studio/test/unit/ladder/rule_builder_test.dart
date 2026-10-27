import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/executable_graph.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

void main() {
  group('Rule Builder Generated Rules Execution Tests', () {
    test('START -> MOTOR rule evaluates and activates motor when start is high', () {
      final rung = LadderNetwork(
        id: 'rung_1',
        name: 'Quando [START_BTN] ativar -> ligar [MOTOR_M1]',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
        ],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'p1',
        name: 'Test',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
        networks: [rung],
      );
      final validator = GraphValidator();
      final result = validator.validate(project);

      expect(result.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      // Scan with input false
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);

      // Scan with input true
      runtime.tagStore.setValue('START_BTN', TagValue.boolean(true));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);
    });

    test('START -> TON -> VALVE rule delay evaluation', () {
      final rung = LadderNetwork(
        id: 'rung_2',
        name: 'Quando [START_BTN] ativar -> esperar 5s e acionar [VALVE_V204]',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(
            id: 'n2',
            type: NodeType.timerTON,
            config: NodeConfig(tagId: 'T_VALVE', presetValue: TagValue.integer(5000)),
          ),
          LadderNode(id: 'n3', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_V204')),
        ],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'p2',
        name: 'Test TON',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(true)),
          'VALVE_V204': Tag(id: 'VALVE_V204', name: 'Valve', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
        networks: [rung],
      );
      final validator = GraphValidator();
      final result = validator.validate(project);

      expect(result.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      // Cycle before 5s (accumulate 1000ms)
      runtime.singleScan(1000);
      expect(runtime.tagStore.getBool('VALVE_V204'), isFalse);

      // Cycle reaching 5000ms
      runtime.singleScan(4500);
      expect(runtime.tagStore.getBool('VALVE_V204'), isTrue);
    });

    test('SENSOR -> CTU -> ALARM rule pulse counting', () {
      final rung = LadderNetwork(
        id: 'rung_3',
        name: 'Contar 3 pecas e ligar ALARM',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'SENSOR_OPT')),
          LadderNode(
            id: 'n2',
            type: NodeType.counterCTU,
            config: NodeConfig(tagId: 'C_ALARM', presetValue: TagValue.integer(3)),
          ),
          LadderNode(id: 'n3', type: NodeType.coil, config: NodeConfig(tagId: 'ALARM_HORN')),
        ],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'p3',
        name: 'Test CTU',
        tags: {
          'SENSOR_OPT': Tag(id: 'SENSOR_OPT', name: 'Sensor', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'ALARM_HORN': Tag(id: 'ALARM_HORN', name: 'Alarm', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
        networks: [rung],
      );
      final validator = GraphValidator();
      final result = validator.validate(project);

      expect(result.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      // Pulse 1
      runtime.tagStore.setValue('SENSOR_OPT', TagValue.boolean(true));
      runtime.singleScan(10);
      runtime.tagStore.setValue('SENSOR_OPT', TagValue.boolean(false));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM_HORN'), isFalse);

      // Pulse 2
      runtime.tagStore.setValue('SENSOR_OPT', TagValue.boolean(true));
      runtime.singleScan(10);
      runtime.tagStore.setValue('SENSOR_OPT', TagValue.boolean(false));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM_HORN'), isFalse);

      // Pulse 3 -> Target reached
      runtime.tagStore.setValue('SENSOR_OPT', TagValue.boolean(true));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM_HORN'), isTrue);
    });

    test('TEMP > 80 -> TRIP_ALARM comparison rule', () {
      final rung = LadderNetwork(
        id: 'rung_4',
        name: 'Se TEMP_MOTOR > 80 ligar TRIP_ALARM',
        nodes: [
          LadderNode(
            id: 'n1',
            type: NodeType.compareGreater,
            config: NodeConfig(tagId: 'TEMP_MOTOR', presetValue: TagValue.real(80.0)),
          ),
          LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'TRIP_ALARM')),
        ],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'p4',
        name: 'Test Compare',
        tags: {
          'TEMP_MOTOR': Tag(id: 'TEMP_MOTOR', name: 'Temp', type: TagType.real, initialValue: TagValue.real(70.0)),
          'TRIP_ALARM': Tag(id: 'TRIP_ALARM', name: 'Trip', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
        networks: [rung],
      );
      final validator = GraphValidator();
      final result = validator.validate(project);

      expect(result.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));

      // Temp at 70 -> false
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isFalse);

      // Temp at 85 -> true
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(85.0));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isTrue);
    });
  });
}
