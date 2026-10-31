import 'package:flutter/material.dart';
import '../../../models/ladder_project.dart';
import '../../../models/ladder_node.dart';
import '../../../models/node_config.dart';
import '../../../models/tag_value.dart';
import '../../../models/enums.dart';
import '../../../runtime/ladder_runtime.dart';
import '../layout/ladder_layout_engine.dart';
import 'ladder_node_visual.dart';

/// Industrial Ladder Network Canvas that renders mathematically exact
/// orthogonal electrical diagrams calculated by LadderLayoutEngine
class LadderNetworkCanvas extends StatelessWidget {
  final LadderProject project;
  final int rungIndex;
  final LadderRuntime runtime;
  final int? selectedRungIndex;
  final int? selectedNodeIndex;
  final bool isSimulationRunning;
  final void Function(String tagId)? onToggleTag;
  final void Function(int rungIndex, int nodeIndex) onNodeSelectionChanged;
  final void Function(int rungIndex, int nodeIndex) onNodeEditRequest;
  final void Function(int rungIndex, int nodeIndex) onNodeOptionsRequest;
  final void Function(int rungIndex, [int? insertIndex]) onComponentAddRequest;
  final double? minCanvasWidth;
  final void Function(bool isDragging) onDraggingStateChanged;
  final VoidCallback onProjectChanged;

  const LadderNetworkCanvas({
    super.key,
    required this.project,
    required this.rungIndex,
    required this.runtime,
    required this.selectedRungIndex,
    required this.selectedNodeIndex,
    required this.isSimulationRunning,
    required this.onToggleTag,
    required this.onNodeSelectionChanged,
    required this.onNodeEditRequest,
    required this.onNodeOptionsRequest,
    required this.onComponentAddRequest,
    this.minCanvasWidth,
    required this.onDraggingStateChanged,
    required this.onProjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rung = project.networks[rungIndex];
    final layout = LadderLayoutEngine.layoutNetwork(
      network: rung,
      rungIndex: rungIndex,
      minWidth: minCanvasWidth,
    );

    return SizedBox(
      width: layout.totalWidth + 20,
      height: layout.totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Layer 1: Background Orthogonal Electrical Conductor Wires & Junctions (GPU Repaint Boundary Isolated)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OrthogonalWirePainter(
                  layout: layout,
                  isSimulationRunning: isSimulationRunning,
                ),
              ),
            ),
          ),

          // 2. Layer 2: Interactive Wire Segment Targets (Click to Insert / Drop to Move or Insert)
          ...layout.wires.where((w) => w.isHorizontal && w.length >= 8.0).map((wire) {
            return Positioned(
              left: wire.from.x < wire.to.x ? wire.from.x : wire.to.x,
              top: wire.from.y - 16.0,
              width: wire.length,
              height: 32.0,
              child: DragTarget<Object>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  final data = details.data;
                  if (data is NodeType) {
                    final isTimer = data == NodeType.timerTON || data == NodeType.timerTOF;
                    final isCounter = data == NodeType.counterCTU || data == NodeType.counterCTD;
                    final isCompare = data == NodeType.compareEqual || data == NodeType.compareGreater || data == NodeType.compareLess;
                    final isMath = data == NodeType.mathADD || data == NodeType.mathSUB || data == NodeType.mathMUL || data == NodeType.mathDIV;
                    final ts = DateTime.now().microsecondsSinceEpoch;
                    final LadderNode newNode;
                    if (data == NodeType.parallel) {
                      newNode = LadderNode(
                        id: 'node_${ts}_par',
                        type: NodeType.parallel,
                        config: NodeConfig(),
                        branches: [
                          [LadderNode(id: 'node_${ts}_b0', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0'))],
                          [LadderNode(id: 'node_${ts}_b1', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.1'))],
                        ],
                      );
                    } else {
                      newNode = LadderNode(
                        id: 'node_$ts',
                        type: data,
                        config: data == NodeType.pid
                            ? NodeConfig.pid()
                            : NodeConfig(
                                tagId: (isCompare || isMath) ? 'AI0.0' : null,
                                presetValue: isTimer
                                    ? TagValue.integer(3000)
                                    : (isCounter
                                        ? TagValue.integer(5)
                                        : (isCompare ? TagValue.integer(50) : (isMath ? TagValue.integer(1) : null))),
                                outputTagId: isMath ? 'M0.6' : null,
                              ),
                      );
                    }
                    if (wire.parallelNodeIndex != null && wire.branchIndex != null) {
                      final pNode = rung.nodes[wire.parallelNodeIndex!];
                      pNode.branches?[wire.branchIndex!].insert(wire.insertIndex, newNode);
                    } else {
                      rung.insertNode(newNode, wire.insertIndex);
                    }
                    rung.rebuildConnections();
                    onProjectChanged();
                    onNodeEditRequest(rungIndex, wire.insertIndex);
                  } else if (data is Map<String, dynamic> && data['type'] == 'move') {
                    final srcRung = data['srcRung'] as int;
                    final srcNode = data['srcNode'] as int;
                    final nodeToMove = project.networks[srcRung].nodes[srcNode];

                    project.networks[srcRung].removeNodeAt(srcNode);
                    final adjustedInsertIndex = (srcRung == rungIndex && srcNode < wire.insertIndex)
                        ? wire.insertIndex - 1
                        : wire.insertIndex;
                    if (wire.parallelNodeIndex != null && wire.branchIndex != null) {
                      final pNode = rung.nodes[wire.parallelNodeIndex!];
                      pNode.branches?[wire.branchIndex!].insert(adjustedInsertIndex, nodeToMove);
                    } else {
                      project.networks[rungIndex].insertNode(nodeToMove, adjustedInsertIndex);
                    }
                    project.networks[srcRung].rebuildConnections();
                    project.networks[rungIndex].rebuildConnections();
                    onProjectChanged();
                  } else if (data is Map<String, dynamic> && data['type'] == 'tag') {
                    final tagId = data['tagId'] as String;
                    final newNode = LadderNode(
                      id: 'node_${DateTime.now().microsecondsSinceEpoch}',
                      type: NodeType.contactNO,
                      config: NodeConfig(tagId: tagId),
                    );
                    if (wire.parallelNodeIndex != null && wire.branchIndex != null) {
                      final pNode = rung.nodes[wire.parallelNodeIndex!];
                      pNode.branches?[wire.branchIndex!].insert(wire.insertIndex, newNode);
                    } else {
                      rung.insertNode(newNode, wire.insertIndex);
                    }
                    rung.rebuildConnections();
                    onProjectChanged();
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  return InkWell(
                    splashColor: const Color(0xFF4FD1C5).withValues(alpha: 0.2),
                    onTap: () => onComponentAddRequest(rungIndex, wire.insertIndex),
                    child: Center(
                      child: isHovered
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4FD1C5),
                                shape: BoxShape.circle,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            );
          }),

          // 3. Layer 3: Positioned Node Visual Widgets
          ...layout.nodes.map((nodeGeo) {
            final isSelected = selectedRungIndex == rungIndex && selectedNodeIndex == nodeGeo.nodeIndex;
            final node = nodeGeo.node;

            return Positioned(
              left: nodeGeo.bounds.left,
              top: nodeGeo.bounds.top,
              width: nodeGeo.bounds.width,
              height: nodeGeo.bounds.height,
              child: DragTarget<Object>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  final data = details.data;
                  if (data is NodeType) {
                    final isTimer = data == NodeType.timerTON || data == NodeType.timerTOF;
                    final isCounter = data == NodeType.counterCTU || data == NodeType.counterCTD;
                    final newNode = LadderNode(
                      id: 'node_${DateTime.now().microsecondsSinceEpoch}_new',
                      type: data,
                      config: NodeConfig(
                        presetValue: isTimer
                            ? TagValue.integer(3000)
                            : (isCounter ? TagValue.integer(5) : null),
                      ),
                    );
                    final parallelNode = LadderNode(
                      id: 'node_${DateTime.now().microsecondsSinceEpoch}_par',
                      type: NodeType.parallel,
                      config: NodeConfig(),
                      branches: [
                        [node.clone()],
                        [newNode],
                      ],
                    );
                    rung.nodes[nodeGeo.nodeIndex] = parallelNode;
                    rung.rebuildConnections();
                    onProjectChanged();
                  } else if (data is Map<String, dynamic> && data['type'] == 'tag') {
                    final tagId = data['tagId'] as String;
                    node.config.tagId = tagId;
                    rung.rebuildConnections();
                    onProjectChanged();
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  final visualWidget = LadderNodeVisual(
                    node: node,
                    isSelected: isSelected,
                    runtime: runtime,
                  );

                  final interactiveContent = InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      onNodeSelectionChanged(rungIndex, nodeGeo.nodeIndex);
                      final tag = node.config.tagId;
                      if (isSimulationRunning && tag != null && tag.isNotEmpty && onToggleTag != null) {
                        onToggleTag!(tag);
                      } else {
                        onNodeEditRequest(rungIndex, nodeGeo.nodeIndex);
                      }
                    },
                    onLongPress: () => onNodeOptionsRequest(rungIndex, nodeGeo.nodeIndex),
                    child: visualWidget,
                  );

                  return Container(
                    decoration: BoxDecoration(
                      border: isHovered ? Border.all(color: const Color(0xFF4FD1C5), width: 1.5) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isSimulationRunning
                        ? interactiveContent
                        : Draggable<Map<String, dynamic>>(
                            data: {
                              'type': 'move',
                              'srcRung': rungIndex,
                              'srcNode': nodeGeo.nodeIndex,
                            },
                            onDragStarted: () {
                              onNodeSelectionChanged(rungIndex, nodeGeo.nodeIndex);
                              onDraggingStateChanged(true);
                            },
                            onDragEnd: (details) => onDraggingStateChanged(false),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.85,
                                child: visualWidget,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: visualWidget,
                            ),
                            child: interactiveContent,
                          ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Precise CustomPainter drawing all orthogonal wire conductors, junctions and illuminated power rails
class _OrthogonalWirePainter extends CustomPainter {
  final NetworkLayout layout;
  final bool isSimulationRunning;

  _OrthogonalWirePainter({
    required this.layout,
    this.isSimulationRunning = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all orthogonal wire segments
    for (final wire in layout.wires) {
      if (wire.isEnergized) {
        // Multi-layer natural LED/phosphor diffusion glow (Siemens / Rockwell standard)
        // Outer ambient glow
        final ambientGlow = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
          ..strokeWidth = 10.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

        canvas.drawLine(
          Offset(wire.from.x, wire.from.y),
          Offset(wire.to.x, wire.to.y),
          ambientGlow,
        );

        // Inner halo glow
        final innerGlow = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
          ..strokeWidth = 5.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

        canvas.drawLine(
          Offset(wire.from.x, wire.from.y),
          Offset(wire.to.x, wire.to.y),
          innerGlow,
        );

        // High intensity green core conductor
        final corePaint = Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(wire.from.x, wire.from.y),
          Offset(wire.to.x, wire.to.y),
          corePaint,
        );
      } else {
        final offPaint = Paint()
          ..color = const Color(0xFF64748B) // Crisp industrial steel conductor (high contrast against dark canvas)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square;

        canvas.drawLine(
          Offset(wire.from.x, wire.from.y),
          Offset(wire.to.x, wire.to.y),
          offPaint,
        );
      }
    }

    // 2. Draw all Tee-junction dots
    for (final junction in layout.junctions) {
      if (!junction.isTeeJunction) continue;

      final center = Offset(junction.point.x, junction.point.y);

      if (junction.isEnergized) {
        final dotGlow = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(center, LadderLayoutMetrics.junctionDotRadius + 2.5, dotGlow);

        final dotCore = Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, LadderLayoutMetrics.junctionDotRadius, dotCore);
      } else {
        final dotPaint = Paint()
          ..color = const Color(0xFF64748B)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, LadderLayoutMetrics.junctionDotRadius, dotPaint);
      }
    }

    // 3. Power Rails (Discrete vertical bar segments per rung):
    // Left Power Rail (L1 / 24VDC) at x=0: Always energized in RUN mode (live bus)
    final bool l1Energized = isSimulationRunning;
    if (l1Energized) {
      final l1Ambient = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.15)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawLine(const Offset(0, 4.0), Offset(0, size.height - 4.0), l1Ambient);

      final l1Halo = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..strokeWidth = 5.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawLine(const Offset(0, 4.0), Offset(0, size.height - 4.0), l1Halo);

      final l1Core = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(const Offset(0, 4.0), Offset(0, size.height - 4.0), l1Core);
    } else {
      final l1RailPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(const Offset(0, 4.0), Offset(0, size.height - 4.0), l1RailPaint);
    }

    // Right Power Rail (Neutral / 0VDC / L2) at layout.totalWidth:
    // Energized if any wire reaching the right power rail conducts
    final double l2X = layout.totalWidth;
    final bool l2Energized = isSimulationRunning &&
        layout.wires.any((w) => (w.to.x >= l2X - 6.0 || w.from.x >= l2X - 6.0) && w.isEnergized);

    if (l2Energized) {
      final l2Ambient = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.15)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawLine(Offset(l2X, 4.0), Offset(l2X, size.height - 4.0), l2Ambient);

      final l2Halo = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..strokeWidth = 5.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawLine(Offset(l2X, 4.0), Offset(l2X, size.height - 4.0), l2Halo);

      final l2Core = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(l2X, 4.0), Offset(l2X, size.height - 4.0), l2Core);
    } else {
      final l2RailPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(l2X, 4.0), Offset(l2X, size.height - 4.0), l2RailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrthogonalWirePainter oldDelegate) =>
      oldDelegate.isSimulationRunning != isSimulationRunning || oldDelegate.layout != layout;
}
