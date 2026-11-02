import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/ui/editor/widgets/rung_list.dart';

void main() {
  testWidgets('RungList prompts confirmation before deleting a non-empty rung', (tester) async {
    final project = LadderProject(
      id: 'test_proj',
      name: 'Test Project',
      networks: [
        LadderNetwork(
          id: 'rung_1',
          name: 'Controle de Bomba Principal',
          nodes: [
            LadderNode(
              id: 'node_1',
              type: NodeType.contactNO,
              config: NodeConfig(tagId: 'START_PB'),
            ),
          ],
        ),
      ],
    );

    final runtime = LadderRuntime();
    bool projectChangedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RungList(
            project: project,
            runtime: runtime,
            networkValidationErrors: const {},
            onNodeSelectionChanged: (rungIdx, nodeIdx) {},
            onNodeEditRequest: (rungIdx, nodeIdx) {},
            onNodeOptionsRequest: (rungIdx, nodeIdx) {},
            onComponentAddRequest: (rungIdx, [insertIdx]) {},
            onDraggingStateChanged: (dragging) {},
            onProjectChanged: () {
              projectChangedCalled = true;
            },
          ),
        ),
      ),
    );

    // Initial state: 1 rung
    expect(find.text('// Controle de Bomba Principal'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Verify Semantics wrapper
    expect(find.bySemanticsLabel('Excluir Rung 0001'), findsOneWidget);

    // Click delete button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Confirmation dialog should be displayed
    expect(find.text('Excluir Rung 0001?'), findsOneWidget);
    expect(find.textContaining('Deseja excluir permanentemente o Rung 0001'), findsOneWidget);

    // Cancel deletion
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Rung is still present, onProjectChanged not called
    expect(project.networks.length, 1);
    expect(projectChangedCalled, isFalse);
    expect(find.text('// Controle de Bomba Principal'), findsOneWidget);

    // Click delete button again
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Confirm deletion
    await tester.tap(find.text('Excluir Rung'));
    await tester.pumpAndSettle();

    // Rung removed and onProjectChanged called
    expect(project.networks.length, 0);
    expect(projectChangedCalled, isTrue);
    expect(find.text('// Controle de Bomba Principal'), findsNothing);
  });

  testWidgets('RungList immediately removes an empty rung without dialog', (tester) async {
    final project = LadderProject(
      id: 'test_proj_empty',
      name: 'Test Project Empty',
      networks: [
        LadderNetwork(
          id: 'empty_rung',
          name: '',
          nodes: [],
        ),
      ],
    );

    final runtime = LadderRuntime();
    bool projectChangedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RungList(
            project: project,
            runtime: runtime,
            networkValidationErrors: const {},
            onNodeSelectionChanged: (rungIdx, nodeIdx) {},
            onNodeEditRequest: (rungIdx, nodeIdx) {},
            onNodeOptionsRequest: (rungIdx, nodeIdx) {},
            onComponentAddRequest: (rungIdx, [insertIdx]) {},
            onDraggingStateChanged: (dragging) {},
            onProjectChanged: () {
              projectChangedCalled = true;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);

    // Click delete on completely empty rung
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Should NOT show confirmation dialog
    expect(find.text('Excluir Rung 0001?'), findsNothing);
    expect(project.networks.length, 0);
    expect(projectChangedCalled, isTrue);
  });
}
