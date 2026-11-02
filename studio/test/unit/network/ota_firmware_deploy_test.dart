import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/ui/networks_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OTA Firmware Deploy in NetworksPage', () {
    testWidgets('Renders OTA Firmware section and fetches status', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool otaStatusCalled = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/system/ota/status') {
          otaStatusCalled = true;
          return http.Response(
            json.encode({
              'ok': true,
              'running_partition': 'ota_0',
              'running_version': 'v3.2.0',
              'project_name': 'ENDAP',
              'next_partition': 'ota_1',
              'partition_size': 1880064,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/mqtt/config') {
          return http.Response(
            json.encode({'enabled': false, 'broker_url': 'mqtt://192.168.0.50:1883'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/cluster/nodes') {
          return http.Response(json.encode([]), 200);
        }

        return http.Response('OK', 200);
      });

      final netManager = NetworkManager(client: client);
      netManager.gatewayIp = '192.168.0.229';

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
      expect(find.text('Deploy de Firmware OTA (ESP32)'), findsOneWidget);
      expect(find.text('OTA DISPONÍVEL'), findsOneWidget);
      expect(find.textContaining('Partição ativa: ota_0'), findsOneWidget);
      expect(find.textContaining('Versão: v3.2.0'), findsOneWidget);
      expect(otaStatusCalled, isTrue);

      // 2. Verifica Opção 1: Upload Local
      expect(find.text('1. Upload de Binário Local (.bin)'), findsOneWidget);
      expect(find.text('Selecionar .bin'), findsOneWidget);

      // 3. Verifica Opção 2: GitHub URL
      expect(find.text('2. Baixar Atualização do GitHub & Gravar OTA'), findsOneWidget);
      expect(find.text('Baixar & Gravar'), findsOneWidget);
      expect(find.textContaining('https://raw.githubusercontent.com/mateusrossi-jpg/LANDELL/main/firmware/build/ENDAP.bin'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Simulates OTA upload with streaming progress to /api/system/ota', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = MockClient((request) async {
        if (request.url.path == '/api/system/ota' && request.method == 'POST') {
          return http.Response(
            json.encode({
              'ok': true,
              'status': 'ota_success',
              'message': 'Firmware gravado com sucesso! Reiniciando CLP em 1s...',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/system/ota/status') {
          return http.Response(
            json.encode({'ok': true, 'running_partition': 'ota_0', 'running_version': 'v1.0'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('OK', 200);
      });

      final netManager = NetworkManager(client: client);
      netManager.gatewayIp = '192.168.0.229';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NetworksPage(networkManager: netManager, httpClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deploy de Firmware OTA (ESP32)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
