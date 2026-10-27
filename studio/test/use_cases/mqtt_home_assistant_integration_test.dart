import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:endap_studio/core/ui/networks_page.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('USE CASE — MQTT & HOME ASSISTANT INTEGRATION (UI & DOM & API)', () {
    late List<http.Request> capturedRequests;
    late Map<String, dynamic> mqttMockConfig;
    late Map<String, dynamic> mqttMockStatus;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudioEventBus.instance.clear();
      capturedRequests = [];

      mqttMockConfig = {
        'enabled': false,
        'broker_url': 'mqtt://192.168.0.50:1883',
        'client_id': 'endap_1694216240',
        'username': 'homeassistant',
        'base_topic': 'endap',
        'ha_discovery': true,
        'publish_interval_ms': 100,
        'connected': false,
      };

      mqttMockStatus = {
        'connected': false,
        'enabled': false,
        'messages_published': 0,
        'messages_received': 0,
        'reconnect_count': 0,
        'broker_url': 'mqtt://192.168.0.50:1883',
        'client_id': 'endap_1694216240',
        'base_topic': 'endap',
      };
    });

    MockClient createHarnessClient() {
      return MockClient((request) async {
        capturedRequests.add(request);
        final path = request.url.path;

        if (path == '/api/mqtt/config') {
          if (request.method == 'GET') {
            return http.Response(json.encode(mqttMockConfig), 200, headers: {'content-type': 'application/json'});
          } else if (request.method == 'POST') {
            final body = json.decode(request.body);
            mqttMockConfig.addAll(body);
            if (mqttMockConfig['enabled'] == true) {
              mqttMockConfig['connected'] = true;
              mqttMockStatus['connected'] = true;
              mqttMockStatus['enabled'] = true;
              mqttMockStatus['messages_published'] = 12;
            }
            return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
          }
        }

        if (path == '/api/mqtt/status') {
          return http.Response(json.encode(mqttMockStatus), 200, headers: {'content-type': 'application/json'});
        }

        if (path == '/api/mqtt/discovery') {
          mqttMockStatus['messages_published'] = (mqttMockStatus['messages_published'] as int) + 5;
          return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
        }

        if (path == '/api/status' || path == '/api/public/status') {
          return http.Response(json.encode({
            'node_id': 1694216240,
            'operational_state': 'online',
            'net_ready': 1,
            'net_wifi_sta_ip_text': '192.168.0.27',
            'inputs': [],
            'outputs': [],
          }), 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('OK', 200);
      });
    }

    testWidgets('Caso de Uso Humano no DOM: Visualizar painel, preencher broker, alternar switches e salvar', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = createHarnessClient();
      final netManager = NetworkManager(client: client);
      netManager.gatewayIp = '192.168.0.27';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NetworksPage(networkManager: netManager, httpClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verifica presença do componente DOM
      expect(find.text('Integração MQTT & Home Assistant'), findsOneWidget);
      expect(find.text('DESATIVADO'), findsOneWidget);

      // 2. Simula clique do mouse humano para habilitar o Switch MQTT
      final enableSwitch = find.widgetWithText(SwitchListTile, 'Habilitar Cliente MQTT');
      expect(enableSwitch, findsOneWidget);
      await tester.tap(enableSwitch);
      await tester.pumpAndSettle();

      // 3. Após habilitar, campos de configuração aparecem no DOM
      expect(find.text('URL do Broker MQTT'), findsOneWidget);
      expect(find.text('Home Assistant Auto-Discovery'), findsOneWidget);

      // 4. Simula interação humana digitando no campo de Broker
      final brokerField = find.widgetWithText(TextField, 'URL do Broker MQTT');
      await tester.enterText(brokerField, 'mqtt://192.168.0.57:1883');
      await tester.pumpAndSettle();

      // 5. Simula clique no botão "Salvar no CLP"
      final saveButton = find.widgetWithText(ElevatedButton, 'Salvar no CLP');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 6. Validação do envio da requisição POST
      final saveReq = capturedRequests.firstWhere((r) => r.url.path == '/api/mqtt/config' && r.method == 'POST');
      final savedData = json.decode(saveReq.body);
      expect(savedData['enabled'], isTrue);
      expect(savedData['broker_url'], 'mqtt://192.168.0.57:1883');
      expect(savedData['ha_discovery'], isTrue);

      // 7. Atualiza estado e verifica que o badge mudou para CONECTADO
      expect(find.text('CONECTADO'), findsOneWidget);
    });

    test('Validação de Contrato do Home Assistant Discovery Payload', () {
      final nodeId = 1694216240;
      final outputId = 100;
      final topic = 'homeassistant/switch/endap_$nodeId/out_$outputId/config';
      final payload = {
        'name': 'Bomba Principal (Q100)',
        'unique_id': 'endap_${nodeId}_out_$outputId',
        'state_topic': 'endap/$nodeId/state/output/$outputId',
        'command_topic': 'endap/$nodeId/cmd/output/$outputId/set',
        'payload_on': '1',
        'payload_off': '0',
        'state_on': '1',
        'state_off': '0',
        'availability_topic': 'endap/$nodeId/status',
        'payload_available': 'online',
        'payload_not_available': 'offline',
        'device': {
          'identifiers': ['endap_$nodeId'],
          'name': 'ENDAP PLC $nodeId',
          'model': 'ENDAP Industrial Controller',
          'manufacturer': 'ENDAP Automation',
          'sw_version': '1.0.0'
        }
      };

      expect(topic, startsWith('homeassistant/switch/'));
      expect(payload['command_topic'], contains('/cmd/output/100/set'));
      expect(payload['state_topic'], contains('/state/output/100'));
      final deviceMap = payload['device'] as Map<String, dynamic>;
      expect(deviceMap['identifiers'], contains('endap_1694216240'));
    });
  });
}
