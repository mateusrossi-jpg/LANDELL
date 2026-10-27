import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/auth/session_manager.dart';
import 'package:endap_studio/core/ui/login_page.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/ui/widgets/create_io_dialog.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder_autosave.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/core/services/network_manager.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PHASE V1.1 — AUTH & SESSION', () {
    testWidgets('1.1 Login Page displays dark industrial form and logs in operator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            networkManager: NetworkManager(),
            onLoginSuccess: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LANDELL STUDIO'), findsOneWidget);
      expect(find.text('IDENTIFICAÇÃO DO OPERADOR'), findsOneWidget);
      expect(find.text('ENTRAR'), findsOneWidget);
      expect(find.text('ACESSO TÉCNICO EM CAMPO'), findsOneWidget);

      // Attempt submit without username
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o usuário para autenticar.'), findsOneWidget);

      // Enter username & password
      await tester.enterText(find.byType(TextField).first, 'OP_ALFA');
      await tester.enterText(find.byType(TextField).last, 'secret123');
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();

      expect(SessionManager.instance.isLoggedIn, isTrue);
      expect(SessionManager.instance.currentUser, 'OP_ALFA');
    });

    testWidgets('1.2 Technical Access grants immediate authorized access', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            networkManager: NetworkManager(),
            onLoginSuccess: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACESSO TÉCNICO EM CAMPO'));
      await tester.pumpAndSettle();

      expect(SessionManager.instance.isLoggedIn, isTrue);
      expect(SessionManager.instance.currentUser, 'TECNICO_CAMPO');
    });
  });

  group('PHASE V1.1 — REAL I/O CREATION & VALIDATION', () {
    testWidgets('2.1 Validates duplicate address, duplicate name and incompatible type', (tester) async {
      final project = LadderProject(
        id: 'proj_test',
        name: 'Projeto Teste',
        tags: {
          'START_BTN': Tag(
            id: 'START_BTN',
            name: 'START_BTN',
            type: TagType.bool,
            address: 'X0',
            initialValue: TagValue.boolean(false),
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateIoDialog(project: project),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt duplicate address X0
      await tester.enterText(find.byType(TextField).at(0), 'X0');
      await tester.enterText(find.byType(TextField).at(1), 'BOTAO_2');
      await tester.tap(find.text('CRIAR'));
      await tester.pumpAndSettle();
      expect(find.text('Endereço "X0" já está em uso.'), findsOneWidget);

      // Attempt duplicate name START_BTN
      await tester.enterText(find.byType(TextField).at(0), 'X1');
      await tester.enterText(find.byType(TextField).at(1), 'START_BTN');
      await tester.tap(find.text('CRIAR'));
      await tester.pumpAndSettle();
      expect(find.text('Nome simbólico "START_BTN" já existe no projeto.'), findsOneWidget);

      // Attempt incompatible address (Y0 for Digital Input)
      await tester.enterText(find.byType(TextField).at(0), 'Y0');
      await tester.enterText(find.byType(TextField).at(1), 'SENSOR_S1');
      await tester.tap(find.text('CRIAR'));
      await tester.pumpAndSettle();
      expect(find.text('Endereço incompatível com Entrada Digital. Use o padrão Ix.y (Ex: I0.0, I1.0).'), findsOneWidget);
    });

    testWidgets('2.2 Successfully creates real I/O point and persists to project', (tester) async {
      final project = LadderProject(
        id: 'proj_test',
        name: 'Projeto Teste',
        tags: {},
      );

      Tag? createdTag;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateIoDialog(
              project: project,
              onTagCreated: (tag) {
                createdTag = tag;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'X0');
      await tester.enterText(find.byType(TextField).at(1), 'START_BTN');
      await tester.enterText(find.byType(TextField).at(2), 'Botoeira de Partida Principal');

      await tester.tap(find.text('CRIAR'));
      await tester.pumpAndSettle();

      expect(createdTag, isNotNull);
      expect(createdTag!.name, 'START_BTN');
      expect(createdTag!.address, 'X0');
      expect(project.tags.containsKey('START_BTN'), isTrue);
      expect(project.tags['START_BTN']!.address, 'X0');
    });

    testWidgets('2.3 Successfully creates Analog Input tag with engineering scale in CreateIoDialog', (tester) async {
      final project = LadderProject(
        id: 'proj_test_analog',
        name: 'Projeto Teste Analog',
        tags: {},
      );

      Tag? createdTag;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateIoDialog(
              project: project,
              onTagCreated: (tag) {
                createdTag = tag;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch dropdown to Analog Input
      await tester.tap(find.text('Digital Input'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analog Input').last);
      await tester.pumpAndSettle();

      // Enter address AI0.0, name SENSOR_TEMP
      await tester.enterText(find.byType(TextField).at(0), 'AI0.0');
      await tester.enterText(find.byType(TextField).at(1), 'SENSOR_TEMP');

      await tester.ensureVisible(find.text('CRIAR'));
      await tester.tap(find.text('CRIAR'));
      await tester.pumpAndSettle();

      expect(createdTag, isNotNull);
      expect(createdTag!.name, 'SENSOR_TEMP');
      expect(createdTag!.address, 'AI0.0');
      expect(createdTag!.type, TagType.real);
      expect(createdTag!.unit, '°C');
      expect(createdTag!.rawMin, 0.0);
      expect(createdTag!.rawMax, 10.0);
      expect(createdTag!.scaledMin, 0.0);
      expect(createdTag!.scaledMax, 100.0);
      expect(createdTag!.scaleValue(5.0), 50.0);
    });
  });

  group('PHASE V1.1 — END-TO-END COHESION: HOME → LADDER → SIMULATION → I/O MATRIX', () {
    test('3.1 Full pipeline: START_BTN -> MOTOR_M1 -> Energizes -> Event Log -> Persistence', () async {
      // 1. Create real project with real tags
      final project = LadderProject(
        id: 'proj_v1',
        name: 'Linha de Montagem',
      );

      final startTag = Tag(
        id: 'START_BTN',
        name: 'START_BTN',
        type: TagType.bool,
        address: 'X0',
        initialValue: TagValue.boolean(false),
      );
      final motorTag = Tag(
        id: 'MOTOR_M1',
        name: 'MOTOR_M1',
        type: TagType.bool,
        address: 'Y0',
        initialValue: TagValue.boolean(false),
      );

      project.tags['START_BTN'] = startTag;
      project.tags['MOTOR_M1'] = motorTag;

      // 2. Build Ladder Rung: NO(START_BTN) -> COIL(MOTOR_M1)
      final rung = LadderNetwork(
        id: 'rung_0',
        name: 'Partida Direta Motor M1',
      );
      final noNode = LadderNode(
        id: 'node_no_start',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'START_BTN'),
      );
      final coilNode = LadderNode(
        id: 'node_coil_motor',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR_M1'),
      );
      rung.addNode(noNode);
      rung.addNode(coilNode);
      project.networks.add(rung);

      // 3. Validate & Compile Graph
      final validator = GraphValidator();
      final validationResult = validator.validate(project);
      expect(validationResult.isValid, isTrue);
      expect(validationResult.executableGraph, isNotNull);

      // 4. Runtime Simulation
      final runtime = LadderRuntime();
      runtime.loadProject(validationResult.executableGraph!);

      // Initially OFF
      runtime.tagStore.setBool('START_BTN', false);
      runtime.singleScan(50);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
      expect(runtime.nodeStates[noNode.id]?.energized, isFalse);
      expect(runtime.nodeStates[coilNode.id]?.energized, isFalse);

      // Force START_BTN ON
      runtime.tagStore.setBool('START_BTN', true);
      StudioEventBus.instance.emit(
        type: 'TAG_FORCED',
        source: 'TEST_SUITE',
        message: 'START_BTN FORÇADO ON',
        severity: EventSeverity.info,
      );

      runtime.singleScan(50);

      // Verify MOTOR_M1 is ON and nodes are energized
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);
      expect(runtime.nodeStates[noNode.id]?.energized, isTrue);
      expect(runtime.nodeStates[coilNode.id]?.energized, isTrue);

      // Verify Event Log
      expect(StudioEventBus.instance.events.any((e) => e.message.contains('START_BTN')), isTrue);

      // 5. Persistence: Save & Reload
      await saveCurrentLadder(project);
      final reloadedProject = await loadCurrentLadder();
      expect(reloadedProject, isNotNull);
      final startTagReloaded = reloadedProject!.tags.values.firstWhere((t) => t.name == 'START_BTN' || t.id == 'START_BTN');
      final motorTagReloaded = reloadedProject.tags.values.firstWhere((t) => t.name == 'MOTOR_M1' || t.id == 'MOTOR_M1');
      expect(startTagReloaded.address, 'X0');
      expect(motorTagReloaded.address, 'Y0');
      expect(reloadedProject.networks.first.nodes.length, 2);
    });
  });

  group('PHASE V1.1 — MOBILE RESPONSIVENESS (390x844, 393x852, 414x896)', () {
    final viewports = [
      const Size(390, 844),
      const Size(393, 852),
      const Size(414, 896),
    ];

    for (final size in viewports) {
      testWidgets('Zero overflow on ${size.width.toInt()}x${size.height.toInt()} in StudioScaffold', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final project = LadderProject(
          id: 'proj_mobile',
          name: 'Mobile Project',
          tags: {
            'START_BTN': Tag(id: 'START_BTN', name: 'START_BTN', type: TagType.bool, address: 'X0'),
            'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'MOTOR_M1', type: TagType.bool, address: 'Y0'),
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: StudioScaffold(
              initialProject: project,
              initialIndex: 0,
              networkManager: NetworkManager(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Check Home Page loads without overflow
        expect(tester.takeException(), isNull);
        expect(find.textContaining(RegExp(r'(LANDELL|ENDAP)', caseSensitive: false)), findsWidgets);

        // Open Drawer
        final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
        scaffoldState.openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.textContaining(RegExp(r'(LANDELL|ENDAP)', caseSensitive: false)), findsWidgets);

        final drawerTile = find.descendant(of: find.byType(Drawer), matching: find.textContaining('Rede & Topologia'));
        await tester.ensureVisible(drawerTile);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(drawerTile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Controlador'), findsWidgets);
      });
    }
  });
}
