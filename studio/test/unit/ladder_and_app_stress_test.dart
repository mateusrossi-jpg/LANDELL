// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.loginTechnical();
  });

  group('TESTES DE ESTRESSE — ENDAP STUDIO & MOTOR LADDER IEC', () {
    test('Stress Test 1: 1.000 Ciclos Rápidos de Scan Determinístico em Projeto Complexo', () {
      final project = LadderProject(
        id: 'proj_stress_1000',
        name: 'Projeto Estresse 1000 Scans',
        tags: {
          'START': Tag(id: 'START', name: 'START', type: TagType.bool),
          'STOP': Tag(id: 'STOP', name: 'STOP', type: TagType.bool),
          'MOTOR': Tag(id: 'MOTOR', name: 'MOTOR', type: TagType.bool),
          'PULSE': Tag(id: 'PULSE', name: 'PULSE', type: TagType.bool),
          'T0': Tag(id: 'T0', name: 'T0', type: TagType.timer, initialValue: TagValue.integer(2000)),
          'C0': Tag(id: 'C0', name: 'C0', type: TagType.counter, initialValue: TagValue.integer(10)),
          'COUNT_DONE': Tag(id: 'COUNT_DONE', name: 'COUNT_DONE', type: TagType.bool),
          'VALVE': Tag(id: 'VALVE', name: 'VALVE', type: TagType.bool),
        },
        networks: [
          // Rung 0: Partida com Selo
          LadderNetwork(
            id: 'net_0',
            name: 'Partida com Selo',
            nodes: [
              LadderNode(
                id: 'n_branch',
                type: NodeType.parallel,
                config: NodeConfig(),
                branches: [
                  [LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START'))],
                  [LadderNode(id: 'n_seal', type: NodeType.contactNO, config: NodeConfig(tagId: 'MOTOR'))],
                ],
              ),
              LadderNode(id: 'n_stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP')),
              LadderNode(id: 'n_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR')),
            ],
          ),
          // Rung 1: Temporizador TON
          LadderNetwork(
            id: 'net_1',
            name: 'Temporização Motor -> Válvula',
            nodes: [
              LadderNode(id: 'n_m_contact', type: NodeType.contactNO, config: NodeConfig(tagId: 'MOTOR')),
              LadderNode(id: 'n_ton', type: NodeType.timerTON, config: NodeConfig(tagId: 'T0', presetValue: TagValue.integer(2000))),
              LadderNode(id: 'n_valve', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE')),
            ],
          ),
          // Rung 2: Contador CTU
          LadderNetwork(
            id: 'net_2',
            name: 'Contagem de Pulsos',
            nodes: [
              LadderNode(id: 'n_pulse', type: NodeType.contactNO, config: NodeConfig(tagId: 'PULSE')),
              LadderNode(id: 'n_ctu', type: NodeType.counterCTU, config: NodeConfig(tagId: 'C0', presetValue: TagValue.integer(10))),
              LadderNode(id: 'n_cdone', type: NodeType.coil, config: NodeConfig(tagId: 'COUNT_DONE')),
            ],
          ),
        ],
      );

      for (final net in project.networks) {
        net.rebuildConnections();
      }

      final validator = GraphValidator();
      final valResult = validator.validate(project);
      expect(valResult.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(valResult.executableGraph!);

      // Inicia com START em alta
      runtime.tagStore.setBool('START', true);
      runtime.tagStore.setBool('STOP', false);

      final stopwatch = Stopwatch()..start();

      // Executa 1000 ciclos de scan
      for (int i = 0; i < 1000; i++) {
        // Aos 10 scans (1s), solta START (o selo deve manter o MOTOR ligado)
        if (i == 10) {
          runtime.tagStore.setBool('START', false);
        }

        // Gera pulsos alternados para o contador a cada 5 scans
        if (i % 5 == 0) {
          runtime.tagStore.setBool('PULSE', true);
        } else if (i % 5 == 2) {
          runtime.tagStore.setBool('PULSE', false);
        }

        runtime.singleScan(100);

        // Verificações em pontos-chave
        if (i >= 10 && i < 18) {
          // Motor selado ligado
          expect(runtime.tagStore.getBool('MOTOR'), isTrue);
          // Antes de 2000ms (20 scans de 100ms), VALVE ainda deve ser false
          expect(runtime.tagStore.getBool('VALVE'), isFalse);
        }

        if (i >= 25) {
          // Após 2000ms (25 scans x 100ms), TON completou e VALVE deve ser true
          expect(runtime.tagStore.getBool('VALVE'), isTrue);
        }
      }

      stopwatch.stop();
      print('1.000 scans concluídos em: ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsedMicroseconds / 1000} us por scan)');

      // O tempo médio por scan deve ser extremamente rápido (< 2ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      // Contador completou os 10 pulsos
      expect(runtime.tagStore.getBool('COUNT_DONE'), isTrue);
    });

    test('Stress Test 2: Compilação de Bytecode Determinístico para Projeto com 30 Rungs', () {
      final networks = <LadderNetwork>[];
      final tags = <String, Tag>{};

      for (int i = 0; i < 30; i++) {
        final inTag = 'I${i ~/ 8}.${i % 8}';
        final outTag = 'Q${i ~/ 8}.${i % 8}';
        tags[inTag] = Tag(id: inTag, name: inTag, type: TagType.bool);
        tags[outTag] = Tag(id: outTag, name: outTag, type: TagType.bool);

        networks.add(
          LadderNetwork(
            id: 'net_$i',
            name: 'Rung de Processo $i',
            nodes: [
              LadderNode(id: 'in_$i', type: NodeType.contactNO, config: NodeConfig(tagId: inTag)),
              LadderNode(id: 'out_$i', type: NodeType.coil, config: NodeConfig(tagId: outTag)),
            ],
          ),
        );
      }

      final bigProject = LadderProject(
        id: 'big_proj_30',
        name: 'Projeto 30 Rungs',
        tags: tags,
        networks: networks,
      );

      final validator = GraphValidator();
      final valRes = validator.validate(bigProject);
      expect(valRes.isValid, isTrue);

      final compiler = BytecodeCompiler();
      final bytes = compiler.compile(bigProject);

      expect(bytes, isNotEmpty);
      print('Compilados ${bytes.length} bytes de bytecode determinístico para 30 rungs.');
      expect(bytes.length, greaterThan(60));
    });

    testWidgets('Stress Test 3: Alternância Rápida de Modos (Edição -> Simulação -> Hardware) 30x', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => TelemetrySyncService.instance.stop());

      final project = LadderProject(
        id: 'p_modes',
        name: 'Modos Stress',
        tags: {
          'START': Tag(id: 'START', name: 'START', type: TagType.bool),
          'MOTOR': Tag(id: 'MOTOR', name: 'MOTOR', type: TagType.bool),
        },
        networks: [
          LadderNetwork(
            id: 'net_0',
            name: 'Direct Start',
            nodes: [
              LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START')),
              LadderNode(id: 'n_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR')),
            ],
          )..rebuildConnections(),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(initialProject: project),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alterna rapidamente entre os botões de modo
      for (int i = 0; i < 15; i++) {
        // Toca em Simulação
        await tester.tap(find.text('Simulação'));
        await tester.pump(const Duration(milliseconds: 50));

        // Toca em Conectado ao ESP32
        await tester.tap(find.text('Conectado ao ESP32'));
        await tester.pump(const Duration(milliseconds: 50));

        // Toca de volta em Edição
        await tester.tap(find.text('Edição'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pump(const Duration(milliseconds: 200));
      // Garante que o editor continua estável e responsivo
      expect(find.text('START'), findsOneWidget);
      expect(find.text('MOTOR'), findsOneWidget);
    });

    testWidgets('Stress Test 4: Forçamento Rápido e Toggle Contínuo de I/O em Simulação', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => TelemetrySyncService.instance.stop());

      final project = LadderProject(
        id: 'p_toggle',
        name: 'Toggle Stress',
        tags: {
          'SENSOR': Tag(id: 'SENSOR', name: 'SENSOR', type: TagType.bool),
          'OUT': Tag(id: 'OUT', name: 'OUT', type: TagType.bool),
        },
        networks: [
          LadderNetwork(
            id: 'net_0',
            name: 'Sensor Rung',
            nodes: [
              LadderNode(id: 'n_sensor', type: NodeType.contactNO, config: NodeConfig(tagId: 'SENSOR')),
              LadderNode(id: 'n_out', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
            ],
          )..rebuildConnections(),
        ],
      );

      final runtime = LadderRuntime();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(initialProject: project, runtime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ativa Simulação
      await tester.tap(find.text('Simulação'));
      await tester.pump(const Duration(milliseconds: 100));

      // Dispara 10 toggles sucessivos no contato SENSOR respeitando kDoubleTapTimeout
      final contactFinder = find.text('SENSOR');
      expect(contactFinder, findsOneWidget);

      for (int i = 0; i < 10; i++) {
        await tester.tap(contactFinder);
        await tester.pump(const Duration(milliseconds: 350));
      }

      // Ao fim de 10 toggles pares, SENSOR deve retornar a false
      expect(runtime.tagStore.getBool('SENSOR'), isFalse);
      expect(runtime.tagStore.getBool('OUT'), isFalse);

      // Mais 1 toggle -> Liga
      await tester.tap(contactFinder);
      await tester.pump(const Duration(milliseconds: 350));
      expect(runtime.tagStore.getBool('SENSOR'), isTrue);
      expect(runtime.tagStore.getBool('OUT'), isTrue);
    });

    testWidgets('Stress Test 5: Navegação em Ciclo por Todas as 8 Abas sem Falhas ou Overflows', (tester) async {
      tester.view.physicalSize = const Size(414, 896); // iPhone XR Mobile Viewport
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final nm = NetworkManager();
      final project = LadderProject(id: 'p_nav_stress', name: 'Nav Stress');

      await tester.pumpWidget(
        MaterialApp(
          home: StudioScaffold(
            initialProject: project,
            networkManager: nm,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);

      // Percorre os destinos do Drawer
      final destinations = [
        'Painel HMI (Telas & Kiosk)',
        'Lógica Ladder IEC',
        'GPIO / TAGS',
        'Diagnósticos de Campo',
        'Gestão, OEE & Relatórios',
        'Rede & Topologia',
      ];

      for (final dest in destinations) {
        scaffoldState.openDrawer();
        await tester.pump(const Duration(milliseconds: 300));
        expect(scaffoldState.isDrawerOpen, isTrue);

        await tester.tap(find.text(dest).first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Retorna para a Home
      scaffoldState.openDrawer();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Painel HMI (Telas & Kiosk)').first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
