// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/models/demo_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';
import '../../ladder_autosave.dart';
import '../services/studio_event_bus.dart';
import '../../home/models/home_widget_config.dart';
import '../../home/models/hmi_screen.dart';
import '../../home/renderers/home_widget_renderer.dart';
import '../../home/ui/widgets/widget_gallery_dialog.dart';
import '../../home/ui/widgets/widget_config_dialog.dart';
import '../../home/ui/widgets/export_hmi_dialog.dart';
import '../../home/ui/widgets/hmi_screen_dialog.dart';
import 'widgets/create_io_dialog.dart';
import 'widgets/endap_logo_widget.dart';
import '../services/network_manager.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';
import '../../design_system/tokens.dart';
import '../../design_system/industrial_tokens.dart';

class HomePage extends StatefulWidget {
  final LadderProject? project;
  final LadderRuntime? runtime;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onProjectUpdated;
  final VoidCallback? onOpenDrawer;
  final NetworkManager networkManager;
  final bool initialKioskMode;
  final VoidCallback? onTriggerEmergency;
  final ValueChanged<bool>? onKioskModeChanged;
  final bool embedded;

  const HomePage({
    super.key,
    this.project,
    this.runtime,
    this.onNavigateTab,
    this.onProjectUpdated,
    this.onOpenDrawer,
    required this.networkManager,
    this.initialKioskMode = false,
    this.onTriggerEmergency,
    this.onKioskModeChanged,
    this.embedded = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isEditMode = false;
  late bool _isKioskMode;
  late LadderProject _localProject;
  late List<HmiScreen> _screens;
  int _activeScreenIndex = 0;
  late List<HomeWidgetConfig> _widgets;

  // Filtros de Operação e Visão
  String _selectedController = 'ALL'; // 'ALL' ou IP do nó
  String _previewRole = 'TODOS'; // 'TODOS', 'OPERADOR', 'MANUTENÇÃO', 'GESTOR'

  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  void _enterKioskMode() {
    setState(() => _isKioskMode = true);
    widget.onKioskModeChanged?.call(true);
  }

  void _exitKioskMode() {
    setState(() => _isKioskMode = false);
    widget.onKioskModeChanged?.call(false);
  }

  @override
  void initState() {
    super.initState();
    _isKioskMode = widget.initialKioskMode;
    _localProject =
        widget.project ??
        LadderProject(id: 'proj_default', name: 'Projeto Padrão');
    _initScreensAndWidgets();
    TelemetrySyncService.instance.addListener(_onTelemetryUpdated);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  void _onTelemetryUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    TelemetrySyncService.instance.removeListener(_onTelemetryUpdated);
    super.dispose();
  }

  void _initScreensAndWidgets() {
    if (_localProject.hmiScreens != null && _localProject.hmiScreens!.isNotEmpty) {
      _screens = List.from(_localProject.hmiScreens!);
    } else if (_localProject.dashboardWidgets != null && _localProject.dashboardWidgets!.isNotEmpty) {
      // Prioriza widgets existentes no projeto
      _screens = [
        HmiScreen(
          id: 'screen_operacao_principal',
          title: '01 - Operação Principal',
          iconName: 'precision_manufacturing',
          allowedRoles: ['OPERADOR', 'MANUTENÇÃO', 'GESTOR', 'INTEGRADOR'],
          widgets: List.from(_localProject.dashboardWidgets!),
          isKioskEnabled: true,
        ),
      ];
      _localProject.hmiScreens = List.from(_screens);
    } else if (DemoProject.createCleanTccProject().hmiScreens != null &&
        DemoProject.createCleanTccProject().hmiScreens!.isNotEmpty) {
      _screens = List.from(DemoProject.createCleanTccProject().hmiScreens!);
      _localProject.hmiScreens = List.from(_screens);
    } else {
      _screens = [
        HmiScreen(
          id: 'screen_operacao_principal',
          title: '01 - Operação Principal',
          iconName: 'precision_manufacturing',
          allowedRoles: ['OPERADOR', 'MANUTENÇÃO', 'GESTOR', 'INTEGRADOR'],
          widgets: [],
          isKioskEnabled: true,
        ),
      ];
      _localProject.hmiScreens = List.from(_screens);
    }

    if (_activeScreenIndex >= _screens.length) {
      _activeScreenIndex = 0;
    }
    _widgets = List.from(_screens[_activeScreenIndex].widgets);
    _localProject.dashboardWidgets = List.from(_widgets);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialKioskMode != oldWidget.initialKioskMode) {
      _isKioskMode = widget.initialKioskMode;
    }
    if (widget.project != null && widget.project?.id != oldWidget.project?.id) {
      _localProject = widget.project!;
      _initScreensAndWidgets();
    }
  }

  Future<void> _saveWidgets() async {
    for (int i = 0; i < _widgets.length; i++) {
      _widgets[i].order = i;
    }
    _screens[_activeScreenIndex].widgets = List.from(_widgets);
    _localProject.hmiScreens = List.from(_screens);
    _localProject.dashboardWidgets = List.from(_widgets);
    await saveCurrentLadder(_localProject);
    widget.onProjectUpdated?.call();
    if (mounted) setState(() {});
  }

  void _switchScreen(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _activeScreenIndex = index;
      _widgets = List.from(_screens[_activeScreenIndex].widgets);
      _localProject.dashboardWidgets = List.from(_widgets);
    });
  }

  Future<void> _openNewScreenDialog() async {
    final newScreen = await HmiScreenDialog.show(context, isNew: true);
    if (newScreen != null && mounted) {
      setState(() {
        _screens.add(newScreen);
        _activeScreenIndex = _screens.length - 1;
        _widgets = List.from(newScreen.widgets);
        _localProject.hmiScreens = List.from(_screens);
        _localProject.dashboardWidgets = List.from(_widgets);
      });
      await saveCurrentLadder(_localProject);
      widget.onProjectUpdated?.call();
      StudioEventBus.instance.emit(
        type: 'HMI_SCREEN_ADDED',
        source: 'HOME_PAGE',
        message: 'NOVA TELA DE IHM CRIADA: ${newScreen.title}',
        severity: EventSeverity.info,
      );
    }
  }

  Future<void> _openEditScreenDialog(int index) async {
    if (index < 0 || index >= _screens.length) return;
    final current = _screens[index];
    final updated = await HmiScreenDialog.show(context, screen: current, isNew: false);
    if (updated != null && mounted) {
      setState(() {
        _screens[index] = updated;
        if (_activeScreenIndex == index) {
          _widgets = List.from(updated.widgets);
        }
        _localProject.hmiScreens = List.from(_screens);
      });
      await saveCurrentLadder(_localProject);
      widget.onProjectUpdated?.call();
      StudioEventBus.instance.emit(
        type: 'HMI_SCREEN_UPDATED',
        source: 'HOME_PAGE',
        message: 'TELA IHM ATUALIZADA: ${updated.title}',
        severity: EventSeverity.info,
      );
    }
  }

  Future<void> _deleteScreen(int index) async {
    if (_screens.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTokens.panel2,
          content: Text(
            'O projeto deve conter ao menos uma tela de IHM ativa.',
            style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final target = _screens[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTokens.line, width: 1.0),
        ),
        title: const Text(
          'Excluir Tela de IHM',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja excluir permanentemente a tela "${target.title}" e todos os seus mostradores associados?',
          style: const TextStyle(color: AppTokens.muted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: AppTokens.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXCLUIR TELA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _screens.removeAt(index);
        if (_activeScreenIndex >= _screens.length) {
          _activeScreenIndex = _screens.length - 1;
        }
        _widgets = List.from(_screens[_activeScreenIndex].widgets);
        _localProject.hmiScreens = List.from(_screens);
        _localProject.dashboardWidgets = List.from(_widgets);
      });
      await saveCurrentLadder(_localProject);
      widget.onProjectUpdated?.call();
    }
  }

  void _openExportHmiDialog() {
    ExportHmiDialog.show(
      context,
      project: _localProject,
      screens: _screens,
      activeScreenIndex: _activeScreenIndex,
      networkManager: widget.networkManager,
    );
  }

  void _showUnlockPinDialog() {
    final pinController = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: IndustrialTokens.bgPanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: IndustrialTokens.borderSubtle),
            ),
            title: Row(
              children: const [
                Icon(Icons.lock, color: IndustrialTokens.progYellow, size: 20),
                SizedBox(width: 8),
                Text(
                  'DESBLOQUEIO DE SEGURANÇA KIOSK',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Digite o PIN numérico do técnico para sair do modo touch kiosk:',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('kiosk_pin_field'),
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: IndustrialTokens.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    errorText: pinError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (pinController.text == '1234') {
                      Navigator.pop(ctx);
                      _exitKioskMode();
                    } else {
                      setDialogState(() => pinError = 'PIN incorreto (padrão: 1234)');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ),
              ElevatedButton(
                key: const Key('kiosk_pin_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: IndustrialTokens.telemetryCyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  if (pinController.text == '1234') {
                    Navigator.pop(ctx);
                    _exitKioskMode();
                  } else {
                    setDialogState(() => pinError = 'PIN incorreto (padrão: 1234)');
                  }
                },
                child: const Text('DESBLOQUEAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddWidgetFlow() async {
    final template = await WidgetGalleryDialog.show(context);
    if (template == null || !mounted) return;

    final newWidget = await WidgetConfigDialog.show(
      context,
      project: _localProject,
      templateType: template,
    );

    if (newWidget != null && mounted) {
      setState(() {
        newWidget.order = _widgets.length;
        _widgets.add(newWidget);
      });
      await _saveWidgets();
      StudioEventBus.instance.emit(
        type: 'WIDGET_ADDED',
        source: 'HOME_DASHBOARD',
        message:
            'WIDGET ADICIONADO: ${newWidget.title} (${newWidget.templateType.name})',
        severity: EventSeverity.info,
      );
    }
  }

  Future<void> _openEditWidget(HomeWidgetConfig config) async {
    final updated = await WidgetConfigDialog.show(
      context,
      project: _localProject,
      templateType: config.templateType,
      existingWidget: config,
    );

    if (updated != null && mounted) {
      final index = _widgets.indexWhere((w) => w.id == config.id);
      if (index != -1) {
        setState(() {
          _widgets[index] = updated;
        });
        await _saveWidgets();
        StudioEventBus.instance.emit(
          type: 'WIDGET_EDITED',
          source: 'HOME_DASHBOARD',
          message: 'WIDGET ATUALIZADO: ${updated.title}',
          severity: EventSeverity.info,
        );
      }
    }
  }

  Future<void> _deleteWidget(HomeWidgetConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTokens.line, width: 1.0),
        ),
        title: Text(
          'Remover Widget',
          style: TextStyle(
            color: AppTokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Deseja remover "${config.title}" da tela atual?',
          style: TextStyle(color: AppTokens.muted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCELAR',
              style: TextStyle(
                color: AppTokens.muted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'REMOVER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _widgets.removeWhere((w) => w.id == config.id);
      });
      await _saveWidgets();
      StudioEventBus.instance.emit(
        type: 'WIDGET_DELETED',
        source: 'HOME_DASHBOARD',
        message: 'WIDGET REMOVIDO: ${config.title}',
        severity: EventSeverity.warning,
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _widgets.removeAt(oldIndex);
      _widgets.insert(newIndex, item);
    });
    _saveWidgets();
  }

  IconData _getIconForName(String name) {
    switch (name) {
      case 'precision_manufacturing':
        return Icons.precision_manufacturing;
      case 'speed':
        return Icons.speed;
      case 'tune':
        return Icons.tune;
      case 'analytics':
        return Icons.analytics;
      case 'thermostat':
        return Icons.thermostat;
      case 'water_drop':
        return Icons.water_drop;
      case 'electric_meter':
        return Icons.electric_meter;
      case 'dashboard':
      default:
        return Icons.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isKioskMode) {
      return _buildKioskModeView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161922),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top App Bar / Header com abas de Telas IHM
            _buildHeader(),

            // Barra de Filtro de Controladores (Apenas se não estiver embedded)
            if (!widget.embedded)
              _buildMultiControllerBar(),

            // Conteúdo Principal da Tela Ativa
            Expanded(
              child: _isEditMode
                  ? _buildEditModeBody()
                  : _buildNormalModeBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKioskModeView() {
    final activeScreen = _screens.isNotEmpty && _activeScreenIndex < _screens.length
        ? _screens[_activeScreenIndex]
        : null;

    final timeStr =
        '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF161922),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Touch Kiosk Header
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                return Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E222B),
                    border: Border(bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0)),
                  ),
                  child: Row(
                    children: [
                      // Kiosk Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF0284C7), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: isNarrow ? 90 : 180),
                              child: Text(
                                isNarrow
                                    ? 'KIOSK'
                                    : (activeScreen != null ? 'KIOSK • ${activeScreen.title}' : 'LANDELL KIOSK'),
                                style: const TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Kiosk Screen Switcher Tabs
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _screens.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final scr = entry.value;
                              if (!scr.isKioskEnabled) return const SizedBox.shrink();
                              final isSelected = idx == _activeScreenIndex;

                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => _switchScreen(idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2B303C) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF353B4A),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getIconForName(scr.iconName),
                                          size: 14,
                                          color: isSelected ? const Color(0xFF0284C7) : Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          scr.title,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white60,
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Emergency Stop Button
                      if (widget.onTriggerEmergency != null) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.dangerous, size: 15),
                          label: Text(
                            isNarrow ? 'PARADA' : 'PARADA EMERGÊNCIA',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          onPressed: widget.onTriggerEmergency,
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Clock Display (hidden on narrow screens)
                      if (!isNarrow) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131722),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF222B3D)),
                          ),
                          child: Text(
                            timeStr,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Exit Kiosk (PIN-protected)
                      ElevatedButton.icon(
                        key: const Key('btn_sair_kiosk'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFFF59E0B),
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.lock_open, size: 14),
                        label: Text(
                          isNarrow ? 'SAIR' : 'SAIR DO KIOSK',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _showUnlockPinDialog,
                      ),
                    ],
                  ),
                );
              },
            ),

            // Kiosk Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_widgets.isEmpty)
                      _buildEmptyState()
                    else
                      ..._buildGroupedWidgets(isMobile: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiControllerBar() {
    final nodes = widget.networkManager.nodes;
    final totalControllers = nodes.isNotEmpty ? nodes.length : 1;

    final stripContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.device_hub_rounded, size: 13, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        const Text(
          'CONTROLADORES:',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),

        // Chip: Visão Global (Todos)
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _selectedController = 'ALL'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _selectedController == 'ALL' ? const Color(0xFF2B303C) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _selectedController == 'ALL' ? const Color(0xFF0284C7) : const Color(0xFF353B4A),
                width: 1.0,
              ),
            ),
            child: Text(
              'Todos os Controladores ($totalControllers)',
              style: TextStyle(
                color: _selectedController == 'ALL' ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Chips para cada controlador detectado
        ...nodes.map((node) {
          final isSelected = _selectedController == node.ip;
          final isOnline = node.status == NodeStatus.online;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _selectedController = node.ip),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2B303C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF353B4A),
                    width: 1.0,
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
                        color: isOnline ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${node.id} (${node.ip})',
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(width: 8),

        // Role Access Preview Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF252A36),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF353B4A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_outlined, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _previewRole,
                  isDense: true,
                  dropdownColor: const Color(0xFF252A36),
                  style: const TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Visão: Todas Telas')),
                    DropdownMenuItem(value: 'OPERADOR', child: Text('Visão: Operador')),
                    DropdownMenuItem(value: 'MANUTENÇÃO', child: Text('Visão: Técnico')),
                    DropdownMenuItem(value: 'GESTOR', child: Text('Visão: Gestor')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _previewRole = val);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E222B),
        border: Border(bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: stripContent,
      ),
    );
  }

  Widget _buildNormalModeBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final activeScreen = _screens.isNotEmpty && _activeScreenIndex < _screens.length
            ? _screens[_activeScreenIndex]
            : null;

        // Verifica permissão da tela com base no filtro de visualização
        final isRestricted = activeScreen != null &&
            _previewRole != 'TODOS' &&
            !activeScreen.canAccess(_previewRole);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRestricted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1315),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_person_outlined, color: Color(0xFFF43F5E), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TELA RESTRITA PARA O PERFIL: $_previewRole',
                              style: const TextStyle(
                                color: Color(0xFFF43F5E),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Esta tela só é visível para os perfis: ${activeScreen.allowedRoles.join(", ")}.',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Widgets Area
              if (_widgets.isEmpty)
                _buildEmptyState()
              else
                ..._buildGroupedWidgets(isMobile: isMobile),

              const SizedBox(height: 20),

              // FAB Button with Speed Dial / Option Sheet
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _showAddActionSheet,
                      child: const Center(
                        child: Icon(Icons.add, color: Color(0xFF2DD4BF), size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditModeBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.panel,
            border: Border(bottom: BorderSide(color: AppTokens.line, width: 1.0)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTokens.focus, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arraste para reordenar verticalmente • Toque no ícone de ajuste para configurar',
                  style: TextStyle(color: AppTokens.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: _widgets.length,
            // ignore: deprecated_member_use
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final widgetConfig = _widgets[index];
              return Container(
                key: ValueKey(widgetConfig.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: HomeWidgetRenderer(
                  config: widgetConfig,
                  project: _localProject,
                  runtime: widget.runtime,
                  networkManager: widget.networkManager,
                  isEditMode: true,
                  onEdit: () => _openEditWidget(widgetConfig),
                  onDelete: () => _deleteWidget(widgetConfig),
                  onStateChanged: () => setState(() {}),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FD1C5),
                foregroundColor: const Color(0xFF121418),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'ADICIONAR WIDGET',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
              onPressed: _openAddWidgetFlow,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedWidgets({bool isMobile = false}) {
    final List<Widget> items = [];
    int i = 0;

    while (i < _widgets.length) {
      final current = _widgets[i];

      // Check if current and next can be paired side-by-side (2 standard widgets on desktop/tablet)
      if (!isMobile &&
          current.sizePreset == WidgetSizePreset.standard &&
          i + 1 < _widgets.length &&
          _widgets[i + 1].sizePreset == WidgetSizePreset.standard) {
        final next = _widgets[i + 1];
        items.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HomeWidgetRenderer(
                  config: current,
                  project: _localProject,
                  runtime: widget.runtime,
                  networkManager: widget.networkManager,
                  isEditMode: false,
                  onStateChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: HomeWidgetRenderer(
                  config: next,
                  project: _localProject,
                  runtime: widget.runtime,
                  networkManager: widget.networkManager,
                  isEditMode: false,
                  onStateChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
        );
        items.add(const SizedBox(height: 16));
        i += 2;
      } else {
        // Render single full-width widget
        items.add(
          HomeWidgetRenderer(
            config: current,
            project: _localProject,
            runtime: widget.runtime,
            networkManager: widget.networkManager,
            isEditMode: false,
            onStateChanged: () => setState(() {}),
          ),
        );
        items.add(const SizedBox(height: 16));
        i++;
      }
    }

    return items;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTokens.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTokens.line, width: 1.0),
      ),
      child: Column(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            color: AppTokens.muted,
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            'PAINEL HMI VAZIO',
            style: TextStyle(
              color: AppTokens.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adicione widgets para monitorar e controlar variáveis de processo em tempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTokens.muted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.focus,
              foregroundColor: AppTokens.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'ADICIONAR WIDGET',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            onPressed: _openAddWidgetFlow,
          ),
        ],
      ),
    );
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF222B3D)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'AÇÕES DO PROJETO',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A202E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF222B3D),
                    ),
                  ),
                  child: const Icon(
                    Icons.memory,
                    color: Color(0xFF2DD4BF),
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Novo Ponto de I/O (Tag)',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: const Text(
                  'Criar entrada/saída digital ou analógica no CLP',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newTag = await CreateIoDialog.show(
                    context,
                    project: _localProject,
                    onTagCreated: (tag) {
                      setState(() {});
                      widget.onProjectUpdated?.call();
                    },
                  );
                  if (newTag != null && mounted) {
                    setState(() {});
                    widget.onProjectUpdated?.call();
                  }
                },
              ),
              const Divider(color: Color(0xFF1E2638)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A202E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF222B3D),
                    ),
                  ),
                  child: const Icon(
                    Icons.widgets_outlined,
                    color: Color(0xFF2DD4BF),
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Adicionar Widget HMI',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: const Text(
                  'Escolher mostrador, gauge, sparkline ou atuador',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddWidgetFlow();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_isEditMode) {
      return Container(
        width: double.infinity,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF1E222B),
          border: Border(
            bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'EDIT DASHBOARD',
                style: TextStyle(
                  color: Color(0xFFEAB308),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.add, color: Color(0xFF0284C7), size: 20),
              tooltip: 'Adicionar Widget',
              onPressed: _openAddWidgetFlow,
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => setState(() => _isEditMode = false),
              child: const Text('DONE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    // Normal Mode Header com Gerenciador de Telas IHM
    return Container(
      width: double.infinity,
      height: widget.embedded ? 36 : 44,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E222B),
        border: Border(bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0)),
      ),
      child: Row(
        children: [
          // Se não estiver embutido no Scaffold global, exibe botão de menu
          if (!widget.embedded && widget.onOpenDrawer != null) ...[
            IconButton(
              icon: const Icon(Icons.menu, size: 18, color: Colors.white70),
              onPressed: widget.onOpenDrawer,
              tooltip: 'Abrir Navegação',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: isMobile ? 26 : 32, minHeight: 28),
            ),
            SizedBox(width: isMobile ? 2 : 4),
          ],

          if (!widget.embedded) ...[
            const EndapLogoWidget(
              size: 18,
              showText: true,
              showSubtitle: false,
              title: 'LANDELL',
            ),
            SizedBox(width: isMobile ? 4 : 8),
            Container(width: 1, height: 16, color: const Color(0xFF2A303D)),
            SizedBox(width: isMobile ? 4 : 8),
          ] else ...[
            // Quando embutido no StudioScaffold, evita duplicar o logo/marca já presente no Ribbon Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF252A36),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF353B4A)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined, size: 12, color: Color(0xFF0284C7)),
                  SizedBox(width: 4),
                  Text(
                    'TELAS',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Container(width: 1, height: 14, color: const Color(0xFF2A303D)),
            SizedBox(width: isMobile ? 6 : 8),
          ],

          // Screen Selector Tabs roláveis no centro
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._screens.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final scr = entry.value;
                    final isSelected = idx == _activeScreenIndex;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        key: Key('hmi_screen_tab_$idx'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _switchScreen(idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF2B303C),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF353B4A),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getIconForName(scr.iconName),
                                size: 13,
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                scr.title,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (scr.allowedRoles.length < 4) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.lock_outline, size: 11, color: Color(0xFFEAB308)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Botão: + Nova Tela
                  Tooltip(
                    message: 'Adicionar Nova Tela de IHM',
                    child: InkWell(
                      key: const Key('btn_nova_tela_ihm'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: _openNewScreenDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B303C),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF353B4A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add, size: 13, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text(
                              'Nova Tela',
                              style: TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Botão: Configurar Tela Ativa (RBAC)
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Configurar permissões e nome da tela ativa',
                    child: InkWell(
                      key: const Key('btn_config_tela_ihm'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openEditScreenDialog(_activeScreenIndex),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B26),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF222B3D)),
                        ),
                        child: const Icon(Icons.settings_outlined, size: 14, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),

                  // Botão: Excluir Tela Ativa (se houver mais de 1)
                  if (_screens.length > 1) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Excluir esta tela de IHM',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _deleteScreen(_activeScreenIndex),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B26),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF222B3D)),
                          ),
                          child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFF43F5E)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(width: isMobile ? 3 : 6),

          // Ações Fixas à Direita
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botão: Modo Kiosk (Touch Operator)
              Tooltip(
                message: 'Iniciar Modo Touch Kiosk para chão de fábrica',
                child: isMobile
                    ? IconButton(
                        key: const Key('btn_modo_kiosk'),
                        icon: const Icon(Icons.touch_app, size: 16, color: Color(0xFF2DD4BF)),
                        tooltip: 'KIOSK',
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: _enterKioskMode,
                      )
                    : ElevatedButton.icon(
                        key: const Key('btn_modo_kiosk'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFF2DD4BF),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: const BorderSide(color: Color(0xFF2DD4BF), width: 1.0),
                        ),
                        icon: const Icon(Icons.touch_app, size: 14),
                        label: const Text('KIOSK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: _enterKioskMode,
                      ),
              ),
              SizedBox(width: isMobile ? 2 : 4),

              // Botão: Exportar Pacote IHM (.endap-hmi)
              Tooltip(
                message: 'Exportar pacote IHM para tablets e painéis embutidos',
                child: isMobile
                    ? IconButton(
                        key: const Key('btn_exportar_ihm'),
                        icon: const Icon(Icons.download, size: 16, color: Color(0xFF0284C7)),
                        tooltip: 'Exportar IHM',
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: _openExportHmiDialog,
                      )
                    : ElevatedButton.icon(
                        key: const Key('btn_exportar_ihm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('EXPORTAR IHM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: _openExportHmiDialog,
                      ),
              ),
              SizedBox(width: isMobile ? 2 : 4),

              // Ícone: Adicionar Widget
              Tooltip(
                message: 'Adicionar Widget na tela atual',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _openAddWidgetFlow,
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 3 : 5),
                    child: Icon(Icons.add_rounded, size: isMobile ? 16 : 18, color: const Color(0xFF2DD4BF)),
                  ),
                ),
              ),

              // Ícone: Reordenar / Editar Layout
              Tooltip(
                message: 'Editar Dashboard',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => setState(() => _isEditMode = true),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 3 : 5),
                    child: Icon(Icons.tune_rounded, size: isMobile ? 15 : 16, color: const Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
    ],
  ),
);
  }
}
