import 'package:flutter/material.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';

class NumericSparklineWidget extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;

  const NumericSparklineWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    String displayValue = '---';
    String unit = config.unit ?? '';
    bool hasData = false;
    bool hasRealTelemetry = false;

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
        displayValue = realVal.toStringAsFixed(config.decimalPlaces);
        hasData = true;
        hasRealTelemetry = true;
      } else if (intVal != null) {
        displayValue = intVal.toString();
        hasData = true;
        hasRealTelemetry = true;
      } else if (tag.initialValue?.realValue != null) {
        displayValue = tag.initialValue!.realValue!.toStringAsFixed(config.decimalPlaces);
        hasData = true;
      } else if (tag.initialValue?.intValue != null) {
        displayValue = tag.initialValue!.intValue!.toString();
        hasData = true;
      }
      // Sem valor real no store nem initialValue: mantém '---' (SEM DADOS).
    }
    // Sem tag vinculada: sem dados reais; '---' já é o valor exibido.

    final bool isSparkline = config.templateType == WidgetTemplateType.sparkline;

    // ISA-101 Mini Analog Bar Gauge: Calcula fração normalizada (0.0 a 1.0)
    double? numericVal;
    if (displayValue != '---') {
      numericVal = double.tryParse(displayValue);
    }
    final minScale = config.minValue ?? 0.0;
    final maxScale = (config.maxValue != null && config.maxValue! > minScale) ? config.maxValue! : 100.0;
    final fraction = numericVal != null
        ? ((numericVal - minScale) / (maxScale - minScale)).clamp(0.0, 1.0)
        : null;

    final isHumidity = unit == '%' || (config.tagId?.toUpperCase().contains('HUM') ?? false) || (config.tagId?.toUpperCase().contains('UMID') ?? false);
    final isTemperature = unit.contains('°C') || unit == 'C' || (config.tagId?.toUpperCase().contains('TEMP') ?? false);
    final indicatorColor = isHumidity
        ? const Color(0xFF38BDF8)
        : (isTemperature ? const Color(0xFFF59E0B) : const Color(0xFF4FD1C5));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayValue,
                style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: TextStyle(
                    color: indicatorColor.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ISA-101 High-Performance Mini Analog Bar (Situação Visual Instantânea)
        if (fraction != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              width: double.infinity,
              color: const Color(0xFF131922),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],


        if (isSparkline && hasRealTelemetry && fraction != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: _buildRealSparkline(config.tagId ?? 'default', fraction, indicatorColor),
          ),
        ],
        if (isSparkline && (!hasRealTelemetry || fraction == null) && hasData) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                'SEM SÉRIE TEMPORAL',
                style: TextStyle(
                  color: const Color(0xFF8C98A8).withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Buffer de histórico de leituras reais por tag (máximo 25 pontos por canal)
  static final Map<String, List<double>> _realHistoryByTag = {};

  Widget _buildRealSparkline(String tagKey, double currentFraction, Color color) {
    final history = _realHistoryByTag.putIfAbsent(tagKey, () => <double>[]);
    if (history.isEmpty || (history.last - currentFraction).abs() > 0.001 || history.length < 2) {
      history.add(currentFraction);
      if (history.length > 25) {
        history.removeAt(0);
      }
    }

    return CustomPaint(
      size: const Size(double.infinity, 32),
      painter: _RealSparklinePainter(
        values: List.unmodifiable(history),
        strokeColor: color,
      ),
    );
  }
}

class _RealSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color strokeColor;

  const _RealSparklinePainter({
    required this.values,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    if (values.length == 1) {
      final y = (1.0 - values.first.clamp(0.0, 1.0)) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      return;
    }

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);
    final firstY = (1.0 - values.first.clamp(0.0, 1.0)) * size.height;

    path.moveTo(0, firstY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, firstY);

    for (int i = 1; i < values.length; i++) {
      final x = i * stepX;
      final y = (1.0 - values[i].clamp(0.0, 1.0)) * size.height;
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RealSparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.strokeColor != strokeColor;
  }
}
