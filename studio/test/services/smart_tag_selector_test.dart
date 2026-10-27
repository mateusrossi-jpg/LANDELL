import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/home/ui/widgets/widget_config_dialog.dart';

void main() {
  testWidgets('Smart Tag Selector shows tags, categories, search and auto-populates ranges', (tester) async {
    final project = LadderProject(
      id: 'p_selector',
      name: 'Selector Project',
      tags: {
        'BTN_START': Tag(
          id: 'BTN_START',
          name: 'BTN_START',
          type: TagType.bool,
          address: 'I0.0',
          description: 'Botão Partida Painel',
        ),
        'MOTOR_M1': Tag(
          id: 'MOTOR_M1',
          name: 'MOTOR_M1',
          type: TagType.bool,
          address: 'Q0.0',
          description: 'Motor Bomba Principal',
        ),
        'PRESSAO_BAR': Tag(
          id: 'PRESSAO_BAR',
          name: 'PRESSAO_BAR',
          type: TagType.real,
          address: 'AI0.0',
          unit: 'bar',
          scaledMin: 0.0,
          scaledMax: 16.0,
          description: 'Transmissor Pressão Hidráulica',
        ),
        'FLAG_CYCLE': Tag(
          id: 'FLAG_CYCLE',
          name: 'FLAG_CYCLE',
          type: TagType.bool,
          address: 'M0.0',
          description: 'Flag Ciclo Automático',
        ),
      },
      networks: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => WidgetConfigDialog.show(
                context,
                project: project,
                templateType: WidgetTemplateType.gauge,
                initialTagId: 'BTN_START',
              ),
              child: const Text('OPEN DIALOG'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the dialog
    await tester.tap(find.text('OPEN DIALOG'));
    await tester.pumpAndSettle();

    // Verify dialog opened and displays initial tag
    expect(find.text('VARIÁVEL / TAG DO CLP (IEC 61131-3)'), findsOneWidget);
    expect(find.text('BTN_START'), findsOneWidget);
    expect(find.text('ALTERAR'), findsOneWidget);

    // Tap ALTERAR to open the smart picker
    await tester.tap(find.text('ALTERAR'));
    await tester.pumpAndSettle();

    // Verify categories are visible
    expect(find.text('TODAS'), findsOneWidget);
    expect(find.text('ENTRADAS (%IX)'), findsOneWidget);
    expect(find.text('SAÍDAS (%QX)'), findsOneWidget);
    expect(find.text('ANALÓGICAS (%IW)'), findsOneWidget);
    expect(find.text('MEMÓRIAS (%M)'), findsOneWidget);

    // Filter by SAÍDAS (%QX)
    await tester.tap(find.text('SAÍDAS (%QX)'));
    await tester.pumpAndSettle();

    expect(find.text('MOTOR_M1'), findsOneWidget);
    expect(find.text('PRESSAO_BAR'), findsNothing);

    // Filter by ANALÓGICAS (%IW)
    final analogChip = find.text('ANALÓGICAS (%IW)');
    await tester.ensureVisible(analogChip);
    await tester.tap(analogChip);
    await tester.pumpAndSettle();

    expect(find.text('PRESSAO_BAR'), findsOneWidget);
    expect(find.text('MOTOR_M1'), findsNothing);

    // Select PRESSAO_BAR
    await tester.tap(find.text('PRESSAO_BAR'));
    await tester.pumpAndSettle();

    // Verify smart selector collapsed back and selected PRESSAO_BAR
    expect(find.text('PRESSAO_BAR'), findsWidgets);
    expect(find.textContaining('Unidade: bar'), findsOneWidget);

    // Verify title and scale limits auto-populated
    expect(find.text('Transmissor Pressão Hidráulica'), findsOneWidget);
    expect(find.text('bar'), findsOneWidget);
    expect(find.text('16.0'), findsOneWidget);
  });
}
