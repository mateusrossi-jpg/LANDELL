import 'package:endap_studio/ladder/ui/editor/widgets/ladder_toolbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LadderToolbox displays Tooltips and Semantics labels for tools', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LadderToolbox(
            isDraggingNode: false,
            onNodeDeleted: (rung, node) {},
            onNodeTapped: (type) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of Tooltips for NO contact and COIL
    final noTooltipFinder = find.byTooltip('Contato Normal Aberto (NO)');
    final coilTooltipFinder = find.byTooltip('Bobina de Saída (COIL)');

    expect(noTooltipFinder, findsOneWidget);
    expect(coilTooltipFinder, findsOneWidget);

    // Verify Semantics
    final semanticsNO = tester.getSemantics(noTooltipFinder);
    expect(semanticsNO.label, contains('Contato Normal Aberto (NO)'));
  });
}
