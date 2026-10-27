import 'package:flutter/material.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';

class GaugeWidget extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;

  const GaugeWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    double currentVal = 0.0;
    String displayValue = 'SEM DADOS';
    bool hasValue = false;
    bool hasRealTelemetry = false;
    String unit = config.unit ?? 'PSI';
    final double minVal = config.minValue ?? 0.0;
    final double maxVal = config.maxValue ?? 100.0;

    if (config.tagId != null && project.tags.containsKey(config.tagId)) {
      final tag = project.tags[config.tagId!]!;
      unit = config.unit ?? tag.unit ?? '';
      
      var tagVal = runtime?.tagStore.getValue(tag.id);
      if (tagVal == null && tag.address != null) {
        tagVal = runtime?.tagStore.getValue(tag.address!);
      }
      final realVal = tagVal?.realValue;
      final intVal = tagVal?.intValue;

      if (realVal != null) {
        currentVal = realVal;
        displayValue = realVal.toStringAsFixed(config.decimalPlaces);
        hasValue = true;
        hasRealTelemetry = true;
      } else if (intVal != null) {
        currentVal = intVal.toDouble();
        displayValue = intVal.toString();
        hasValue = true;
        hasRealTelemetry = true;
      } else if (tag.initialValue?.realValue != null) {
        currentVal = tag.initialValue!.realValue!;
        displayValue = currentVal.toStringAsFixed(config.decimalPlaces);
        hasValue = true;
      } else if (tag.initialValue?.intValue != null) {
        currentVal = tag.initialValue!.intValue!.toDouble();
        displayValue = currentVal.toInt().toString();
        hasValue = true;
      }
    }

    final double range = (maxVal - minVal) <= 0 ? 100.0 : (maxVal - minVal);
    final double normalized = hasRealTelemetry ? ((currentVal - minVal) / range).clamp(0.0, 1.0) : 0.0;

    Color progressColor = const Color(0xFF2DD4BF);
    if (hasRealTelemetry && config.criticalMax != null && currentVal >= config.criticalMax!) {
      progressColor = const Color(0xFFF43F5E);
    } else if (hasRealTelemetry && config.warningMax != null && currentVal >= config.warningMax!) {
      progressColor = const Color(0xFFF59E0B);
    }

    return Center(
      child: SizedBox(
        width: 105,
        height: 105,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(105, 105),
              painter: _GaugePainter(
                progress: normalized,
                progressColor: progressColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    color: const Color(0xFFF1F5F9),
                    fontSize: hasValue ? 20 : 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color progressColor;

  const _GaugePainter({
    required this.progress,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final bgPaint = Paint()
      ..color = const Color(0xFF1E2638)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = 2.4; // rad (~137.5 deg)
    const sweepAngle = 4.6; // rad (~263.5 deg)

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Active arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
  }
}
