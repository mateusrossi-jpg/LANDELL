import 'package:flutter/material.dart';
import '../../design_system/industrial_tokens.dart';
import '../network/authenticated_http_client.dart';
import '../services/network_manager.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';
import '../../ladder/validation/graph_validator.dart';
import '../../ladder/ui/editor/firmware_sync_service.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';
import '../../features/gpio_tags/ui/gpio_tags_page.dart';
import '../../ladder/ui/editor/ladder_editor_page.dart';
import '../auth/session_manager.dart';
import 'widgets/export_project_dialog.dart';
import 'widgets/audit_log_dialog.dart';
import 'widgets/user_session_dialog.dart';
import 'widgets/industrial_ribbon_bar.dart';
import 'widgets/industrial_terminal_drawer.dart';
import 'widgets/endap_logo_widget.dart';
import 'personas/engineering_workspace_view.dart';
import 'personas/maintenance_diagnostics_view.dart';
import 'personas/manager_analytics_view.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'networks_page.dart';
import '../../ladder/ui/editor/file_helper.dart';
import '../../ladder_autosave.dart';

class StudioScaffold extends StatefulWidget {
  final LadderProject initialProject;
  final int initialIndex;
  final NetworkManager networkManager;
  final bool autoStartTelemetry;
  const StudioScaffold({
    super.key,
    required this.initialProject,
    this.initialIndex = 0,
    required this.networkManager,
    this.autoStartTelemetry = true,
  });

  @override
  State<StudioScaffold> createState() => _StudioScaffoldState();
}

class _StudioScaffoldState extends State<StudioScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _selectedIndex;
  late LadderProject _project;
  final LadderRuntime _runtime = LadderRuntime();

  IndustrialPlcMode _plcMode = IndustrialPlcMode.run;
  bool _showTerminal = true;
  bool _isKioskMode = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _project = widget.initialProject;
    _syncRuntime();
    widget.networkManager.addListener(_onNetworkChanged);
    if (widget.autoStartTelemetry) {
      _initTelemetry();
    }
  }

  @override
  void didUpdateWidget(covariant StudioScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProject.id != oldWidget.initialProject.id || widget.initialProject != oldWidget.initialProject) {
      _project = widget.initialProject;
      _syncRuntime();
      setState(() {});
    }
  }

  void _onNetworkChanged() {
    final gatewayIp = widget.networkManager.isHardwareOnline && widget.networkManager.gatewayIp.isNotEmpty
        ? widget.networkManager.gatewayIp
        : TelemetrySyncService.instance.gatewayIp;
    TelemetrySyncService.instance.updateControllerIps(
      _activeControllerIps(gatewayIp),
    );
  }

  @override
  void dispose() {
    widget.networkManager.removeListener(_onNetworkChanged);
    TelemetrySyncService.instance.stop();
    super.dispose();
  }

  Future<void> _initTelemetry() async {
    final gatewayIp = await FirmwareSyncService.getSavedGatewayIp();
    TelemetrySyncService.instance.init(
      project: _project,
      runtime: _runtime,
      gatewayIp: gatewayIp,
      controllerIps: _activeControllerIps(gatewayIp),
    );
    if (widget.autoStartTelemetry) {
      TelemetrySyncService.instance.start(interval: const Duration(milliseconds: 150));
    }
  }

  List<String> _activeControllerIps(String gatewayIp) {
    final ips = <String>[];
    for (final node in widget.networkManager.nodes) {
      if (node.role != 'Controlador' || node.status != NodeStatus.online) continue;
      final ip = node.ip.trim();
      if (ip.isEmpty || ips.contains(ip)) continue;
      ips.add(ip);
    }
    if (!ips.contains(gatewayIp)) {
      ips.insert(0, gatewayIp);
    }
    ips.sort();
    if (ips.isNotEmpty && ips.first != gatewayIp) {
      ips.remove(gatewayIp);
      ips.insert(0, gatewayIp);
    }
    return ips;
  }

  void _syncRuntime() {
    final validator = GraphValidator();
    final result = validator.validate(_project);
    if (result.isValid && result.executableGraph != null) {
      _runtime.loadProject(result.executableGraph!);
      TelemetrySyncService.instance.init(
        project: _project,
        runtime: _runtime,
      );
    }
  }

  String get _currentPersona {
    switch (_selectedIndex) {
      case 0:
        return 'HOME';
      case 1:
      case 2:
      case 6:
        return 'ENGENHEIRO';
      case 4:
        return 'MANUTENÇÃO';
      case 5:
        return 'GESTOR';
      default:
        return 'HOME';
    }
  }

  void _onPersonaChanged(String newPersona) {
    if (newPersona == 'ENGENHEIRO' && !SessionManager.instance.isIntegrator) {
      _showAccessRestrictedDialog('Workspace de Engenharia');
      return;
    }
    if (newPersona == 'MANUTENÇÃO' && !SessionManager.instance.isMaintenance) {
      _showAccessRestrictedDialog('Diagnósticos e Forçamento de E/S');
      return;
    }

    setState(() {
      switch (newPersona) {
        case 'HOME':
        case 'OPERADOR':
          _selectedIndex = 0;
          break;
        case 'ENGENHEIRO':
          _selectedIndex = 6; // Workspace Completo
          break;
        case 'MANUTENÇÃO':
          _selectedIndex = 4;
          break;
        case 'GESTOR':
          _selectedIndex = 5;
          break;
      }
    });
  }

  void _onSelectDestination(int index) {
    final isOperator = !SessionManager.instance.isIntegrator;
    if (isOperator && (index == 1 || index == 2 || index == 6)) {
      final destName = index == 1 ? 'Lógica Ladder IEC' : 'GPIO / TAGS';
      _showAccessRestrictedDialog(destName);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _showAccessRestrictedDialog(String destName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFF43F5E).withValues(alpha: 0.4), width: 1.0),
        ),
        title: Row(
          children: const [
            Icon(Icons.gpp_bad_outlined, color: Color(0xFFF43F5E), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ACESSO RESTRITO POR PERFIL',
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'O perfil atual (${SessionManager.instance.currentRole}) não tem permissão para acessar "$destName".\n\n'
          'Conforme o critério de segurança industrial US07 / NEC04, apenas o perfil correspondente ou "INTEGRADOR" pode modificar regras lógicas e diagnósticos restritos.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A202E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              UserSessionDialog.show(
                context,
                networkManager: widget.networkManager,
                onLogout: _handleLogout,
              );
            },
            child: const Text('Trocar Perfil / Login', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _handleProjectUpdated() {
    _syncRuntime();
    setState(() {});
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildDeployTargetOption({
    required String id,
    required String title,
    required String subtitle,
    required String badge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0284C7).withValues(alpha: 0.15) : const Color(0xFF1E222B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF0284C7) : const Color(0xFF2A303D),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF334155), width: 0.8),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeploy() async {
    final gatewayIp = widget.networkManager.controller.ip.trim().isNotEmpty
        ? widget.networkManager.controller.ip.trim()
        : widget.networkManager.gatewayIp.trim();

    if (gatewayIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum Gateway configurado ou conectado na rede.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Identifica nós de campo disponíveis
    final fieldNodes = widget.networkManager.nodes
        .where((n) => n.controllerIndex > 0 && n.status != NodeStatus.offline)
        .toList();

    String selectedTarget = 'ALL';

    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131722),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: IndustrialTokens.telemetryCyan.withValues(alpha: 0.4), width: 1.0),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: IndustrialTokens.telemetryCyan, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Gravar Lógica no CLP (Deploy)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecione o controlador de destino para compilação e download do bytecode determinístico:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                
                // Opção 1: Toda a Célula
                _buildDeployTargetOption(
                  id: 'ALL',
                  title: 'Toda a Célula (Particionado por Nó)',
                  subtitle: 'Compila e envia automaticamente os Rungs para seus respectivos controladores.',
                  badge: '${_project.networks.length} Rung(s)',
                  selected: selectedTarget == 'ALL',
                  onTap: () => setDialogState(() => selectedTarget = 'ALL'),
                ),
                const SizedBox(height: 6),

                // Opção 2: Gateway Principal
                _buildDeployTargetOption(
                  id: 'GATEWAY',
                  title: 'Gateway Principal (Híbrido)',
                  subtitle: 'IP: $gatewayIp · Execução local e coordenação.',
                  badge: '${_project.networks.where((n) => n.targetControllerId == 'GATEWAY' || n.targetControllerId == 'GLOBAL' || n.targetControllerId == 'ALL').length} Rung(s)',
                  selected: selectedTarget == 'GATEWAY',
                  onTap: () => setDialogState(() => selectedTarget = 'GATEWAY'),
                ),

                // Opção 3+: Nós de Campo
                for (final node in fieldNodes) ...[
                  const SizedBox(height: 6),
                  _buildDeployTargetOption(
                    id: node.id,
                    title: 'Nó ${node.controllerIndex} (${node.id})',
                    subtitle: 'IP: ${node.ip.isNotEmpty ? node.ip : "Rádio ESP-NOW L2"} · Controlador Remoto',
                    badge: '${_project.networks.where((r) => r.targetControllerId == node.id || r.targetControllerId == 'GLOBAL').length} Rung(s)',
                    selected: selectedTarget == node.id,
                    onTap: () => setDialogState(() => selectedTarget = node.id),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Limpar Lógica do CLP'),
              onPressed: () => Navigator.pop(ctx, 'CLEAR'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: IndustrialTokens.runGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('Compilar & Gravar', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, selectedTarget),
            ),
          ],
        ),
      ),
    );

    if (confirm == null || !mounted) return;

    if (confirm == 'CLEAR') {
      final syncService = FirmwareSyncService();
      final ok = await syncService.clearRules(gatewayIp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✓ Lógica Ladder removida do CLP com sucesso. Todas as saídas estão livres!' : 'Falha ao limpar lógica no CLP ($gatewayIp).'),
          backgroundColor: ok ? const Color(0xFF064E3B) : const Color(0xFF991B1B),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Compilando e gravando lógica no CLP...'),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        duration: const Duration(seconds: 4),
      ),
    );

    final syncService = FirmwareSyncService();
    bool allOk = false;
    String targetDesc = '';

    if (confirm == 'ALL') {
      int successCount = 0;
      int targetCount = 0;
      final details = <String>[];

      // 1. Gateway
      final gwRungs = _project.networks.where((n) => 
        n.targetControllerId == 'GATEWAY' || n.targetControllerId == 'GLOBAL' || n.targetControllerId == 'ALL'
      ).length;
      if (gwRungs > 0) {
        targetCount++;
        final ok = await syncService.syncRules(gatewayIp, _project, targetControllerId: 'GATEWAY');
        if (ok) {
          successCount++;
          details.add('Gateway ($gwRungs rungs)');
        }
      }

      // 2. Nós de Campo
      for (final n in fieldNodes) {
        if (n.ip.isNotEmpty && n.ip != 'Sem IP') {
          final nodeRungs = _project.networks.where((r) =>
            r.targetControllerId == n.id || r.targetControllerId == 'GLOBAL'
          ).length;
          if (nodeRungs > 0) {
            targetCount++;
            final ok = await syncService.syncRules(n.ip, _project, targetControllerId: n.id);
            if (ok) {
              successCount++;
              details.add('Nó ${n.controllerIndex} ($nodeRungs rungs)');
            }
          }
        }
      }

      allOk = targetCount == 0 || successCount == targetCount;
      targetDesc = details.isNotEmpty ? details.join(', ') : 'Gateway ($gatewayIp)';
    } else if (confirm == 'GATEWAY') {
      allOk = await syncService.syncRules(gatewayIp, _project, targetControllerId: 'GATEWAY');
      targetDesc = 'Gateway ($gatewayIp)';
    } else {
      final targetNode = fieldNodes.firstWhere(
        (n) => n.id == confirm, 
        orElse: () => EndapNode(id: confirm, ip: gatewayIp, role: 'node'),
      );
      final targetIp = targetNode.ip.isNotEmpty && targetNode.ip != 'Sem IP' ? targetNode.ip : gatewayIp;
      allOk = await syncService.syncRules(targetIp, _project, targetControllerId: confirm);
      targetDesc = 'Nó ${targetNode.controllerIndex > 0 ? targetNode.controllerIndex : targetNode.id} ($targetIp)';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (allOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Deploy realizado com sucesso: $targetDesc! Modo RUN ativo.'),
          backgroundColor: const Color(0xFF064E3B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✕ Falha ao gravar lógica em $targetDesc. Verifique conexão.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleFetch() async {
    final gatewayIp = widget.networkManager.controller.ip.trim().isNotEmpty
        ? widget.networkManager.controller.ip.trim()
        : widget.networkManager.gatewayIp.trim();

    if (gatewayIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum Gateway configurado para leitura.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Baixando lógica em execução no CLP...'),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        duration: const Duration(seconds: 3),
      ),
    );

    final syncService = FirmwareSyncService();
    final fetched = await syncService.fetchRules(gatewayIp);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (fetched != null && fetched.networks.isNotEmpty) {
      setState(() {
        _project = fetched;
        _syncRuntime();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${fetched.networks.length} Rungs recuperados com sucesso do CLP!'),
          backgroundColor: const Color(0xFF064E3B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nenhuma lógica prévia encontrada no CLP ($gatewayIp).'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    }
  }

  Future<void> _handleFailsafe() async {
    setState(() => _plcMode = IndustrialPlcMode.fault);

    final gatewayIp = widget.networkManager.controller.ip.trim().isNotEmpty
        ? widget.networkManager.controller.ip.trim()
        : widget.networkManager.gatewayIp.trim();

    if (gatewayIp.isNotEmpty) {
      try {
        final client = AuthenticatedHttpClient();
        await client.post(
          Uri.parse('http://$gatewayIp/api/failsafe/output/test'),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF43F5E), width: 1.2),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ESTADO SEGURO ACIONADO (FAILSAFE)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'O comando de Parada Failsafe foi enviado ao CLP. Todas as saídas digitais foram forçadas para estado desligado (ALL ZERO SAFE STATE).\n\nPara restaurar a operação normal, execute o Reset de Segurança.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              setState(() => _plcMode = IndustrialPlcMode.run);
              Navigator.pop(ctx);
            },
            child: const Text('Reset de Segurança (Retornar a RUN)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(
          networkManager: widget.networkManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = SessionManager.instance.currentUser ?? 'OPERADOR INDUSTRIAL';
    final currentRole = SessionManager.instance.currentRole ?? 'LOCAL';

    final pages = [
      // 0: Painel HMI com Telas Múltiplas e Widgets Customizáveis
      HomePage(
        key: const PageStorageKey('home_page_hmi_0'),
        project: _project,
        runtime: _runtime,
        networkManager: widget.networkManager,
        onNavigateTab: (idx) => _onSelectDestination(idx),
        onProjectUpdated: _handleProjectUpdated,
        onOpenDrawer: _openDrawer,
        onTriggerEmergency: _handleFailsafe,
        initialKioskMode: _isKioskMode,
        onKioskModeChanged: (isKiosk) => setState(() => _isKioskMode = isKiosk),
        embedded: true,
      ),
      // 1: Lógica Ladder IEC
      LadderEditorPage(
        initialProject: _project,
        onOpenDrawer: _openDrawer,
        runtime: _runtime,
        isActive: _selectedIndex == 1,
        networkManager: widget.networkManager,
        embedded: true,
      ),
      // 2: GPIO / TAGS
      GpioTagsPage(
        networkManager: widget.networkManager,
        project: _project,
        onProjectUpdated: _handleProjectUpdated,
        onOpenDrawer: _openDrawer,
        embedded: true,
      ),
      // 3: Redes & Topologia
      NetworksPage(
        networkManager: widget.networkManager,
        onOpenDrawer: _openDrawer,
        embedded: true,
      ),
      // 4: Persona Manutenção & Forçamento
      MaintenanceDiagnosticsView(
        networkManager: widget.networkManager,
        project: _project,
        runtime: _runtime,
      ),
      // 5: Persona Gestão & OEE
      ManagerAnalyticsView(
        networkManager: widget.networkManager,
        project: _project,
        runtime: _runtime,
      ),
      // 6: Workspace Completo de Engenharia (IDE)
      EngineeringWorkspaceView(
        project: _project,
        runtime: _runtime,
        networkManager: widget.networkManager,
        onProjectUpdated: _handleProjectUpdated,
        onOpenDrawer: _openDrawer,
        isActive: _selectedIndex == 6,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF161922),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E222B),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DrawerHeader(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E222B),
                  border: Border(bottom: BorderSide(color: Color(0xFF2A303D), width: 1.0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const EndapLogoWidget(
                      size: 28,
                      showText: true,
                      showSubtitle: true,
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Navigator.pop(context);
                        UserSessionDialog.show(
                          context,
                          networkManager: widget.networkManager,
                          onLogout: _handleLogout,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252A36),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF353B4A), width: 1.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentRole,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    _buildDrawerItem(
                      index: 0,
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard,
                      title: 'Painel HMI (Telas & Kiosk)',
                      subtitle: 'Supervisão de processo, IHM de máquina e modo tablet',
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      index: 1,
                      icon: Icons.account_tree_outlined,
                      activeIcon: Icons.account_tree,
                      title: 'Lógica Ladder IEC',
                      subtitle: 'Rungs, tags e lógica do controlador',
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      index: 2,
                      icon: Icons.memory_outlined,
                      activeIcon: Icons.memory,
                      title: 'GPIO / TAGS',
                      subtitle: 'Mapeamento físico GPIO ↔ TAG IEC ↔ Função',
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      index: 4,
                      icon: Icons.build_circle_outlined,
                      activeIcon: Icons.build_circle,
                      title: 'Diagnósticos de Campo',
                      subtitle: 'Live Energy Flow e Forçamento de E/S',
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      index: 5,
                      icon: Icons.analytics_outlined,
                      activeIcon: Icons.analytics,
                      title: 'Gestão, OEE & Relatórios',
                      subtitle: 'Indicadores, perdas e frota de nós',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Color(0xFF2A303D), height: 16),
              ),
              // Ferramentas & Diagnósticos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 4, bottom: 8),
                      child: Text(
                        'FERRAMENTAS & DIAGNÓSTICO',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    _buildDrawerItem(
                      index: 3,
                      icon: Icons.hub_outlined,
                      activeIcon: Icons.hub,
                      title: 'Rede & Topologia',
                      subtitle: 'Descoberta de nós, IP e status Wi-Fi',
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        leading: const Icon(Icons.history_edu, color: Color(0xFF94A3B8), size: 20),
                        title: const Text(
                          'Trilha de Auditoria & Eventos',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Histórico de operações e diagnósticos',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          AuditLogDialog.show(context, networkManager: widget.networkManager);
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF94A3B8), size: 20),
                        title: const Text(
                          'Gestão de Usuários & Login',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Perfis de operador e credenciais',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          UserSessionDialog.show(
                            context,
                            networkManager: widget.networkManager,
                            onLogout: _handleLogout,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Color(0xFF2A303D), height: 16),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A36),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF353B4A), width: 1.0),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      leading: const Icon(Icons.download_rounded, color: Color(0xFFE2E8F0), size: 20),
                      title: const Text('Exportar Projeto', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Salvar pacote .endap consolidado', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                      onTap: () {
                        Navigator.pop(context);
                        ExportProjectDialog.show(context, project: _project);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.0),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      leading: const Icon(Icons.upload_file_rounded, color: Color(0xFF0284C7), size: 20),
                      title: const Text('Restaurar Pacote .endap', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Importar backup completo da máquina', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                      onTap: () async {
                        Navigator.pop(context);
                        final imported = await importProject();
                        if (imported != null && mounted) {
                          setState(() {
                            _project = imported;
                          });
                          _handleProjectUpdated();
                          await saveCurrentLadder(imported);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF064E3B),
                                content: Text('✓ Pacote "${imported.name}" restaurado com sucesso!'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Color(0xFF2A303D), height: 16),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  leading: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                  title: const Text('Encerrar Sessão', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ListenableBuilder(
                  listenable: widget.networkManager,
                  builder: (context, _) {
                    final state = _connectionState(widget.networkManager);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252A36),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF353B4A), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: state.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: state.color.withValues(alpha: 0.45),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.desc,
                              style: TextStyle(color: state.color, fontSize: 10.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isKioskMode) ...[
              ListenableBuilder(
                listenable: widget.networkManager,
                builder: (context, _) => SizedBox(
                  width: double.infinity,
                  child: IndustrialRibbonBar(
                    plcMode: _plcMode,
                    networkManager: widget.networkManager,
                    activePersona: _currentPersona,
                    onPersonaChanged: _onPersonaChanged,
                    onDeploy: _handleDeploy,
                    onFetch: _handleFetch,
                    onTriggerFailsafe: _handleFailsafe,
                    onOpenDrawer: _openDrawer,
                    isTerminalVisible: _showTerminal,
                    onToggleTerminal: () => setState(() => _showTerminal = !_showTerminal),
                    scanDurationUs: _runtime.lastScanDurationUs,
                  ),
                ),
              ),
            ],
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
            if (!_isKioskMode && _showTerminal)
              IndustrialTerminalDrawer(
                onClose: () => setState(() => _showTerminal = false),
              ),
          ],
        ),
      ),
    );
  }

  ({String label, Color color, IconData icon, String desc}) _connectionState(NetworkManager nm) {
    if (nm.controller.isOnline) {
      return (
        label: 'ONLINE',
        color: const Color(0xFF10B981),
        icon: Icons.cloud_done_outlined,
        desc: 'Controller ${nm.controller.nodeName} • ${nm.gatewayIp}',
      );
    }
    if (nm.isScanning) {
      return (
        label: 'RECONECTANDO',
        color: const Color(0xFFF59E0B),
        icon: Icons.sync_outlined,
        desc: 'Buscando Controller em ${nm.gatewayIp}',
      );
    }
    return (
      label: 'OFFLINE',
      color: const Color(0xFFF43F5E),
      icon: Icons.cloud_off_outlined,
      desc: nm.hasAlternativeControllerIp
          ? 'Conecte-se ao Wi-Fi do controlador • reconexão automática'
          : 'Sem conexão com o Controller',
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF252A36) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.6) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _onSelectDestination(index);
          },
        ),
      ),
    );
  }
}
