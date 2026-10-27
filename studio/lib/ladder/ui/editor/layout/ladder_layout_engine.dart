import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../../models/ladder_network.dart';
import '../../../models/ladder_node.dart';
import '../../../models/enums.dart';

/// Central metrics for industrial ladder layout adhering to strict orthogonal grid
class LadderLayoutMetrics {
  static const double nodeHeight = 64.0;
  static const double contactWidth = 80.0;
  static const double blockWidth = 116.0;
  static const double wireThickness = 2.0;
  static const double minWireGap = 16.0;
  static const double branchLeadGap = 16.0;
  static const double branchVerticalGap = 64.0;
  static const double rungVerticalMargin = 20.0;
  static const double railLeadWidth = 24.0;
  static const double endLeadWidth = 32.0;
  static const double junctionDotRadius = 3.0;
}

/// A 2D point representing an electrical terminal or junction coordinate
@immutable
class GridPoint {
  final double x;
  final double y;

  const GridPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 0.001 &&
          (y - other.y).abs() < 0.001;

  @override
  int get hashCode => Object.hash((x * 1000).round(), (y * 1000).round());

  @override
  String toString() => '($x, $y)';
}

/// Represents an orthogonal electrical conductor wire between two exact points
@immutable
class WireSegmentGeometry {
  final GridPoint from;
  final GridPoint to;
  final bool isEnergized;
  final int rungIndex;
  final int insertIndex;
  final int? parallelNodeIndex;
  final int? branchIndex;

  const WireSegmentGeometry({
    required this.from,
    required this.to,
    required this.isEnergized,
    required this.rungIndex,
    required this.insertIndex,
    this.parallelNodeIndex,
    this.branchIndex,
  });

  bool get isHorizontal => (from.y - to.y).abs() < 0.001;
  bool get isVertical => (from.x - to.x).abs() < 0.001;
  double get length => isHorizontal ? (to.x - from.x).abs() : (to.y - from.y).abs();
}

/// Represents a T-junction or intersection where electrical conductors meet
@immutable
class JunctionGeometry {
  final GridPoint point;
  final bool isSplit; // true for entry branch split, false for exit branch join
  final List<GridPoint> connectedPoints;
  final bool isEnergized;
  final bool isTeeJunction; // true if 3-way connection requiring visible dot

  const JunctionGeometry({
    required this.point,
    required this.isSplit,
    required this.connectedPoints,
    required this.isEnergized,
    this.isTeeJunction = true,
  });
}

/// Represents an instruction block / contact placed in the layout
@immutable
class NodeGeometry {
  final LadderNode node;
  final Rect bounds;
  final GridPoint inputTerminal;
  final GridPoint outputTerminal;
  final int rungIndex;
  final int nodeIndex;
  final int? branchIndex; // null if on main rung line
  final String? parentParallelId;

  const NodeGeometry({
    required this.node,
    required this.bounds,
    required this.inputTerminal,
    required this.outputTerminal,
    required this.rungIndex,
    required this.nodeIndex,
    this.branchIndex,
    this.parentParallelId,
  });
}

/// Complete geometric solution for a Ladder Network
class NetworkLayout {
  final int rungIndex;
  final double totalWidth;
  final double totalHeight;
  final double mainAxisY;
  final List<NodeGeometry> nodes;
  final List<WireSegmentGeometry> wires;
  final List<JunctionGeometry> junctions;

  const NetworkLayout({
    required this.rungIndex,
    required this.totalWidth,
    required this.totalHeight,
    required this.mainAxisY,
    required this.nodes,
    required this.wires,
    required this.junctions,
  });
}

/// Deterministic Layout Engine that transforms topologic LadderNetworks
/// into absolute, mathematical orthogonal electrical geometries
class LadderLayoutEngine {
  /// Solves the full geometry of a LadderNetwork with arbitrary parallel branches
  static NetworkLayout layoutNetwork({
    required LadderNetwork network,
    required int rungIndex,
    double startX = LadderLayoutMetrics.railLeadWidth,
    double mainY = LadderLayoutMetrics.nodeHeight / 2, // 32.0
    double? minWidth,
  }) {
    final List<NodeGeometry> placedNodes = [];
    final List<WireSegmentGeometry> placedWires = [];
    final List<JunctionGeometry> placedJunctions = [];

    double currentX = startX;
    GridPoint lastPoint = GridPoint(0.0, mainY);

    double maxNetworkY = LadderLayoutMetrics.nodeHeight;

    // Check if the rung ends with an output coil
    final bool hasCoilAtEnd = network.nodes.isNotEmpty &&
        (network.nodes.last.type == NodeType.coil ||
         network.nodes.last.type == NodeType.coilSet ||
         network.nodes.last.type == NodeType.coilReset);

    // Calculate layout width
    final int nonCoilCount = hasCoilAtEnd ? network.nodes.length - 1 : network.nodes.length;

    for (int i = 0; i < nonCoilCount; i++) {
      final node = network.nodes[i];

      final bool prevEnergized = (lastPoint.x == 0.0)
          ? true
          : (i > 0 ? network.nodes[i - 1].isConducting : false);

      if (node.type == NodeType.parallel && node.branches != null && node.branches!.isNotEmpty) {
        // Layout parallel structure
        final parallelLayout = _layoutParallelNode(
          parallelNode: node,
          rungIndex: rungIndex,
          nodeIndex: i,
          entryPoint: GridPoint(currentX, mainY),
          inPowerFlow: prevEnergized,
        );

        // Connect wire from lastPoint to parallel entry
        if (lastPoint.x < parallelLayout.entryJunctionPoint.x) {
          placedWires.add(WireSegmentGeometry(
            from: lastPoint,
            to: parallelLayout.entryJunctionPoint,
            isEnergized: prevEnergized,
            rungIndex: rungIndex,
            insertIndex: i,
          ));
        }

        placedNodes.addAll(parallelLayout.nodes);
        placedWires.addAll(parallelLayout.wires);
        placedJunctions.addAll(parallelLayout.junctions);

        lastPoint = parallelLayout.exitJunctionPoint;
        currentX = lastPoint.x + LadderLayoutMetrics.minWireGap;

        if (parallelLayout.totalHeight > maxNetworkY) {
          maxNetworkY = parallelLayout.totalHeight;
        }
      } else {
        // Layout standard linear node (Contact, Timer, Counter, Comparator, Math, PID)
        final double width = _getNodeWidth(node.type);
        final rect = Rect.fromLTWH(currentX, mainY - 32.0, width, 64.0);
        final inputTerm = GridPoint(currentX, mainY);
        final outputTerm = GridPoint(currentX + width, mainY);

        // Connect wire from last point to input terminal
        if (lastPoint.x < inputTerm.x) {
          placedWires.add(WireSegmentGeometry(
            from: lastPoint,
            to: inputTerm,
            isEnergized: prevEnergized,
            rungIndex: rungIndex,
            insertIndex: i,
          ));
        }

        placedNodes.add(NodeGeometry(
          node: node,
          bounds: rect,
          inputTerminal: inputTerm,
          outputTerminal: outputTerm,
          rungIndex: rungIndex,
          nodeIndex: i,
        ));

        lastPoint = outputTerm;
        currentX = outputTerm.x + LadderLayoutMetrics.minWireGap;
      }
    }

    // Determine final total width of the rung
    final double minRequiredWidth = hasCoilAtEnd
        ? currentX + LadderLayoutMetrics.contactWidth + LadderLayoutMetrics.railLeadWidth + 20.0
        : currentX + LadderLayoutMetrics.endLeadWidth;

    final double effectiveTotalWidth = (minWidth != null && minWidth > minRequiredWidth)
        ? minWidth
        : minRequiredWidth;

    if (hasCoilAtEnd) {
      final coilNode = network.nodes.last;
      final int coilIndex = network.nodes.length - 1;
      final double coilWidth = LadderLayoutMetrics.contactWidth;
      // Coil is anchored to the right end before the right power rail lead
      final double coilInputX = effectiveTotalWidth - coilWidth - LadderLayoutMetrics.railLeadWidth;
      final double coilOutputX = coilInputX + coilWidth;

      final bool prevEnergized = (lastPoint.x == 0.0)
          ? true
          : (coilIndex > 0 ? network.nodes[coilIndex - 1].isConducting : false);

      // Connecting conductor wire from last condition node to coil input (spans the entire middle gap)
      if (lastPoint.x < coilInputX) {
        placedWires.add(WireSegmentGeometry(
          from: lastPoint,
          to: GridPoint(coilInputX, mainY),
          isEnergized: prevEnergized,
          rungIndex: rungIndex,
          insertIndex: coilIndex,
        ));
      }

      placedNodes.add(NodeGeometry(
        node: coilNode,
        bounds: Rect.fromLTWH(coilInputX, mainY - 32.0, coilWidth, 64.0),
        inputTerminal: GridPoint(coilInputX, mainY),
        outputTerminal: GridPoint(coilOutputX, mainY),
        rungIndex: rungIndex,
        nodeIndex: coilIndex,
      ));

      // Final wire segment from coil output to Neutral Rail (L2)
      placedWires.add(WireSegmentGeometry(
        from: GridPoint(coilOutputX, mainY),
        to: GridPoint(effectiveTotalWidth, mainY),
        isEnergized: coilNode.isEnergized || coilNode.isConducting,
        rungIndex: rungIndex,
        insertIndex: network.nodes.length,
      ));
    } else {
      // No coil at the end: conductor wire extends to Neutral Rail (L2)
      placedWires.add(WireSegmentGeometry(
        from: lastPoint,
        to: GridPoint(effectiveTotalWidth, mainY),
        isEnergized: network.nodes.isEmpty ? true : network.nodes.last.isConducting,
        rungIndex: rungIndex,
        insertIndex: network.nodes.length,
      ));
    }

    return NetworkLayout(
      rungIndex: rungIndex,
      totalWidth: effectiveTotalWidth,
      totalHeight: maxNetworkY,
      mainAxisY: mainY,
      nodes: placedNodes,
      wires: placedWires,
      junctions: placedJunctions,
    );
  }

  static _ParallelResult _layoutParallelNode({
    required LadderNode parallelNode,
    required int rungIndex,
    required int nodeIndex,
    required GridPoint entryPoint,
    bool inPowerFlow = true,
  }) {
    final branches = parallelNode.branches ?? [];
    final int branchCount = branches.length;

    // 1. Calculate width of each branch
    final List<double> branchWidths = [];
    for (var branch in branches) {
      double bWidth = 0.0;
      for (var bNode in branch) {
        bWidth += _getNodeWidth(bNode.type);
        bWidth += LadderLayoutMetrics.minWireGap;
      }
      if (branch.isNotEmpty) {
        bWidth -= LadderLayoutMetrics.minWireGap;
      }
      branchWidths.add(bWidth);
    }

    // Parallel block width is the maximum branch width + branch lead gaps
    double maxBranchWidth = branchWidths.fold(0.0, (max, w) => w > max ? w : max);
    if (maxBranchWidth < 60.0) maxBranchWidth = 60.0;

    final double leadGap = LadderLayoutMetrics.branchLeadGap; // 16.0
    final double totalParallelWidth = leadGap + maxBranchWidth + leadGap;

    final double entryX = entryPoint.x;
    final double mainY = entryPoint.y;
    final double exitX = entryX + totalParallelWidth;

    final List<NodeGeometry> placedNodes = [];
    final List<WireSegmentGeometry> placedWires = [];
    final List<JunctionGeometry> junctions = [];

    final List<GridPoint> entryBranchPoints = [];
    final List<GridPoint> exitBranchPoints = [];

    // Check if any branch in the parallel block currently conducts power to the exit
    final bool anyBranchConducts = inPowerFlow && branches.any((branch) =>
        branch.isEmpty ? true : branch.last.isConducting);

    // 2. Position nodes and horizontal leads for each branch
    for (int bIdx = 0; bIdx < branchCount; bIdx++) {
      final branch = branches[bIdx];
      final double branchY = mainY + (bIdx * LadderLayoutMetrics.branchVerticalGap);

      final branchInPoint = GridPoint(entryX + leadGap, branchY);
      entryBranchPoints.add(GridPoint(entryX, branchY));
      exitBranchPoints.add(GridPoint(exitX, branchY));

      // Horizontal lead from entry vertical rail to branch start
      placedWires.add(WireSegmentGeometry(
        from: GridPoint(entryX, branchY),
        to: branchInPoint,
        isEnergized: inPowerFlow,
        rungIndex: rungIndex,
        insertIndex: 0,
        parallelNodeIndex: nodeIndex,
        branchIndex: bIdx,
      ));

      double curBx = branchInPoint.x;
      GridPoint lastBranchPoint = branchInPoint;

      for (int nIdx = 0; nIdx < branch.length; nIdx++) {
        final bNode = branch[nIdx];
        final double nWidth = _getNodeWidth(bNode.type);
        final rect = Rect.fromLTWH(curBx, branchY - 32.0, nWidth, 64.0);
        final bIn = GridPoint(curBx, branchY);
        final bOut = GridPoint(curBx + nWidth, branchY);

        if (lastBranchPoint.x < bIn.x) {
          placedWires.add(WireSegmentGeometry(
            from: lastBranchPoint,
            to: bIn,
            isEnergized: lastBranchPoint.x == branchInPoint.x ? inPowerFlow : branch[nIdx - 1].isConducting,
            rungIndex: rungIndex,
            insertIndex: nIdx,
            parallelNodeIndex: nodeIndex,
            branchIndex: bIdx,
          ));
        }

        placedNodes.add(NodeGeometry(
          node: bNode,
          bounds: rect,
          inputTerminal: bIn,
          outputTerminal: bOut,
          rungIndex: rungIndex,
          nodeIndex: nodeIndex,
          branchIndex: bIdx,
          parentParallelId: parallelNode.id,
        ));

        lastBranchPoint = bOut;
        curBx = bOut.x + LadderLayoutMetrics.minWireGap;
      }

      // Horizontal lead from branch end to exit vertical rail
      placedWires.add(WireSegmentGeometry(
        from: lastBranchPoint,
        to: GridPoint(exitX, branchY),
        isEnergized: branch.isEmpty ? inPowerFlow : branch.last.isConducting,
        rungIndex: rungIndex,
        insertIndex: branch.length,
        parallelNodeIndex: nodeIndex,
        branchIndex: bIdx,
      ));
    }

    // 3. Vertical bus wires for entry and exit junctions
    final double maxBranchY = mainY + ((branchCount - 1) * LadderLayoutMetrics.branchVerticalGap);

    // Left vertical rail from mainY to last branchY
    placedWires.add(WireSegmentGeometry(
      from: GridPoint(entryX, mainY),
      to: GridPoint(entryX, maxBranchY),
      isEnergized: inPowerFlow,
      rungIndex: rungIndex,
      insertIndex: 0,
      parallelNodeIndex: nodeIndex,
    ));

    // Right vertical rail from mainY to last branchY
    placedWires.add(WireSegmentGeometry(
      from: GridPoint(exitX, mainY),
      to: GridPoint(exitX, maxBranchY),
      isEnergized: anyBranchConducts,
      rungIndex: rungIndex,
      insertIndex: 0,
      parallelNodeIndex: nodeIndex,
    ));

    // Primary entry and exit junctions
    final entryJunction = JunctionGeometry(
      point: GridPoint(entryX, mainY),
      isSplit: true,
      connectedPoints: entryBranchPoints,
      isEnergized: inPowerFlow,
    );

    final exitJunction = JunctionGeometry(
      point: GridPoint(exitX, mainY),
      isSplit: false,
      connectedPoints: exitBranchPoints,
      isEnergized: anyBranchConducts,
    );

    junctions.add(entryJunction);
    junctions.add(exitJunction);

    // Additional intermediate branch T-junctions if 3+ branches
    for (int bIdx = 1; bIdx < branchCount - 1; bIdx++) {
      final branchY = mainY + (bIdx * LadderLayoutMetrics.branchVerticalGap);
      junctions.add(JunctionGeometry(
        point: GridPoint(entryX, branchY),
        isSplit: true,
        connectedPoints: [GridPoint(entryX, branchY)],
        isEnergized: inPowerFlow,
      ));
      junctions.add(JunctionGeometry(
        point: GridPoint(exitX, branchY),
        isSplit: false,
        connectedPoints: [GridPoint(exitX, branchY)],
        isEnergized: anyBranchConducts,
      ));
    }

    final double totalHeight = maxBranchY + 32.0;

    return _ParallelResult(
      nodes: placedNodes,
      wires: placedWires,
      junctions: junctions,
      entryJunctionPoint: GridPoint(entryX, mainY),
      exitJunctionPoint: GridPoint(exitX, mainY),
      totalWidth: totalParallelWidth,
      totalHeight: totalHeight,
    );
  }

  static double _getNodeWidth(NodeType type) {
    switch (type) {
      case NodeType.contactNO:
      case NodeType.contactNC:
      case NodeType.coil:
      case NodeType.coilSet:
      case NodeType.coilReset:
        return LadderLayoutMetrics.contactWidth; // 80.0
      case NodeType.timerTON:
      case NodeType.timerTOF:
      case NodeType.counterCTU:
      case NodeType.counterCTD:
      case NodeType.compareEqual:
      case NodeType.compareGreater:
      case NodeType.compareLess:
      case NodeType.mathADD:
      case NodeType.mathSUB:
      case NodeType.mathMUL:
      case NodeType.mathDIV:
        return LadderLayoutMetrics.blockWidth; // 116.0
      case NodeType.pid:
        return 130.0;
      case NodeType.parallel:
        return 120.0;
    }
  }
}

class _ParallelResult {
  final List<NodeGeometry> nodes;
  final List<WireSegmentGeometry> wires;
  final List<JunctionGeometry> junctions;
  final GridPoint entryJunctionPoint;
  final GridPoint exitJunctionPoint;
  final double totalWidth;
  final double totalHeight;

  _ParallelResult({
    required this.nodes,
    required this.wires,
    required this.junctions,
    required this.entryJunctionPoint,
    required this.exitJunctionPoint,
    required this.totalWidth,
    required this.totalHeight,
  });
}
