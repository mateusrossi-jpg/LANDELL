import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/ui/editor/layout/ladder_layout_engine.dart';
import 'package:endap_studio/ladder/ui/editor/widgets/ladder_network_canvas.dart';

void main() {
  group('1. TESTE 1 — CASO A: CONTATO -> BOBINA (Ramo Único)', () {
    test('Calcula geometria ortogonal perfeita sem curvas ou diagonais', () {
      final network = LadderNetwork(
        id: 'net_1',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      expect(layout.nodes.length, 2);
      expect(layout.mainAxisY, 32.0);

      // Todos os fios devem ser 100% horizontais ou verticais
      for (final wire in layout.wires) {
        expect(wire.isHorizontal || wire.isVertical, isTrue);
        if (wire.isHorizontal) {
          expect(wire.from.y, wire.to.y);
          expect(wire.from.y, 32.0);
        }
      }

      // Terminal do Contato 1 conecta exatamente no fio anterior e posterior
      final contactGeo = layout.nodes[0];
      final coilGeo = layout.nodes[1];

      expect(contactGeo.inputTerminal.y, 32.0);
      expect(contactGeo.outputTerminal.y, 32.0);
      expect(coilGeo.inputTerminal.y, 32.0);
      expect(coilGeo.outputTerminal.y, 32.0);

      // Fio intermediário liga perfeitamente output do Contato ao input da Bobina
      final midWire = layout.wires.firstWhere((w) => w.from.x == contactGeo.outputTerminal.x);
      expect(midWire.to.x, coilGeo.inputTerminal.x);
      expect(midWire.from.y, 32.0);
      expect(midWire.to.y, 32.0);
    });
  });

  group('2. TESTE 2 — CASO B: PARALELO COM 2 RAMOS', () {
    test('Ambos os ramos compartilham exatamente o mesmo branchEntryX e branchExitX', () {
      final network = LadderNetwork(
        id: 'net_2',
        nodes: [
          LadderNode(
            id: 'par_1',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'b1_1', type: NodeType.contactNO, config: NodeConfig(tagId: 'BTN_A'))],
              [LadderNode(id: 'b2_1', type: NodeType.contactNO, config: NodeConfig(tagId: 'BTN_B'))],
            ],
          ),
          LadderNode(id: 'out_1', type: NodeType.coil, config: NodeConfig(tagId: 'COIL_1')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      final branchNodes = layout.nodes.where((n) => n.parentParallelId == 'par_1').toList();
      expect(branchNodes.length, 2);

      final nodeA = branchNodes[0];
      final nodeB = branchNodes[1];

      // Y dos ramos
      expect(nodeA.inputTerminal.y, 32.0);
      expect(nodeB.inputTerminal.y, 96.0); // 32 + 64

      // X de início e fim dos nós nos ramos são idênticos
      expect(nodeA.bounds.left, nodeB.bounds.left);
      expect(nodeA.bounds.right, nodeB.bounds.right);

      // Barramento vertical esquerdo conecta entryX perfeitamente do ramo 0 ao ramo 1
      final leftRail = layout.wires.firstWhere((w) => w.isVertical && w.from.x == layout.junctions.first.point.x);
      expect(leftRail.from.y, 32.0);
      expect(leftRail.to.y, 96.0);
      expect(leftRail.from.x, leftRail.to.x);

      // Barramento vertical direito conecta exitX perfeitamente do ramo 0 ao ramo 1
      final rightRail = layout.wires.firstWhere((w) => w.isVertical && w.from.x != leftRail.from.x);
      expect(rightRail.from.y, 32.0);
      expect(rightRail.to.y, 96.0);
      expect(rightRail.from.x, rightRail.to.x);

      // Fios horizontais de ambos os ramos terminam no mesmo X de saída
      final wireExitA = layout.wires.firstWhere((w) => w.from.x == nodeA.outputTerminal.x && w.from.y == 32.0);
      final wireExitB = layout.wires.firstWhere((w) => w.from.x == nodeB.outputTerminal.x && w.from.y == 96.0);
      expect(wireExitA.to.x, rightRail.from.x);
      expect(wireExitB.to.x, rightRail.from.x);
    });
  });

  group('3. TESTE 3 — CASO C: PARALELO COM 3 RAMOS', () {
    test('3 ramos com Ys consistentes (32, 96, 160) e alinhamento X exato', () {
      final network = LadderNetwork(
        id: 'net_3',
        nodes: [
          LadderNode(
            id: 'par_3',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'c1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A'))],
              [LadderNode(id: 'c2', type: NodeType.contactNO, config: NodeConfig(tagId: 'B'))],
              [LadderNode(id: 'c3', type: NodeType.contactNO, config: NodeConfig(tagId: 'C'))],
            ],
          ),
          LadderNode(id: 'out_3', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      final branchNodes = layout.nodes.where((n) => n.parentParallelId == 'par_3').toList();
      expect(branchNodes.length, 3);

      expect(branchNodes[0].inputTerminal.y, 32.0);
      expect(branchNodes[1].inputTerminal.y, 96.0);
      expect(branchNodes[2].inputTerminal.y, 160.0);

      // Todos os nós começam e terminam no mesmo X
      for (final n in branchNodes) {
        expect(n.bounds.left, branchNodes[0].bounds.left);
        expect(n.bounds.right, branchNodes[0].bounds.right);
      }

      // Barramentos verticais cobrem de y=32 a y=160
      final leftRail = layout.wires.firstWhere((w) => w.isVertical && w.from.x == layout.junctions.first.point.x);
      expect(leftRail.from.y, 32.0);
      expect(leftRail.to.y, 160.0);

      // Junction dots nos ramos intermediários
      expect(layout.junctions.where((j) => j.isTeeJunction).length, 4); // Entry & Exit nos ramos 0 e 1
    });
  });

  group('4. TESTE 4 — CASO D: PARALELO -> CONTATO -> BOBINA', () {
    test('Conexão em série entre saída do paralelo e contato seguinte é 100% horizontal', () {
      final network = LadderNetwork(
        id: 'net_4',
        nodes: [
          LadderNode(
            id: 'par_4',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'p1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START'))],
              [LadderNode(id: 'p2', type: NodeType.contactNO, config: NodeConfig(tagId: 'SEL'))],
            ],
          ),
          LadderNode(id: 'mid_contact', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP')),
          LadderNode(id: 'coil_4', type: NodeType.coil, config: NodeConfig(tagId: 'PUMP')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      final midContact = layout.nodes.firstWhere((n) => n.node.id == 'mid_contact');
      final exitJunction = layout.junctions.firstWhere((j) => !j.isSplit);

      // Fio ligando a saída do paralelo à entrada do contato STOP
      final connectingWire = layout.wires.firstWhere((w) => w.from.x == exitJunction.point.x && w.isHorizontal);
      expect(connectingWire.to.x, midContact.inputTerminal.x);
      expect(connectingWire.from.y, 32.0);
      expect(connectingWire.to.y, 32.0);
      expect(connectingWire.isHorizontal, isTrue);
    });
  });

  group('5. TESTE 5 — CASO E: DOIS GRUPOS PARALELOS EM SÉRIE', () {
    test('Saída do Grupo 1 conecta à Entrada do Grupo 2 por linha horizontal determinística', () {
      final network = LadderNetwork(
        id: 'net_5',
        nodes: [
          LadderNode(
            id: 'par_g1',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'a', type: NodeType.contactNO, config: NodeConfig(tagId: 'A'))],
              [LadderNode(id: 'b', type: NodeType.contactNO, config: NodeConfig(tagId: 'B'))],
            ],
          ),
          LadderNode(
            id: 'par_g2',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'c', type: NodeType.contactNO, config: NodeConfig(tagId: 'C'))],
              [LadderNode(id: 'd', type: NodeType.contactNO, config: NodeConfig(tagId: 'D'))],
            ],
          ),
          LadderNode(id: 'coil_5', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      final exitG1 = layout.junctions[1]; // Exit G1
      final entryG2 = layout.junctions[2]; // Entry G2

      expect(exitG1.point.y, 32.0);
      expect(entryG2.point.y, 32.0);
      expect(entryG2.point.x, greaterThan(exitG1.point.x));

      // Fio intermediário conectando Saída G1 -> Entrada G2
      final interGroupWire = layout.wires.firstWhere((w) => w.from.x == exitG1.point.x && w.isHorizontal);
      expect(interGroupWire.to.x, entryG2.point.x);
      expect(interGroupWire.from.y, 32.0);
      expect(interGroupWire.to.y, 32.0);
      expect(interGroupWire.isHorizontal, isTrue);
      expect(interGroupWire.length, 16.0); // minWireGap

      // Sem diagonais, sem curvas, todos os fios são estritamente horizontais ou verticais
      for (final wire in layout.wires) {
        expect(wire.isHorizontal || wire.isVertical, isTrue);
      }
    });
  });

  group('6. RENDERIZAÇÃO NO CANVAS EM VIEWPORTS MOBILE', () {
    for (final size in [
      const Size(390, 844),
      const Size(393, 852),
      const Size(414, 896),
    ]) {
      testWidgets('LadderNetworkCanvas renderiza Caso 5 sem overflow em ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final project = LadderProject(
          id: 'p_test',
          name: 'Test Canvas',
          networks: [
            LadderNetwork(
              id: 'net_test',
              nodes: [
                LadderNode(
                  id: 'par_1',
                  type: NodeType.parallel,
                  config: NodeConfig(),
                  branches: [
                    [LadderNode(id: 'a', type: NodeType.contactNO, config: NodeConfig(tagId: 'A'))],
                    [LadderNode(id: 'b', type: NodeType.contactNO, config: NodeConfig(tagId: 'B'))],
                  ],
                ),
                LadderNode(
                  id: 'par_2',
                  type: NodeType.parallel,
                  config: NodeConfig(),
                  branches: [
                    [LadderNode(id: 'c', type: NodeType.contactNO, config: NodeConfig(tagId: 'C'))],
                    [LadderNode(id: 'd', type: NodeType.contactNO, config: NodeConfig(tagId: 'D'))],
                  ],
                ),
                LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'Y0')),
              ],
            ),
          ],
        );

        final runtime = LadderRuntime();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: LadderNetworkCanvas(
                  project: project,
                  rungIndex: 0,
                  runtime: runtime,
                  selectedRungIndex: null,
                  selectedNodeIndex: null,
                  isSimulationRunning: true,
                  onToggleTag: null,
                  onNodeSelectionChanged: (r, n) {},
                  onNodeEditRequest: (r, n) {},
                  onNodeOptionsRequest: (r, n) {},
                  onComponentAddRequest: (r, [i]) {},
                  onDraggingStateChanged: (_) {},
                  onProjectChanged: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
        expect(find.text('D'), findsOneWidget);
        expect(find.text('Y0'), findsOneWidget);
      });
    }
  });
}
