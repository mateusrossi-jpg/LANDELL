import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/ui/editor/layout/ladder_layout_engine.dart';

void main() {
  group('LadderLayoutEngine Mathematical & Topological Tests', () {
    test('Linear Rung: L1 -> NO -> COIL -> L2 has identical Y axis for all nodes and wires', () {
      final network = LadderNetwork(
        id: 'net_1',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START')),
          LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      expect(layout.nodes.length, 2);
      expect(layout.mainAxisY, 32.0);

      // Verify node terminals are strictly on mainAxisY
      for (final node in layout.nodes) {
        expect(node.inputTerminal.y, 32.0);
        expect(node.outputTerminal.y, 32.0);
      }

      // Verify all wire segments are strictly horizontal on mainAxisY
      for (final wire in layout.wires) {
        expect(wire.isHorizontal, isTrue);
        expect(wire.from.y, 32.0);
        expect(wire.to.y, 32.0);
      }

      // Verify wire continuity: first wire reaches node[0].in, intermediate wire connects node[0].out to node[1].in, last wire connects node[1].out to rail
      final wire0 = layout.wires.firstWhere((w) => w.to == layout.nodes[0].inputTerminal);
      final wire1 = layout.wires.firstWhere((w) => w.from == layout.nodes[0].outputTerminal);
      final wire2 = layout.wires.firstWhere((w) => w.from == layout.nodes[1].outputTerminal);

      expect(wire0.to, layout.nodes[0].inputTerminal);
      expect(wire1.to, layout.nodes[1].inputTerminal);
      expect(wire2.from, layout.nodes[1].outputTerminal);
    });

    test('Parallel with 2 branches: Shared Entry/Exit Junctions and Exact Orthogonal Leads', () {
      final network = LadderNetwork(
        id: 'net_par_2',
        nodes: [
          LadderNode(
            id: 'par',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'a', type: NodeType.contactNO, config: NodeConfig(tagId: 'A'))],
              [LadderNode(id: 'b', type: NodeType.contactNO, config: NodeConfig(tagId: 'B'))],
            ],
          ),
          LadderNode(id: 'c', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      expect(layout.junctions.length, 2);
      final entryJunction = layout.junctions.firstWhere((j) => j.isSplit);
      final exitJunction = layout.junctions.firstWhere((j) => !j.isSplit);

      // Entry/Exit junctions on mainAxisY
      expect(entryJunction.point.y, 32.0);
      expect(exitJunction.point.y, 32.0);

      // 2 branch connection points per junction
      expect(entryJunction.connectedPoints.length, 2);
      expect(exitJunction.connectedPoints.length, 2);

      // First branch on main axis (y=32), second branch on lower branch axis (y=96)
      expect(entryJunction.connectedPoints[0].y, 32.0);
      expect(entryJunction.connectedPoints[1].y, 96.0);
      expect(exitJunction.connectedPoints[0].y, 32.0);
      expect(exitJunction.connectedPoints[1].y, 96.0);

      // Vertical bus bars exist and connect top to bottom without crossing node bodies
      final verticalWires = layout.wires.where((w) => w.isVertical).toList();
      expect(verticalWires.length, 2); // Left vertical bus & Right vertical bus
      expect(verticalWires[0].from.y, 32.0);
      expect(verticalWires[0].to.y, 96.0);
      expect(verticalWires[1].from.y, 32.0);
      expect(verticalWires[1].to.y, 96.0);
    });

    test('Parallel with 3 branches: Continuous Shared Vertical Rails', () {
      final network = LadderNetwork(
        id: 'net_par_3',
        nodes: [
          LadderNode(
            id: 'par',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'a', type: NodeType.contactNO, config: NodeConfig(tagId: 'A'))],
              [LadderNode(id: 'b', type: NodeType.contactNO, config: NodeConfig(tagId: 'B'))],
              [LadderNode(id: 'c', type: NodeType.contactNC, config: NodeConfig(tagId: 'C'))],
            ],
          ),
          LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      final verticalWires = layout.wires.where((w) => w.isVertical).toList();
      expect(verticalWires.length, 2);
      expect(verticalWires[0].from.y, 32.0);
      expect(verticalWires[0].to.y, 160.0); // 32 + 2 * 64
      expect(verticalWires[1].from.y, 32.0);
      expect(verticalWires[1].to.y, 160.0);
    });

    test('Multiple consecutive parallels: Continuous Electrical Flow Without Square Collision', () {
      final network = LadderNetwork(
        id: 'net_multi_par',
        nodes: [
          LadderNode(
            id: 'par1',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'a1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A1'))],
              [LadderNode(id: 'a2', type: NodeType.contactNO, config: NodeConfig(tagId: 'A2'))],
            ],
          ),
          LadderNode(
            id: 'par2',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'B1'))],
              [LadderNode(id: 'b2', type: NodeType.contactNO, config: NodeConfig(tagId: 'B2'))],
            ],
          ),
          LadderNode(id: 'coil', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      expect(layout.junctions.length, 4); // 2 entry + 2 exit junctions

      // Check non-overlapping bounds
      final par1ExitX = layout.junctions[1].point.x;
      final par2EntryX = layout.junctions[2].point.x;

      expect(par2EntryX, greaterThanOrEqualTo(par1ExitX));

      // There is an electrical wire bridging par1 exit to par2 entry
      final bridgeWire = layout.wires.firstWhere((w) => w.isHorizontal && w.from.x == par1ExitX && w.to.x == par2EntryX);
      expect(bridgeWire.from.y, 32.0);
      expect(bridgeWire.to.y, 32.0);
    });

    test('Verification of Non-overlapping Node Rectangles and Clean Boundaries', () {
      final network = LadderNetwork(
        id: 'net_audit',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'A')),
          LadderNode(id: 'n2', type: NodeType.timerTON, config: NodeConfig(tagId: 'T1')),
          LadderNode(
            id: 'par',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [LadderNode(id: 'p1', type: NodeType.contactNO, config: NodeConfig(tagId: 'P1'))],
              [LadderNode(id: 'p2', type: NodeType.counterCTU, config: NodeConfig(tagId: 'C1'))],
              [LadderNode(id: 'p3', type: NodeType.contactNC, config: NodeConfig(tagId: 'P3'))],
            ],
          ),
          LadderNode(id: 'n3', type: NodeType.coil, config: NodeConfig(tagId: 'OUT')),
        ],
      );

      final layout = LadderLayoutEngine.layoutNetwork(network: network, rungIndex: 0);

      // Check no node overlaps another node
      for (int i = 0; i < layout.nodes.length; i++) {
        for (int j = i + 1; j < layout.nodes.length; j++) {
          final nA = layout.nodes[i];
          final nB = layout.nodes[j];
          final overlaps = nA.bounds.overlaps(nB.bounds);
          expect(overlaps, isFalse, reason: 'Node ${nA.node.id} overlaps with ${nB.node.id}');
        }
      }

      // Check no vertical wire cuts through any NodeRect
      for (final wire in layout.wires.where((w) => w.isVertical)) {
        for (final node in layout.nodes) {
          // If vertical wire x is strictly inside node width (excluding boundaries)
          final xInside = wire.from.x > node.bounds.left && wire.from.x < node.bounds.right;
          final yInside = (wire.from.y < node.bounds.bottom && wire.to.y > node.bounds.top) ||
                          (wire.to.y < node.bounds.bottom && wire.from.y > node.bounds.top);
          expect(xInside && yInside, isFalse, reason: 'Vertical wire cuts through node ${node.node.id}');
        }
      }
    });
  });
}
