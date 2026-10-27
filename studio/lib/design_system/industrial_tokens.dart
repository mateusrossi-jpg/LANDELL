import 'package:flutter/material.dart';
import 'tokens.dart';

/// Design Tokens e Paleta Industrial nível Siemens TIA Portal v20 / TwinCAT Pro
/// 100% harmonizado com a identidade visual do Tema 4 e ergonomia anti-fadiga.
class IndustrialTokens {
  // Cores de Superfície e Estrutura (Arquitetura de 4 Níveis Anti-Fadiga)
  static const Color bgCanvas = AppColors.background;       // 0xFF161922 Nível 0: Fundo bancada absorvente
  static const Color bgSurface = AppColors.panel;            // 0xFF1E222B Nível 1: Estrutura, docks e ribbons
  static const Color bgPanel = AppColors.panel2;             // 0xFF252A36 Nível 2: Cartões de trabalho e rungs
  static const Color bgSubtle = AppColors.field;             // 0xFF1A1E27 Nível 3: Inputs e células rebaixadas
  static const Color bgHighlight = Color(0xFF2C3240);        // Destaque suave de seleção
  static const Color borderSubtle = AppColors.line;          // 0xFF2A303D Bordas estruturais (1px)
  static const Color borderProminent = AppColors.lineBright; // 0xFF353B4A Bordas de cards e foco

  // Estados Lógicos e de CLP (Norma Internacional IEC 60073 e Siemens TIA)
  static const Color runGreen = AppColors.run;               // 0xFF22C55E Verde Siemens TIA
  static const Color runGreenGlow = Color(0xFF4ADE80);       // Live Energy Flow
  static const Color progYellow = AppColors.warn;            // 0xFFEAB308 Âmbar industrial
  static const Color faultRed = AppColors.fault;             // 0xFFEF4444 Vermelho IEC
  static const Color offlineGrey = Color(0xFF64748B);        // Desconectado / Inativo
  static const Color infoBlue = AppColors.focus;             // 0xFF0284C7 Azul Engenharia Siemens
  static const Color telemetryCyan = Color(0xFF0EA5E9);      // Azul ciano telemetria

  // Alertas de Forçamento Industrial (Sutis e Elegantes)
  static const Color forceActiveBg = Color(0xFF362708);
  static const Color forceActiveBorder = Color(0xFFEAB308);
  static const Color forceActiveText = Color(0xFFFEF08A);

  // Tipografia Industrial Calibrada Anti-Fadiga (Tabular Figures para estabilidade óptica)
  static const TextStyle codeMonospace = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.4,
    color: AppColors.text,
  );

  static const TextStyle headerTitle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.35,
    color: AppColors.text,
  );

  static const TextStyle badgeText = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 10.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}
