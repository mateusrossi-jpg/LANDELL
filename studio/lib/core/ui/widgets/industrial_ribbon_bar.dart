import 'package:flutter/material.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../services/network_manager.dart';
import 'endap_logo_widget.dart';

enum IndustrialPlcMode { run, prog, fault }

/// Ribbon Bar Superior Responsivo (Desktop, Tablet e Mobile / iPhone XR)
class IndustrialRibbonBar extends StatelessWidget {
  final IndustrialPlcMode plcMode;
  final NetworkManager networkManager;
  final String activePersona;
  final ValueChanged<String> onPersonaChanged;
  final VoidCallback onDeploy;
  final VoidCallback onFetch;
  final VoidCallback onTriggerFailsafe;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onToggleTerminal;
  final bool isTerminalVisible;
  final int? scanDurationUs;

  const IndustrialRibbonBar({
    super.key,
    required this.plcMode,
    required this.networkManager,
    required this.activePersona,
    required this.onPersonaChanged,
    required this.onDeploy,
    required this.onFetch,
    required this.onTriggerFailsafe,
    this.onOpenDrawer,
    this.onToggleTerminal,
    this.isTerminalVisible = false,
    this.scanDurationUs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return Container(
          width: double.infinity,
          height: isMobile ? 46 : 50,
          decoration: const BoxDecoration(
            color: Color(0xFF1E222B), // Nível 1: Estrutura / Ribbon
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
          child: isMobile ? _buildMobileBar(context) : _buildDesktopBar(context, constraints.maxWidth),
        );
      },
    );
  }

  // 1. Barra Compacta para Celulares / iPhone XR (Largura < 800px)
  Widget _buildMobileBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Row(
          children: [
            // Botão Menu / Drawer
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFFE2E8F0), size: 21),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Menu',
              onPressed: onOpenDrawer,
            ),
            const SizedBox(width: 4),

            // Logo Oficial Vetorial LANDELL (Versão compacta para mobile)
            InkWell(
              onTap: onOpenDrawer,
              borderRadius: BorderRadius.circular(4),
              child: EndapLogoWidget(
                size: 19,
                showText: true,
                showSubtitle: false,
                title: 'LANDELL',
                isLive: plcMode == IndustrialPlcMode.run,
              ),
            ),

            const SizedBox(width: 6),

            // Pill Unificado de Status + IP + Scan Time (Mobile)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A36),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: networkManager.isHardwareOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : const Color(0xFF353B4A),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: networkManager.isHardwareOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        networkManager.isHardwareOnline
                            ? '${networkManager.gatewayIp} • ${networkManager.kernelExecMaxUs > 0 ? "${(networkManager.kernelExecMaxUs / 1000.0).toStringAsFixed(1)}ms" : "1.0ms"}'
                            : 'SIM • ${scanDurationUs != null && scanDurationUs! > 0 ? "${(scanDurationUs! / 1000.0).toStringAsFixed(1)}ms" : "1.0ms"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IndustrialTokens.codeMonospace.copyWith(
                          color: const Color(0xFFE2E8F0),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (networkManager.unclaimedNodes.isNotEmpty) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: '${networkManager.unclaimedNodes.length} novo(s) nó(s) aguardando adoção',
                child: InkWell(
                  onTap: onOpenDrawer,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEAB308), width: 1.0),
                    ),
                    child: const Icon(Icons.sensors_rounded, size: 12, color: Color(0xFFEAB308)),
                  ),
                ),
              ),
            ],

            const Spacer(),

            if (onDeploy != null) ...[
              Tooltip(
                message: 'Gravar Lógica no ESP32 (Deploy)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onDeploy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF0284C7), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF38BDF8)),
                        SizedBox(width: 2),
                        Text(
                          'GRAVAR',
                          style: TextStyle(
                            color: Color(0xFFE0F2FE),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            if (onFetch != null) ...[
              Tooltip(
                message: 'Ler Lógica do ESP32 (Fetch)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onFetch,
                  child: Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A36),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF353B4A), width: 1),
                    ),
                    child: const Icon(Icons.cloud_download_outlined, size: 14, color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Menu Dropdown de Seleção de Persona no Mobile
            PopupMenuButton<String>(
              tooltip: 'Selecionar Perfil',
              color: const Color(0xFF1E222B),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFF353B4A)),
              ),
              onSelected: onPersonaChanged,
              itemBuilder: (ctx) => [
                _buildPopupMenuItem('HOME', 'Painel HMI'),
                _buildPopupMenuItem('ENGENHEIRO', 'Workspace Engenheiro'),
                _buildPopupMenuItem('MANUTENÇÃO', 'Manutenção & Forçamento'),
                _buildPopupMenuItem('GESTOR', 'Gestão, OEE & BI'),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A36),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF353B4A), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _personaShortLabel(activePersona),
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),

            if (onToggleTerminal != null) ...[
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onToggleTerminal,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.terminal_rounded,
                    size: 16,
                    color: isTerminalVisible ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],

            const SizedBox(width: 6),

            // Botão Failsafe / Parada Compacto e Elegante
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTriggerFailsafe,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B181E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF6B2129), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop_circle_outlined, size: 12, color: Color(0xFFEF4444)),
                      SizedBox(width: 3),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 2. Barra Completa para Desktop / Tablets (Expandida para 100% da Largura)
  Widget _buildDesktopBar(BuildContext context, double maxWidth) {
    final effectiveWidth = maxWidth > 28 ? maxWidth - 28 : 0.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: effectiveWidth),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bloco Esquerdo: Menu, Marca, Status do CLP e Telemetria
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFFE2E8F0), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Menu',
                  onPressed: onOpenDrawer,
                ),
                const SizedBox(width: 6),
                // Logo & Identidade Oficial LANDELL
                InkWell(
                  onTap: onOpenDrawer,
                  borderRadius: BorderRadius.circular(4),
                  child: EndapLogoWidget(
                    size: 22,
                    showText: true,
                    showSubtitle: false,
                    title: 'LANDELL',
                    isLive: plcMode == IndustrialPlcMode.run,
                  ),
                ),

                const SizedBox(width: 14),
                const SizedBox(
                  height: 16,
                  child: VerticalDivider(color: Color(0xFF2A303D), width: 1),
                ),
                const SizedBox(width: 12),

                // Badge de Estado do CLP
                _buildPlcStateBadge(isCompact: false),

                const SizedBox(width: 10),

                // Telemetria Real do Kernel Determinístico / Runtime
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A36),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF353B4A)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed,
                        size: 12,
                        color: networkManager.isHardwareOnline ? const Color(0xFF22C55E) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        networkManager.isHardwareOnline
                            ? (networkManager.kernelExecMaxUs > 0
                                ? '${networkManager.kernelExecMaxUs}µs • ${networkManager.kernelJitterMaxUs}µs JITTER'
                                : '1.0ms • KERNEL OK')
                            : (scanDurationUs != null && scanDurationUs! > 0
                                ? '${(scanDurationUs! / 1000.0).toStringAsFixed(2)}ms • SIMULADOR'
                                : 'SIMULADOR LOCAL'),
                        style: IndustrialTokens.codeMonospace.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),

                if (networkManager.unclaimedNodes.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: '${networkManager.unclaimedNodes.length} novo(s) nó(s) aguardando adoção',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenDrawer,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.6), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sensors_rounded, color: Color(0xFFEAB308), size: 13),
                              const SizedBox(width: 5),
                              Text(
                                '${networkManager.unclaimedNodes.length} NÓ PENDENTE',
                                style: const TextStyle(
                                  color: Color(0xFFEAB308),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Bloco Central: Seletor de Persona
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildPersonaSelector(),
            ),

            // Bloco Direito: Ferramentas de Engenharia & Botão FAILSAFE
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleTerminal != null)
                  IconButton(
                    tooltip: 'Terminal de Diagnóstico',
                    icon: Icon(
                      Icons.terminal_rounded,
                      color: isTerminalVisible ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: onToggleTerminal,
                  ),
                IconButton(
                  tooltip: 'Gravar Lógica (Deploy)',
                  icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF22C55E), size: 18),
                  onPressed: onDeploy,
                ),
                IconButton(
                  tooltip: 'Ler do CLP (Fetch)',
                  icon: const Icon(Icons.cloud_download_outlined, color: Color(0xFF38BDF8), size: 18),
                  onPressed: onFetch,
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTriggerFailsafe,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B181E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF6B2129), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.stop_circle_outlined, size: 13, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text(
                            'FAILSAFE',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlcStateBadge({bool isCompact = false}) {
    Color dotColor;
    Color bg;
    Color borderColor;
    Color textColor;
    String label;

    switch (plcMode) {
      case IndustrialPlcMode.run:
        dotColor = const Color(0xFF22C55E);
        bg = const Color(0xFF173322);
        borderColor = const Color(0xFF235835);
        textColor = const Color(0xFF86EFAC);
        label = isCompact ? 'RUN' : 'RUN • DETERMINÍSTICO';
        break;
      case IndustrialPlcMode.prog:
        dotColor = const Color(0xFFEAB308);
        bg = const Color(0xFF38290D);
        borderColor = const Color(0xFF634510);
        textColor = const Color(0xFFFDE047);
        label = isCompact ? 'PROG' : 'PROGRAMAÇÃO';
        break;
      case IndustrialPlcMode.fault:
        dotColor = const Color(0xFFEF4444);
        bg = const Color(0xFF3B181E);
        borderColor = const Color(0xFF6B2129);
        textColor = const Color(0xFFFCA5A5);
        label = isCompact ? 'FALHA' : 'FALHA / ALARME';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaSelector() {
    final personas = [
      {'id': 'HOME', 'label': 'Painel HMI'},
      {'id': 'ENGENHEIRO', 'label': 'Engenharia'},
      {'id': 'MANUTENÇÃO', 'label': 'Manutenção'},
      {'id': 'GESTOR', 'label': 'Gestão & BI'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A36),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF353B4A)),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: personas.map((p) {
          final isSelected = activePersona == p['id'];
          return InkWell(
            onTap: () => onPersonaChanged(p['id'] as String),
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String id, String label) {
    final isSelected = activePersona == id;
    return PopupMenuItem<String>(
      value: id,
      child: Row(
        children: [
          if (isSelected)
            const EndapLogoWidget(size: 14, showText: false)
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF475569),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? IndustrialTokens.telemetryCyan : Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _personaShortLabel(String id) {
    switch (id) {
      case 'HOME':
      case 'OPERADOR':
        return 'HMI';
      case 'ENGENHEIRO':
        return 'ENG';
      case 'MANUTENÇÃO':
        return 'MAN';
      case 'GESTOR':
      default:
        return 'OEE';
    }
  }
}
