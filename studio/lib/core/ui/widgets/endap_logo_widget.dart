import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Logotipo Oficial LANDELL Automation — Conceito "The Cyber-Physical Cross"
///
/// Homenagem a Roberto Landell de Moura (Pioneiro da transmissão sem fio)
/// e convergência entre o mundo físico e cibernético em tempo real:
/// - Escudo octogonal chanfrado em titânio aeroespacial
/// - 4 braços entrelaçados em simetria rotacional (Nó Cibernético-Físico)
/// - Núcleo Nexus rebaixado com diodo de sincronismo determinístico (1ms / IEC 60073 RUN #22C55E)
/// - Tipografia industrial anti-fadiga com tracking refinado
class EndapLogoWidget extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showSubtitle;
  final bool isLive;
  final String title;

  const EndapLogoWidget({
    super.key,
    this.size = 28.0,
    this.showText = true,
    this.showSubtitle = false,
    this.isLive = true,
    this.title = 'LANDELL STUDIO',
  });

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CyberPhysicalCrossPainter(isLive: isLive),
      ),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: size * 0.35),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFFF1F5F9),
                    fontSize: size * 0.48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: size * 0.16,
                  height: size * 0.16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 1),
              Text(
                'EDGE-NATIVE AUTOMATION',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Alias oficial de compatibilidade para a nova marca
typedef LandellLogoWidget = EndapLogoWidget;

class _CyberPhysicalCrossPainter extends CustomPainter {
  final bool isLive;

  _CyberPhysicalCrossPainter({required this.isLive});

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate space of original vector curves is 226x236
    final scale = math.min(size.width / 226.0, size.height / 236.0);
    final dx = (size.width - 226.0 * scale) / 2.0;
    final dy = (size.height - 236.0 * scale) / 2.0;

    // Dual alternating titanium linear gradients
    final grad1 = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
    ).createShader(Rect.fromLTWH(dx, dy, 226.0 * scale, 236.0 * scale));

    final grad2 = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFF64748B)],
    ).createShader(Rect.fromLTWH(dx, dy, 226.0 * scale, 236.0 * scale));

    final paint1 = Paint()
      ..shader = grad1
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..shader = grad2
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFF8FAFC).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, 0.8 * scale);

    // Draw the 4 exact interlocking titanium bands
    final b0 = _band0(scale, scale, dx, dy);
    canvas.drawPath(b0, paint1);
    canvas.drawPath(b0, strokePaint);

    final b1 = _band1(scale, scale, dx, dy);
    canvas.drawPath(b1, paint2);
    canvas.drawPath(b1, strokePaint);

    final b2 = _band2(scale, scale, dx, dy);
    canvas.drawPath(b2, paint1);
    canvas.drawPath(b2, strokePaint);

    final b3 = _band3(scale, scale, dx, dy);
    canvas.drawPath(b3, paint2);
    canvas.drawPath(b3, strokePaint);

    // Center deterministic diode housing (IEC 60073 - 1ms synchronism)
    final cx = dx + 113.0 * scale;
    final cy = dy + 118.0 * scale;
    final rHousing = 14.0 * scale;
    final rDiode = 9.0 * scale;

    final housingPaint = Paint()
      ..color = const Color(0xFF1A1E27)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), rHousing, housingPaint);

    final housingBorderPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, 1.5 * scale);
    canvas.drawCircle(Offset(cx, cy), rHousing, housingBorderPaint);

    final diodeColor = isLive ? const Color(0xFF22C55E) : const Color(0xFF64748B);

    if (isLive) {
      final glowPaint = Paint()
        ..color = diodeColor.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 5.0 * scale));
      canvas.drawCircle(Offset(cx, cy), rDiode * 1.5, glowPaint);
    }

    final diodePaint = Paint()
      ..color = diodeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), rDiode, diodePaint);

    if (isLive) {
      final specPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - 2.5 * scale, cy - 2.5 * scale), 2.8 * scale, specPaint);
    }
  }

  Path _band0(double scaleX, double scaleY, double dx, double dy) {
    final p = Path();
    p.moveTo(dx + 132.00 * scaleX, dy + 215.43 * scaleY);
    p.cubicTo(dx + 132.00 * scaleX, dy + 209.62 * scaleY, dx + 131.53 * scaleX, dy + 204.00 * scaleY, dx + 130.96 * scaleX, dy + 202.93 * scaleY);
    p.lineTo(dx + 129.93 * scaleX, dy + 201.00 * scaleY);
    p.lineTo(dx + 112.96 * scaleX, dy + 201.00 * scaleY);
    p.lineTo(dx + 96.00 * scaleX, dy + 201.00 * scaleY);
    p.lineTo(dx + 96.00 * scaleX, dy + 199.22 * scaleY);
    p.cubicTo(dx + 96.00 * scaleX, dy + 198.25 * scaleY, dx + 99.35 * scaleX, dy + 194.12 * scaleY, dx + 103.45 * scaleX, dy + 190.05 * scaleY);
    p.lineTo(dx + 110.90 * scaleX, dy + 182.65 * scaleY);
    p.lineTo(dx + 102.29 * scaleX, dy + 173.58 * scaleY);
    p.cubicTo(dx + 97.56 * scaleX, dy + 168.58 * scaleY, dx + 93.33 * scaleX, dy + 164.36 * scaleY, dx + 92.90 * scaleX, dy + 164.19 * scaleY);
    p.cubicTo(dx + 92.47 * scaleX, dy + 164.01 * scaleY, dx + 87.75 * scaleX, dy + 168.40 * scaleY, dx + 82.41 * scaleX, dy + 173.94 * scaleY);
    p.cubicTo(dx + 77.08 * scaleX, dy + 179.47 * scaleY, dx + 71.99 * scaleX, dy + 184.00 * scaleY, dx + 71.11 * scaleX, dy + 184.00 * scaleY);
    p.cubicTo(dx + 69.41 * scaleX, dy + 184.00 * scaleY, dx + 48.45 * scaleX, dy + 169.59 * scaleY, dx + 43.75 * scaleX, dy + 165.19 * scaleY);
    p.cubicTo(dx + 42.04 * scaleX, dy + 163.60 * scaleY, dx + 41.00 * scaleX, dy + 161.59 * scaleY, dx + 41.00 * scaleX, dy + 159.88 * scaleY);
    p.lineTo(dx + 41.00 * scaleX, dy + 157.13 * scaleY);
    p.lineTo(dx + 75.42 * scaleX, dy + 123.86 * scaleY);
    p.lineTo(dx + 109.83 * scaleX, dy + 90.60 * scaleY);
    p.lineTo(dx + 104.98 * scaleX, dy + 85.29 * scaleY);
    p.cubicTo(dx + 102.31 * scaleX, dy + 82.37 * scaleY, dx + 98.74 * scaleX, dy + 78.81 * scaleY, dx + 97.04 * scaleX, dy + 77.38 * scaleY);
    p.lineTo(dx + 93.95 * scaleX, dy + 74.78 * scaleY);
    p.lineTo(dx + 88.72 * scaleX, dy + 79.60 * scaleY);
    p.cubicTo(dx + 85.85 * scaleX, dy + 82.25 * scaleY, dx + 70.68 * scaleX, dy + 96.83 * scaleY, dx + 55.00 * scaleX, dy + 111.99 * scaleY);
    p.cubicTo(dx + 39.32 * scaleX, dy + 127.16 * scaleY, dx + 22.75 * scaleX, dy + 143.15 * scaleY, dx + 18.17 * scaleX, dy + 147.53 * scaleY);
    p.lineTo(dx + 9.84 * scaleX, dy + 155.50 * scaleY);
    p.lineTo(dx + 10.50 * scaleX, dy + 161.00 * scaleY);
    p.cubicTo(dx + 11.49 * scaleX, dy + 169.26 * scaleY, dx + 14.71 * scaleX, dy + 173.84 * scaleY, dx + 24.72 * scaleX, dy + 181.26 * scaleY);
    p.cubicTo(dx + 47.54 * scaleX, dy + 198.17 * scaleY, dx + 81.01 * scaleX, dy + 221.49 * scaleY, dx + 85.50 * scaleX, dy + 223.62 * scaleY);
    p.lineTo(dx + 90.50 * scaleX, dy + 225.98 * scaleY);
    p.lineTo(dx + 111.25 * scaleX, dy + 225.99 * scaleY);
    p.lineTo(dx + 132.00 * scaleX, dy + 226.00 * scaleY);
    p.lineTo(dx + 132.00 * scaleX, dy + 215.43 * scaleY);
    p.close();
    return p;
  }

  Path _band1(double scaleX, double scaleY, double dx, double dy) {
    final p = Path();
    p.moveTo(dx + 147.50 * scaleX, dy + 220.44 * scaleY);
    p.cubicTo(dx + 169.12 * scaleX, dy + 205.88 * scaleY, dx + 202.87 * scaleX, dy + 181.07 * scaleY, dx + 208.63 * scaleX, dy + 175.50 * scaleY);
    p.cubicTo(dx + 212.08 * scaleX, dy + 172.17 * scaleY, dx + 214.17 * scaleX, dy + 169.16 * scaleY, dx + 214.90 * scaleX, dy + 166.50 * scaleY);
    p.cubicTo(dx + 215.60 * scaleX, dy + 163.92 * scaleY, dx + 215.99 * scaleX, dy + 148.26 * scaleY, dx + 215.99 * scaleX, dy + 122.52 * scaleY);
    p.lineTo(dx + 216.00 * scaleX, dy + 82.54 * scaleY);
    p.lineTo(dx + 205.50 * scaleX, dy + 93.00 * scaleY);
    p.lineTo(dx + 195.00 * scaleX, dy + 103.46 * scaleY);
    p.lineTo(dx + 195.00 * scaleX, dy + 116.17 * scaleY);
    p.cubicTo(dx + 195.00 * scaleX, dy + 124.34 * scaleY, dx + 194.61 * scaleX, dy + 129.12 * scaleY, dx + 193.90 * scaleX, dy + 129.56 * scaleY);
    p.cubicTo(dx + 193.28 * scaleX, dy + 129.94 * scaleY, dx + 189.97 * scaleX, dy + 127.44 * scaleY, dx + 186.39 * scaleX, dy + 123.89 * scaleY);
    p.lineTo(dx + 179.98 * scaleX, dy + 117.54 * scaleY);
    p.lineTo(dx + 171.44 * scaleX, dy + 126.07 * scaleY);
    p.lineTo(dx + 162.90 * scaleX, dy + 134.61 * scaleY);
    p.lineTo(dx + 173.99 * scaleX, dy + 145.54 * scaleY);
    p.cubicTo(dx + 185.30 * scaleX, dy + 156.68 * scaleY, dx + 186.98 * scaleX, dy + 159.29 * scaleY, dx + 185.10 * scaleX, dy + 162.80 * scaleY);
    p.cubicTo(dx + 183.37 * scaleX, dy + 166.05 * scaleY, dx + 157.65 * scaleX, dy + 184.00 * scaleY, dx + 154.73 * scaleX, dy + 184.00 * scaleY);
    p.cubicTo(dx + 152.69 * scaleX, dy + 184.00 * scaleY, dx + 145.72 * scaleX, dy + 177.43 * scaleY, dx + 120.34 * scaleX, dy + 151.56 * scaleY);
    p.lineTo(dx + 88.50 * scaleX, dy + 119.12 * scaleY);
    p.lineTo(dx + 80.40 * scaleX, dy + 126.86 * scaleY);
    p.lineTo(dx + 72.30 * scaleX, dy + 134.60 * scaleY);
    p.lineTo(dx + 103.62 * scaleX, dy + 166.55 * scaleY);
    p.cubicTo(dx + 120.84 * scaleX, dy + 184.12 * scaleY, dx + 135.63 * scaleX, dy + 199.92 * scaleY, dx + 136.47 * scaleX, dy + 201.65 * scaleY);
    p.cubicTo(dx + 137.54 * scaleX, dy + 203.85 * scaleY, dx + 138.00 * scaleX, dy + 207.88 * scaleY, dx + 138.00 * scaleX, dy + 214.97 * scaleY);
    p.lineTo(dx + 138.00 * scaleX, dy + 225.13 * scaleY);
    p.lineTo(dx + 140.25 * scaleX, dy + 224.47 * scaleY);
    p.cubicTo(dx + 141.49 * scaleX, dy + 224.11 * scaleY, dx + 144.75 * scaleX, dy + 222.30 * scaleY, dx + 147.50 * scaleX, dy + 220.44 * scaleY);
    p.close();
    return p;
  }

  Path _band2(double scaleX, double scaleY, double dx, double dy) {
    final p = Path();
    p.moveTo(dx + 165.49 * scaleX, dy + 123.94 * scaleY);
    p.cubicTo(dx + 175.95 * scaleX, dy + 113.73 * scaleY, dx + 191.47 * scaleX, dy + 98.66 * scaleY, dx + 200.00 * scaleX, dy + 90.44 * scaleY);
    p.lineTo(dx + 215.50 * scaleX, dy + 75.50 * scaleY);
    p.lineTo(dx + 215.80 * scaleX, dy + 70.71 * scaleY);
    p.cubicTo(dx + 216.21 * scaleX, dy + 64.29 * scaleY, dx + 212.61 * scaleX, dy + 56.43 * scaleY, dx + 207.40 * scaleX, dy + 52.36 * scaleY);
    p.cubicTo(dx + 205.25 * scaleX, dy + 50.69 * scaleY, dx + 199.22 * scaleX, dy + 46.25 * scaleY, dx + 194.00 * scaleX, dy + 42.50 * scaleY);
    p.cubicTo(dx + 163.05 * scaleX, dy + 20.28 * scaleY, dx + 153.50 * scaleX, dy + 13.68 * scaleY, dx + 150.20 * scaleX, dy + 12.22 * scaleY);
    p.lineTo(dx + 146.50 * scaleX, dy + 10.59 * scaleY);
    p.lineTo(dx + 118.25 * scaleX, dy + 10.31 * scaleY);
    p.lineTo(dx + 90.00 * scaleX, dy + 10.03 * scaleY);
    p.lineTo(dx + 90.00 * scaleX, dy + 16.08 * scaleY);
    p.lineTo(dx + 90.00 * scaleX, dy + 22.12 * scaleY);
    p.lineTo(dx + 95.15 * scaleX, dy + 27.56 * scaleY);
    p.lineTo(dx + 100.29 * scaleX, dy + 33.00 * scaleY);
    p.lineTo(dx + 115.15 * scaleX, dy + 33.00 * scaleY);
    p.cubicTo(dx + 126.20 * scaleX, dy + 33.00 * scaleY, dx + 130.00 * scaleX, dy + 33.31 * scaleY, dx + 130.00 * scaleX, dy + 34.22 * scaleY);
    p.cubicTo(dx + 130.00 * scaleX, dy + 34.90 * scaleY, dx + 126.97 * scaleX, dy + 38.50 * scaleY, dx + 123.27 * scaleX, dy + 42.23 * scaleY);
    p.lineTo(dx + 116.53 * scaleX, dy + 49.02 * scaleY);
    p.lineTo(dx + 125.34 * scaleX, dy + 57.76 * scaleY);
    p.lineTo(dx + 134.16 * scaleX, dy + 66.50 * scaleY);
    p.lineTo(dx + 143.89 * scaleX, dy + 56.25 * scaleY);
    p.cubicTo(dx + 150.45 * scaleX, dy + 49.34 * scaleY, dx + 154.33 * scaleX, dy + 46.00 * scaleY, dx + 155.81 * scaleX, dy + 46.00 * scaleY);
    p.cubicTo(dx + 157.86 * scaleX, dy + 46.00 * scaleY, dx + 162.53 * scaleX, dy + 49.03 * scaleY, dx + 178.04 * scaleX, dy + 60.45 * scaleY);
    p.cubicTo(dx + 185.23 * scaleX, dy + 65.74 * scaleY, dx + 185.96 * scaleX, dy + 66.58 * scaleY, dx + 185.98 * scaleX, dy + 69.60 * scaleY);
    p.cubicTo(dx + 186.00 * scaleX, dy + 71.43 * scaleY, dx + 155.40 * scaleX, dy + 102.64 * scaleY, dx + 123.04 * scaleX, dy + 133.81 * scaleY);
    p.lineTo(dx + 116.57 * scaleX, dy + 140.03 * scaleY);
    p.lineTo(dx + 124.51 * scaleX, dy + 148.01 * scaleY);
    p.lineTo(dx + 132.45 * scaleX, dy + 156.00 * scaleY);
    p.lineTo(dx + 139.47 * scaleX, dy + 149.25 * scaleY);
    p.cubicTo(dx + 143.33 * scaleX, dy + 145.54 * scaleY, dx + 155.04 * scaleX, dy + 134.15 * scaleY, dx + 165.49 * scaleX, dy + 123.94 * scaleY);
    p.close();
    return p;
  }

  Path _band3(double scaleX, double scaleY, double dx, double dy) {
    final p = Path();
    p.moveTo(dx + 32.00 * scaleX, dy + 113.62 * scaleY);
    p.cubicTo(dx + 32.00 * scaleX, dy + 104.35 * scaleY, dx + 32.32 * scaleX, dy + 101.00 * scaleY, dx + 33.22 * scaleX, dy + 101.00 * scaleY);
    p.cubicTo(dx + 33.89 * scaleX, dy + 101.00 * scaleY, dx + 36.99 * scaleX, dy + 103.52 * scaleY, dx + 40.10 * scaleX, dy + 106.60 * scaleY);
    p.lineTo(dx + 45.76 * scaleX, dy + 112.20 * scaleY);
    p.lineTo(dx + 47.63 * scaleX, dy + 111.17 * scaleY);
    p.cubicTo(dx + 48.66 * scaleX, dy + 110.60 * scaleY, dx + 52.88 * scaleX, dy + 106.70 * scaleY, dx + 57.00 * scaleX, dy + 102.50 * scaleY);
    p.lineTo(dx + 64.50 * scaleX, dy + 94.86 * scaleY);
    p.lineTo(dx + 52.75 * scaleX, dy + 83.47 * scaleY);
    p.lineTo(dx + 41.00 * scaleX, dy + 72.07 * scaleY);
    p.lineTo(dx + 41.00 * scaleX, dy + 69.23 * scaleY);
    p.lineTo(dx + 41.00 * scaleX, dy + 66.39 * scaleY);
    p.lineTo(dx + 54.55 * scaleX, dy + 56.44 * scaleY);
    p.cubicTo(dx + 64.48 * scaleX, dy + 49.16 * scaleY, dx + 68.89 * scaleX, dy + 46.50 * scaleY, dx + 71.06 * scaleX, dy + 46.50 * scaleY);
    p.lineTo(dx + 74.01 * scaleX, dy + 46.50 * scaleY);
    p.lineTo(dx + 106.27 * scaleX, dy + 78.74 * scaleY);
    p.lineTo(dx + 138.54 * scaleX, dy + 110.98 * scaleY);
    p.lineTo(dx + 146.55 * scaleX, dy + 103.02 * scaleY);
    p.lineTo(dx + 154.57 * scaleX, dy + 95.06 * scaleY);
    p.lineTo(dx + 120.39 * scaleX, dy + 60.78 * scaleY);
    p.cubicTo(dx + 94.33 * scaleX, dy + 34.65 * scaleY, dx + 86.08 * scaleX, dy + 25.79 * scaleY, dx + 85.67 * scaleX, dy + 23.50 * scaleY);
    p.cubicTo(dx + 85.37 * scaleX, dy + 21.85 * scaleY, dx + 84.85 * scaleX, dy + 18.36 * scaleY, dx + 84.50 * scaleX, dy + 15.75 * scaleY);
    p.lineTo(dx + 83.88 * scaleX, dy + 11.00 * scaleY);
    p.lineTo(dx + 81.62 * scaleX, dy + 11.00 * scaleY);
    p.cubicTo(dx + 77.69 * scaleX, dy + 11.00 * scaleY, dx + 69.47 * scaleX, dy + 16.05 * scaleY, dx + 46.98 * scaleX, dy + 32.27 * scaleY);
    p.cubicTo(dx + 17.90 * scaleX, dy + 53.26 * scaleY, dx + 15.39 * scaleX, dy + 55.31 * scaleY, dx + 12.85 * scaleX, dy + 60.26 * scaleY);
    p.lineTo(dx + 10.67 * scaleX, dy + 64.50 * scaleY);
    p.lineTo(dx + 10.29 * scaleX, dy + 106.17 * scaleY);
    p.lineTo(dx + 9.92 * scaleX, dy + 147.85 * scaleY);
    p.lineTo(dx + 20.96 * scaleX, dy + 137.04 * scaleY);
    p.lineTo(dx + 32.00 * scaleX, dy + 126.24 * scaleY);
    p.lineTo(dx + 32.00 * scaleX, dy + 113.62 * scaleY);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _CyberPhysicalCrossPainter oldDelegate) {
    return oldDelegate.isLive != isLive;
  }
}
