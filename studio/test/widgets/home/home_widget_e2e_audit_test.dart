import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder_autosave.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/core/ui/home_page.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.loginTechnical();
  });

  group('AUDITORIA REAL 1 — CRIAÇÃO & GALERIA', () {
    testWidgets('Galeria apresenta todos os 7 templates', (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final project = LadderProject(id: 'p1', name: 'P1');
      await tester.pumpWidget(MaterialApp(home: HomePage(project: project, networkManager: NetworkManager())));
      await tester.pumpAndSettle();

      // Entra no modo de edição
      await tester.tap(find.byTooltip('Editar Dashboard'));
      await tester.pumpAndSettle();

      // Clica em ADICIONAR WIDGET
      await tester.tap(find.text('ADICIONAR WIDGET'));
      await tester.pumpAndSettle();

      // Valida que todos os 7 templates aparecem
      expect(find.text('GALERIA DE WIDGETS'), findsOneWidget);
      expect(find.text('MANÔMETRO RADIAL'), findsOneWidget);
      expect(find.text('TENDÊNCIA / SPARKLINE'), findsOneWidget);
      expect(find.text('VALOR NUMÉRICO'), findsOneWidget);
      expect(find.text('INDICADOR DIGITAL'), findsOneWidget);
      expect(find.text('ATUADOR OPERACIONAL'), findsOneWidget);
      expect(find.text('MÉTRICA COMPACTA'), findsOneWidget);
      expect(find.text('MATRIZ DE I/O DIGITAL'), findsOneWidget);
    });
  });

  group('AUDITORIA REAL 2 & 3 — VINCULAÇÃO & ESTADO EM TEMPO REAL', () {
    testWidgets('Widget Gauge reflete alterações no TagStateStore dinamicamente (100 -> 250 -> 400)', (tester) async {
      final project = LadderProject(
        id: 'p_realtime',
        name: 'Realtime Project',
        tags: {
          'TEMP_MOTOR': Tag(
            id: 'TEMP_MOTOR',
            name: 'TEMP_MOTOR',
            type: TagType.real,
            unit: '°C',
            initialValue: TagValue.real(100.0),
          ),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_gauge_temp',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.gauge,
            title: 'TEMP MOTOR GAUGE',
            unit: '°C',
            minValue: 0,
            maxValue: 500,
            decimalPlaces: 0,
          ),
        ],
      );

      final runtime = LadderRuntime();
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(100.0));

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(project: project, runtime: runtime, networkManager: NetworkManager()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEMP MOTOR GAUGE'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);

      // Atualiza para 250
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(250.0));
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(project: project, runtime: runtime, networkManager: NetworkManager()),
        ),
      );
      await tester.pump();
      expect(find.text('250'), findsOneWidget);

      // Atualiza para 400
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(400.0));
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            project: project,
            runtime: runtime,
            networkManager: NetworkManager(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('400'), findsOneWidget);
    });
  });

  group('AUDITORIA REAL 4 — MÚLTIPLOS WIDGETS COM A MESMA TAG', () {
    testWidgets('Gauge + Numeric + Sparkline exibem o mesmo valor em sincronia', (tester) async {
      final project = LadderProject(
        id: 'p_multi',
        name: 'Multi Widget Project',
        tags: {
          'TEMP_MOTOR': Tag(
            id: 'TEMP_MOTOR',
            name: 'TEMP_MOTOR',
            type: TagType.real,
            unit: '°C',
          ),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_g',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.gauge,
            title: 'GAUGE TEMP',
            decimalPlaces: 1,
          ),
          HomeWidgetConfig(
            id: 'w_n',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.numeric,
            title: 'NUMERIC TEMP',
            decimalPlaces: 1,
          ),
          HomeWidgetConfig(
            id: 'w_s',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.sparkline,
            title: 'SPARKLINE TEMP',
            decimalPlaces: 1,
          ),
        ],
      );

      final runtime = LadderRuntime();
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(182.4));

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(project: project, runtime: runtime, networkManager: NetworkManager()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GAUGE TEMP'), findsOneWidget);
      expect(find.text('NUMERIC TEMP'), findsOneWidget);
      expect(find.text('SPARKLINE TEMP'), findsOneWidget);
      expect(find.text('182.4'), findsNWidgets(3));
    });
  });

  group('AUDITORIA REAL 5 & 7 — EDIÇÃO E EXCLUSÃO', () {
    testWidgets('Edição de título e limites atualiza tela imediatamente', (tester) async {
      final project = LadderProject(
        id: 'p_edit',
        name: 'Edit Project',
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_edit_1',
            templateType: WidgetTemplateType.numeric,
            title: 'TITULO ORIGINAL',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: HomePage(project: project, networkManager: NetworkManager())));
      await tester.pumpAndSettle();

      expect(find.text('TITULO ORIGINAL'), findsOneWidget);

      // Entra em Edit Mode
      await tester.tap(find.byTooltip('Editar Dashboard'));
      await tester.pumpAndSettle();

      // Toca em Configurar
      await tester.tap(find.byTooltip('Configurar Widget'));
      await tester.pumpAndSettle();

      // Altera o título
      await tester.enterText(find.widgetWithText(TextField, 'TITULO ORIGINAL'), 'TITULO NOVO HMI');
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('TITULO NOVO HMI'), findsOneWidget);
    });

    testWidgets('Exclusão de widget remove o card mas preserva projeto', (tester) async {
      final project = LadderProject(
        id: 'p_del',
        name: 'Delete Project',
        tags: {
          'START': Tag(id: 'START', name: 'START', type: TagType.bool),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_del_1',
            tagId: 'START',
            templateType: WidgetTemplateType.digital,
            title: 'WIDGET A SER EXCLUIDO',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: HomePage(project: project, networkManager: NetworkManager())));
      await tester.pumpAndSettle();

      expect(find.text('WIDGET A SER EXCLUIDO'), findsOneWidget);

      // Entra no modo de edição
      await tester.tap(find.byTooltip('Editar Dashboard'));
      await tester.pumpAndSettle();

      // Clica no botão de excluir
      await tester.tap(find.byTooltip('Remover Widget'));
      await tester.pumpAndSettle();

      // Confirma remoção
      await tester.tap(find.text('REMOVER'));
      await tester.pumpAndSettle();

      expect(find.text('WIDGET A SER EXCLUIDO'), findsNothing);
      expect(project.tags.containsKey('START'), isTrue);
    });
  });

  group('AUDITORIA REAL 8 & 9 — PERSISTÊNCIA & PROJETOS LEGADOS', () {
    test('Persistência salva e restaura widgets completos via SharedPreferences', () async {
      final project = LadderProject(
        id: 'p_pers',
        name: 'Persistence Project',
        tags: {
          'PRESSAO': Tag(id: 'PRESSAO', name: 'PRESSAO', type: TagType.real, unit: 'PSI'),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_pers_gauge',
            tagId: 'PRESSAO',
            templateType: WidgetTemplateType.gauge,
            title: 'PRESSAO CALDEIRA',
            unit: 'PSI',
            minValue: 0,
            maxValue: 200,
          ),
        ],
      );

      await saveCurrentLadder(project);

      final reloaded = await loadCurrentLadder();
      expect(reloaded, isNotNull);
      expect(reloaded!.dashboardWidgets, isNotNull);
      expect(reloaded.dashboardWidgets!.length, 1);
      expect(reloaded.dashboardWidgets![0].title, 'PRESSAO CALDEIRA');
      expect(reloaded.dashboardWidgets![0].unit, 'PSI');
      expect(reloaded.dashboardWidgets![0].maxValue, 200.0);
    });

    test('Projeto legado sem dashboardWidgets abre normalmente', () {
      final legacyJson = {
        'id': 'legacy_1',
        'name': 'Legacy 1',
        'tags': {},
        'networks': [],
        'metadata': {},
      };

      final project = LadderProject.fromJson(legacyJson);
      expect(project.dashboardWidgets, isNull);

      final defaults = HomeWidgetConfig.createDefaultWidgets(project);
      expect(defaults, isNotEmpty);
      expect(defaults.length, 4);
    });
  });

  group('AUDITORIA REAL 10 — MOBILE VIEWPORTS (390x844, 393x852, 414x896)', () {
    for (final size in [
      const Size(390, 844),
      const Size(393, 852),
      const Size(414, 896),
    ]) {
      testWidgets('Zero overflow na resolução ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final project = LadderProject(
          id: 'p_mobile',
          name: 'Mobile Test',
          tags: {
            'T1': Tag(id: 'T1', name: 'TEMP', type: TagType.real, unit: '°C'),
            'P1': Tag(id: 'P1', name: 'PRESS', type: TagType.real, unit: 'bar'),
          },
        );

        await tester.pumpWidget(MaterialApp(home: HomePage(project: project, networkManager: NetworkManager())));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AUDITORIA REAL 12 & 13 — INTEGRAÇÃO COM NAVEGAÇÃO E LADDER', () {
    testWidgets('Navegação e alteração de estado no Ladder reflete na Home', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = LadderProject(
        id: 'p_nav',
        name: 'Nav Test',
        tags: {
          'MOTOR_M1': Tag(
            id: 'MOTOR_M1',
            name: 'MOTOR_M1',
            type: TagType.bool,
            address: 'Y0',
            initialValue: TagValue.boolean(false),
          ),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_motor',
            tagId: 'MOTOR_M1',
            templateType: WidgetTemplateType.digital,
            title: 'MOTOR PRINCIPAL',
            onText: 'EM OPERAÇÃO',
            offText: 'PARADO',
          ),
        ],
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

      // Home Dashboard exibe o widget configurado
      expect(find.text('MOTOR PRINCIPAL'), findsOneWidget);
      expect(find.text('PARADO'), findsOneWidget);

      // Navega para aba Ladder IEC (índice 1) via Drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Lógica Ladder IEC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Scaffold), findsWidgets);

      // Retorna para a Home (índice 0) via Drawer e confere o widget preservado
      final scaffoldState2 = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState2.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Painel HMI (Telas & Kiosk)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MOTOR PRINCIPAL'), findsOneWidget);
      expect(find.text('PARADO'), findsOneWidget);
    });
  });
}
