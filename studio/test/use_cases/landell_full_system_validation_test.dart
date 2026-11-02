import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/compiler/bytecode_disassembler.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/runtime/pid_math.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/ui/networks_page.dart';
import 'package:endap_studio/core/ui/personas/engineering_workspace_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LANDELL Full System Practical Validation Suite', () {
    // -------------------------------------------------------------
    // PILAR 1: MOTOR LADDER IEC 61131-3 & MATEMÁTICA / PID
    // -------------------------------------------------------------
    test('Pilar 1.1: Lógica Básica (NO Contact -> Coil)', () {
      final project = LadderProject(
        id: 'proj_basic',
        name: 'Basic Contact Coil',
        tags: {
          'I0.0': Tag(id: 'I0.0', name: 'Entrada 0', type: TagType.bool, address: 'I0.0'),
          'Q0.0': Tag(id: 'Q0.0', name: 'Saida 0', type: TagType.bool, address: 'Q0.0'),
        },
        networks: [
          LadderNetwork(
            id: 'net_0',
            nodes: [
              LadderNode(id: 'n_in', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')),
              LadderNode(id: 'n_out', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')),
            ],
          )..rebuildConnections(),
        ],
      );

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);

      // I0.0 = 0 -> Q0.0 deve ser 0
      runtime.tagStore.setBool('I0.0', false);
      runtime.singleScan(50);
      expect(runtime.tagStore.getBool('Q0.0'), isFalse);

      // I0.0 = 1 -> Q0.0 deve ser 1
      runtime.tagStore.setBool('I0.0', true);
      runtime.singleScan(50);
      expect(runtime.tagStore.getBool('Q0.0'), isTrue);
    });

    test('Pilar 1.2: Temporizador TON com Contagem Progressiva e Energização', () {
      final project = LadderProject(
        id: 'proj_ton',
        name: 'TON Timer Test',
        tags: {
          'I0.4': Tag(id: 'I0.4', name: 'Botao Pulso', type: TagType.bool, address: 'I0.4'),
          'T0': Tag(id: 'T0', name: 'Timer T0', type: TagType.timer, address: 'T0'),
          'Q0.1': Tag(id: 'Q0.1', name: 'Rele Alarme', type: TagType.bool, address: 'Q0.1'),
        },
        networks: [
          LadderNetwork(
            id: 'net_ton',
            nodes: [
              LadderNode(id: 'btn_ton', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.4')),
              LadderNode(id: 'ton_block', type: NodeType.timerTON, config: NodeConfig(tagId: 'T0', presetValue: TagValue.integer(200))),
              LadderNode(id: 'coil_ton', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.1')),
            ],
          )..rebuildConnections(),
        ],
      );

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);

      // Passo 1: Desligado
      runtime.tagStore.setBool('I0.4', false);
      runtime.singleScan(50);
      expect(runtime.tagStore.getBool('T0.DN'), isFalse);
      expect(runtime.tagStore.getBool('Q0.1'), isFalse);

      // Passo 2: Liga entrada -> Começa a contar
      runtime.tagStore.setBool('I0.4', true);
      runtime.singleScan(100); // 100ms < 200ms
      expect(runtime.tagStore.getBool('T0.DN'), isFalse);
      expect(runtime.tagStore.getBool('T0.TT'), isTrue);
      expect(runtime.tagStore.getBool('Q0.1'), isFalse);

      // Passo 3: Mais 100ms -> Atinge 200ms -> DN = true, Q0.1 = true
      runtime.singleScan(100);
      expect(runtime.tagStore.getBool('T0.DN'), isTrue);
      expect(runtime.tagStore.getBool('Q0.1'), isTrue);

      // Passo 4: Solta entrada -> Zera imediatamente
      runtime.tagStore.setBool('I0.4', false);
      runtime.singleScan(50);
      expect(runtime.tagStore.getBool('T0.DN'), isFalse);
      expect(runtime.tagStore.getBool('Q0.1'), isFalse);
    });

    test('Pilar 1.3: Bloco PID Industrial (Equivalência C/Firmware e Anti-Windup)', () {
      final params = PidParams(
        kpX100: 250,
        kiX100: 50,
        kdX100: 10,
        direct: false,
        manualEnable: true,
        outMin: 0,
        outMax: 100,
        deadbandX10: 0,
        enoThreshold: 20,
        enoHysteresis: 5,
        safeOut: 0,
      );

      final state = PidState();
      PidMath.disable(params, state);
      expect(state.mvPercent, equals(0));
      expect(state.eno, isFalse);

      // Simula passo de controle: Setpoint = 50%, Sensor PV = 20% (Erro = 30%)
      PidMath.step(params, state, pvPct: 20, spPct: 50);
      expect(state.mvPercent, greaterThan(70)); // Resposta proporcional forte
      expect(state.eno, isTrue); // Acima de 20% aciona o ENO (estágio de aquecimento/bomba)

      // Anti-windup: PV atinge 100% -> Erro negativo -> Sai da saturação
      for (int i = 0; i < 5; i++) {
        PidMath.step(params, state, pvPct: 100, spPct: 50);
      }
      expect(state.mvPercent, equals(0)); // Clamp no limite mínimo sem trava de integrador
    });

    // -------------------------------------------------------------
    // PILAR 2: COMPILADOR DE BYTECODE & OPCODES
    // -------------------------------------------------------------
    test('Pilar 2: Compilação de Projeto para Bytecode Binário IEC', () {
      final project = LadderProject(
        id: 'proj_compile',
        name: 'Bytecode Compile Test',
        tags: {
          'I0.0': Tag(id: 'I0.0', name: 'In', type: TagType.bool, address: 'X0'),
          'Q0.0': Tag(id: 'Q0.0', name: 'Out', type: TagType.bool, address: 'Y0'),
        },
        networks: [
          LadderNetwork(
            id: 'net_comp',
            nodes: [
              LadderNode(id: 'c1', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')),
              LadderNode(id: 'c2', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')),
            ],
          )..rebuildConnections(),
        ],
      );

      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);
      expect(bytecode.isNotEmpty, isTrue);
      // Header: 'E' 'N' 'D' 'P'
      expect(bytecode[0], equals(0x45));
      expect(bytecode[1], equals(0x4E));
      expect(bytecode[2], equals(0x44));
      expect(bytecode[3], equals(0x50));

      final disasm = BytecodeDisassembler();
      final restored = disasm.disassemble(bytecode);
      expect(restored.networks.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // PILAR 3: TELEMETRIA CIBERFÍSICA & MAPEAMENTO DE HARDWARE
    // -------------------------------------------------------------
    test('Pilar 3: Sincronização de Telemetria I/O e Sensor Capacitivo AI0.0', () {
      final project = DemoProject.createDemoProject();
      final val = GraphValidator().validate(project);
      final runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);

      final syncService = TelemetrySyncService.instance;
      syncService.init(project: project, runtime: runtime);

      // Simula payload real do ESP32 vindo de /api/io/map
      final mockIoMapJson = {
        'ok': true,
        'inputs': [
          {'channel_id': 10, 'name': 'I0.0', 'state': 1},
          {'channel_id': 14, 'name': 'I0.4', 'state': 0},
          {'channel_id': 72, 'name': 'AI0.0', 'value': 50.0},
        ],
        'outputs': [
          {'channel_id': 100, 'name': 'Q0.0', 'state': 1},
          {'channel_id': 101, 'name': 'Q0.1', 'state': 0},
        ],
        'internals': [
          {'channel_id': 40, 'name': 'T0', 'type': 'timer', 'state': 0, 'active': true, 'elapsed': 150},
        ],
      };

      syncService.processIoMapJson(mockIoMapJson);

      // Valida reflexo imediato no TagStore
      expect(runtime.tagStore.getBool('I0.0'), isTrue);
      expect(runtime.tagStore.getBool('I0.4'), isFalse);
      expect(runtime.tagStore.getBool('Q0.0'), isTrue);
      expect(runtime.tagStore.getBool('Q0.1'), isFalse);
      expect(runtime.tagStore.getReal('AI0.0'), equals(50.0));
      expect(runtime.tagStore.getInt('T0.ACC'), equals(150));
      expect(runtime.tagStore.getBool('T0.TT'), isTrue);
    });

    // -------------------------------------------------------------
    // PILAR 4: REDE, PROVISIONAMENTO WI-FI & OTA FIRMWARE
    // -------------------------------------------------------------
    testWidgets('Pilar 4: Interface de Rede com Modo AP 192.168.4.1 e Deploy OTA', (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = MockClient((request) async {
        if (request.url.path == '/api/system/ota/status') {
          return http.Response(
            json.encode({
              'ok': true,
              'running_partition': 'ota_0',
              'running_version': 'v3.2.0',
              'next_partition': 'ota_1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/wifi/scan') {
          return http.Response(
            json.encode({
              'ok': true,
              'count': 2,
              'networks': [
                {'ssid': 'Rossi', 'rssi': -45, 'auth': 'wpa2-psk'},
                {'ssid': 'Bancada_Testes', 'rssi': -60, 'auth': 'wpa2-psk'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('OK', 200);
      });

      final netManager = NetworkManager(client: client);
      netManager.gatewayIp = '192.168.4.1';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NetworksPage(networkManager: netManager, httpClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica OTA
      expect(find.text('Deploy de Firmware OTA (ESP32)'), findsOneWidget);
      expect(find.text('OTA DISPONÍVEL'), findsOneWidget);

      // Abre provisionamento Wi-Fi
      final wifiBtn = find.widgetWithText(OutlinedButton, 'Conectar Wi-Fi');
      expect(wifiBtn, findsOneWidget);
      await tester.tap(wifiBtn);
      await tester.pumpAndSettle();

      // Verifica dica de modo AP e chips de seleção rápida
      expect(find.textContaining('Passo 1: Se o CLP estiver em modo de configuração'), findsOneWidget);
      expect(find.text('192.168.4.1 (Modo AP)'), findsOneWidget);
      expect(find.text('192.168.0.229 (Bancada STA)'), findsOneWidget);

      // Clica em Próximo para escanear
      final nextBtn = find.widgetWithText(ElevatedButton, 'Próximo');
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Verifica que listou a rede Rossi
      expect(find.text('Rossi'), findsOneWidget);
      expect(find.text('Bancada_Testes'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });

    // -------------------------------------------------------------
    // PILAR 5: WORKSPACE DE ENGENHARIA RETRÁTIL & MODO FOCO
    // -------------------------------------------------------------
    testWidgets('Pilar 5: Workspace de Engenharia com Painéis Retráteis', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = MockClient((request) async => http.Response('OK', 200));
      final netManager = NetworkManager(client: client);
      final project = DemoProject.createDemoProject();
      final runtime = LadderRuntime();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: EngineeringWorkspaceView(
              project: project,
              runtime: runtime,
              networkManager: netManager,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Painel esquerdo (Organizer) visível inicialmente
      expect(find.textContaining('Controlador ['), findsOneWidget);

      // Clica no botão de Modo Foco na barra de ferramentas superior
      final focusBtn = find.text('Modo Foco (Maximizar Ladder)');
      expect(focusBtn, findsOneWidget);
      await tester.tap(focusBtn);
      await tester.pumpAndSettle();

      // Organizer recolhido para guia fina vertical de 28px
      expect(find.text('ORGANIZER'), findsOneWidget);

      // Console recolhido para barra fina inferior
      expect(find.text('CONSOLE DE COMPILAÇÃO'), findsOneWidget);

      // Clica para Restaurar Painéis
      final restoreBtn = find.text('Restaurar Painéis');
      expect(restoreBtn, findsOneWidget);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // Organizer visível novamente
      expect(find.textContaining('Controlador ['), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
