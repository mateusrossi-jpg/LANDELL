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

Tag _boolTag(String id, String address) => Tag(
      id: id,
      name: id,
      type: TagType.bool,
      address: address,
      initialValue: TagValue.boolean(false),
    );

void main() {
  group('Telemetria: SET/RESET em modo Hardware', () {
    late LadderProject project;
    late LadderRuntime runtime;
    late TelemetrySyncService service;
    final requests = <Uri>[];

    setUp(() {
      project = LadderProject(
        id: 'latch',
        name: 'Latch',
        tags: {
          'I0.0': _boolTag('I0.0', 'I0.0'),
          'I0.1': _boolTag('I0.1', 'I0.1'),
          'Q0.0': _boolTag('Q0.0', 'Q0.0'),
        },
        networks: [
          LadderNetwork(
            id: 'n_set',
            nodes: [
              LadderNode(
                id: 'c_set',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'I0.0'),
              ),
              LadderNode(
                id: 'k_set',
                type: NodeType.coilSet,
                config: NodeConfig(tagId: 'Q0.0'),
              ),
            ],
          )..rebuildConnections(),
          LadderNetwork(
            id: 'n_rst',
            nodes: [
              LadderNode(
                id: 'c_rst',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'I0.1'),
              ),
              LadderNode(
                id: 'k_rst',
                type: NodeType.coilReset,
                config: NodeConfig(tagId: 'Q0.0'),
              ),
            ],
          )..rebuildConnections(),
        ],
      );

      runtime = LadderRuntime();
      final res = GraphValidator().validate(project);
      expect(res.isValid, isTrue);
      runtime.loadProject(res.executableGraph!);

      requests.clear();
      service = TelemetrySyncService.instance;
      service.stop();
      service.httpClient = MockClient((request) async {
        requests.add(request.url);
        return http.Response('OK', 200);
      });
      service.init(project: project, runtime: runtime, gatewayIp: '192.168.4.1');
    });

    tearDown(() => service.stop());

    Map<String, dynamic> ioMap({required int i0, required int i1, required int q0, bool forced = false}) => {
          'inputs': [
            {'channel_id': 10, 'name': 'I0.0', 'state': i0},
            {'channel_id': 11, 'name': 'I0.1', 'state': i1},
          ],
          'outputs': [
            {'channel_id': 100, 'name': 'Q0.0', 'desired': q0, 'state': q0, 'forced': forced},
          ],
        };

    test('Reset vindo do hardware (0) desarma a saida retida e nao e reforcada', () {
      service.processIoMapJson(ioMap(i0: 1, i1: 0, q0: 1));
      expect(runtime.tagStore.getBool('Q0.0'), isTrue);

      // Botao fisico de reset: entrada I0.0 solta, I0.1 acionada, ESP32 reporta saida 0
      service.processIoMapJson(ioMap(i0: 0, i1: 1, q0: 0));
      expect(runtime.tagStore.getBool('Q0.0'), isFalse);

      // Nenhum comando de forcar saida (/api/set com value) pode ser enviado ao ESP32
      expect(requests.where((u) => u.path == '/api/set' && u.queryParameters.containsKey('value')), isEmpty);
    });

    test('Saida Ladder travada por forcamento antigo e liberada no ESP32', () async {
      service.processIoMapJson(ioMap(i0: 0, i1: 0, q0: 0, forced: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        requests.any((u) =>
            u.path == '/api/set' &&
            u.queryParameters['id'] == '100' &&
            u.queryParameters['action'] == 'release'),
        isTrue,
      );
    });

    test('init sem IP preserva status online (LED nao cai ao trocar de modo)', () async {
      service.httpClient = MockClient((request) async {
        return http.Response(jsonEncode(ioMap(i0: 0, i1: 0, q0: 0)), 200);
      });
      await service.pollOnce();
      expect(service.isOnline, isTrue);

      service.pause();
      service.init(project: project, runtime: runtime);
      expect(service.isOnline, isTrue);
      expect(service.gatewayIp, equals('192.168.4.1'));
    });
  });
}
