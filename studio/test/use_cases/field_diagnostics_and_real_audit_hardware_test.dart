import 'dart:convert';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:endap_studio/core/services/hardware_force_bridge.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/core/ui/personas/maintenance_diagnostics_view.dart';
import 'package:endap_studio/core/ui/widgets/audit_log_dialog.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validação Real de Diagnósticos de Campo e Trilha de Auditoria com Hardware', () {
    late LadderProject project;
    late LadderRuntime runtime;
    final List<String> capturedHttpUrls = [];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      capturedHttpUrls.clear();
      StudioEventBus.instance.clear();

      project = LadderProject(
        id: 'test_proj',
        name: 'Hardware Test Project',
        networks: [
          LadderNetwork(id: 'net_0', name: 'Main Net'),
        ],
        tags: {
          'tag_q0': Tag(
            id: 'tag_q0',
            name: 'BOMBA_RELE',
            type: TagType.bool,
            address: '%QX0.0',
            description: 'Saída Digital Rele 1',
          ),
          'tag_i0': Tag(
            id: 'tag_i0',
            name: 'SENSOR_FIM_CURSO',
            type: TagType.bool,
            address: '%IX0.0',
            description: 'Entrada Digital Fim de Curso',
          ),
        },
      );

      runtime = LadderRuntime();
      runtime.tagStore.setBool('tag_q0', false);
      runtime.tagStore.setBool('tag_i0', false);
    });

    test('NetworkManager busca e ingere eventos reais do ESP32 (/api/auth/audit)', () async {
      final mockClient = MockClient((request) async {
        capturedHttpUrls.add(request.url.toString());
        if (request.url.path == '/api/auth/audit') {
          return http.Response(
            json.encode({
              'events': [
                {
                  'timestamp_ms': 12345,
                  'action': 'login_success',
                  'detail': 'user=admin ip=192.168.4.2',
                },
                {
                  'timestamp_ms': 25000,
                  'action': 'manual_io',
                  'detail': 'output_id=100 value=1 by=admin',
                },
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/public/status') {
          return http.Response(json.encode({'node_id': 'GW_01'}), 200);
        }
        return http.Response('{}', 200);
      });

      final netManager = NetworkManager(client: mockClient);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      final auditList = await netManager.fetchHardwareAuditLogs();
      expect(auditList.length, 2);
      expect(auditList[0]['action'], 'login_success');
      expect(auditList[1]['action'], 'manual_io');

      // Verifica ingestão no StudioEventBus
      final events = StudioEventBus.instance.events;
      expect(events.any((e) => e.source == 'ESP32 HARDWARE' && e.message.contains('login_success')), isTrue);
      expect(events.any((e) => e.source == 'ESP32 HARDWARE' && e.message.contains('manual_io')), isTrue);
    });

    testWidgets('MaintenanceDiagnosticsView aciona force real no ESP32 (/api/io/force) ao forçar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final List<http.Request> capturedRequests = [];
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        capturedHttpUrls.add(request.url.toString());
        if (request.url.path == '/api/io/force') {
          return http.Response(json.encode({'status': 'ok'}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/public/status') {
          return http.Response(json.encode({'node_id': 'GW_01', 'status': 'ONLINE'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('OK', 200);
      });

      final netManager = NetworkManager(client: mockClient);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      // Injeta mockClient no GpioService singleton
      GpioService.instance.httpClientForTesting = mockClient;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceDiagnosticsView(
              networkManager: netManager,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontra a tag BOMBA_RELE na tabela
      expect(find.text('BOMBA_RELE'), findsOneWidget);

      // Localiza o botão de forçamento para ON da primeira tag
      final forceOnBtn = find.text('ON');
      expect(forceOnBtn, findsWidgets);

      await tester.tap(forceOnBtn.first);
      await tester.pumpAndSettle();

      // Verifica que no TagStateStore foi forçada
      expect(runtime.tagStore.isForced('tag_q0'), isTrue);
      expect(runtime.tagStore.getBool('tag_q0'), isTrue);

      // Verifica que a requisição real POST /api/io/force foi disparada para a saída Q0.0 (id 100)
      expect(
        capturedRequests.any((req) =>
            req.url.path == '/api/io/force' &&
            req.method == 'POST' &&
            req.body.contains('"action":"set"') &&
            req.body.contains('"id":100') &&
            req.body.contains('"value":1')),
        isTrue,
        reason: 'Deveria ter enviado POST /api/io/force id=100 value=1 ao hardware ESP32',
      );

      // Agora desforça o canal
      final unforceBtn = find.text('LIBERAR');
      expect(unforceBtn, findsWidgets);
      await tester.tap(unforceBtn.first);
      await tester.pumpAndSettle();

      expect(runtime.tagStore.isForced('tag_q0'), isFalse);
      expect(
        capturedRequests.any((req) =>
            req.url.path == '/api/io/force' &&
            req.method == 'POST' &&
            req.body.contains('"action":"release"') &&
            req.body.contains('"id":100')),
        isTrue,
        reason: 'Deveria ter enviado POST /api/io/force id=100 action=release ao hardware ESP32. Requests: ${capturedRequests.map((r) => "${r.method} ${r.url.path} ${r.body}").toList()}',
      );
    });

    testWidgets('AuditLogDialog sincroniza logs reais do hardware ESP32 via botão', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/audit') {
          return http.Response(
            json.encode({
              'events': [
                {
                  'timestamp_ms': 88000,
                  'action': 'emergency_stop_triggered',
                  'detail': 'E-STOP trip input GPIO 18',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final netManager = NetworkManager(client: mockClient);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AuditLogDialog.show(ctx, networkManager: netManager),
                child: const Text('Abrir Auditoria'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Auditoria'));
      await tester.pumpAndSettle();

      expect(find.text('TRILHA DE AUDITORIA & EVENTOS'), findsOneWidget);
      expect(find.text('Sincronizar ESP32'), findsOneWidget);

      await tester.tap(find.text('Sincronizar ESP32'));
      await tester.pumpAndSettle();

      // O evento de emergência do ESP32 deve estar visível no diálogo
      expect(find.textContaining('emergency_stop_triggered'), findsOneWidget);
    });

    test('HardwareForceBridge: forçamento de entrada digital física (%IX0.0 -> id 10)', () async {
      final List<http.Request> reqs = [];
      final mock = MockClient((r) async {
        reqs.add(r);
        return http.Response('{"status":"ok"}', 200);
      });
      GpioService.instance.httpClientForTesting = mock;

      final netManager = NetworkManager(client: mock);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      final res = await HardwareForceBridge.force(netManager, '%IX0.0', true);
      expect(res, HardwareForceResult.applied);
      final forceReq = reqs.firstWhere((r) => r.url.path == '/api/io/force');
      expect(forceReq.body, contains('"id":10'));
      expect(forceReq.body, contains('"value":1'));
      expect(forceReq.body, contains('"action":"set"'));
    });

    test('HardwareForceBridge: liberação geral de forçamentos (release_all)', () async {
      final List<http.Request> reqs = [];
      final mock = MockClient((r) async {
        reqs.add(r);
        return http.Response('{"status":"ok"}', 200);
      });
      GpioService.instance.httpClientForTesting = mock;

      final netManager = NetworkManager(client: mock);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      final res = await HardwareForceBridge.releaseAll(netManager);
      expect(res, HardwareForceResult.applied);
      final releaseReq = reqs.firstWhere((r) => r.url.path == '/api/io/force');
      expect(releaseReq.body, contains('"action":"release_all"'));
    });

    test('HardwareForceBridge: fail-safe ativo (409) emite evento crítico de auditoria', () async {
      final mock = MockClient((r) async {
        return http.Response('{"error":"failsafe_active"}', 409);
      });
      GpioService.instance.httpClientForTesting = mock;

      final netManager = NetworkManager(client: mock);
      netManager.controller = ControllerInfo(
        ip: '192.168.4.1',
        isOnline: true,
        nodeName: 'ENDAP-Gateway',
        id: 'GW_01',
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        transport: 'WIFI',
        profile: 0,
      );
      netManager.setConnectionStateForTesting(ConnectionState.hardwareOnline);

      final res = await HardwareForceBridge.force(netManager, '%QX0.0', true);
      expect(res, HardwareForceResult.blockedFailsafe);

      final events = StudioEventBus.instance.events;
      expect(events.any((e) => e.type == 'IO_FORCE_BLOCKED' && e.severity == EventSeverity.critical), isTrue);
    });
  });
}
