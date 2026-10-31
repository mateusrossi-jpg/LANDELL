import 'package:flutter/material.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../services/network_manager.dart';
import '../../services/studio_event_bus.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/runtime/ladder_runtime.dart';
import '../../../ladder/validation/graph_validator.dart';
import '../../../ladder/compiler/bytecode_compiler.dart';
import '../../../ladder/ui/editor/ladder_editor_page.dart';
import '../../../features/gpio_tags/ui/gpio_tags_page.dart';
import '../networks_page.dart';

/// Workspace de Engenharia & Integração (IDE Industrial Completa)
/// Padrão Rockwell Studio 5000 / Schneider EcoStruxure / Siemens TIA Portal
/// Com Controller Organizer na lateral, abas de edição de Lógica/IO/IHM, e console de compilação.
class EngineeringWorkspaceView extends StatefulWidget {
  final LadderProject project;
  final LadderRuntime runtime;
  final NetworkManager networkManager;
  final VoidCallback? onProjectUpdated;
  final VoidCallback? onOpenDrawer;
  final bool isActive;

  const EngineeringWorkspaceView({
    super.key,
    required this.project,
    required this.runtime,
    required this.networkManager,
    this.onProjectUpdated,
    this.onOpenDrawer,
    this.isActive = true,
  });

  @override
  State<EngineeringWorkspaceView> createState() => _EngineeringWorkspaceViewState();
}

class _EngineeringWorkspaceViewState extends State<EngineeringWorkspaceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showProjectTree = true;
  bool _showConsole = true;
  String _selectedTreeItem = 'MainProgram';
  List<String> _consoleLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _runCheckAndCompile(silent: true);
  }

  void _runCheckAndCompile({bool silent = false}) {
    final validator = GraphValidator();
    final valResult = validator.validate(widget.project);
    final compiler = BytecodeCompiler();
    final bytes = compiler.compile(widget.project);
    final scanUs = widget.runtime.lastScanDurationUs;

    setState(() {
      _consoleLogs = [
        '[INFO] Grafo IEC 61131-3: ${widget.project.networks.length} Rung(s), ${widget.project.tags.length} Tag(s). ${valResult.isValid ? "Sintaxe 100% válida e determinística." : "Erros: ${valResult.errors.map((e) => e.message).join(", ")}"}',
        '[INFO] Gerador de Bytecode: ${bytes.length} bytes gerados para a VM do ESP32.',
        scanUs > 0
            ? '[PERF] Ciclo determinístico do Runtime: ${scanUs} µs (${(scanUs / 10.0).toStringAsFixed(1)}% do budget de 1000 µs).'
            : (widget.networkManager.isHardwareOnline && widget.networkManager.kernelExecMaxUs > 0
                ? '[PERF] Kernel ESP32 Telemetria: Exec max ${widget.networkManager.kernelExecMaxUs} µs • Jitter max ${widget.networkManager.kernelJitterMaxUs} µs.'
                : '[PERF] Runtime em repouso determinístico (aguardando I/O ou ciclo).'),
      ];
    });

    if (!silent) {
      StudioEventBus.instance.emit(
        type: 'BUILD_VERIFY',
        source: 'ENGINEERING_WORKSPACE',
        message: 'Lógica validada: ${widget.project.networks.length} Rungs, ${bytes.length} bytes de bytecode gerados.',
        severity: valResult.isValid ? EventSeverity.info : EventSeverity.warning,
      );
    }
  }

  @override
  void didUpdateWidget(covariant EngineeringWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.project != oldWidget.project || widget.runtime != oldWidget.runtime) {
      _runCheckAndCompile(silent: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 850;

    return Container(
      color: IndustrialTokens.bgCanvas,
      child: Column(
        children: [
          // 1. Barra de Ferramentas Secundária de Engenharia (Workbench Toolbar)
          _buildWorkbenchToolbar(),

          // 2. Área Central com Organizer Lateral + Document Editor Multi-Aba
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Painel Esquerdo: Controller Organizer (Árvore de Projeto)
                if (_showProjectTree) ...[
                  SizedBox(
                    width: isSmallScreen ? 180 : 250,
                    child: _buildControllerOrganizer(),
                  ),
                  const VerticalDivider(width: 1, thickness: 1, color: IndustrialTokens.borderSubtle),
                ] else ...[
                  Material(
                    color: IndustrialTokens.bgSurface,
                    child: InkWell(
                      onTap: () => setState(() => _showProjectTree = true),
                      child: Container(
                        width: 28,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: const [
                            Icon(Icons.chevron_right, size: 16, color: IndustrialTokens.telemetryCyan),
                            SizedBox(height: 12),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                'ORGANIZER',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1, color: IndustrialTokens.borderSubtle),
                ],

                // Área Central: Abas de Documentos e Editores
                Expanded(
                  child: Column(
                    children: [
                      // Barra de Abas do Editor
                      _buildEditorTabBar(),

                      // Conteúdo das Abas
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(), // Evita swipe acidental em drag-and-drop
                          children: [
                            // Aba 0: Editor Ladder IEC 61131-3
                            LadderEditorPage(
                              initialProject: widget.project,
                              runtime: widget.runtime,
                              networkManager: widget.networkManager,
                              onOpenDrawer: widget.onOpenDrawer,
                              isActive: widget.isActive && _tabController.index == 0,
                              embedded: true,
                            ),

                            // Aba 1: Mapeamento de Tags e I/O de Hardware
                            GpioTagsPage(
                              networkManager: widget.networkManager,
                              project: widget.project,
                              onProjectUpdated: widget.onProjectUpdated,
                              onOpenDrawer: widget.onOpenDrawer,
                              embedded: true,
                            ),

                            // Aba 2: Topologia & Nós de Rede
                            NetworksPage(
                              networkManager: widget.networkManager,
                              onOpenDrawer: widget.onOpenDrawer,
                              embedded: true,
                            ),
                          ],
                        ),
                      ),

                      // Painel Inferior: Console de Compilação & Determinismo
                      if (_showConsole) ...[
                        const Divider(height: 1, thickness: 1, color: IndustrialTokens.borderSubtle),
                        SizedBox(
                          height: 125,
                          child: _buildCompilationConsole(),
                        ),
                      ] else ...[
                        const Divider(height: 1, thickness: 1, color: IndustrialTokens.borderSubtle),
                        Material(
                          color: IndustrialTokens.bgPanel,
                          child: InkWell(
                            onTap: () => setState(() => _showConsole = true),
                            child: Container(
                              height: 24,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.keyboard_arrow_up, size: 14, color: IndustrialTokens.telemetryCyan),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'CONSOLE DE COMPILAÇÃO',
                                    style: TextStyle(color: IndustrialTokens.telemetryCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _consoleLogs.isNotEmpty ? _consoleLogs.first : 'Console em repouso determinístico',
                                      style: const TextStyle(color: Colors.white38, fontSize: 9.0, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.open_in_full, size: 12, color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Barra de Ferramentas Secundária de Engenharia
  Widget _buildWorkbenchToolbar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: IndustrialTokens.bgPanel,
        border: Border(
          bottom: BorderSide(color: IndustrialTokens.borderSubtle, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Toggle Tree
          IconButton(
            icon: Icon(
              _showProjectTree ? Icons.account_tree : Icons.account_tree_outlined,
              size: 16,
              color: _showProjectTree ? IndustrialTokens.telemetryCyan : Colors.white54,
            ),
            tooltip: _showProjectTree ? 'Ocultar Controller Organizer' : 'Exibir Controller Organizer',
            onPressed: () => setState(() => _showProjectTree = !_showProjectTree),
          ),
          const SizedBox(width: 4),

          // Toggle Console
          IconButton(
            icon: Icon(
              _showConsole ? Icons.terminal : Icons.terminal_outlined,
              size: 16,
              color: _showConsole ? IndustrialTokens.telemetryCyan : Colors.white54,
            ),
            tooltip: _showConsole ? 'Ocultar Console de Compilação' : 'Exibir Console de Compilação',
            onPressed: () => setState(() => _showConsole = !_showConsole),
          ),

          const SizedBox(width: 8),

          // Modo Foco / Maximizar Área do Ladder
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: (!_showProjectTree && !_showConsole) ? IndustrialTokens.telemetryCyan : Colors.white70,
              side: BorderSide(
                color: (!_showProjectTree && !_showConsole) ? IndustrialTokens.telemetryCyan : IndustrialTokens.borderSubtle,
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: Icon(
              (!_showProjectTree && !_showConsole) ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 14,
            ),
            label: Text(
              (!_showProjectTree && !_showConsole) ? 'Restaurar Painéis' : 'Modo Foco (Maximizar Ladder)',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                if (!_showProjectTree && !_showConsole) {
                  _showProjectTree = true;
                  _showConsole = true;
                } else {
                  _showProjectTree = false;
                  _showConsole = false;
                }
              });
            },
          ),

          const SizedBox(width: 8),
          const VerticalDivider(color: IndustrialTokens.borderSubtle, indent: 8, endIndent: 8),
          const SizedBox(width: 8),

          // Botão Verificar Sintaxe & Determinismo
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: IndustrialTokens.runGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('Verificar Lógica', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _runCheckAndCompile(silent: false);
              final validator = GraphValidator();
              final valResult = validator.validate(widget.project);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    valResult.isValid
                        ? '✓ Grafo IEC 61131-3 válido: ${widget.project.networks.length} Rung(s), ${widget.project.tags.length} Tag(s).'
                        : '✕ Erros detectados: ${valResult.errors.map((e) => e.message).join(", ")}',
                  ),
                  backgroundColor: valResult.isValid ? const Color(0xFF064E3B) : const Color(0xFFDC2626),
                ),
              );
            },
          ),

          const SizedBox(width: 6),

          // Botão Compilar Bytecode ENDP
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: IndustrialTokens.infoBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.build_circle_outlined, size: 14),
            label: const Text('Compilar Bytecode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _runCheckAndCompile(silent: false);
              final compiler = BytecodeCompiler();
              final bytes = compiler.compile(widget.project);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ Bytecode compilado: ${bytes.length} bytes gerados para a VM do ESP32.'),
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
              );
            },
          ),

          const SizedBox(width: 24),

          // Indicador de Alvo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: IndustrialTokens.bgCanvas,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: IndustrialTokens.borderSubtle),
            ),
            child: Row(
              children: const [
                Icon(Icons.memory, size: 13, color: Colors.white70),
                SizedBox(width: 6),
                Text(
                  'TARGET: ESP32-WROOM-32 (1ms Deterministic VM)',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // 2. Controller Organizer (Árvore de Projeto Industrial)
  Widget _buildControllerOrganizer() {
    final controllerName = widget.networkManager.controller.nodeName.isNotEmpty
        ? widget.networkManager.controller.nodeName
        : (widget.networkManager.controller.id.isNotEmpty
            ? widget.networkManager.controller.id
            : 'Controlador Principal');

    return Material(
      color: IndustrialTokens.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da Árvore
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: IndustrialTokens.bgPanel,
            child: Row(
              children: [
                const Icon(Icons.account_tree, size: 15, color: IndustrialTokens.telemetryCyan),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CONTROLLER ORGANIZER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: 'Recolher Organizer',
                  child: InkWell(
                    onTap: () => setState(() => _showProjectTree = false),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.chevron_left, size: 16, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista em Árvore Hierárquica
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildTreeGroup(
                  title: 'Controlador [$controllerName]',
                  icon: Icons.developer_board,
                  children: [
                    _buildTreeLeaf(
                      id: 'CyclicTask',
                      title: 'Tasks & Scan (1ms Cíclica)',
                      icon: Icons.schedule,
                      onTap: () => _tabController.animateTo(0),
                    ),
                    _buildTreeLeaf(
                      id: 'ControllerTags',
                      title: 'Controller Tags (Globais)',
                      icon: Icons.list_alt,
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ],
                ),
                _buildTreeGroup(
                  title: 'Lógica & Programas',
                  icon: Icons.code,
                  children: [
                    _buildTreeLeaf(
                      id: 'MainProgram',
                      title: 'MainProgram (Ladder IEC)',
                      icon: Icons.table_rows,
                      badge: '${widget.project.networks.length} Rungs',
                      onTap: () => _tabController.animateTo(0),
                    ),
                    _buildTreeLeaf(
                      id: 'FaultRoutine',
                      title: 'FaultRoutine (Failsafe)',
                      icon: Icons.warning_amber,
                      onTap: () => _tabController.animateTo(0),
                    ),
                  ],
                ),
                _buildTreeGroup(
                  title: 'Hardware & E/S de Campo',
                  icon: Icons.settings_input_component,
                  children: [
                    _buildTreeLeaf(
                      id: 'EmbeddedIO',
                      title: 'E/S Embutidas (GPIOs)',
                      icon: Icons.memory,
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ],
                ),
                _buildTreeGroup(
                  title: 'Cluster & Nós de Campo',
                  icon: Icons.hub,
                  children: [
                    _buildTreeLeaf(
                      id: 'NodesTopology',
                      title: 'Topologia de Rede & Descoberta',
                      icon: Icons.settings_ethernet,
                      iconColor: IndustrialTokens.runGreen,
                      onTap: () => _tabController.animateTo(2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: true,
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(icon, size: 16, color: IndustrialTokens.infoBlue),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildTreeLeaf({
    required String id,
    required String title,
    required IconData icon,
    Color? iconColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedTreeItem == id;
    return Material(
      color: isSelected ? IndustrialTokens.bgHighlight : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedTreeItem = id);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 32, right: 10, top: 5, bottom: 5),
          child: Row(
            children: [
              Icon(icon, size: 13, color: iconColor ?? Colors.white60),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: IndustrialTokens.bgCanvas,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: IndustrialTokens.borderSubtle),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: IndustrialTokens.telemetryCyan, fontSize: 8.5, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 3. Barra de Abas do Editor Central
  Widget _buildEditorTabBar() {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: IndustrialTokens.bgPanel,
        border: Border(
          bottom: BorderSide(color: IndustrialTokens.borderSubtle, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: IndustrialTokens.telemetryCyan,
        indicatorWeight: 2,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: const [
          Tab(
            child: Row(
              children: [
                Icon(Icons.table_rows, size: 14),
                SizedBox(width: 6),
                Text('Lógica Ladder IEC'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 14),
                SizedBox(width: 6),
                Text('Mapeamento de I/O & Tags'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 14),
                SizedBox(width: 6),
                Text('Rede & Topologia de Nós'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Console de Compilação & Determinismo
  Widget _buildCompilationConsole() {
    return Container(
      color: IndustrialTokens.bgPanel,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: IndustrialTokens.telemetryCyan, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BUILD & DETERMINISM CONSOLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'BYTECODE ENDP v1 • DETERMINISTIC VM COMPLIANT',
                  style: TextStyle(color: IndustrialTokens.runGreen, fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Recolher Console',
                child: InkWell(
                  onTap: () => setState(() => _showConsole = false),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IndustrialTokens.bgCanvas,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: IndustrialTokens.borderSubtle),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _consoleLogs.map((log) {
                    final isPerf = log.startsWith('[PERF]');
                    final isBytecode = log.contains('Bytecode');
                    final Color textColor = isPerf
                        ? IndustrialTokens.runGreen
                        : (isBytecode ? IndustrialTokens.infoBlue : Colors.white70);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        log,
                        style: TextStyle(color: textColor, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
