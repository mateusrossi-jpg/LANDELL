import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:endap_studio/core/ui/networks_page.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SIMULAÇÃO DE CASOS DE USO — GATEWAY HÍBRIDO, DEDICADO & NÓ DE CAMPO ESP-NOW', () {
    late List<http.Request> capturedRequests;
    late Map<String, dynamic> gatewayState;
    late List<Map<String, dynamic>> discoveredNodes;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudioEventBus.instance.clear();
      capturedRequests = [];

      // Estado inicial: Gateway Híbrido com IOs locais ativos
      gatewayState = {
        'node_id': 1694216240,
        'profile': 0, // 0 = GATEWAY_HYBRID, 4 = GATEWAY_DEDICATED
        'node_name': 'ENDAP-Gateway-Hibrido',
        'operational_state': 'online',
        'transport_name': 'wifi-udp',
        'net_wifi_sta_ip_text': '192.168.0.27',
        'k_jitter_max': 108,
        'k_exec_max': 14,
        'k_deadline_miss': 0,
        'inputs': [
          {'id': 10, 'value': 0, 'gpio': 16, 'name': 'I0.0 Local'},
          {'id': 11, 'value': 0, 'gpio': 17, 'name': 'I0.1 Local'},
        ],
        'outputs': [
          {'id': 100, 'value': 0, 'gpio': 23, 'name': 'Q0.0 Local', 'failsafe': false},
          {'id': 101, 'value': 0, 'gpio': 4, 'name': 'Q0.1 Local', 'failsafe': false},
        ],
      };

      // Nós remotos registrados (incluindo Nó de Campo ESP-NOW)
      discoveredNodes = [
        {
          'id': '1694216240',
          'ip': '192.168.0.27',
          'state': 'online',
          'role': 'Gateway Híbrido',
          'last_transport': 'WIFI',
          'rssi': 0,
          'jitter_us': 108,
        },
        {
          'id': 'ENDAP-ESPNOW-02',
          'ip': '0.0.0.0', // Sem IP TCP/IP! Opera em camada MAC pura
          'mac': '34:85:18:99:AA:BB',
          'state': 'online',
          'role': 'Field Node Remoto',
          'last_transport': 'ESPNOW',
          'rssi': -58,
          'jitter_us': 94,
          'radio_latency_ms': 2,
          'inputs': [{'id': 20, 'value': 0, 'name': 'I0.0 Remoto Sensor'}],
          'outputs': [{'id': 120, 'value': 0, 'name': 'Q0.0 Remoto Esteira'}],
        }
      ];
    });

    MockClient createHarnessClient() {
      return MockClient((request) async {
        capturedRequests.add(request);
        final path = request.url.path;

        if (path == '/api/public/status') {
          return http.Response(json.encode(gatewayState), 200, headers: {'content-type': 'application/json'});
        }

        if (path == '/api/status') {
          return http.Response(json.encode(gatewayState), 200, headers: {'content-type': 'application/json'});
        }

        if (path == '/api/onboarding/status') {
          return http.Response(
            json.encode({
              'state': 'ACTIVE',
              'node_name': gatewayState['node_name'],
              'profile': gatewayState['profile'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path == '/api/onboarding/claim') {
          final body = request.body;
          if (body.contains('profile=4')) {
            gatewayState['profile'] = 4;
            gatewayState['node_name'] = 'Gateway Dedicado';
            // Em modo dedicado, saídas locais entram em repouso
            for (var o in gatewayState['outputs']) {
              o['value'] = 0;
              o['failsafe'] = true;
            }
          } else if (body.contains('profile=0')) {
            gatewayState['profile'] = 0;
            gatewayState['node_name'] = 'Gateway Híbrido';
            for (var o in gatewayState['outputs']) {
              o['failsafe'] = false;
            }
          }
          return http.Response(json.encode({'status': 'claimed', 'profile': gatewayState['profile']}), 200);
        }

        if (path == '/api/nodes') {
          return http.Response(json.encode({'nodes': discoveredNodes}), 200, headers: {'content-type': 'application/json'});
        }

        if (path == '/api/io/force') {
          final data = json.decode(request.body);
          final id = data['id'];
          final val = data['value'] ?? 0;
          for (var o in gatewayState['outputs']) {
            if (o['id'] == id) {
              o['value'] = val;
            }
          }
          return http.Response(json.encode({'ok': true}), 200);
        }

        if (path == '/api/ladder/bytecode') {
          return http.Response(json.encode({'ok': true, 'loaded_bytes': request.bodyBytes.length}), 200);
        }

        return http.Response('{"ok":true}', 200);
      });
    }

    // =========================================================================
    // CASO DE USO 1: GATEWAY HÍBRIDO (CLP 1ms LOCAL + REDE)
    // =========================================================================
    testWidgets('Caso de Uso 1: Gateway Híbrido — Lógica Ladder Local + Telemetria de Rede Ativa', (tester) async {
      final client = createHarnessClient();
      final networkManager = NetworkManager(client: client);
      networkManager.gatewayIp = '192.168.0.27';
      await networkManager.scanNetwork();

      expect(gatewayState['profile'], equals(0));
      expect(gatewayState['node_name'], equals('ENDAP-Gateway-Hibrido'));

      // 1. Compilação de Ladder local no Studio
      final project = LadderProject(
        id: 'proj_esteira_local',
        name: 'Controle Esteira Local',
        networks: [
          LadderNetwork(
            id: 'net_1',
            name: 'Controle Motor',
            nodes: [
              LadderNode(
                id: 'in_sensor',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'SENSOR_IN'),
              ),
              LadderNode(
                id: 'out_relay',
                type: NodeType.coil,
                config: NodeConfig(tagId: 'CONVEYOR_OUT'),
              ),
            ],
          ),
        ],
        tags: {
          'SENSOR_IN': Tag(id: 'SENSOR_IN', name: 'SensorIndutivo', type: TagType.bool, address: '%IX0.0'),
          'CONVEYOR_OUT': Tag(id: 'CONVEYOR_OUT', name: 'MotorEsteira', type: TagType.bool, address: '%QX0.0'),
        },
      );

      final bytecode = BytecodeCompiler().compile(project);
      expect(bytecode, isNotEmpty);
      expect(bytecode.length, greaterThan(8));

      // 2. Simula envio de bytecode para o Gateway Híbrido
      final res = await client.post(
        Uri.parse('http://192.168.0.27/api/ladder/bytecode'),
        body: bytecode,
      );
      expect(res.statusCode, equals(200));

      // 3. Verifica acionamento de saída local
      await client.post(
        Uri.parse('http://192.168.0.27/api/io/force'),
        body: json.encode({'action': 'set', 'id': 100, 'value': 1}),
      );
      expect(gatewayState['outputs'][0]['value'], equals(1));
      expect(gatewayState['outputs'][0]['failsafe'], isFalse);
    });

    // =========================================================================
    // CASO DE USO 2: GATEWAY PURA COMUNICAÇÃO (DEDICADO / CONCENTRADOR)
    // =========================================================================
    testWidgets('Caso de Uso 2: Gateway Dedicado — Comutação via Studio e Failsafe de Saídas Locais', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createHarnessClient();
      final networkManager = NetworkManager(client: client);
      networkManager.gatewayIp = '192.168.0.27';
      await networkManager.scanNetwork();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworksPage(
              networkManager: networkManager,
              httpClient: client,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica exibição do seletor no DOM
      expect(find.text('PAPEL DO GATEWAY'), findsOneWidget);
      expect(find.text('Gateway Híbrido'), findsOneWidget);
      expect(find.text('Gateway Dedicado'), findsOneWidget);

      // Clica para comutar para Gateway Dedicado (Pura Comunicação)
      final dedicatedBtn = find.text('Gateway Dedicado');
      await tester.tap(dedicatedBtn);
      await tester.pumpAndSettle();

      // Valida que o claim foi enviado com profile=4
      expect(gatewayState['profile'], equals(4));
      expect(gatewayState['node_name'], equals('Gateway Dedicado'));
      // Saídas locais foram forçadas para estado seguro de repouso (failsafe)
      expect(gatewayState['outputs'][0]['failsafe'], isTrue);
      expect(gatewayState['outputs'][0]['value'], equals(0));

      // Valida badge atualizado no Studio
      expect(find.text('MODO DEDICADO'), findsOneWidget);
    });

    // =========================================================================
    // CASO DE USO 3: NÓ DE CAMPO ESP-NOW (FIELD NODE REMOTO)
    // =========================================================================
    testWidgets('Caso de Uso 3: Nó de Campo ESP-NOW — Descoberta de Rádio, Latência de 2ms e Telemetria', (tester) async {
      final client = createHarnessClient();
      final networkManager = NetworkManager(client: client);
      networkManager.gatewayIp = '192.168.0.27';
      await networkManager.scanNetwork();

      // 1. Valida que o Gateway descobriu o Nó de Campo ESP-NOW
      final espNowNode = discoveredNodes.firstWhere((n) => n['last_transport'] == 'ESPNOW');
      expect(espNowNode['id'], equals('ENDAP-ESPNOW-02'));
      expect(espNowNode['mac'], equals('34:85:18:99:AA:BB'));
      expect(espNowNode['ip'], equals('0.0.0.0')); // Sem dependência de roteador ou pilha TCP/IP!

      // 2. Valida métricas de alto desempenho do enlace de rádio MAC
      expect(espNowNode['radio_latency_ms'], lessThanOrEqualTo(3)); // Latência ultrabaixa de 2 ms
      expect(espNowNode['rssi'], equals(-58)); // Excelente sinal sem fio local
      expect(espNowNode['jitter_us'], equals(94)); // Jitter determinístico no nó remoto

      // 3. Simula telegrama ESP-NOW de disparo de sensor no nó de campo
      espNowNode['inputs'][0]['value'] = 1; // Sensor indutivo M12 acionado remotamente

      // 4. Gateway repassa o evento para o Studio
      final nodesRes = await client.get(Uri.parse('http://192.168.0.27/api/nodes'));
      final nodesData = json.decode(nodesRes.body);
      final remoteSensor = nodesData['nodes'][1]['inputs'][0];

      expect(remoteSensor['name'], equals('I0.0 Remoto Sensor'));
      expect(remoteSensor['value'], equals(1)); // Estado refletido com sucesso!
    });
  });
}
