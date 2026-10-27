import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:endap_studio/core/services/network_manager.dart';

void main() {
  group('LadderEditorPage Multi-Controller UI Integration Tests', () {
    late LadderProject testProject;

    setUp(() {
      testProject = LadderProject.blank(name: 'Projeto Teste Distribuído');
      testProject.tags['I0.0'] = Tag(
        id: 'I0.0',
        name: 'Sensor 1',
        address: 'I0.0',
        type: TagType.bool,
        initialValue: TagValue(boolValue: true),
      );
      testProject.tags['Q0.0'] = Tag(
        id: 'Q0.0',
        name: 'Motor 1',
        address: 'Q0.0',
        type: TagType.bool,
        initialValue: TagValue(boolValue: false),
      );

      // Rung 0: Gateway
      final r0 = LadderNetwork(
        id: 'net_gw',
        name: 'Controle Gateway Principal',
        targetControllerId: 'GATEWAY',
        targetControllerName: 'Gateway',
        isEnabled: true,
      );
      r0.addNode(LadderNode(id: 'c0', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')));
      r0.addNode(LadderNode(id: 'coil0', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')));
      testProject.networks.add(r0);

      // Rung 1: Nó 01 (Prensa)
      final r1 = LadderNetwork(
        id: 'net_node1',
        name: 'Ciclo Prensa Nó 01',
        targetControllerId: 'node_01',
        targetControllerName: 'Nó 01',
        isEnabled: true,
      );
      r1.addNode(LadderNode(id: 'c1', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')));
      r1.addNode(LadderNode(id: 'coil1', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')));
      testProject.networks.add(r1);

      // Rung 2: Nó 02 (Desativado)
      final r2 = LadderNetwork(
        id: 'net_node2',
        name: 'Esteira Nó 02 (Desativada)',
        targetControllerId: 'node_02',
        targetControllerName: 'Nó 02',
        isEnabled: false,
      );
      r2.addNode(LadderNode(id: 'c2', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')));
      r2.addNode(LadderNode(id: 'coil2', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')));
      testProject.networks.add(r2);
    });

    testWidgets('Renders all controllers in global plant view with original sequential indices', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: testProject,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Devem aparecer os 3 rungs declarados
      expect(find.text('// Controle Gateway Principal'), findsOneWidget);
      expect(find.text('// Ciclo Prensa Nó 01'), findsOneWidget);
      expect(find.text('// Esteira Nó 02 (Desativada)'), findsOneWidget);

      // Numeração sequencial original preservada (0001, 0002, 0003)
      expect(find.text('0001'), findsOneWidget);
      expect(find.text('0002'), findsOneWidget);
      expect(find.text('0003'), findsOneWidget);

      // Badges dos controladores visíveis nos rungs
      expect(find.text('Gateway'), findsAtLeastNWidgets(1));
      expect(find.text('Nó 01'), findsAtLeastNWidgets(1));
      expect(find.text('Nó 02'), findsAtLeastNWidgets(1));

      // Indicadores de ativo e inativo
      expect(find.text('ATIVO'), findsNWidgets(2));
      expect(find.text('INATIVO'), findsNWidgets(1));
    });

    testWidgets('Filtering by individual controller shows only its rungs while keeping original index', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: testProject,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no chip do Nó 01 no filtro superior
      final node1Chip = find.text('Nó 01');
      expect(node1Chip, findsAtLeastNWidgets(1));
      await tester.tap(node1Chip.first);
      await tester.pumpAndSettle();

      // Agora deve exibir apenas o Rung do Nó 01
      expect(find.text('// Ciclo Prensa Nó 01'), findsOneWidget);
      expect(find.text('// Controle Gateway Principal'), findsNothing);
      expect(find.text('// Esteira Nó 02 (Desativada)'), findsNothing);

      // O índice original 0002 é preservado!
      expect(find.text('0002'), findsOneWidget);
      expect(find.text('0001'), findsNothing);

      // Botão de deploy adapta para o Nó 01
      expect(find.text('Deploy (Nó 01)'), findsOneWidget);
    });

    testWidgets('Filtering by Inativos shows only disabled rungs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: testProject,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no chip "Inativos"
      final inativosChip = find.text('Inativos');
      expect(inativosChip, findsOneWidget);
      await tester.tap(inativosChip);
      await tester.pumpAndSettle();

      // Apenas o Rung 3 desativado deve estar visível
      expect(find.text('// Esteira Nó 02 (Desativada)'), findsOneWidget);
      expect(find.text('// Controle Gateway Principal'), findsNothing);
      expect(find.text('// Ciclo Prensa Nó 01'), findsNothing);
      expect(find.text('0003'), findsOneWidget);
    });

    testWidgets('Toggling ATIVO chip toggles isEnabled in project', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LadderEditorPage(
              initialProject: testProject,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rung 0 está ATIVO. Vamos clicar no botão ATIVO do primeiro rung para desativá-lo
      final ativoButtons = find.text('ATIVO');
      expect(ativoButtons, findsNWidgets(2));
      await tester.tap(ativoButtons.first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // Rung 0 agora deve estar INATIVO
      expect(testProject.networks[0].isEnabled, isFalse);
      expect(find.text('INATIVO'), findsNWidgets(2));
    });
  });
}
