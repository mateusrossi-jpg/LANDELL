import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/ui/editor/layout/ladder_layout_engine.dart';

void main() {
  group('LADDER GEOMETRY AND TOPOLOGY COMPREHENSIVE TESTS', () {
    test('A) 1 Contato + Bobina -> Geometria ortogonal e conexões exatas', () {
      final network = LadderNetwork(
        id: 'net_a',
        nodes: [
          LadderNode(id: 'no_1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_1')),
          LadderNode(id: 'coil_1', type: NodeType.coil, config: NodeConfig(tagId: 'OUT_1')),
        ],
      )..rebuildConnections();

      expect(network.connections.length, equals(1));
      expect(network.connections.first.fromNodeId, equals('no_1'));
      expect(network.connections.first.toNodeId, equals('coil_1'));

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      expect(layout.nodes.length, equals(2));
      // First node at startX (24.0), width 80 -> output at 104.0
      expect(layout.nodes[0].inputTerminal.x, equals(24.0));
      expect(layout.nodes[0].outputTerminal.x, equals(104.0));
      // Second node is a COIL anchored at the right end of the rung before L2 rail lead (140.0)
      expect(layout.nodes[1].inputTerminal.x, equals(140.0));
      expect(layout.nodes[1].outputTerminal.x, equals(220.0));

      // All wires are strictly horizontal (since no branches)
      for (final wire in layout.wires) {
        expect(wire.isHorizontal, isTrue);
        expect(wire.from.y, equals(layout.mainAxisY));
        expect(wire.to.y, equals(layout.mainAxisY));
      }
    });

    test('B) 2 Contatos em Série -> Geometria e alinhamento', () {
      final network = LadderNetwork(
        id: 'net_b',
        nodes: [
          LadderNode(id: 'no_1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_1')),
          LadderNode(id: 'nc_1', type: NodeType.contactNC, config: NodeConfig(tagId: 'IN_2')),
          LadderNode(id: 'coil_1', type: NodeType.coil, config: NodeConfig(tagId: 'OUT_1')),
        ],
      )..rebuildConnections();

      expect(network.connections.length, equals(2));
      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      expect(layout.nodes.length, equals(3));
      for (final wire in layout.wires) {
        expect(wire.isHorizontal, isTrue);
      }
    });

    test('C) Paralelo com 2 ramos -> Geometria ortogonal determinística e junctions coincidentes', () {
      final parallelNode = LadderNode(
        id: 'par_2',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_A'))],
          [LadderNode(id: 'b2', type: NodeType.contactNC, config: NodeConfig(tagId: 'IN_B'))],
        ],
      );
      final coilNode = LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final network = LadderNetwork(id: 'net_c', nodes: [parallelNode, coilNode]);
      network.rebuildConnections();

      // Connections: par_2->coil, par_2->b1, b1->coil, par_2->b2, b2->coil
      expect(network.connections.length, equals(5));

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      expect(layout.junctions.length, equals(2));

      final entryJunction = layout.junctions.firstWhere((j) => j.isSplit);
      final exitJunction = layout.junctions.firstWhere((j) => !j.isSplit);

      // Junction points must match mainAxisY
      expect(entryJunction.point.y, equals(layout.mainAxisY));
      expect(exitJunction.point.y, equals(layout.mainAxisY));
      expect(exitJunction.point.x, greaterThan(entryJunction.point.x));

      // Vertical bus wires: strictly vertical
      final verticalWires = layout.wires.where((w) => w.isVertical).toList();
      expect(verticalWires.length, equals(2)); // Left bus and Right bus
      expect(verticalWires[0].from.x, equals(entryJunction.point.x));
      expect(verticalWires[1].from.x, equals(exitJunction.point.x));
      expect(verticalWires[0].from.y, equals(layout.mainAxisY));
      expect(verticalWires[0].to.y, equals(layout.mainAxisY + LadderLayoutMetrics.branchVerticalGap));
    });

    test('D) Paralelo com 3 ramos -> Espaçamento uniforme e barramento vertical contínuo', () {
      final parallelNode = LadderNode(
        id: 'par_3',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_1'))],
          [LadderNode(id: 'b2', type: NodeType.contactNC, config: NodeConfig(tagId: 'IN_2'))],
          [LadderNode(id: 'b3', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_3'))],
        ],
      );
      final coilNode = LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final network = LadderNetwork(id: 'net_d', nodes: [parallelNode, coilNode]);
      network.rebuildConnections();

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      expect(layout.nodes.length, equals(4)); // 3 branch nodes + 1 coil

      // Verify branch vertical coordinates
      final branchNodes = layout.nodes.where((n) => n.parentParallelId == 'par_3').toList();
      expect(branchNodes.length, equals(3));
      expect(branchNodes[0].inputTerminal.y, equals(layout.mainAxisY));
      expect(branchNodes[1].inputTerminal.y, equals(layout.mainAxisY + LadderLayoutMetrics.branchVerticalGap));
      expect(branchNodes[2].inputTerminal.y, equals(layout.mainAxisY + 2 * LadderLayoutMetrics.branchVerticalGap));

      // Vertical bus spans full height from mainY to last branchY
      final verticalWires = layout.wires.where((w) => w.isVertical).toList();
      expect(verticalWires.length, equals(2));
      expect(verticalWires[0].length, equals(2 * LadderLayoutMetrics.branchVerticalGap));
    });

    test('E & F) Paralelo com 4 e 5 ramos -> Algoritmo genérico N ramos', () {
      for (int n = 4; n <= 5; n++) {
        final branches = List.generate(n, (i) => [
          LadderNode(id: 'b_$i', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_$i'))
        ]);
        final parallelNode = LadderNode(
          id: 'par_$n',
          type: NodeType.parallel,
          config: NodeConfig(),
          branches: branches,
        );
        final coilNode = LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

        final network = LadderNetwork(id: 'net_$n', nodes: [parallelNode, coilNode]);
        network.rebuildConnections();

        final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
        final verticalWires = layout.wires.where((w) => w.isVertical).toList();
        expect(verticalWires.length, equals(2));
        expect(verticalWires[0].length, equals((n - 1) * LadderLayoutMetrics.branchVerticalGap));
      }
    });

    test('G) Paralelos em série (Paralelo A -> Paralelo B -> Saída) -> Junctions independentes e conexão em série', () {
      final parA = LadderNode(
        id: 'par_A',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'a1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A1'))],
          [LadderNode(id: 'a2', type: NodeType.contactNO, config: NodeConfig(tagId: 'A2'))],
        ],
      );

      final parB = LadderNode(
        id: 'par_B',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'B1'))],
          [LadderNode(id: 'b2', type: NodeType.contactNC, config: NodeConfig(tagId: 'B2'))],
        ],
      );

      final coilNode = LadderNode(id: 'coil_out', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final network = LadderNetwork(id: 'net_series_par', nodes: [parA, parB, coilNode]);
      network.rebuildConnections();

      // Connections:
      // par_A -> par_B
      // a1 -> par_B, a2 -> par_B
      // par_B -> coil_out
      // b1 -> coil_out, b2 -> coil_out
      expect(network.connections.any((c) => c.fromNodeId == 'par_A' && c.toNodeId == 'par_B'), isTrue);
      expect(network.connections.any((c) => c.fromNodeId == 'a1' && c.toNodeId == 'par_B'), isTrue);
      expect(network.connections.any((c) => c.fromNodeId == 'a2' && c.toNodeId == 'par_B'), isTrue);
      expect(network.connections.any((c) => c.fromNodeId == 'par_B' && c.toNodeId == 'coil_out'), isTrue);
      expect(network.connections.any((c) => c.fromNodeId == 'b1' && c.toNodeId == 'coil_out'), isTrue);
      expect(network.connections.any((c) => c.fromNodeId == 'b2' && c.toNodeId == 'coil_out'), isTrue);

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      // Must have 4 distinct junctions (2 for Group A, 2 for Group B)
      expect(layout.junctions.length, equals(4));

      final j1A = layout.junctions[0];
      final j2A = layout.junctions[1];
      final j1B = layout.junctions[2];
      final j2B = layout.junctions[3];

      expect(j1A.point.x, lessThan(j2A.point.x));
      expect(j2A.point.x, lessThan(j1B.point.x));
      expect(j1B.point.x, lessThan(j2B.point.x));

      // Connecting wire between Group A and Group B must exist and be strictly horizontal
      final interGroupWire = layout.wires.firstWhere(
        (w) => w.from == j2A.point && w.to == j1B.point,
      );
      expect(interGroupWire.isHorizontal, isTrue);
      expect(interGroupWire.length, equals(LadderLayoutMetrics.minWireGap));
    });

    test('H, I, J, K) Paralelo seguido de Bloco (TON, TOF, CTU, COIL)', () {
      final par = LadderNode(
        id: 'par_block',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'c1', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_1'))],
          [LadderNode(id: 'c2', type: NodeType.contactNC, config: NodeConfig(tagId: 'IN_2'))],
        ],
      );

      final ton = LadderNode(id: 'ton', type: NodeType.timerTON, config: NodeConfig(tagId: 'T1', presetValue: TagValue.integer(2000)));
      final coil = LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final network = LadderNetwork(id: 'net_par_ton', nodes: [par, ton, coil]);
      network.rebuildConnections();

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      final tonGeo = layout.nodes.firstWhere((n) => n.node.id == 'ton');

      // TON must remain aligned on the mainAxisY
      expect(tonGeo.inputTerminal.y, equals(layout.mainAxisY));
      expect(tonGeo.outputTerminal.y, equals(layout.mainAxisY));
    });

    test('L) Dois paralelos com quantidade diferente de ramos (Grupo A = 2, Grupo B = 3)', () {
      final parA = LadderNode(
        id: 'par_A',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'a1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A1'))],
          [LadderNode(id: 'a2', type: NodeType.contactNO, config: NodeConfig(tagId: 'A2'))],
        ],
      );

      final parB = LadderNode(
        id: 'par_B',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'B1'))],
          [LadderNode(id: 'b2', type: NodeType.contactNC, config: NodeConfig(tagId: 'B2'))],
          [LadderNode(id: 'b3', type: NodeType.contactNO, config: NodeConfig(tagId: 'B3'))],
        ],
      );

      final coil = LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final network = LadderNetwork(id: 'net_diff_par', nodes: [parA, parB, coil]);
      network.rebuildConnections();

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);
      final verticalWires = layout.wires.where((w) => w.isVertical).toList();
      expect(verticalWires.length, equals(4)); // 2 for group A + 2 for group B
      expect(verticalWires[0].length, equals(LadderLayoutMetrics.branchVerticalGap)); // Group A height
      expect(verticalWires[1].length, equals(LadderLayoutMetrics.branchVerticalGap));
      expect(verticalWires[2].length, equals(2 * LadderLayoutMetrics.branchVerticalGap)); // Group B height
      expect(verticalWires[3].length, equals(2 * LadderLayoutMetrics.branchVerticalGap));
    });

    test('E2E: Paralelo A -> Paralelo B -> Saída com Validação, Compilação e Simulação Real', () {
      final project = LadderProject(
        id: 'proj_e2e_double_parallel',
        name: 'E2E Double Parallel',
        tags: {
          'A1': Tag(id: 'A1', name: 'A1', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'A2': Tag(id: 'A2', name: 'A2', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'B1': Tag(id: 'B1', name: 'B1', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'B2': Tag(id: 'B2', name: 'B2', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'OUT': Tag(id: 'OUT', name: 'OUT', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final parA = LadderNode(
        id: 'par_A',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'node_a1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A1'))],
          [LadderNode(id: 'node_a2', type: NodeType.contactNO, config: NodeConfig(tagId: 'A2'))],
        ],
      );

      final parB = LadderNode(
        id: 'par_B',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'node_b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'B1'))],
          [LadderNode(id: 'node_b2', type: NodeType.contactNO, config: NodeConfig(tagId: 'B2'))],
        ],
      );

      final coil = LadderNode(id: 'node_out', type: NodeType.coil, config: NodeConfig(tagId: 'OUT'));

      final rung = LadderNetwork(id: 'rung_1', nodes: [parA, parB, coil])..rebuildConnections();
      project.networks.add(rung);

      // Validate
      final validator = GraphValidator();
      final valResult = validator.validate(project);
      expect(valResult.isValid, isTrue);

      // Run
      final runtime = LadderRuntime();
      runtime.loadProject(valResult.executableGraph!);

      // Condition: (A1 OR A2) AND (B1 OR B2) => OUT
      // 1. All false -> OUT false
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('OUT'), isFalse);

      // 2. A1 true, B1 false -> OUT false
      runtime.tagStore.setBool('A1', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('OUT'), isFalse);

      // 3. A1 true, B2 true -> OUT true
      runtime.tagStore.setBool('B2', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('OUT'), isTrue);

      // 4. A1 false, A2 true, B1 true, B2 false -> OUT true
      runtime.tagStore.setBool('A1', false);
      runtime.tagStore.setBool('A2', true);
      runtime.tagStore.setBool('B1', true);
      runtime.tagStore.setBool('B2', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('OUT'), isTrue);

      // 5. Test JSON Save and Reload
      final json = project.toJson();
      final restored = LadderProject.fromJson(json);
      final valRestored = validator.validate(restored);
      expect(valRestored.isValid, isTrue);
    });
  });
}
