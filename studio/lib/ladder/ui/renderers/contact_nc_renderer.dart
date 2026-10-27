import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../models/block_port_descriptor.dart';
import '../renderers/base_block_renderer.dart';
import '../renderers/render_context.dart';
import '../../ui/ladder_theme.dart';

class ContactNcRenderer implements BaseBlockRenderer {
  @override
  List<BlockPortDescriptor> get ports => const [
    BlockPortDescriptor(
      id: 'in',
      direction: PortDirection.input,
      dataType: PortDataType.boolean,
      verticalSlot: 0,
    ),
    BlockPortDescriptor(
      id: 'out',
      direction: PortDirection.output,
      dataType: PortDataType.boolean,
      verticalSlot: 0,
    ),
  ];

  @override
  Size get preferredSize => const Size(64, 54);

  @override
  Widget render(
    BuildContext context,
    LadderNode node,
    RenderContext renderContext,
  ) {
    final bool isEnergized = node.isEnergized;
    final paint = isEnergized
        ? AppTheme.energizedPaint
        : AppTheme.technicalPaint;
    final opacity = isEnergized ? AppTheme.activeOpacity : AppTheme.idleOpacity;

    return SizedBox(
      width: preferredSize.width,
      height: preferredSize.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            height: 2,
            child: Opacity(
              opacity: opacity,
              child: Container(color: paint.color),
            ),
          ),
          Positioned(
            left: 20,
            top: 12,
            bottom: 12,
            child: Opacity(
              opacity: opacity,
              child: Container(width: 4, color: paint.color),
            ),
          ),
          Positioned(
            right: 20,
            top: 12,
            bottom: 12,
            child: Opacity(
              opacity: opacity,
              child: Container(width: 4, color: paint.color),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 14,
            bottom: 14,
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _DiagonalLinePainter(drawingPaint: paint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  final Paint drawingPaint;
  _DiagonalLinePainter({required this.drawingPaint});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      drawingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinePainter oldDelegate) =>
      oldDelegate.drawingPaint != drawingPaint;
}
