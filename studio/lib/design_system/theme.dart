import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: const Color(0xFF161922), // Nível 0: Bancada absorvente
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF0284C7),
      onPrimary: Colors.white,
      secondary: Color(0xFF252A36),
      onSecondary: Color(0xFFE2E8F0),
      surface: Color(0xFF1E222B),                  // Nível 1: Estrutura / Docks
      surfaceContainerHigh: Color(0xFF252A36),      // Nível 2: Cartões de trabalho
      onSurface: Color(0xFFE2E8F0),                 // Anti-glare Slate 200
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    cardTheme: CardThemeData(
      color: const Color(0xFF252A36),               // Nível 2
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFF353B4A), width: 1.0),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E222B),           // Nível 1
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFFE2E8F0)),
      titleTextStyle: TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E222B),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFF353B4A), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1E27),           // Nível 3: Inset rebaixado
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF2A303D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF2A303D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
      ),
    ),
  );

  static final ThemeData light = dark;
}
