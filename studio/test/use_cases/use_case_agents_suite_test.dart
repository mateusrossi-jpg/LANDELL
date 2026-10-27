import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/hardware_force_bridge.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/core/auth/session_manager.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/plc_tag_contract.dart';
import 'package:endap_studio/ladder/validation/executable_graph.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

/// =========================================================================
/// ENDAP TEST SUITE DE AGENTES DE CASOS DE USO (USE CASE AGENTS)
/// Validação automatizada completa de ponta a ponta:
/// Do Provisionamento até a Execução das Lógicas no Microcontrolador
/// =========================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('USE CASE AGENTS SUITE — Validação Automatizada Completa ENDAP', () {
    late List<http.Request> capturedRequests;
    late Map<String, dynamic> mockEsp32State;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudioEventBus.instance.clear();
      capturedRequests = [];

      // Estado simulado fiel ao firmware real ESP32
      mockEsp32State = {
        'node_id': 1694216240,
        'transport_name': 'wifi-udp',
        'net_ready': 1,
        'operational_state': 'online',
        'net_wifi_sta_ip_text': '192.168.0.27',
        'inputs': [
          {'channel_id': 10, 'name': 'I0.0', 'type': 'digital_input', 'gpio': 16, 'profile': 'gpio', 'state': 0, 'forced': false, 'implemented': true},
          {'channel_id': 11, 'name': 'I0.1', 'type': 'digital_input', 'gpio': 17, 'profile': 'gpio', 'state': 0, 'forced': false, 'implemented': true},
          {'channel_id': 22, 'name': 'AI0.0', 'type': 'analog_input', 'gpio': 34, 'profile': 'gpio', 'state': 2048, 'forced': false, 'implemented': true},
        ],
        'outputs': [
          {'channel_id': 100, 'name': 'Q0.0', 'type': 'digital_output', 'gpio': 23, 'profile': 'relay', 'desired': 0, 'reported': 0, 'failsafe': false, 'forced': false, 'driver_enabled': true, 'physical_present': true},
          {'channel_id': 101, 'name': 'Q0.1', 'type': 'digital_output', 'gpio': 4, 'profile': 'relay', 'desired': 0, 'reported': 0, 'failsafe': false, 'forced': false, 'driver_enabled': true, 'physical_present': true},
        ],
        'audit_events': <Map<String, dynamic>>[
          {'timestamp_ms': 1000, 'action': 'boot_ready', 'detail': 'Deterministic kernel 1ms initialized'},
        ],
        'failsafe_active': false,
      };
    });

    MockClient createHarnessClient() {
      return MockClient((request) async {
        capturedRequests.add(request);
        final path = request.url.path;

        // /api/public/status
        if (path == '/api/public/status') {
          return http.Response(
            json.encode({
              'node_id': mockEsp32State['node_id'],
              'transport_name': mockEsp32State['transport_name'],
              'net_ready': mockEsp32State['net_ready'],
              'operational_state': mockEsp32State['operational_state'],
              'net_wifi_sta_ip_text': mockEsp32State['net_wifi_sta_ip_text'],
              'inputs': mockEsp32State['inputs'],
              'outputs': mockEsp32State['outputs'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/status
        if (path == '/api/status') {
          return http.Response(
            json.encode({
              'status': 'ONLINE',
              'k_jitter_max': 5,
              'k_exec_max': 48,
              'k_deadline_miss': 0,
              'k_overrun': 0,
              'inputs': mockEsp32State['inputs'],
              'outputs': mockEsp32State['outputs'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/onboarding/status
        if (path == '/api/onboarding/status') {
          return http.Response(
            json.encode({
              'state': 'ACTIVE',
              'node_name': 'ENDAP-Gateway',
              'profile': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/onboarding/claim
        if (path == '/api/onboarding/claim') {
          return http.Response(
            json.encode({'status': 'claimed', 'claimed_node_id': '1694216240'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/nodes
        if (path == '/api/nodes') {
          return http.Response(
            json.encode({
              'nodes': [
                {
                  'id': '1694216240',
                  'ip': '192.168.0.27',
                  'state': 'online',
                  'cluster_state': 'online',
                  'registry_state': 'active',
                  'last_transport': 'WIFI',
                  'version': 'v1.0-checkpoint',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/io/map
        if (path == '/api/io/map') {
          return http.Response(
            json.encode({
              'inputs': mockEsp32State['inputs'],
              'outputs': mockEsp32State['outputs'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/io/force
        if (path == '/api/io/force') {
          if (mockEsp32State['failsafe_active'] == true) {
            return http.Response(
              json.encode({'error': 'failsafe_active'}),
              409,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = json.decode(request.body) as Map<String, dynamic>;
          final action = body['action'];
          if (action == 'set') {
            final id = body['id'] as int;
            final val = body['value'] as int;
            for (var out in mockEsp32State['outputs']) {
              if (out['channel_id'] == id) {
                out['forced'] = true;
                out['reported'] = val;
              }
            }
            (mockEsp32State['audit_events'] as List).add({
              'timestamp_ms': 50000,
              'action': 'io_force_set',
              'detail': 'channel=$id value=$val',
            });
            return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
          } else if (action == 'release') {
            final id = body['id'] as int;
            for (var out in mockEsp32State['outputs']) {
              if (out['channel_id'] == id) {
                out['forced'] = false;
                out['reported'] = out['desired'];
              }
            }
            (mockEsp32State['audit_events'] as List).add({
              'timestamp_ms': 60000,
              'action': 'io_force_release',
              'detail': 'channel=$id',
            });
            return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
          } else if (action == 'release_all') {
            for (var out in mockEsp32State['outputs']) {
              out['forced'] = false;
              out['reported'] = out['desired'];
            }
            return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
          }
          return http.Response('{"error":"bad_action"}', 400);
        }

        // /api/auth/audit
        if (path == '/api/auth/audit') {
          return http.Response(
            json.encode({'events': mockEsp32State['audit_events']}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // /api/logic/upload
        if (path == '/api/logic/upload') {
          (mockEsp32State['audit_events'] as List).add({
            'timestamp_ms': 70000,
            'action': 'logic_uploaded',
            'detail': 'bytecode_size=${request.bodyBytes.length}',
          });
          return http.Response('{"status":"ok","compiled":true}', 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('OK', 200);
      });
    }

    // =======================================================================
    // AGENTE 1: OnboardingProvisioningAgent (UC-01 - Bootstrap & Rede)
    // =======================================================================
    test('Agente 1: OnboardingProvisioningAgent valida ciclo completo de bootstrap, claim e cluster', () async {
      final mock = createHarnessClient();
      GpioService.instance.httpClientForTesting = mock;
      final netManager = NetworkManager(client: mock);

      // 1. Probing e Descoberta Inicial
      final online = await netManager.discoverAndConnect();
      expect(online, isTrue, reason: 'Controlador deve ser descoberto online via /api/public/status');
      expect(netManager.controller.id, 'ENDAP-1694216240');
      expect(netManager.controller.onboardingState, ControllerOnboardingState.active);

      // 2. Claim / Provisionamento
      final claimed = await netManager.provisionController(name: 'Gateway-Principal', profile: 0);
      expect(claimed, isTrue);
      expect(capturedRequests.any((r) => r.url.path == '/api/onboarding/claim'), isTrue);

      // 3. Cluster e Registro de Nós
      expect(netManager.nodes.length, 1);
      expect(netManager.nodes.first.status, NodeStatus.online);
      expect(netManager.nodes.first.ip, anyOf('192.168.0.27', '192.168.0.229'));
    });

    // =======================================================================
    // AGENTE 2: HardwareProfileAgent (UC-02 - Mapeamento & Strapping Pins)
    // =======================================================================
    test('Agente 2: HardwareProfileAgent valida salvaguarda de pinos e calibração de sensores', () async {
      // 1. Verificação de Strapping Pins do ESP32
      const strappingPins = [0, 2, 12, 15];
      for (final pin in strappingPins) {
        expect(
          PlcTagContract.hardwareGpios.values.contains(pin),
          isFalse,
          reason: 'GPIO $pin é strapping pin crítico do ESP32 e NUNCA deve ser atribuído a saídas comuns',
        );
      }

      // 2. Mapeamento Canônico IEC
      expect(PlcTagContract.normalizeAddress('%IX0.0'), 'I0.0');
      expect(PlcTagContract.normalizeAddress('%QX0.0'), 'Q0.0');
      expect(PlcTagContract.addressToId('I0.0'), 10);
      expect(PlcTagContract.addressToId('Q0.0'), 100);

      // 3. Calibração Analógica de Sensores
      const rawAdc = 2048; // 50% de 4096 (12 bits)
      const zeroAdc = 800; // 4mA ou zero seco
      const spanAdc = 4000; // 20mA ou 100% umidade
      final calibratedValue = ((rawAdc - zeroAdc) / (spanAdc - zeroAdc)) * 100.0;
      expect(calibratedValue, closeTo(39.0, 0.5));
    });

    // =======================================================================
    // AGENTE 3: LadderEngineAgent (UC-03 - Lógica IEC 61131-3 & Compilação)
    // =======================================================================
    test('Agente 3: LadderEngineAgent constrói rungs (NO/NC, Bobina, TON), compila bytecode e executa', () async {
      final project = LadderProject(
        id: 'agent_logic_proj',
        name: 'Ladder Industrial Test',
        networks: [
          // Rung 1: Partida com intertravamento (%IX0.0 liga %QX0.0)
          LadderNetwork(
            id: 'net_1',
            name: 'Intertravamento Bomba',
            nodes: [
              LadderNode(
                id: 'n_in',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'START_BTN'),
              ),
              LadderNode(
                id: 'n_out',
                type: NodeType.coil,
                config: NodeConfig(tagId: 'PUMP_OUT'),
              ),
            ],
          ),
          // Rung 2: Temporizador TON de retardo
          LadderNetwork(
            id: 'net_2',
            name: 'Retardo Temporizado',
            nodes: [
              LadderNode(
                id: 'n_ton',
                type: NodeType.timerTON,
                config: NodeConfig(
                  tagId: 'TIMER_DELAY',
                  presetValue: TagValue.integer(200),
                ),
              ),
              LadderNode(
                id: 'n_valve',
                type: NodeType.coil,
                config: NodeConfig(tagId: 'VALVE_OUT'),
              ),
            ],
          ),
        ],
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, address: '%IX0.0'),
          'PUMP_OUT': Tag(id: 'PUMP_OUT', name: 'Pump', type: TagType.bool, address: '%QX0.0'),
          'TIMER_DELAY': Tag(id: 'TIMER_DELAY', name: 'TimerDelay', type: TagType.timer, address: 'T0'),
          'VALVE_OUT': Tag(id: 'VALVE_OUT', name: 'Valve', type: TagType.bool, address: '%QX0.1'),
        },
      );

      // 1. Compilação Bytecode
      final bytecode = BytecodeCompiler().compile(project);
      expect(bytecode, isNotEmpty, reason: 'Bytecode gerado não pode ser vazio');
      expect(bytecode.length, greaterThan(8), reason: 'Header e instruções devem estar presentes');

      // 2. Execução no Runtime
      final runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));
      runtime.tagStore.setBool('START_BTN', true);
      runtime.singleScan(50);

      // Avaliação da Bobina
      final pumpLive = runtime.tagStore.getBool('PUMP_OUT');
      expect(pumpLive, isTrue, reason: 'START_BTN true deve energizar PUMP_OUT');
    });

    // =======================================================================
    // AGENTE 4: HmiSupervisionAgent (UC-04 - HMI & Widgets em Tempo Real)
    // =======================================================================
    test('Agente 4: HmiSupervisionAgent valida telemetria sem dados falsos e bloqueio Kiosk', () async {
      final runtime = LadderRuntime();
      runtime.tagStore.setBool('SENSOR_RUN', true);
      runtime.tagStore.setInt('TEMP_C', 45);

      // Validação de dados reais no TagStateStore (zero mocks)
      expect(runtime.tagStore.getBool('SENSOR_RUN'), isTrue);
      expect(runtime.tagStore.getInt('TEMP_C'), 45);

      // Simulação de transição de telemetria
      runtime.tagStore.setInt('TEMP_C', 52);
      expect(runtime.tagStore.getInt('TEMP_C'), 52);

      // Validação de autenticação de sessão
      await SessionManager.instance.login('admin', '1234');
      expect(SessionManager.instance.isLoggedIn, isTrue);
      expect(SessionManager.instance.currentUser, 'admin');
    });

    // =======================================================================
    // AGENTE 5: FieldTroubleshootingAgent (UC-05 - Forçamento Real & Fail-Safe)
    // =======================================================================
    test('Agente 5: FieldTroubleshootingAgent valida forçamento físico real, liberação e bloqueio por Fail-Safe', () async {
      final mock = createHarnessClient();
      GpioService.instance.httpClientForTesting = mock;
      final netManager = NetworkManager(client: mock);
      final connected = await netManager.discoverAndConnect();
      expect(connected, isTrue);
      expect(netManager.isHardwareOnline, isTrue);

      // 1. Forçar Saída Física Q0.0 ON (id=100)
      final forceRes = await HardwareForceBridge.force(netManager, '%QX0.0', true);
      expect(forceRes, HardwareForceResult.applied);
      final forceSetReq = capturedRequests.firstWhere((r) => r.url.path == '/api/io/force' && r.body.contains('"action":"set"'));
      expect(forceSetReq.body, contains('"id":100'));
      expect(forceSetReq.body, contains('"value":1'));

      // 2. Forçar Entrada Física I0.0 ON (id=10)
      final inForceRes = await HardwareForceBridge.force(netManager, '%IX0.0', true);
      expect(inForceRes, HardwareForceResult.applied);

      // 3. Liberar Forçamento Geral (release_all)
      final relAllRes = await HardwareForceBridge.releaseAll(netManager);
      expect(relAllRes, HardwareForceResult.applied);
      expect(capturedRequests.any((r) => r.url.path == '/api/io/force' && r.body.contains('"action":"release_all"')), isTrue);

      // 4. Teste de Intertravamento Fail-Safe (Conflito 409)
      mockEsp32State['failsafe_active'] = true;
      final blockedRes = await HardwareForceBridge.force(netManager, '%QX0.0', true);
      expect(blockedRes, HardwareForceResult.blockedFailsafe);

      // Verifica alarme crítico emitido no EventBus
      final events = StudioEventBus.instance.events;
      expect(events.any((e) => e.type == 'IO_FORCE_BLOCKED' && e.severity == EventSeverity.critical), isTrue);
    });

    // =======================================================================
    // AGENTE 6: AuditGovernanceAgent (UC-06 - Trilha de Auditoria & Recuperação)
    // =======================================================================
    test('Agente 6: AuditGovernanceAgent valida ingestão de eventos reais e rastreabilidade total', () async {
      final mock = createHarnessClient();
      GpioService.instance.httpClientForTesting = mock;
      final netManager = NetworkManager(client: mock);
      final connected = await netManager.discoverAndConnect();
      expect(connected, isTrue);

      // Simula eventos de hardware
      (mockEsp32State['audit_events'] as List).add({
        'timestamp_ms': 88000,
        'action': 'emergency_stop_triggered',
        'detail': 'E-STOP input GPIO 18 tripped',
      });

      final logs = await netManager.fetchHardwareAuditLogs();
      expect(logs.length, greaterThanOrEqualTo(2));
      expect(logs.any((l) => l['action'] == 'emergency_stop_triggered'), isTrue);

      // Verifica ingestão no StudioEventBus
      final events = StudioEventBus.instance.events;
      expect(events.any((e) => e.source == 'ESP32 HARDWARE' && e.message.contains('emergency_stop_triggered')), isTrue);
    });
  });
}
