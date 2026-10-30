import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/ui/editor/widgets/variables_panel.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  testWidgets('VariablesPanel renders tooltips for action buttons', (WidgetTester tester) async {
    final tags = <String, Tag>{
      'TAG1': Tag(id: 'TAG1', name: 'Sensor 1', type: TagType.bool),
      'ANALOG1': Tag(id: 'ANALOG1', name: 'Pressure 1', type: TagType.real, address: 'AI00'),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VariablesPanel(
            tags: tags,
            simulationInputs: const {},
            onTagAdded: (_) {},
            onTagRemoved: (_) {},
            onSimulationInputChanged: (_, __) {},
          ),
        ),
      ),
    );

    // Expand panel first
    await tester.tap(find.byType(VariablesPanel));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Adicionar tag rápida'), findsOneWidget);
    expect(find.byTooltip('Criar nova tag configurada'), findsOneWidget);
    expect(find.byTooltip('Calibrar tag ANALOG1'), findsOneWidget);
    expect(find.byTooltip('Editar tag TAG1'), findsOneWidget);
    expect(find.byTooltip('Remover tag TAG1'), findsOneWidget);
  });
}
