import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/home/renderers/digital_widget.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  testWidgets('DigitalWidget provides Tooltip and Semantics label and button role', (WidgetTester tester) async {
    final project = LadderProject(
      id: 'p_a11y',
      name: 'Accessibility Project',
      tags: {
        'MOTOR_RUN': Tag(
          id: 'MOTOR_RUN',
          name: 'MOTOR_RUN',
          address: 'Q0.0',
          type: TagType.bool,
          initialValue: TagValue.boolean(true),
        ),
      },
    );

    final runtime = LadderRuntime();
    runtime.tagStore.setValue('MOTOR_RUN', TagValue.boolean(true));

    final config = HomeWidgetConfig(
      id: 'w_dig',
      tagId: 'MOTOR_RUN',
      title: 'MOTOR STATUS',
      templateType: WidgetTemplateType.digital,
      onText: 'OPERANDO',
      offText: 'PARADO',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DigitalWidget(
              config: config,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tooltip presence
    final tooltipFinder = find.byTooltip('Q0.0: OPERANDO • Clique para forçar ponto de I/O');
    expect(tooltipFinder, findsOneWidget);

    // Verify Semantics label on the Semantics widget
    final semanticsFinder = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Q0.0: OPERANDO');
    expect(semanticsFinder, findsOneWidget);

    final semantics = tester.getSemantics(semanticsFinder);
    expect(semantics.label, contains('Q0.0: OPERANDO'));

    // Verify tapping opens IoForceDialog (finding FORÇAR ON / OFF actions)
    await tester.tap(tooltipFinder);
    await tester.pumpAndSettle();

    expect(find.text('FORÇAR ON'), findsOneWidget);
    expect(find.text('FORÇAR OFF'), findsOneWidget);
  });
}
