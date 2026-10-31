import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/core/ui/personas/engineering_workspace_view.dart';
import 'package:endap_studio/core/services/network_manager.dart';

void main() {
  group('TON Hardware Activation & Retractable Panels Tests', () {
    late LadderProject project;
    late LadderRuntime runtime;

    setUp(() {
      project = LadderProject(
        id: 'test_ton_proj',
        name: 'Test TON Project',
        tags: {
          'I0.4': Tag(id: 'I0.4', name: 'Botao Pulso', type: TagType.bool, initialValue: TagValue.boolean(false), address: 'I0.4'),
          'T0': Tag(id: 'T0', name: 'Temporizador T0', type: TagType.timer, initialValue: TagValue.boolean(false), address: 'T0'),
          'Q0.3': Tag(id: 'Q0.3', name: 'Rele Alarme', type: TagType.bool, initialValue: TagValue.boolean(false), address: 'Q0.3'),
        },
        networks: [
          LadderNetwork(
            id: 'net_ton',
            name: 'Rung TON Test',
            nodes: [
              LadderNode(id: 'n_in', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.4')),
              LadderNode(id: 'n_ton', type: NodeType.timerTON, config: NodeConfig(tagId: 'T0', presetValue: TagValue.integer(3000))),
              LadderNode(id: 'n_coil', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.3')),
            ],
          )..rebuildConnections(),
        ],
      );

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);
      runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);
    });

    testWidgets('TON block energizes and counts progress smoothly, then conducts to coil', (tester) async {
      final nm = NetworkManager();
      addTearDown(() => nm.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: project,
              runtime: runtime,
              networkManager: nm,
              embedded: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final tonNode = project.networks.first.nodes[1];
      final coilNode = project.networks.first.nodes[2];

      // Inicialmente desligado
      expect(tonNode.isEnergized, isFalse);
      expect(tonNode.isConducting, isFalse);
      expect(coilNode.isEnergized, isFalse);

      // Simula hardware real ativando entrada I0.4
      runtime.tagStore.setBool('I0.4', true);
      runtime.singleScan(100);

      // TON recebe fluxo de energia e entra no modo de temporização (TT / EN)
      expect(runtime.tagStore.getBool('T0.EN'), isTrue);
      expect(runtime.tagStore.getBool('T0.TT'), isTrue);
      expect(runtime.tagStore.getBool('T0.DN'), isFalse);

      // Mais varreduras até atingir o preset de 3000ms
      runtime.singleScan(3000);
      expect(runtime.tagStore.getBool('T0.DN'), isTrue);
      expect(runtime.tagStore.getBool('T0.TT'), isFalse);
      expect(runtime.tagStore.getBool('Q0.3'), isTrue);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Telemetry packet with timer status immediately reflects in TagStore and node energization', (tester) async {
      TelemetrySyncService.instance.init(
        project: project,
        runtime: runtime,
        gatewayIp: '192.168.0.229',
      );
      TelemetrySyncService.instance.injectEnabled = true;

      final ioMapPayload = {
        'inputs': [
          {'channel_id': 14, 'name': 'I0.4', 'type': 'digital_input', 'state': 1},
        ],
        'outputs': [
          {'channel_id': 103, 'name': 'Q0.3', 'type': 'digital_output', 'state': 1},
        ],
        'internals': [
          {'channel_id': 40, 'name': 'T0', 'type': 'timer', 'state': 1, 'active': false, 'elapsed': 500},
        ],
      };

      TelemetrySyncService.instance.processIoMapJson(ioMapPayload);

      expect(runtime.tagStore.getBool('I0.4'), isTrue);
      expect(runtime.tagStore.getBool('T0'), isTrue);
      expect(runtime.tagStore.getBool('T0.DN'), isTrue);
      expect(runtime.tagStore.getInt('T0.ACC'), 500);
      expect(runtime.tagStore.getBool('Q0.3'), isTrue);
    });

    testWidgets('EngineeringWorkspaceView retractable panels (Organizer, Console, Focus Mode)', (tester) async {
      final nm = NetworkManager();
      addTearDown(() => nm.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineeringWorkspaceView(
              project: project,
              runtime: runtime,
              networkManager: nm,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Verifica que o botão "Modo Foco (Maximizar Ladder)" existe
      expect(find.text('Modo Foco (Maximizar Ladder)'), findsOneWidget);

      // Clica em "Modo Foco (Maximizar Ladder)" -> recolhe Organizer e Console
      await tester.tap(find.text('Modo Foco (Maximizar Ladder)'));
      await tester.pumpAndSettle();

      expect(find.text('Restaurar Painéis'), findsOneWidget);
      expect(find.text('ORGANIZER'), findsOneWidget); // trilho vertical retraído
      expect(find.text('CONSOLE DE COMPILAÇÃO'), findsOneWidget); // barra inferior retraída

      // Clica em "Restaurar Painéis" -> reabre ambos
      await tester.tap(find.text('Restaurar Painéis'));
      await tester.pumpAndSettle();

      expect(find.text('Modo Foco (Maximizar Ladder)'), findsOneWidget);
      expect(find.text('CONTROLLER ORGANIZER'), findsOneWidget);
    });

    testWidgets('LadderEditorPage retractable Component Toolbox', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final nm = NetworkManager();
      addTearDown(() => nm.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: project,
              runtime: runtime,
              networkManager: nm,
              embedded: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Botão na barra secundária
      expect(find.text('Ocultar Paleta'), findsOneWidget);

      // Clica para ocultar paleta
      await tester.tap(find.text('Ocultar Paleta'));
      await tester.pumpAndSettle();

      expect(find.text('Paleta Componentes'), findsOneWidget);
      expect(find.text('Paleta de Componentes Oculta (Mais espaço para visualização)'), findsOneWidget);

      // Clica para reexibir
      await tester.tap(find.text('Exibir Componentes'));
      await tester.pumpAndSettle();

      expect(find.text('Ocultar Paleta'), findsOneWidget);
    });
  });
}
