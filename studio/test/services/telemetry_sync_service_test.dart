import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';

void main() {
  group('TelemetrySyncService Unit Tests', () {
    late LadderProject project;
    late LadderRuntime runtime;
    late TelemetrySyncService service;

    setUp(() {
      // Cria projeto com lógica simples X0 -> (Y0)
      project = LadderProject(
        id: 'test_proj',
        name: 'Test Project',
        tags: {
          'START_BTN': Tag(
            id: 'START_BTN',
            name: 'START_BTN',
            type: TagType.bool,
            address: 'X0',
            initialValue: TagValue.boolean(false),
          ),
          'MOTOR_M1': Tag(
            id: 'MOTOR_M1',
            name: 'MOTOR_M1',
            type: TagType.bool,
            address: 'Y0',
            initialValue: TagValue.boolean(false),
          ),
        },
        networks: [
          LadderNetwork(
            id: 'net_1',
            nodes: [
              LadderNode(
                id: 'n_x0',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'START_BTN'),
              ),
              LadderNode(
                id: 'n_y0',
                type: NodeType.coil,
                config: NodeConfig(tagId: 'MOTOR_M1'),
              ),
            ],
          )..rebuildConnections(),
        ],
      );

      runtime = LadderRuntime();
      final valResult = GraphValidator().validate(project);
      expect(valResult.isValid, isTrue);
      runtime.loadProject(valResult.executableGraph!);

      service = TelemetrySyncService.instance;
      service.stop();
      service.init(project: project, runtime: runtime, gatewayIp: '192.168.4.1');
    });

    tearDown(() {
      service.stop();
    });

    test('1 & 2: JSON X0 = 1 -> true e X0 = 0 -> false via TagStateStore e Ladder', () {
      // Processa X0 = 1
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': 1}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
      // Ladder executou e acionou Y0
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);

      // Processa X0 = 0
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': 0}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isFalse);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
    });

    test('3 & 4: JSON X0 = true -> true e X0 = false -> false (tipos booleanos)', () {
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': true}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);

      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': false}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isFalse);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
    });

    test('5: Atualizacao do TagStateStore reflete corretamente', () {
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': 1}
        ],
        'outputs': [
          {'name': 'Y0', 'value': 1}
        ]
      });

      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
    });

    test('6: Erro HTTP marca estado como OFFLINE', () async {
      service.httpClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final success = await service.pollOnce();
      expect(success, isFalse);
      expect(service.status, equals(TelemetryConnectionStatus.offline));
      expect(service.isOnline, isFalse);
    });

    test('6b: Sucesso HTTP marca estado como ONLINE', () async {
      service.httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'inputs': [
              {'name': 'X0', 'value': 1}
            ],
            'outputs': []
          }),
          200,
        );
      });

      final success = await service.pollOnce();
      expect(success, isTrue);
      expect(service.status, equals(TelemetryConnectionStatus.online));
      expect(service.isOnline, isTrue);
      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
    });

    test('7: Tag em FORCE nao e sobrescrita pela telemetria', () {
      // Forca START_BTN como FALSE
      runtime.tagStore.forceBool('START_BTN', false);
      expect(runtime.tagStore.isForced('START_BTN'), isTrue);

      // Telemetria recebe X0 = 1 (true)
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': 1}
        ],
        'outputs': []
      });

      // Permanece FALSE devido ao FORCE
      expect(runtime.tagStore.getBool('START_BTN'), isFalse);

      // Libera forca
      runtime.tagStore.releaseForce('START_BTN');
      expect(runtime.tagStore.isForced('START_BTN'), isFalse);

      // Agora a telemetria passa a atualizar
      service.processIoMapJson({
        'inputs': [
          {'name': 'X0', 'value': 1}
        ],
        'outputs': []
      });
      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
    });

    test('8: Polling nao cria multiplas instancias / timers concorrentes', () {
      service.start(interval: const Duration(milliseconds: 100));
      expect(service.isPolling, isTrue);

      // Chamar start novamente deve reiniciar de forma limpa sem timers duplicados
      service.start(interval: const Duration(milliseconds: 200));
      expect(service.isPolling, isTrue);

      service.stop();
      expect(service.isPolling, isFalse);
    });

    test('9: Firmware real payload mapping via channel_id (IN1 com channel_id: 10 -> X0)', () {
      // O firmware envia channel_id: 10 e name: "IN1".
      // START_BTN tem address: 'X0'. Deve casar pelo channel_id 10 -> X0.
      service.processIoMapJson({
        'inputs': [
          {'id': 10, 'channel_id': 10, 'name': 'IN1', 'value': 1}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);

      service.processIoMapJson({
        'inputs': [
          {'id': 10, 'channel_id': 10, 'name': 'IN1', 'value': 0}
        ],
        'outputs': []
      });

      expect(runtime.tagStore.getBool('START_BTN'), isFalse);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
    });

    test('10: Output real payload mapping via channel_id (OUT102 com channel_id: 101 -> Y1)', () {
      // Adiciona uma tag de saída independente (Y1) sem bobina/network controlando-a
      project.tags['OUT_STATUS'] = Tag(
        id: 'OUT_STATUS',
        name: 'OUT_STATUS',
        type: TagType.bool,
        address: 'Y1',
        initialValue: TagValue.boolean(false),
      );

      // O firmware envia channel_id: 101 e name: "OUT102".
      // OUT_STATUS tem address: 'Y1'. Deve casar pelo channel_id 101 -> Y1.
      service.processIoMapJson({
        'inputs': [],
        'outputs': [
          {'id': 101, 'channel_id': 101, 'name': 'OUT102', 'value': 1}
        ]
      });

      expect(runtime.tagStore.getBool('OUT_STATUS'), isTrue);

      service.processIoMapJson({
        'inputs': [],
        'outputs': [
          {'id': 101, 'channel_id': 101, 'name': 'OUT102', 'value': 0}
        ]
      });

      expect(runtime.tagStore.getBool('OUT_STATUS'), isFalse);
    });

    test('11: Limites canônicos X0 (10), X15 (25), Y0 (100), Y15 (115)', () {
      // Adiciona tags X15 e Y15 ao projeto
      project.tags['TAG_X15'] = Tag(
        id: 'TAG_X15',
        name: 'TAG_X15',
        type: TagType.bool,
        address: 'X15',
        initialValue: TagValue.boolean(false),
      );
      project.tags['TAG_Y15'] = Tag(
        id: 'TAG_Y15',
        name: 'TAG_Y15',
        type: TagType.bool,
        address: 'Y15',
        initialValue: TagValue.boolean(false),
      );

      service.processIoMapJson({
        'inputs': [
          {'channel_id': 25, 'name': 'IN16', 'value': 1}
        ],
        'outputs': [
          {'channel_id': 115, 'name': 'OUT116', 'value': 1}
        ]
      });

      expect(runtime.tagStore.getBool('TAG_X15'), isTrue);
      expect(runtime.tagStore.getBool('TAG_Y15'), isTrue);
    });

    test('12: channel_id fora do range canônico e canais inválidos são ignorados', () {
      // Valores fora do range (ex: 9, 26, 99, 116) não devem causar exceção nem alterar tags indevidas
      service.processIoMapJson({
        'inputs': [
          {'channel_id': 9, 'name': 'UNKNOWN_9', 'value': 1},
          {'channel_id': 26, 'name': 'UNKNOWN_26', 'value': 1},
        ],
        'outputs': [
          {'channel_id': 99, 'name': 'UNKNOWN_99', 'value': 1},
          {'channel_id': 116, 'name': 'UNKNOWN_116', 'value': 1},
        ]
      });

      expect(runtime.tagStore.getBool('START_BTN'), isFalse);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
    });

    test('13: Multi-controlador — I0.x (ctrl 0) e I1.x (ctrl 1) geram IDs globais distintos', () {
      // Primário: I0.0 -> 10. Secundário: I1.0 -> 18 (bytes distintos).
      expect(project.getTagAddress('I0.0'), equals(10));
      expect(project.getTagAddress('I1.0'), equals(18));
      expect(project.getTagAddress('I0.0'), isNot(equals(project.getTagAddress('I1.0'))));

      // Saídas: Q0.0 -> 100, Q1.0 -> 108.
      expect(project.getTagAddress('Q0.0'), equals(100));
      expect(project.getTagAddress('Q1.0'), equals(108));

      // Tag do controlador 2: address I1.0, controllerId '1' (índice 1).
      project.tags['SENSOR_CTRL2'] = Tag(
        id: 'SENSOR_CTRL2',
        name: 'SENSOR_CTRL2',
        type: TagType.bool,
        address: 'I1.0',
        controllerId: '1',
        initialValue: TagValue.boolean(false),
      );
      expect(project.tags['SENSOR_CTRL2']!.controllerIndex, equals(1));
      expect(project.getTagAddress('SENSOR_CTRL2'), equals(18));
    });

    test('14: Multi-controlador — telemetria do controlador 2 desloca canais locais p/ byte 1', () {
      project.tags['SENSOR_CTRL2'] = Tag(
        id: 'SENSOR_CTRL2',
        name: 'SENSOR_CTRL2',
        type: TagType.bool,
        address: 'I1.0', // canal físico local 10 do nó 2 rode no espaço global 18 = I1.0
        initialValue: TagValue.boolean(false),
      );
      // O nó 2 reporta SEUS canais locais (channel_id 10). Com controllerIndex 1,
      // o canal local 10 é deslocado para o byte global 1 -> I1.0 (id 18).
      service.processIoMapJson({
        'inputs': [
          {'channel_id': 10, 'name': 'IN1', 'value': 1}
        ],
        'outputs': [],
      }, controllerIndex: 1);

      expect(runtime.tagStore.getBool('SENSOR_CTRL2'), isTrue);
      // O canal local do primário (I0.0, X0) não é afetado pelo nó secundário.
      expect(runtime.tagStore.getBool('START_BTN'), isFalse);
    });

    test('15: Multi-controlador — pollOnce consulta todos os controladores da lista', () async {
      project.tags['SENSOR_CTRL2'] = Tag(
        id: 'SENSOR_CTRL2',
        name: 'SENSOR_CTRL2',
        type: TagType.bool,
        address: 'I1.0',
        initialValue: TagValue.boolean(false),
      );

      final requested = <String>[];
      service.init(project: project, runtime: runtime, gatewayIp: '192.168.0.27');
      service.updateControllerIps(['192.168.0.27', '192.168.0.12']);
      service.httpClient = MockClient((request) async {
        requested.add(request.url.host);
        // Ambos respondem io/map; cada um com seu canal local 10.
        return http.Response(
          jsonEncode({
            'inputs': [
              {'channel_id': 10, 'name': 'IN1', 'value': 1}
            ],
            'outputs': [],
          }),
          200,
        );
      });

      final ok = await service.pollOnce();
      expect(ok, isTrue);
      expect(requested, containsAll(['192.168.0.27', '192.168.0.12']));
      // Gateway (índice 0): local 10 -> I0.0. Nó 2 (índice 1): local 10 -> I1.0.
      expect(runtime.tagStore.getBool('START_BTN'), isTrue);
      expect(runtime.tagStore.getBool('SENSOR_CTRL2'), isTrue);
      expect(service.status, equals(TelemetryConnectionStatus.online));
    });

    test('16: Multi-controlador — primário offline deixa status offline mas nó 2 é consultado', () async {
      service.init(project: project, runtime: runtime, gatewayIp: '192.168.0.27');
      service.updateControllerIps(['192.168.0.27', '192.168.0.12']);
      service.httpClient = MockClient((request) async {
        if (request.url.host == '192.168.0.27') {
          return http.Response('Not Found', 404);
        }
        return http.Response(
          jsonEncode({
            'inputs': [
              {'channel_id': 10, 'name': 'IN1', 'value': 0}
            ],
            'outputs': [],
          }),
          200,
        );
      });

      final ok = await service.pollOnce();
      expect(ok, isTrue, reason: 'nó 2 online ainda responde');
      expect(service.status, equals(TelemetryConnectionStatus.offline),
          reason: 'status global reflete conectividade do primário');
    });

    test('17: Tag serializa e restaura controllerId', () {
      project.tags['SENSOR_CTRL2'] = Tag(
        id: 'SENSOR_CTRL2',
        name: 'SENSOR_CTRL2',
        type: TagType.bool,
        address: 'I1.0',
        controllerId: '1',
        initialValue: TagValue.boolean(false),
      );
      final restored = Tag.fromJson(project.tags['SENSOR_CTRL2']!.toJson());
      expect(restored.controllerId, equals('1'));
      expect(restored.controllerIndex, equals(1));

      final clone = project.tags['SENSOR_CTRL2']!.clone();
      expect(clone.controllerId, equals('1'));
    });
  });
}
