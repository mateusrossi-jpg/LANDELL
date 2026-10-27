import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/ladder/ui/editor/file_helper.dart';

void main() {
  test('Unified .endap bundle encodes and restores Ladder, Tags, and Home Widgets', () {
    final original = DemoProject.createDemoProject();
    original.name = 'Planta de Produção Alpha';
    original.dashboardWidgets = [
      HomeWidgetConfig(
        id: 'w1',
        title: 'Sensor Pressão Reator',
        templateType: WidgetTemplateType.gauge,
        tagId: 'PRESSAO_01',
        minValue: 0,
        maxValue: 10,
        unit: 'bar',
        order: 0,
      ),
      HomeWidgetConfig(
        id: 'w2',
        title: 'Válvula Principal',
        templateType: WidgetTemplateType.actuator,
        tagId: 'Q0.0',
        order: 1,
      ),
    ];

    final bundleJson = formatProjectJson(
      original,
      scanPeriodMs: 50,
      mode: 'RUN',
    );

    expect(bundleJson, contains('ENDAP'));
    expect(bundleJson, contains('Planta de Produção Alpha'));
    expect(bundleJson, contains('Sensor Pressão Reator'));

    // Parse bundle
    final decoded = jsonDecode(bundleJson) as Map<String, dynamic>;
    expect(decoded.containsKey('project'), isTrue);
    
    final restored = LadderProject.fromJson(decoded['project'] as Map<String, dynamic>);
    expect(restored.name, equals('Planta de Produção Alpha'));
    expect(restored.tags.isNotEmpty, isTrue);
    expect(restored.networks.isNotEmpty, isTrue);
    expect(restored.dashboardWidgets, isNotNull);
    expect(restored.dashboardWidgets!.length, equals(2));
    expect(restored.dashboardWidgets![0].title, equals('Sensor Pressão Reator'));
    expect(restored.dashboardWidgets![1].title, equals('Válvula Principal'));
  });
}
