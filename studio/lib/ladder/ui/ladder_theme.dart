import 'package:flutter/material.dart';

class AppTheme {
  // --- Base Colors (Siemens TIA Pro Anti-Fatigue Palette) ---
  static const Color background = Color(0xFF161922); // Nível 0: Bancada absorvente anti-ofuscamento
  static const Color panelColor = Color(0xFF1E222B); // Nível 1: Estrutura / docks
  static const Color panel2Color = Color(0xFF252A36); // Nível 2: Rungs / cartões
  static const Color borderColor = Color(0xFF2A303D); // --line hairline estrutural
  static const Color textColor = Color(0xFFE2E8F0); // --text Slate 200 (anti-glare)
  static const Color textDimColor = Color(0xFF94A3B8); // --text-dim Slate 400
  static const Color focusColor = Color(0xFF0284C7); // --focus Siemens TIA Blue
  static const Color runColor = Color(0xFF22C55E); // --run Siemens Green
  static const Color warnColor = Color(0xFFEAB308); // --warn Safety Amber
  static const Color faultColor = Color(0xFFEF4444); // --fault IEC Red

  // Aliases for compatibility
  static const Color uiAccent = focusColor;
  static const Color uiAccentMuted = panel2Color;
  static const Color runtimeOn = runColor;
  static const Color runtimeOff = Color(0xFF353B4A);
  static const Color selectionYellow = focusColor;
  static const Color warningColor = warnColor;
  static const Color errorColor = faultColor;
  static const Color backgroundColor = background;
  static const Color cardColor = panel2Color;

  // --- Geometry ---
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 6.0;
  static const double technicalStrokeWidth = 1.5;
  static const double activeStrokeWidth = 2.5;

  static BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);
  static BorderRadius get mediumRadius => BorderRadius.circular(radiusMedium);

  // --- Visual Effects ---
  static final MaskFilter energizedGlow = const MaskFilter.blur(
    BlurStyle.normal,
    1.5,
  );

  static Paint get energizedPaint => Paint()
    ..color = runtimeOn
    ..strokeCap = StrokeCap.round
    ..strokeWidth = activeStrokeWidth
    ..maskFilter = energizedGlow;

  static Paint get technicalPaint => Paint()
    ..color = runtimeOff
    ..strokeCap = StrokeCap.round
    ..strokeWidth = technicalStrokeWidth;

  static const Gradient energyGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Opacity States ---
  static const double idleOpacity = 0.6;
  static const double activeOpacity = 1.0;
}
