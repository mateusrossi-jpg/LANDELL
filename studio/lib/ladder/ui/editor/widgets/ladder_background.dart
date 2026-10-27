import 'package:flutter/material.dart';
import 'dart:ui' as import_ui;

class LadderBackground extends StatelessWidget {
  final Widget child;
  final bool isSimulationRunning;

  const LadderBackground({
    super.key,
    required this.child,
    this.isSimulationRunning = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1318), // Deep Professional Industrial PLC Canvas
      child: CustomPaint(
        painter: _GridPainter(isSimulationRunning: isSimulationRunning),
        child: child,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isSimulationRunning;

  _GridPainter({required this.isSimulationRunning});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle industrial technical dot grid (IEC / CAD style)
    final gridPaint = Paint()
      ..color = const Color(0xFF232B36).withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (double x = 24.0; x < size.width; x += 24) {
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawPoints(import_ui.PointMode.points, [Offset(x, y)], gridPaint);
      }
    }

    // Note: The Power Rails (L1 Hot at x=0 and L2 Neutral at x=totalWidth)
    // are rendered dynamically inside LadderNetworkCanvas for each rung,
    // ensuring perfect alignment with the rung logic and conductors without ghosting.
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.isSimulationRunning != isSimulationRunning;
}
