import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    throw details.exception;
  };

  group('ENDAP STUDIO — VALIDAÇÃO RIGOROSA DE VIEWPORT MOBILE E ZERO OVERFLOW', () {
    const mobileViewports = [
      Size(390, 844), // iPhone 12/13/14
      Size(393, 852), // iPhone 14 Pro / 15
      Size(414, 896), // iPhone XR / 11
    ];

    for (final viewport in mobileViewports) {
      testWidgets('Viewport ${viewport.width.toInt()}x${viewport.height.toInt()} — Editor com Empty State (Sem Rungs)', (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final project = LadderProject(
          id: 'proj_empty_${viewport.width.toInt()}',
          name: 'Projeto Vazio',
          tags: {},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: LadderEditorPage(initialProject: project),
          ),
        );
        await tester.pumpAndSettle();

        // Verificar Empty State compacto presente
        expect(find.text('Lógica Ladder IEC Vazia'), findsOneWidget);
        expect(find.text('Adicionar Rung'), findsOneWidget);

        // Verificar Monitor I/O presente e recolhido
        expect(find.text('Monitor I/O'), findsOneWidget);
      });

      testWidgets('Viewport ${viewport.width.toInt()}x${viewport.height.toInt()} — Editor com 1 Rung, Branches e Múltiplas Tags', (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final project = LadderProject(
          id: 'proj_complex_${viewport.width.toInt()}',
          name: 'Controle Complexo',
          tags: {
            'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
            'STOP_BTN': Tag(id: 'STOP_BTN', name: 'Stop', type: TagType.bool, initialValue: TagValue.boolean(false)),
            'EMERGENCY': Tag(id: 'EMERGENCY', name: 'Emergency', type: TagType.bool, initialValue: TagValue.boolean(false)),
            'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor', type: TagType.bool, initialValue: TagValue.boolean(false)),
          },
          networks: [
            LadderNetwork(
              id: 'net_1',
              name: 'Partida com Selo',
              nodes: [
                LadderNode(
                  id: 'par_1',
                  type: NodeType.parallel,
                  config: NodeConfig(),
                  branches: [
                    [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN'))],
                    [LadderNode(id: 'b2', type: NodeType.contactNO, config: NodeConfig(tagId: 'MOTOR_M1'))],
                  ],
                ),
                LadderNode(id: 'nc_stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP_BTN')),
                LadderNode(id: 'nc_emerg', type: NodeType.contactNC, config: NodeConfig(tagId: 'EMERGENCY')),
                LadderNode(id: 'coil_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
              ],
            ),
            LadderNetwork(
              id: 'net_2',
              name: 'Temporização Válvula',
              nodes: [
                LadderNode(id: 'no_m1', type: NodeType.contactNO, config: NodeConfig(tagId: 'MOTOR_M1')),
                LadderNode(id: 'ton_1', type: NodeType.timerTON, config: NodeConfig(tagId: 'T1', presetValue: TagValue.integer(3000))),
                LadderNode(id: 'coil_valve', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_V1')),
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

        // Verificar nós renderizados
        expect(find.text('0001'), findsOneWidget);
        expect(find.text('0002'), findsOneWidget);

        // Expandir Monitor I/O para o estado Semi
        await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
        await tester.pumpAndSettle();

        // Verificar lista de variáveis rápidas e campo de tag personalizada
        expect(find.text('Adicionar'), findsOneWidget);
        expect(find.text('START_BTN'), findsWidgets);
      });
    }

    testWidgets('Navegação e fluxo completo do Ladder dentro do Scaffold sem quebras', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = LadderProject(
        id: 'proj_flow',
        name: 'Fluxo Ladder',
        tags: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudioScaffold(
            initialIndex: 1, // Inicia no Avançado
            initialProject: project,
            networkManager: NetworkManager(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Como a aba 1 agora é o próprio LadderEditorPage diretamente:
      expect(find.byType(LadderEditorPage), findsOneWidget);

      // Testar clique em "Adicionar Rung" no empty state
      expect(find.text('Adicionar Rung'), findsOneWidget);
      await tester.tap(find.text('Adicionar Rung'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Agora o Rung 0001 existe
      expect(find.text('0001'), findsOneWidget);

      // Inserir NO da toolbox
      await tester.tap(find.text('NO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Inserir COIL da toolbox
      await tester.tap(find.text('COIL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Testar validação
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
    });
  });
}
