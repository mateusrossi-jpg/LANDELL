import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:endap_studio/ladder/ui/editor/widgets/ladder_node_visual.dart';

void main() {
  group('Ladder Editor UI & Geometry Tests', () {
    testWidgets('New Project starts with empty clean state without auto-generated logic', (tester) async {
      final cleanProject = LadderProject(
        id: 'test_clean_proj',
        name: 'Projeto Limpo',
        tags: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LadderEditorPage(initialProject: cleanProject),
        ),
      );
      await tester.pumpAndSettle();

      // Should show clean empty state and no rungs initially
      expect(find.text('Lógica Ladder IEC Vazia'), findsOneWidget);
      expect(find.text('Adicionar Rung'), findsOneWidget);
      expect(find.byType(LadderNodeVisual), findsNothing);
    });

    testWidgets('Rung layout renders node visuals cleanly without canvas error clutter', (tester) async {
      final project = LadderProject(
        id: 'test_proj',
        name: 'Teste Geometria',
        networks: [
          LadderNetwork(
            id: 'net_1',
            nodes: [
              LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
              LadderNode(id: 'n2', type: NodeType.timerTON, config: NodeConfig(tagId: 'T1', presetValue: TagValue.integer(5000))),
              LadderNode(id: 'n3', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_OUT')),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LadderEditorPage(initialProject: project),
        ),
      );
      await tester.pumpAndSettle();

      // Verify node visuals exist
      expect(find.byType(LadderNodeVisual), findsNWidgets(3));
      expect(find.text('START_BTN'), findsOneWidget);
      expect(find.text('MOTOR_OUT'), findsOneWidget);

      // Verify header industrial elements
      expect(find.textContaining('ENDAP'), findsOneWidget);
      expect(find.textContaining('Simula'), findsOneWidget);
    });


    testWidgets('Parallel branch geometry renders correctly in multiple mobile viewports (390x844, 393x852, 414x896)', (tester) async {
      final resolutions = [
        const Size(390, 844),
        const Size(393, 852),
        const Size(414, 896),
      ];

      for (final size in resolutions) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final projectWithBranch = LadderProject(
          id: 'test_branch_proj',
          name: 'Teste Ramo',
          networks: [
            LadderNetwork(
              id: 'net_1',
              nodes: [
                LadderNode(
                  id: 'par_1',
                  type: NodeType.parallel,
                  config: NodeConfig(),
                  branches: [
                    [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_A'))],
                    [LadderNode(id: 'b2', type: NodeType.contactNC, config: NodeConfig(tagId: 'IN_B'))],
                  ],
                ),
                LadderNode(id: 'coil_1', type: NodeType.coil, config: NodeConfig(tagId: 'OUT_Y0')),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: LadderEditorPage(initialProject: projectWithBranch),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('IN_A'), findsOneWidget);
        expect(find.text('IN_B'), findsOneWidget);
        expect(find.text('OUT_Y0'), findsOneWidget);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
