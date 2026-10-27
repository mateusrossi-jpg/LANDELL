import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../models/hmi_screen.dart';

/// Diálogo para criar ou editar as configurações de uma Tela de IHM
/// Permite ao Técnico definir: Título, Ícone, Perfis Autorizados (RBAC) e Habilitação em Modo Kiosk.
class HmiScreenDialog extends StatefulWidget {
  final HmiScreen? initialScreen;
  final bool isNew;

  const HmiScreenDialog({
    super.key,
    this.initialScreen,
    this.isNew = false,
  });

  static Future<HmiScreen?> show(
    BuildContext context, {
    HmiScreen? screen,
    bool isNew = false,
  }) {
    return showDialog<HmiScreen>(
      context: context,
      builder: (_) => HmiScreenDialog(
        initialScreen: screen,
        isNew: isNew,
      ),
    );
  }

  @override
  State<HmiScreenDialog> createState() => _HmiScreenDialogState();
}

class _HmiScreenDialogState extends State<HmiScreenDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedIcon;
  late Set<String> _allowedRoles;
  late bool _isKioskEnabled;

  static const List<Map<String, dynamic>> _availableIcons = [
    {'name': 'precision_manufacturing', 'icon': Icons.precision_manufacturing, 'label': 'Máquina'},
    {'name': 'speed', 'icon': Icons.speed, 'label': 'Medidor'},
    {'name': 'tune', 'icon': Icons.tune, 'label': 'Controle/PID'},
    {'name': 'analytics', 'icon': Icons.analytics, 'label': 'Supervisão'},
    {'name': 'thermostat', 'icon': Icons.thermostat, 'label': 'Térmico'},
    {'name': 'water_drop', 'icon': Icons.water_drop, 'label': 'Fluidos'},
    {'name': 'electric_meter', 'icon': Icons.electric_meter, 'label': 'Energia'},
    {'name': 'dashboard', 'icon': Icons.dashboard, 'label': 'Geral'},
  ];

  static const List<Map<String, String>> _systemRoles = [
    {'id': 'OPERADOR', 'label': 'Operador de Máquina', 'desc': 'Operação no chão de fábrica e acionamentos autorizados'},
    {'id': 'MANUTENÇÃO', 'label': 'Técnico / Manutenção', 'desc': 'Diagnósticos, forçamento de E/S e ajuste fino'},
    {'id': 'GESTOR', 'label': 'Gestor / Supervisão', 'desc': 'Indicadores de produção, tendências e OEE'},
    {'id': 'INTEGRADOR', 'label': 'Integrador (Admin)', 'desc': 'Acesso irrestrito a configurações, lógica e hardware'},
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initialScreen;
    _titleController = TextEditingController(text: s?.title ?? 'Nova Tela de Operação');
    _descController = TextEditingController(text: s?.description ?? '');
    _selectedIcon = s?.iconName ?? 'precision_manufacturing';
    _allowedRoles = Set.from(s?.allowedRoles ?? ['OPERADOR', 'MANUTENÇÃO', 'GESTOR', 'INTEGRADOR']);
    _isKioskEnabled = s?.isKioskEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final roles = _allowedRoles.toList();
    if (!roles.contains('INTEGRADOR')) {
      roles.add('INTEGRADOR'); // Integrador sempre mantém acesso como segurança técnica
    }

    final screen = HmiScreen(
      id: widget.initialScreen?.id ?? 'screen_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      iconName: _selectedIcon,
      allowedRoles: roles,
      widgets: widget.initialScreen?.widgets ?? [],
      isKioskEnabled: _isKioskEnabled,
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
    );

    Navigator.pop(context, screen);
  }

  @override
  Widget build(BuildContext context) {
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
            child: Icon(
              widget.isNew ? Icons.add_to_photos_rounded : Icons.display_settings_rounded,
              color: const Color(0xFF2DD4BF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isNew ? 'NOVA TELA DE IHM' : 'CONFIGURAR TELA IHM & ACESSO',
              style: const TextStyle(
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field
              const Text(
                'Título da Tela:',
                style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ex: 03 - Dosagem & Mistura',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTokens.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Icon Selector
              const Text(
                'Ícone Representativo:',
                style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((item) {
                  final name = item['name'] as String;
                  final icon = item['icon'] as IconData;
                  final label = item['label'] as String;
                  final isSelected = _selectedIcon == name;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedIcon = name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E293B) : AppTokens.panel2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2DD4BF) : AppTokens.line,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: isSelected ? const Color(0xFF2DD4BF) : Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTokens.muted,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // RBAC Role Restrictions
              Row(
                children: const [
                  Icon(Icons.shield_outlined, size: 15, color: Color(0xFF2DD4BF)),
                  SizedBox(width: 6),
                  Text(
                    'Controle de Acesso por Perfil (RBAC):',
                    style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: Column(
                  children: _systemRoles.map((role) {
                    final roleId = role['id']!;
                    final isChecked = _allowedRoles.contains(roleId);
                    final isIntegrator = roleId == 'INTEGRADOR';

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      activeColor: const Color(0xFF0284C7),
                      checkColor: Colors.white,
                      title: Text(
                        role['label']!,
                        style: TextStyle(
                          color: isChecked ? Colors.white : Colors.white60,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        role['desc']!,
                        style: const TextStyle(color: AppTokens.muted, fontSize: 10),
                      ),
                      value: isChecked,
                      onChanged: isIntegrator
                          ? null // Integrador sempre tem acesso
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _allowedRoles.add(roleId);
                                } else {
                                  _allowedRoles.remove(roleId);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Kiosk Mode Option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFF0284C7),
                  title: const Text(
                    'Exibir no Modo Touch Kiosk da Máquina',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Permite que esta tela seja selecionada em painéis touch locais no chão de fábrica',
                    style: TextStyle(color: AppTokens.muted, fontSize: 10),
                  ),
                  value: _isKioskEnabled,
                  onChanged: (val) => setState(() => _isKioskEnabled = val),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR', style: TextStyle(color: AppTokens.muted, fontSize: 12)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _save,
          child: Text(
            widget.isNew ? 'CRIAR TELA' : 'SALVAR ALTERAÇÕES',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}
