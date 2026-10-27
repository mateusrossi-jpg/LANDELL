import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../models/hmi_screen.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../core/services/studio_event_bus.dart';
import '../../../core/services/network_manager.dart';

/// Diálogo industrial para exportação de pacotes de IHM (.endap-hmi)
/// Suporta exportação para tablets, painéis touch kiosk embutidos e IHMs industriais de mercado.
class ExportHmiDialog extends StatefulWidget {
  final LadderProject project;
  final List<HmiScreen> screens;
  final int activeScreenIndex;
  final NetworkManager networkManager;

  const ExportHmiDialog({
    super.key,
    required this.project,
    required this.screens,
    required this.activeScreenIndex,
    required this.networkManager,
  });

  static Future<void> show(
    BuildContext context, {
    required LadderProject project,
    required List<HmiScreen> screens,
    required int activeScreenIndex,
    required NetworkManager networkManager,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ExportHmiDialog(
        project: project,
        screens: screens,
        activeScreenIndex: activeScreenIndex,
        networkManager: networkManager,
      ),
    );
  }

  @override
  State<ExportHmiDialog> createState() => _ExportHmiDialogState();
}

class _ExportHmiDialogState extends State<ExportHmiDialog> {
  String _selectedTarget = 'TABLET_APP'; // TABLET_APP, KIOSK_PANEL, STANDARD_HMI
  bool _exportAllScreens = true;
  bool _includeControllers = true;
  bool _includeSecurityRbac = true;

  String _generateFileName() {
    final cleanProj = widget.project.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${cleanProj}_ihm.endap-hmi';
  }

  Map<String, dynamic> _buildHmiPackage() {
    final screensToExport = _exportAllScreens
        ? widget.screens
        : (widget.screens.isNotEmpty && widget.activeScreenIndex < widget.screens.length
            ? [widget.screens[widget.activeScreenIndex]]
            : widget.screens);

    final controllersList = widget.networkManager.nodes.map((node) {
      return {
        'id': node.id,
        'name': node.id,
        'ip': node.ip,
        'role': node.role,
        'status': node.status.name.toUpperCase(),
        'isOnline': node.status == NodeStatus.online,
        'hardware': 'ESP32-WROOM-32',
      };
    }).toList();

    return {
      'format': 'ENDAP_HMI_PACKAGE_V1',
      'version': '1.0.0',
      'targetProfile': _selectedTarget,
      'exportedAt': DateTime.now().toIso8601String(),
      'project': {
        'id': widget.project.id,
        'name': widget.project.name,
        'author': 'ENDAP Studio Industrial',
      },
      'screens': screensToExport.map((s) => s.toJson()).toList(),
      if (_includeControllers) 'controllers': controllersList,
      if (_includeSecurityRbac)
        'security': {
          'kioskPin': '1234',
          'requireAuth': true,
          'roles': ['OPERADOR', 'MANUTENÇÃO', 'GESTOR', 'INTEGRADOR'],
        },
      'telemetryContract': {
        'protocol': 'ENDAP_REST_AND_WS',
        'defaultPort': 80,
        'scanPeriodMs': 100,
        'syncIntervalMs': 200,
      },
    };
  }

  Future<void> _exportToFile(BuildContext context) async {
    try {
      final hmiData = _buildHmiPackage();
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(hmiData);
      final fileName = _generateFileName();
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      await FilePicker.saveFile(
        dialogTitle: 'Exportar Pacote IHM ENDAP (.endap-hmi)',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['endap-hmi', 'json'],
      );

      StudioEventBus.instance.emit(
        type: 'HMI_EXPORT',
        source: 'HMI_PACKAGE_GENERATOR',
        message: 'PACOTE IHM EXPORTADO: $fileName ($_selectedTarget)',
        severity: EventSeverity.info,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: IndustrialTokens.bgPanel,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: IndustrialTokens.runGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✓ Pacote IHM salvo com sucesso: $fileName',
                    style: const TextStyle(
                      color: IndustrialTokens.runGreen,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao exportar IHM: $e');
    }
  }

  void _copyJsonToClipboard(BuildContext context) {
    final hmiData = _buildHmiPackage();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(hmiData);

    Clipboard.setData(ClipboardData(text: jsonString));
    StudioEventBus.instance.emit(
      type: 'HMI_EXPORT',
      source: 'HMI_PACKAGE_GENERATOR',
      message: 'JSON DO PACOTE IHM COPIADO PARA O CLIPBOARD',
      severity: EventSeverity.info,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTokens.panel2,
        content: Text(
          '✓ Configuração IHM (.endap-hmi) copiada para a área de transferência!',
          style: TextStyle(color: AppTokens.focus, fontWeight: FontWeight.bold),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _generateFileName();
    final hmiData = _buildHmiPackage();
    const encoder = JsonEncoder.withIndent('  ');
    final jsonPreview = encoder.convert(hmiData);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.panel2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3), width: 1.0),
            ),
            child: const Icon(Icons.tablet_mac_rounded, color: Color(0xFF2DD4BF), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GERADOR DE IHM INDUSTRIAL (.endap-hmi)',
              style: TextStyle(
                color: AppTokens.text,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Perfil de Destino do Pacote:',
                style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildTargetOption(
                    id: 'TABLET_APP',
                    title: 'Tablet Móvel / Fixo',
                    subtitle: 'App Android / iOS / Web',
                    icon: Icons.tablet_android,
                  ),
                  const SizedBox(width: 8),
                  _buildTargetOption(
                    id: 'KIOSK_PANEL',
                    title: 'Painel Touch Kiosk',
                    subtitle: 'Display Embutido / HDMI',
                    icon: Icons.touch_app,
                  ),
                  const SizedBox(width: 8),
                  _buildTargetOption(
                    id: 'STANDARD_HMI',
                    title: 'IHM de Mercado',
                    subtitle: 'Rockwell / Modbus / OPC',
                    icon: Icons.precision_manufacturing,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // File Name Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF2DD4BF), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Export Options Checkboxes
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: const Color(0xFF2DD4BF),
                      title: Text(
                        'Exportar todas as telas (${widget.screens.length} telas declaradas)',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _exportAllScreens
                            ? 'Inclui todas as telas criadas no projeto'
                            : 'Exporta apenas a tela selecionada: "${widget.screens.isNotEmpty ? widget.screens[widget.activeScreenIndex].title : ''}"',
                        style: const TextStyle(color: AppTokens.muted, fontSize: 10.5),
                      ),
                      value: _exportAllScreens,
                      onChanged: (val) => setState(() => _exportAllScreens = val),
                    ),
                    const Divider(color: Color(0xFF1E2638), height: 12),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: const Color(0xFF2DD4BF),
                      title: const Text(
                        'Vincular Controladores Ativos & Topologia',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Mapeia ${widget.networkManager.nodes.length} nós/CLPs com IPs para comunicação direta',
                        style: const TextStyle(color: AppTokens.muted, fontSize: 10.5),
                      ),
                      value: _includeControllers,
                      onChanged: (val) => setState(() => _includeControllers = val),
                    ),
                    const Divider(color: Color(0xFF1E2638), height: 12),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: const Color(0xFF2DD4BF),
                      title: const Text(
                        'Segurança & Perfis RBAC (PIN Kiosk: 1234)',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Restringe telas por perfil (Operador, Técnico, Gestor) e trava saída do Kiosk',
                        style: TextStyle(color: AppTokens.muted, fontSize: 10.5),
                      ),
                      value: _includeSecurityRbac,
                      onChanged: (val) => setState(() => _includeSecurityRbac = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Preview of JSON bundle
              const Text(
                'Estrutura do Pacote Gerado (.endap-hmi):',
                style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                height: 110,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonPreview,
                    style: const TextStyle(
                      color: AppTokens.textDim,
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('btn_fechar_export_dialog'),
          onPressed: () => Navigator.pop(context),
          child: const Text('FECHAR', style: TextStyle(color: AppTokens.muted, fontSize: 12)),
        ),
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 15, color: Color(0xFF0284C7)),
          label: const Text('Copiar Pacote JSON', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12)),
          onPressed: () => _copyJsonToClipboard(context),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.download, size: 16),
          label: const Text(
            'BAIXAR PACOTE IHM',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
          ),
          onPressed: () => _exportToFile(context),
        ),
      ],
    );
  }

  Widget _buildTargetOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTarget == id;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedTarget = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : AppTokens.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF2DD4BF) : AppTokens.line,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF2DD4BF) : AppTokens.muted,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTokens.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTokens.muted,
                  fontSize: 9.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
