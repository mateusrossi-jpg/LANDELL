// Design System Tokens – semantic, no hard-coded colours in UI

import 'package:flutter/material.dart';

// ── Colour Tokens ──────────────────────────────────────────────────────
class AppColors {
  // ── 4-Tier Surface Architecture (Ergonomic Anti-Fatigue) ──
  static const Color background = Color(0xFF161922); // Tier 0: Deep graphite workbench canvas (light absorbing)
  static const Color panel = Color(0xFF1E222B);      // Tier 1: Ribbon bar, sidebar & structural dock
  static const Color panel2 = Color(0xFF252A36);     // Tier 2: Active cards, ladder rungs & inspectors
  static const Color field = Color(0xFF1A1E27);      // Tier 3: Inset textboxes, telemetry inputs & watch cells
  
  // ── Crisp Structural Boundaries (1px Precision Hairline) ──
  static const Color line = Color(0xFF2A303D);       // Structural panel divider
  static const Color lineBright = Color(0xFF353B4A); // Card perimeter & focus boundary
  
  // ── Calibrated Anti-Glare Typography (Slate Spectrum) ──
  static const Color text = Color(0xFFE2E8F0);       // Slate 200 (88% luminance, zero retinal glare / halation)
  static const Color textDim = Color(0xFF94A3B8);    // Slate 400 (Crisp metadata & secondary labels)
  static const Color textMuted = Color(0xFF64748B);  // Slate 500 (Memory offsets & inactive captions)
  static const Color focus = Color(0xFF0284C7);      // Siemens TIA Engineering Blue
  
  // ── Status & Telemetry (IEC 60073 / Industrial Standard) ──
  static const Color run = Color(0xFF22C55E);        // Siemens Green (Active / Energized Rungs / Zero-Jitter)
  static const Color warn = Color(0xFFEAB308);       // Safety Amber (Forced I/O / Manual Override / Warning)
  static const Color fault = Color(0xFFEF4444);      // Industrial IEC Red (E-Stop / Watchdog Fault / Trip)

  // Backward compatibility alias & semantics
  static const Color primary = focus;
  static const Color primaryLight = Color(0xFF0EA5E9);
  static const Color primaryLighter = Color(0xFF38BDF8);
  static const Color primaryAccent = focus;
  static const Color onPrimary = Colors.white;

  static const Color secondary = panel2;
  static const Color onSecondary = text;

  static const Color success = run;
  static const Color warning = warn;
  static const Color danger = fault;
  static const Color error = fault;
  static const Color info = focus;

  static const Color backgroundDark = background;
  static const Color surface = panel;
  static const Color surfaceVariant = panel2;
  static const Color surfaceElevated = panel2;
  static const Color outline = line;
  static const Color outlineBright = lineBright;
  static const Color outlineActive = focus;
  static const Color textPrimary = text;
  static const Color textSecondary = textDim;

  static const Color statusOn = run;
  static const Color statusOnGlow = Color(0x2222C55E);
  static const Color statusOff = line;
  static const Color statusSim = warn;
  static const Color statusForced = warn;
}

// ── Industrial Design Tokens Accessor ────────────────────────────────────
class AppTokens {
  static const Color bg = AppColors.background;
  static const Color background = AppColors.background;
  static const Color panel = AppColors.panel;
  static const Color panel2 = AppColors.panel2;
  static const Color field = AppColors.field;
  static const Color line = AppColors.line;
  static const Color lineBright = AppColors.lineBright;
  static const Color text = AppColors.text;
  static const Color textDim = AppColors.textDim;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color muted = AppColors.textMuted;
  static const Color textMuted = AppColors.textMuted;
  static const Color focus = AppColors.focus;
  static const Color primary = AppColors.primary;
  static const Color run = AppColors.run;
  static const Color success = AppColors.success;
  static const Color warn = AppColors.warn;
  static const Color warning = AppColors.warning;
  static const Color fault = AppColors.fault;
  static const Color error = AppColors.error;
}

// ── Typography Tokens (Anti-Fatigue & Tabular Telemetry) ─────────────────
class AppTypography {
  static TextStyle headlineLarge(BuildContext ctx) =>
      Theme.of(ctx).textTheme.headlineLarge!.copyWith(
            color: AppColors.text,
            letterSpacing: -0.01,
            height: 1.35,
          );
  static TextStyle titleMedium(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
            color: AppColors.text,
            letterSpacing: -0.005,
            height: 1.4,
          );
  static TextStyle bodySmall(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodySmall!.copyWith(
            color: AppColors.textDim,
            fontSize: 12.0,
            height: 1.45,
          );
  static TextStyle labelLarge(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelLarge!.copyWith(
            color: AppColors.text,
            letterSpacing: 0.02,
          );

  /// Tabular Monospace: Essencial para tags, ciclos e endereços não tremerem na tela
  static TextStyle tabularMono({
    double fontSize = 11.5,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.text,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0.3,
      color: color,
      height: 1.4,
    );
  }
}

// ── Spacing Tokens ─────────────────────────────────────────────────────
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

// ── Radius Tokens ─────────────────────────────────────────────────────
class AppRadius {
  static const double sm = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
}

// ── Elevation Tokens ───────────────────────────────────────────────────
class AppElevation {
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 6.0;
  static const double level4 = 8.0;
}

// ── Component-state helpers ───────────────────────────────────────────
class AppStateTokens {
  static const double disabledOpacity = 0.38;
  static const Color pressedOverlay = Colors.black12;
  static const Color focusedBorder = Colors.transparent;
}

// ── Density Tokens ─────────────────────────────────────────────────────
class AppDensity {
  static const double compact = 0.8;
  static const double regular = 1.0;
  static const double comfortable = 1.2;
}

// ── Extensions for easy access in UI code ──────────────────────────────
extension DesignTokens on BuildContext {
  Color get colorPrimary => AppColors.primary;
  Color get colorOnPrimary => AppColors.onPrimary;
  Color get colorSecondary => AppColors.secondary;
  Color get colorOnSecondary => AppColors.onSecondary;
  Color get colorSuccess => AppColors.success;
  Color get colorError => AppColors.error;
  Color get colorWarning => AppColors.warning;
  Color get colorInfo => AppColors.info;
  Color get colorSurface => AppColors.surface;
  Color get colorBackground => AppColors.background;
  Color get colorOutline => AppColors.outline;

  double get spacingXs => AppSpacing.xs;
  double get spacingSm => AppSpacing.sm;
  double get spacingMd => AppSpacing.md;
  double get spacingLg => AppSpacing.lg;
  double get spacingXl => AppSpacing.xl;

  double get radiusSm => AppRadius.sm;
  double get radiusMd => AppRadius.md;
  double get radiusLg => AppRadius.lg;

  double get elevation0 => AppElevation.level0;
  double get elevation1 => AppElevation.level1;
  double get elevation2 => AppElevation.level2;
  double get elevation3 => AppElevation.level3;
  double get elevation4 => AppElevation.level4;

  TextStyle get typoHeadlineLarge => AppTypography.headlineLarge(this);
  TextStyle get typoTitleMedium => AppTypography.titleMedium(this);
  TextStyle get typoBodySmall => AppTypography.bodySmall(this);
  TextStyle get typoLabelLarge => AppTypography.labelLarge(this);
}
