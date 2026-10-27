import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/home/renderers/home_widget_renderer.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/core/ui/home_page.dart';
import 'package:endap_studio/core/services/network_manager.dart';

void main() {
  group('1. HOME WIDGET CONFIG & SERIALIZATION TESTS', () {
    test('HomeWidgetConfig serialize and deserialize correctly', () {
      final config = HomeWidgetConfig(
        id: 'w_test_1',
        tagId: 'TEMP_MOTOR',
        templateType: WidgetTemplateType.gauge,
        title: 'Temperatura do Motor',
        unit: '°C',
        minValue: 0,
        maxValue: 150,
        warningMax: 120,
        criticalMax: 140,
        decimalPlaces: 2,
        order: 1,
        sizePreset: WidgetSizePreset.standard,
        visible: true,
      );

      final jsonMap = config.toJson();
      expect(jsonMap['id'], 'w_test_1');
      expect(jsonMap['tagId'], 'TEMP_MOTOR');
      expect(jsonMap['templateType'], 'gauge');
      expect(jsonMap['title'], 'Temperatura do Motor');
      expect(jsonMap['unit'], '°C');
      expect(jsonMap['minValue'], 0.0);
      expect(jsonMap['maxValue'], 150.0);
      expect(jsonMap['warningMax'], 120.0);
      expect(jsonMap['criticalMax'], 140.0);
      expect(jsonMap['decimalPlaces'], 2);
      expect(jsonMap['order'], 1);
      expect(jsonMap['sizePreset'], 'standard');

      final fromJsonConfig = HomeWidgetConfig.fromJson(jsonMap);
      expect(fromJsonConfig.id, config.id);
      expect(fromJsonConfig.tagId, config.tagId);
      expect(fromJsonConfig.templateType, WidgetTemplateType.gauge);
      expect(fromJsonConfig.title, config.title);
      expect(fromJsonConfig.unit, config.unit);
      expect(fromJsonConfig.minValue, 0.0);
      expect(fromJsonConfig.maxValue, 150.0);
      expect(fromJsonConfig.warningMax, 120.0);
      expect(fromJsonConfig.criticalMax, 140.0);
      expect(fromJsonConfig.decimalPlaces, 2);
      expect(fromJsonConfig.order, 1);
      expect(fromJsonConfig.sizePreset, WidgetSizePreset.standard);
    });

    test('Backward compatibility: LadderProject from old JSON without dashboardWidgets', () {
      final legacyJson = {
        'id': 'proj_legacy',
        'name': 'Projeto Antigo',
        'tags': {
          'START_BTN': {
            'id': 'START_BTN',
            'name': 'START_BTN',
            'type': 'bool',
            'address': 'X0',
          }
        },
        'networks': [],
        'metadata': {},
      };

      final project = LadderProject.fromJson(legacyJson);
      expect(project.id, 'proj_legacy');
      expect(project.dashboardWidgets, isNull);

      final defaults = HomeWidgetConfig.createDefaultWidgets(project);
      expect(defaults, isNotEmpty);
      expect(defaults.length, 4);
      expect(defaults[0].templateType, WidgetTemplateType.actuator);
      expect(defaults[1].templateType, WidgetTemplateType.sparkline);
      expect(defaults[2].templateType, WidgetTemplateType.gauge);
      expect(defaults[3].templateType, WidgetTemplateType.ioMatrix);
    });

    test('LadderProject serialization preserves dashboardWidgets', () {
      final project = LadderProject(
        id: 'proj_new',
        name: 'Projeto com Widgets',
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_1',
            tagId: 'PRESSAO',
            templateType: WidgetTemplateType.gauge,
            title: 'Pressão da Linha',
            unit: 'PSI',
          ),
        ],
      );

      final jsonStr = jsonEncode(project.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = LadderProject.fromJson(decoded);

      expect(restored.dashboardWidgets, isNotNull);
      expect(restored.dashboardWidgets!.length, 1);
      expect(restored.dashboardWidgets![0].title, 'Pressão da Linha');
      expect(restored.dashboardWidgets![0].templateType, WidgetTemplateType.gauge);
    });
  });

  group('2. WIDGET RENDERING & MULTI-TAG BINDING TESTS', () {
    testWidgets('Multiple widgets can be bound to the exact same Tag', (tester) async {
      final project = LadderProject(
        id: 'proj_multi',
        name: 'Multi Widget Project',
        tags: {
          'TEMP_MOTOR': Tag(
            id: 'TEMP_MOTOR',
            name: 'TEMP_MOTOR',
            type: TagType.real,
            unit: '°C',
            initialValue: TagValue.real(85.5),
          ),
        },
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_gauge',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.gauge,
            title: 'Gauge Motor',
            unit: '°C',
          ),
          HomeWidgetConfig(
            id: 'w_sparkline',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.sparkline,
            title: 'Tendência Motor',
            unit: '°C',
          ),
          HomeWidgetConfig(
            id: 'w_metric',
            tagId: 'TEMP_MOTOR',
            templateType: WidgetTemplateType.metric,
            title: 'Métrica Motor',
            unit: '°C',
          ),
        ],
      );

      final runtime = LadderRuntime();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HomeWidgetRenderer(config: project.dashboardWidgets![0], project: project, runtime: runtime),
                HomeWidgetRenderer(config: project.dashboardWidgets![1], project: project, runtime: runtime),
                HomeWidgetRenderer(config: project.dashboardWidgets![2], project: project, runtime: runtime),
              ],
            ),
          ),
        ),
      );

      expect(find.text('GAUGE MOTOR'), findsOneWidget);
      expect(find.text('TENDÊNCIA MOTOR'), findsOneWidget);
      expect(find.text('MÉTRICA MOTOR'), findsOneWidget);
      expect(find.text('85.5'), findsNWidgets(3));
    });

    testWidgets('Widget renders graceful fallback when bound tag is missing', (tester) async {
      final project = LadderProject(
        id: 'proj_missing',
        name: 'Missing Tag Project',
        tags: {},
        dashboardWidgets: [
          HomeWidgetConfig(
            id: 'w_orphan',
            tagId: 'TAG_DELETED',
            templateType: WidgetTemplateType.gauge,
            title: 'Medidor Órfão',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeWidgetRenderer(
              config: project.dashboardWidgets![0],
              project: project,
            ),
          ),
        ),
      );

      expect(find.text('VARIÁVEL NÃO ENCONTRADA (TAG_DELETED)'), findsOneWidget);
    });
  });

  group('3. HOME PAGE INTERACTION & MOBILE VIEWPORTS', () {
    for (final size in [
      const Size(390, 844),
      const Size(393, 852),
      const Size(414, 896),
    ]) {
      testWidgets('HomePage renders without overflow on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final project = LadderProject(
          id: 'proj_hmi_mobile',
          name: 'Mobile HMI',
          tags: {
            'X0': Tag(id: 'X0', name: 'START', type: TagType.bool, address: 'X0'),
            'Y0': Tag(id: 'Y0', name: 'MOTOR', type: TagType.bool, address: 'Y0'),
          },
          dashboardWidgets: [
            HomeWidgetConfig(
              id: 'w_actuator_test',
              templateType: WidgetTemplateType.actuator,
              title: 'V-204 VALVE ACTUATOR',
            ),
            HomeWidgetConfig(
              id: 'w_matrix_test',
              templateType: WidgetTemplateType.ioMatrix,
              title: 'DIGITAL I/O MATRIX',
            ),
          ],
        );

        final runtime = LadderRuntime();

        await tester.pumpWidget(
          MaterialApp(
            home: HomePage(
              project: project,
              runtime: runtime,
              networkManager: NetworkManager(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
        expect(find.textContaining('LANDELL'), findsOneWidget);
        expect(find.text('V-204 VALVE ACTUATOR'), findsWidgets);
        expect(find.text('DIGITAL I/O MATRIX'), findsWidgets);
      });
    }

    testWidgets('Entering Edit Mode displays edit header and reorder controls', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final project = LadderProject(
        id: 'proj_edit',
        name: 'Edit Mode Project',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(project: project, networkManager: NetworkManager()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit Dashboard icon button
      final editBtn = find.byTooltip('Editar Dashboard');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify in Edit Mode
      expect(find.text('EDIT DASHBOARD'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('ADICIONAR WIDGET'), findsOneWidget);

      // Tap DONE to return to normal mode
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT DASHBOARD'), findsNothing);
      expect(find.textContaining('LANDELL'), findsOneWidget);
    });
  });
}
