import 'dart:async';
import 'package:flutter/material.dart';

import '../../../ladder_autosave.dart';
import '../../models/ladder_project.dart';
import '../../models/demo_project.dart';
import '../../models/ladder_network.dart';
import '../../models/ladder_node.dart';
import '../../models/node_config.dart';
import '../../models/tag.dart';
import '../../models/tag_value.dart';
import '../../models/enums.dart';
import '../../validation/graph_validator.dart';
import '../../validation/executable_graph.dart';
import 'file_helper.dart';
import '../../runtime/ladder_runtime.dart';
import '../../runtime/node_runtime_state.dart';
import '../../runtime/evaluators/timer_evaluator.dart';
import 'firmware_sync_service.dart';
import 'telemetry_sync_service.dart';
import 'widgets/variables_panel.dart';
import 'widgets/rung_list.dart';
import 'widgets/ladder_toolbox.dart';
import 'widgets/industrial_tag_browser_dialog.dart';
import 'widgets/pid_config_dialog.dart';
import '../../../design_system/tokens.dart';
import '../../../../core/services/network_manager.dart';
import '../../../core/services/hardware_force_bridge.dart';
import '../../../features/gpio_tags/services/gpio_service.dart';

enum EditorMode { editor, simulateLocal, simulateHardware }

class LadderEditorPage extends StatefulWidget {
  final LadderProject? initialProject;
  final VoidCallback? onOpenDrawer;
  final LadderRuntime? runtime;
  final bool isActive;
  final NetworkManager? networkManager;
  final bool embedded;

  const LadderEditorPage({
    super.key,
    this.initialProject,
    this.onOpenDrawer,
    this.runtime,
    this.isActive = true,
    this.networkManager,
    this.embedded = false,
  });

  @override
  State<LadderEditorPage> createState() => _LadderEditorPageState();
}

class _LadderEditorPageState extends State<LadderEditorPage> {
  int? _selectedRungIndex;
  int? _selectedNodeIndex;

  late LadderProject _project;
  bool _initialized = false;
  bool _isDraggingNode = false;
  late final LadderRuntime _runtime;

  EditorMode _mode = EditorMode.simulateLocal;
  final Map<String, bool> _simulationInputs = {};
  final Map<String, String?> _networkValidationErrors = {};

  String _selectedControllerFilter = 'ALL';
  bool _filterOnlyDisabled = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  bool _showToolbox = true;

  Timer? _simulationTimer;
  final int _scanPeriodMs = 100;

  bool _simulationPulseMode = false;

  bool _isOutputTag(String tagId) {
    final clean = tagId.trim().toUpperCase();
    if (clean.startsWith('Q') || clean.startsWith('Y') || clean.startsWith('AO') || clean.startsWith('QW')) {
      return true;
    }
    final tagObj = _project.tags[tagId];
    final addr = tagObj?.address?.trim().toUpperCase();
    if (addr != null && (addr.startsWith('Q') || addr.startsWith('Y') || addr.startsWith('AO') || addr.startsWith('QW'))) {
      return true;
    }
    // Qualquer tag que seja acionada por uma bobina ou bloco funcional no projeto é controlada pelo runtime
    for (final net in _project.networks) {
      for (final n in net.nodes) {
        if ((n.type == NodeType.coil || n.type == NodeType.coilSet || n.type == NodeType.coilReset ||
             n.type == NodeType.timerTON || n.type == NodeType.timerTOF ||
             n.type == NodeType.counterCTU || n.type == NodeType.counterCTD ||
             n.type == NodeType.pid) &&
            n.config.tagId == tagId) {
          return true;
        }
      }
    }
    return false;
  }

  void _syncOutputs() {
    for (final k in _simulationInputs.keys.toList()) {
      if (_isOutputTag(k)) {
        _simulationInputs[k] = _runtime.tagStore.getBool(k);
      }
    }
  }

  String _resolveGatewayIpSync() {
    final nm = widget.networkManager;
    if (nm != null && nm.controller.isOnline && nm.controller.ip.trim().isNotEmpty && nm.controller.ip.trim() != '192.168.4.1' && nm.controller.ip.trim() != '192.168.0.27') {
      return nm.controller.ip.trim();
    }
    if (nm != null && nm.gatewayIp.trim().isNotEmpty && nm.gatewayIp.trim() != '192.168.4.1' && nm.gatewayIp.trim() != '192.168.0.27') {
      return nm.gatewayIp.trim();
    }
    return '192.168.0.229';
  }

  Future<String> _resolveGatewayIp() async {
    final syncIp = _resolveGatewayIpSync();
    if (syncIp != '192.168.4.1' && syncIp != '192.168.0.27') return syncIp;
    try {
      final saved = await FirmwareSyncService.getSavedGatewayIp();
      if (saved.isNotEmpty && saved != '192.168.4.1' && saved != '192.168.0.27') return saved;
    } catch (_) {}
    return '192.168.0.229';
  }

  @override
  void initState() {
    super.initState();
    _runtime = widget.runtime ?? LadderRuntime();
    if (widget.embedded || widget.networkManager != null) {
      _mode = EditorMode.simulateHardware;
    }
    TelemetrySyncService.instance.injectEnabled = _mode == EditorMode.simulateHardware;
    final initialIp = _resolveGatewayIpSync();
    TelemetrySyncService.instance.init(
      project: widget.initialProject ?? LadderProject.blank(),
      runtime: _runtime,
      gatewayIp: initialIp,
    );
    TelemetrySyncService.instance.addListener(_onTelemetryUpdated);
    if (_mode == EditorMode.simulateHardware && !TelemetrySyncService.instance.isPolling) {
      TelemetrySyncService.instance.start();
    }
    if (widget.initialProject != null) {
      _project = widget.initialProject!;
      _initialized = true;
      for (var tag in _project.tags.values) {
        if (tag.type == TagType.bool) {
          _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
        }
      }
      _runPassiveValidation();
      _updateRuntimeProject();
      if (_mode != EditorMode.editor && widget.isActive) {
        _startTimedSimulation();
      }
    } else {
      _project = LadderProject.blank();
      _loadProject();
    }
  }

  void _onTelemetryUpdated() {
    if (!mounted || _mode != EditorMode.simulateHardware) return;
    _syncOutputs();
    _syncNodeEnergization();
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant LadderEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProject != null && widget.initialProject != oldWidget.initialProject) {
      _project = widget.initialProject!;
      _updateRuntimeProject();
      _syncNodeEnergization();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _updateRuntimeProject();
        _syncNodeEnergization();
        if (_mode != EditorMode.editor) {
          _startTimedSimulation();
        }
        if (_mode == EditorMode.simulateHardware && !TelemetrySyncService.instance.isPolling) {
          TelemetrySyncService.instance.start();
        }
      } else if (!widget.isActive) {
        _simulationTimer?.cancel();
        _simulationTimer = null;
        TelemetrySyncService.instance.stop();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _simulationTimer?.cancel();
    TelemetrySyncService.instance.removeListener(_onTelemetryUpdated);
    TelemetrySyncService.instance.stop();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final loaded = await loadCurrentLadder();
    final proj = loaded ?? LadderProject.blank();
    if (mounted) {
      setState(() {
        _project = proj;
        _initialized = true;
        for (var tag in _project.tags.values) {
          if (tag.type == TagType.bool) {
            _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
          }
        }
        _runPassiveValidation();
        _updateRuntimeProject();
        if (_mode == EditorMode.simulateHardware) {
          TelemetrySyncService.instance.injectEnabled = true;
          TelemetrySyncService.instance.init(
            project: _project,
            runtime: _runtime,
            gatewayIp: _resolveGatewayIpSync(),
          );
          if (!TelemetrySyncService.instance.isPolling) {
            TelemetrySyncService.instance.start();
          }
        }
        if (_mode != EditorMode.editor && widget.isActive) {
          _startTimedSimulation();
        }
      });
    }
  }

  Future<void> _saveProject() async {
    await saveCurrentLadder(_project);
    _runPassiveValidation();
    _updateRuntimeProject();
  }

  void _updateRuntimeProject() {
    final validator = GraphValidator();
    final validNetworks = <LadderNetwork>[];
    for (final network in _project.networks) {
      final result = validator.validate(LadderProject(
        id: 'temp',
        name: 'temp',
        networks: [network],
        tags: _project.tags,
      ));
      if (result.isValid && result.executableGraph != null) {
        validNetworks.add(network);
      }
    }
    final runtimeProject = LadderProject(
      id: _project.id,
      name: _project.name,
      tags: _project.tags,
      networks: validNetworks,
    );
    _runtime.loadProject(ExecutableGraph.validated(runtimeProject));
    TelemetrySyncService.instance.init(
      project: _project,
      runtime: _runtime,
    );
  }

  void _runPassiveValidation() {
    _networkValidationErrors.clear();
    final validator = GraphValidator();
    final result = validator.validate(_project);
    if (!result.isValid) {
      for (int i = 0; i < _project.networks.length; i++) {
        final network = _project.networks[i];
        final validationResult = validator.validate(LadderProject(
          id: 'temp',
          name: 'temp',
          networks: [network],
          tags: _project.tags,
        ));
        if (!validationResult.isValid && validationResult.errors.isNotEmpty) {
          _networkValidationErrors[network.id] = validationResult.errors.first.message;
        }
      }
    }
  }

  void _startTimedSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(Duration(milliseconds: _scanPeriodMs), (timer) {
      if (!mounted) return;
      _executeSimulationTick();
    });
  }

  void _applyMode(EditorMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    TelemetrySyncService.instance.injectEnabled = mode == EditorMode.simulateHardware;

    if (mode == EditorMode.editor) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      _releaseAllSimulationForces();
      _clearNodeEnergization();
      TelemetrySyncService.instance.stop();
      return;
    }

    _updateRuntimeProject();

    if (mode == EditorMode.simulateHardware) {
      final ip = _resolveGatewayIpSync();
      TelemetrySyncService.instance.init(
        project: _project,
        runtime: _runtime,
        gatewayIp: ip,
      );
      if (TelemetrySyncService.instance.isPolling == false) {
        TelemetrySyncService.instance.start();
      }
    } else {
      TelemetrySyncService.instance.stop();
    }
    if (_simulationTimer == null && widget.isActive) {
      _startTimedSimulation();
    }
  }

  Future<void> _fetchFromEsp32() async {
    final networkGwIp = widget.networkManager?.controller.ip.trim().isNotEmpty == true
        ? widget.networkManager!.controller.ip.trim()
        : (widget.networkManager?.gatewayIp.trim() ?? '');
    final gatewayIp = networkGwIp.isNotEmpty
        ? networkGwIp
        : await FirmwareSyncService.getSavedGatewayIp();
    final syncService = FirmwareSyncService();
    final fetchedProject = await syncService.fetchRules(gatewayIp);
    if (fetchedProject != null && mounted) {
      setState(() {
        _project = fetchedProject;
        _simulationInputs.clear();
        for (var tag in _project.tags.values) {
          if (tag.type == TagType.bool) {
            _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
          }
        }
        _saveProject();
      });
      _applyMode(EditorMode.simulateHardware);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3FBF5A),
          content: Text(
            'Lógica recuperada do ESP32 ($gatewayIp) com ${fetchedProject.networks.length} rungs!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD9503F),
          content: Text(
            'Nenhuma lógica válida recuperada do ESP32 ($gatewayIp)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Future<void> _handleClearEsp32Ladder() async {
    final networkGwIp = widget.networkManager?.controller.ip.trim().isNotEmpty == true
        ? widget.networkManager!.controller.ip.trim()
        : (widget.networkManager?.gatewayIp.trim() ?? '');
    final gatewayIp = networkGwIp.isNotEmpty
        ? networkGwIp
        : await FirmwareSyncService.getSavedGatewayIp();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTokens.line),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 20),
            SizedBox(width: 8),
            Text('Limpar Lógica do CLP?', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja apagar o programa Ladder gravado no CLP ($gatewayIp)?\n\n'
          'Isso liberará todas as saídas físicas (Q0.0, Q0.1, ...) para comissionamento e testes manuais sem sobreposição de varredura.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar CLP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final syncService = FirmwareSyncService();
    final ok = await syncService.clearRules(gatewayIp);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
        content: Text(
          ok
              ? '✓ Lógica Ladder removida do CLP com sucesso. Todas as saídas estão livres!'
              : 'Falha ao limpar lógica no CLP ($gatewayIp).',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _releaseAllSimulationForces() {
    _runtime.tagStore.releaseAllForces();
  }

  void _clearNodeEnergization() {
    void clearNode(LadderNode node) {
      node.isEnergized = false;
      node.isConducting = false;
      if (node.type == NodeType.parallel && node.branches != null) {
        for (final branch in node.branches!) {
          for (final child in branch) {
            clearNode(child);
          }
        }
      }
    }

    for (final network in _project.networks) {
      for (final node in network.nodes) {
        clearNode(node);
      }
    }
    if (mounted) setState(() {});
  }

  void _executeSimulationTick() {
    switch (_mode) {
      case EditorMode.editor:
        return;
      case EditorMode.simulateLocal:
        _runtime.singleScan(_scanPeriodMs);
        _syncOutputs();
        _syncNodeEnergization();
        if (mounted) {
          setState(() {});
        }
        break;
      case EditorMode.simulateHardware:
        // No modo hardware real, as tags I/Q/M/AI são mantidas pela telemetria do MCU via TelemetrySyncService.
        // Executa varredura de ciclo determinístico para propagar fluxo de potência e calcular temporizadores (TON/TOF) em tempo real
        _runtime.singleScan(_scanPeriodMs);
        _syncOutputs();
        _syncNodeEnergization();
        if (mounted) {
          setState(() {});
        }
        break;
    }
  }

  void _syncNodeEnergization() {
    bool hasChanged = false;

    void syncSingleNode(LadderNode node, {NodeRuntimeState? customState}) {
      final state = customState ?? _runtime.nodeStates[node.id];
      bool newEnergized = false;
      bool newConducting = false;
      if (state != null) {
        if (node.type == NodeType.timerTON || node.type == NodeType.timerTOF) {
          final tTag = node.config.tagId ?? '';
          final storeDn = _runtime.tagStore.getBool('$tTag.DN') ||
              _runtime.tagStore.getBool(tTag) ||
              _runtime.tagStore.getBool('$tTag.Q');
          final storeEn = _runtime.tagStore.getBool('$tTag.EN') ||
              _runtime.tagStore.getBool('$tTag.IN');
          final storeTt = _runtime.tagStore.getBool('$tTag.TT');
          newEnergized = state.runtimeFlags['EN'] == true ||
              state.runtimeFlags['TT'] == true ||
              state.energized ||
              storeEn ||
              storeTt ||
              storeDn;
          newConducting = state.runtimeFlags['DN'] == true || storeDn;
        } else if (node.type == NodeType.counterCTU || node.type == NodeType.counterCTD) {
          final cTag = node.config.tagId ?? '';
          final storeDn = _runtime.tagStore.getBool('$cTag.DN') || _runtime.tagStore.getBool(cTag);
          newEnergized = state.runtimeFlags['CU'] == true || state.runtimeFlags['CD'] == true || state.energized;
          newConducting = state.runtimeFlags['DN'] == true || storeDn;
        } else if (node.type == NodeType.pid) {
          newEnergized = state.runtimeFlags['EN'] == true || state.energized;
          newConducting = state.runtimeFlags['DN'] ?? state.energized;
        } else {
          newEnergized = state.energized;
          newConducting = state.energized;
        }
      } else {
        // Fallback: child.isEnergized is already evaluated by ParallelEvaluator / ScanEngine
        newEnergized = node.isEnergized;
        newConducting = node.isConducting;
      }

      if (node.isEnergized != newEnergized || node.isConducting != newConducting) {
        node.isEnergized = newEnergized;
        node.isConducting = newConducting;
        hasChanged = true;
      }

      if (node.type == NodeType.parallel && node.branches != null) {
        final parState = state ?? _runtime.nodeStates[node.id];
        for (int b = 0; b < node.branches!.length; b++) {
          final branch = node.branches![b];
          for (final child in branch) {
            NodeRuntimeState? childState;
            if (parState != null) {
              childState = parState.subNodeStates['${node.id}_b${b}_${child.id}'];
            }
            syncSingleNode(child, customState: childState);
          }
        }
      }
    }

    for (final network in _project.networks) {
      for (final node in network.nodes) {
        syncSingleNode(node);
      }
    }

    if (hasChanged && mounted) {
      setState(() {});
    }
  }

  void _toggleSimulationTag(String tagId) {
    if (_mode == EditorMode.editor) return;
    final isOutput = _isOutputTag(tagId);
    if (_mode == EditorMode.simulateLocal && isOutput) {
      return; // Em simulação puramente local, saídas normais são controladas pelo scan
    }

    final isPushbutton = tagId.contains('BTN') || tagId.contains('START') || tagId.contains('PULSE') || tagId.contains('MOMENTARY');

    if (_mode == EditorMode.simulateLocal && _simulationPulseMode && isPushbutton) {
      // Se a entrada já estiver ligada, um clique desliga imediatamente
      final current = _simulationInputs[tagId] ?? _runtime.tagStore.getBool(tagId);
      if (current) {
        setState(() {
          _simulationInputs[tagId] = false;
          _runtime.tagStore.setBool(tagId, false);
          _runtime.singleScan(0);
          _syncOutputs();
          _syncNodeEnergization();
        });
        return;
      }

      // MODO BOTÃO DE PULSO (MOMENTARY PUSHBUTTON):
      // Injeta nível alto, executa varredura e agenda abertura automática da entrada (400ms)
      setState(() {
        _simulationInputs[tagId] = true;
        _runtime.tagStore.setBool(tagId, true);
        _runtime.singleScan(0);
        _syncOutputs();
        _syncNodeEnergization();
      });

      Timer(const Duration(milliseconds: 400), () {
        if (!mounted || _mode != EditorMode.simulateLocal) return;
        setState(() {
          _simulationInputs[tagId] = false;
          _runtime.tagStore.setBool(tagId, false);
          _runtime.singleScan(0);
          _syncOutputs();
          _syncNodeEnergization();
        });
      });
      return;
    }

    // MODO CHAVE RETENTIVA (TOGGLE SWITCH) ou ATUAÇÃO HARDWARE:
    final current = (_mode == EditorMode.simulateHardware)
        ? _runtime.tagStore.getBool(tagId)
        : (_simulationInputs[tagId] ?? _runtime.tagStore.getBool(tagId));
    final nextVal = !current;
    setState(() {
      _simulationInputs[tagId] = nextVal;
      _runtime.tagStore.setBool(tagId, nextVal);
      final tagObj = _project.tags[tagId];
      if (tagObj?.address != null && tagObj!.address!.isNotEmpty) {
        _runtime.tagStore.setBool(tagObj.address!, nextVal);
      }
      _runtime.singleScan(0);
      if (_mode == EditorMode.simulateLocal) {
        _syncOutputs();
      }
      _syncNodeEnergization();
    });

    if (_mode == EditorMode.simulateHardware) {
      _dispatchHardwareActuation(tagId, nextVal);
    }
  }

  Future<void> _dispatchHardwareActuation(String tagId, bool value) async {
    final tagObj = _project.tags[tagId];
    final addr = tagObj?.address ?? tagId;
    final chId = HardwareForceBridge.channelIdFor(addr);
    final gatewayIp = await _resolveGatewayIp();

    if (gatewayIp.isNotEmpty && chId != null) {
      try {
        if (addr.startsWith('Q') || addr.startsWith('Y')) {
          await GpioService.instance.setOutput(gatewayIp, chId, value ? 1 : 0);
          await GpioService.instance.postForce(gatewayIp, {'action': 'set', 'id': chId, 'value': value ? 1 : 0});
        } else {
          await GpioService.instance.postForce(gatewayIp, {'action': 'set', 'id': chId, 'value': value ? 1 : 0});
        }
      } catch (e) {
        debugPrint('Erro ao despachar comando para o hardware: $e');
      }
    }
  }

  void _resetSimulation() {
    setState(() {
      _simulationInputs.clear();
      for (var tag in _project.tags.values) {
        _simulationInputs[tag.id] = false;
        _runtime.tagStore.setBool(tag.id, false);
        _runtime.tagStore.setInt(tag.id, 0);
        _runtime.tagStore.setReal(tag.id, 0.0);
        _runtime.tagStore.setBool('${tag.id}.DN', false);
        _runtime.tagStore.setBool('${tag.id}.Q', false);
        _runtime.tagStore.setBool('${tag.id}.EN', false);
        _runtime.tagStore.setBool('${tag.id}.IN', false);
        _runtime.tagStore.setBool('${tag.id}.TT', false);
        _runtime.tagStore.setInt('${tag.id}.ACC', 0);
        _runtime.tagStore.setInt('${tag.id}.ET', 0);
        _runtime.tagStore.setBool('${tag.id}.CU', false);
        _runtime.tagStore.setBool('${tag.id}.CD', false);
        _runtime.tagStore.setInt('${tag.id}.CV', 0);
      }
      _runtime.tagStore.releaseAllForces();
      for (var state in _runtime.nodeStates.values) {
        state.accumulatedTimeMs = 0;
        state.counterValue = 0;
        state.energized = false;
        state.runtimeFlags.clear();
      }
      _clearNodeEnergization();
      _runtime.singleScan(0);
      _syncOutputs();
      _syncNodeEnergization();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF263238),
          duration: Duration(seconds: 2),
          content: Row(
            children: [
              Icon(Icons.restart_alt, color: Color(0xFF4FD1C5), size: 18),
              SizedBox(width: 8),
              Text(
                'Simulação reiniciada: todas as entradas abertas, saídas apagadas e acumuladores zerados.',
                style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildComponentSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 16, right: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF38BDF8),
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ),
    );
  }

  LadderNode _createConfiguredNode(NodeType type) {
    final isTimer = type == NodeType.timerTON || type == NodeType.timerTOF;
    final isCounter = type == NodeType.counterCTU || type == NodeType.counterCTD;
    final isCompare = type == NodeType.compareEqual || type == NodeType.compareGreater || type == NodeType.compareLess;
    final isMath = type == NodeType.mathADD || type == NodeType.mathSUB || type == NodeType.mathMUL || type == NodeType.mathDIV;
    String? defaultTag;

    if (isTimer) {
      for (int t = 0; t <= 15; t++) {
        final candidate = 'T$t';
        final used = _project.networks.any((net) => net.nodes.any((n) => n.config.tagId == candidate));
        if (!used) {
          defaultTag = candidate;
          break;
        }
      }
    } else if (isCounter) {
      for (int c = 0; c <= 15; c++) {
        final candidate = 'C$c';
        final used = _project.networks.any((net) => net.nodes.any((n) => n.config.tagId == candidate));
        if (!used) {
          defaultTag = candidate;
          break;
        }
      }
    } else if (type == NodeType.pid || isCompare || isMath) {
      defaultTag = 'AI0.0';
    }

    if (defaultTag != null && !_project.tags.containsKey(defaultTag)) {
      _project.tags[defaultTag] = Tag(
        id: defaultTag,
        name: defaultTag,
        type: isTimer
            ? TagType.timer
            : (isCounter ? TagType.counter : TagType.real),
        initialValue: isTimer
            ? TagValue.integer(3000)
            : (isCounter ? TagValue.integer(5) : TagValue.real(0.0)),
      );
    }

    if (type == NodeType.pid) {
      if (!_project.tags.containsKey('SP_PID')) {
        _project.tags['SP_PID'] = Tag(
          id: 'SP_PID',
          name: 'SP_PID',
          type: TagType.real,
          address: 'M0.4',
          description: 'Setpoint de Umidade Desejada do Controlador PID (0 a 100%)',
          unit: '%',
          initialValue: TagValue.real(50.0),
        );
      }
      if (!_project.tags.containsKey('MV_PID')) {
        _project.tags['MV_PID'] = Tag(
          id: 'MV_PID',
          name: 'MV_PID',
          type: TagType.real,
          address: 'M0.7',
          description: 'Saída de Controle Calculada pelo Bloco PID (0 a 100%)',
          unit: '%',
          initialValue: TagValue.real(0.0),
        );
      }
    }

    final ts = DateTime.now().microsecondsSinceEpoch;
    if (type == NodeType.parallel) {
      return LadderNode(
        id: 'node_${ts}_par',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [
            LadderNode(
              id: 'node_${ts}_b0',
              type: NodeType.contactNO,
              config: NodeConfig(tagId: 'I0.0'),
            ),
          ],
          [
            LadderNode(
              id: 'node_${ts}_b1',
              type: NodeType.contactNO,
              config: NodeConfig(tagId: 'I0.1'),
            ),
          ],
        ],
      );
    }

    if (type == NodeType.pid) {
      return LadderNode(id: 'node_$ts', type: type, config: NodeConfig.pid());
    }

    return LadderNode(
      id: 'node_$ts',
      type: type,
      config: NodeConfig(
        tagId: defaultTag,
        presetValue: isTimer
            ? TagValue.integer(3000)
            : (isCounter
                ? TagValue.integer(5)
                : (isCompare
                    ? TagValue.integer(50)
                    : (isMath ? TagValue.integer(1) : null))),
        outputTagId: isMath ? 'M0.6' : null,
      ),
    );
  }

  void _showComponentBottomSheet(int rungIndex, [int? insertIndex]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.panel,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTokens.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Adicionar Componente IEC 61131-3',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFE7EBF0)),
                  ),
                  const SizedBox(height: 8),
                  _buildComponentSectionHeader('1. Contatos & Ramificação'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Contato Aberto (NO)', NodeType.contactNO, Icons.power_input),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Contato Fechado (NC)', NodeType.contactNC, Icons.do_not_disturb_on),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Ramo Paralelo (OR / Selo)', NodeType.parallel, Icons.call_split),
                  _buildComponentSectionHeader('2. Bobinas de Saída'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Bobina de Saída (COIL)', NodeType.coil, Icons.radio_button_checked),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Bobina de SET (Retenção / Latch)', NodeType.coilSet, Icons.subdirectory_arrow_right),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Bobina de RESET (Desliga Retenção)', NodeType.coilReset, Icons.settings_backup_restore),
                  _buildComponentSectionHeader('3. Controle de Processo (Malha Fechada)'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Controlador Proporcional-Integral-Derivativo (PID)', NodeType.pid, Icons.tune),
                  _buildComponentSectionHeader('4. Temporizadores & Contadores'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Temporizador no Acionamento (TON)', NodeType.timerTON, Icons.timer),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Temporizador no Desligamento (TOF)', NodeType.timerTOF, Icons.timer_off_outlined),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Contador Crescente (CTU)', NodeType.counterCTU, Icons.plus_one),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Contador Decrescente (CTD)', NodeType.counterCTD, Icons.exposure_neg_1),
                  _buildComponentSectionHeader('5. Comparadores Analógicos'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Igual a (EQU ==)', NodeType.compareEqual, Icons.compare_arrows),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Maior que (GRT >)', NodeType.compareGreater, Icons.arrow_upward),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Menor que (LES <)', NodeType.compareLess, Icons.arrow_downward),
                  _buildComponentSectionHeader('6. Blocos Matemáticos'),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Soma Aritmética (ADD +)', NodeType.mathADD, Icons.add_box_outlined),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Subtração Aritmética (SUB -)', NodeType.mathSUB, Icons.indeterminate_check_box_outlined),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Multiplicação Aritmética (MUL *)', NodeType.mathMUL, Icons.close),
                  _buildComponentMenuOption(rungIndex, insertIndex, 'Divisão Aritmética (DIV /)', NodeType.mathDIV, Icons.percent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComponentMenuOption(int rungIndex, int? insertIndex, String title, NodeType type, IconData icon) {
    final tempNode = LadderNode(
      id: 'temp',
      type: type,
      config: NodeConfig(),
    );
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF4FD1C5), size: 20),
      title: Text(title, style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 13.5)),
      trailing: Text(
        tempNode.symbol,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF3FBF5A),
          fontWeight: FontWeight.bold,
          fontFamily: 'JetBrains Mono',
        ),
      ),
      onTap: () {
        setState(() {
          final newNode = _createConfiguredNode(type);
          if (insertIndex != null) {
            _project.networks[rungIndex].insertNode(newNode, insertIndex);
          } else {
            _project.networks[rungIndex].addNode(newNode);
          }
          _project.networks[rungIndex].rebuildConnections();
          _saveProject();
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _showPidDialog(int rungIndex, int nodeIndex) async {
    final node = _project.networks[rungIndex].nodes[nodeIndex];
    final updated = await PidConfigDialog.show(
      context,
      initial: node.config,
      tags: _project.tags,
    );
    if (updated == null || !mounted) return;
    setState(() {
      ensurePidTags(_project.tags, updated);
      node.config = updated;
      _selectedRungIndex = null;
      _selectedNodeIndex = null;
      _saveProject();
    });
  }

  void _showEditNodeBottomSheet(int rungIndex, int nodeIndex) {
    final node = _project.networks[rungIndex].nodes[nodeIndex];
    if (node.type == NodeType.pid) {
      _showPidDialog(rungIndex, nodeIndex);
      return;
    }
    final initialTag = (node.config.tagId != null && node.config.tagId!.trim().isNotEmpty)
        ? node.config.tagId!
        : (node.type == NodeType.pid ? 'AI0.0' : '');
    final tagController = TextEditingController(text: initialTag);

    String initialPresetText = '';
    final presetVal = node.config.presetValue;
    if (presetVal != null) {
      if (presetVal.stringValue != null) {
        initialPresetText = presetVal.stringValue!;
      } else if (presetVal.intValue != null) {
        initialPresetText = presetVal.intValue.toString();
      } else if (presetVal.realValue != null) {
        initialPresetText = presetVal.realValue.toString();
      } else if (presetVal.boolValue != null) {
        initialPresetText = presetVal.boolValue.toString();
      }
    }

    final presetController = TextEditingController(text: initialPresetText);
    final tagBController = TextEditingController();
    final mathDestController = TextEditingController(text: node.config.outputTagId ?? 'M0.6');

    if (node.type == NodeType.compareEqual ||
        node.type == NodeType.compareGreater ||
        node.type == NodeType.compareLess ||
        node.type == NodeType.mathADD ||
        node.type == NodeType.mathSUB ||
        node.type == NodeType.mathMUL ||
        node.type == NodeType.mathDIV) {
      if (presetVal != null) {
        if (presetVal.stringValue != null && _project.tags.containsKey(presetVal.stringValue!)) {
          tagBController.text = presetVal.stringValue!;
          presetController.text = '';
        } else if (presetVal.stringValue != null) {
          presetController.text = presetVal.stringValue!;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final isCompare = node.type == NodeType.compareEqual ||
                    node.type == NodeType.compareGreater ||
                    node.type == NodeType.compareLess;
                final isMath = node.type == NodeType.mathADD ||
                    node.type == NodeType.mathSUB ||
                    node.type == NodeType.mathMUL ||
                    node.type == NodeType.mathDIV;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Propriedades do elemento',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFE7EBF0)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tipo: ${node.type.name}',
                        style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      // Seletor Industrial de Tag (Operando A / Tag Principal)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tagController,
                              style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13),
                              decoration: InputDecoration(
                                labelText: (isCompare || isMath)
                                    ? 'Operando A (Entrada Analógica — ex: AI0.0 ou AI0.1)'
                                    : (node.type == NodeType.pid
                                        ? '1. Entrada Analógica do Sensor — PV (Ex: AI0.0 ou AI0.1)'
                                        : 'Tag IEC / Endereço (ex: I0.0, Q0.0)'),
                                labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.table_chart_outlined, size: 16),
                            label: const Text('Selecionar Tag'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final selected = await IndustrialTagBrowserDialog.show(
                                context,
                                tags: _project.tags,
                                initialSelectedTagId: tagController.text.isNotEmpty ? tagController.text : null,
                                title: (isCompare || isMath)
                                    ? 'Selecione Tag para Operando A'
                                    : (node.type == NodeType.pid ? 'Selecione a Tag do Sensor (PV)' : 'Seletor de Tags do Controlador'),
                              );
                              if (selected != null) {
                                setModalState(() {
                                  tagController.text = selected;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (node.type == NodeType.timerTON ||
                          node.type == NodeType.timerTOF ||
                          node.type == NodeType.counterCTU ||
                          node.type == NodeType.counterCTD) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: presetController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono'),
                          decoration: InputDecoration(
                            labelText: (node.type == NodeType.timerTON || node.type == NodeType.timerTOF)
                                ? 'Tempo limite Preset PT (ms)'
                                : 'Limite de contagem Preset PV',
                            labelStyle: const TextStyle(color: Color(0xFF8C98A8)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                          ),
                        ),
                      ],
                      if (isCompare || isMath) ...[
                        const SizedBox(height: 16),
                        // Operando B com Seletor Industrial de Tag e indicador de %
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tagBController.text.isNotEmpty ? tagBController : presetController,
                                style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: tagBController.text.isNotEmpty
                                      ? 'Operando B (Tag vinculada)'
                                      : (isCompare
                                          ? 'Operando B (Valor em % — ex: 40 para 40%)'
                                          : 'Operando B (Constante numérica ou Tag)'),
                                  suffixText: (isCompare && tagBController.text.isEmpty) ? '%' : null,
                                  suffixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                                  labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                                ),
                                onChanged: (val) {
                                  if (tagBController.text.isEmpty) {
                                    presetController.text = val;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.table_chart_outlined, size: 16),
                              label: const Text('Tag Operando B'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: const Color(0xFF38BDF8),
                                side: const BorderSide(color: Color(0xFF334155)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                final selected = await IndustrialTagBrowserDialog.show(
                                  context,
                                  tags: _project.tags,
                                  initialSelectedTagId: tagBController.text.isNotEmpty ? tagBController.text : null,
                                  title: 'Selecione Tag para Operando B',
                                );
                                if (selected != null) {
                                  setModalState(() {
                                    tagBController.text = selected;
                                    presetController.text = '';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                      if (isMath) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: mathDestController,
                          style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Tag de Destino do Resultado (OUT — ex: M0.6)',
                            labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.focus,
                          foregroundColor: AppTokens.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            final String rawTagId = tagController.text.trim().toUpperCase();
                            final tag = rawTagId.isNotEmpty ? rawTagId : null;

                            if (tag != null && !_project.tags.containsKey(tag)) {
                              final TagType tType;
                              final TagValue initVal;
                              if (isMath) {
                                tType = TagType.real;
                                initVal = TagValue.real(0.0);
                              } else if (node.type == NodeType.timerTON || node.type == NodeType.timerTOF) {
                                tType = TagType.timer;
                                initVal = TagValue.integer(TimerEvaluator.parsePreset(presetController.text));
                              } else if (node.type == NodeType.counterCTU || node.type == NodeType.counterCTD) {
                                tType = TagType.counter;
                                initVal = TagValue.integer(int.tryParse(presetController.text) ?? 5);
                              } else {
                                tType = TagType.bool;
                                initVal = TagValue.boolean(false);
                              }

                              _project.tags[tag] = Tag(
                                id: tag,
                                name: tag,
                                type: tType,
                                initialValue: initVal,
                              );
                              if (tType == TagType.bool && !_simulationInputs.containsKey(tag)) {
                                _simulationInputs[tag] = false;
                              }
                            }

                            TagValue? presetVal;
                            if (node.type == NodeType.timerTON ||
                                node.type == NodeType.timerTOF ||
                                node.type == NodeType.counterCTU ||
                                node.type == NodeType.counterCTD) {
                              final text = presetController.text.trim();
                              final isTimer = node.type == NodeType.timerTON || node.type == NodeType.timerTOF;
                              final val = isTimer
                                  ? TimerEvaluator.parsePreset(text)
                                  : (int.tryParse(text) ?? 5);
                              presetVal = TagValue.integer(val);
                            } else if (isCompare || isMath) {
                              final targetB = tagBController.text.trim().toUpperCase();
                              if (targetB.isNotEmpty) {
                                presetVal = TagValue.string(targetB);
                              } else {
                                final cleanPreset = presetController.text.replaceAll('%', '').trim();
                                final dVal = double.tryParse(cleanPreset);
                                final iVal = int.tryParse(cleanPreset);
                                if (dVal != null && cleanPreset.contains('.')) {
                                  presetVal = TagValue.real(dVal);
                                } else if (iVal != null) {
                                  presetVal = TagValue.integer(iVal);
                                } else if (cleanPreset.isNotEmpty) {
                                  presetVal = TagValue.string(cleanPreset);
                                }
                              }
                            }
                            node.config = NodeConfig(
                              tagId: tag,
                              presetValue: presetVal,
                              outputTagId: isMath ? mathDestController.text.trim().toUpperCase() : null,
                            );
                            _selectedRungIndex = null;
                            _selectedNodeIndex = null;
                            _saveProject();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Salvar alterações', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showNodeOptionsBottomSheet(int rungIndex, int nodeIndex) {
    final rung = _project.networks[rungIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Opções do elemento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFE7EBF0))),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF4FD1C5)),
                  title: const Text('Editar configurações', style: TextStyle(color: Color(0xFFE7EBF0))),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNodeBottomSheet(rungIndex, nodeIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Color(0xFF3FBF5A)),
                  title: const Text('Duplicar elemento', style: TextStyle(color: Color(0xFFE7EBF0))),
                  onTap: () {
                    setState(() {
                      rung.duplicateNode(nodeIndex);
                      _saveProject();
                    });
                    Navigator.pop(context);
                  },
                ),
                Divider(color: AppTokens.line),
                ListTile(
                  leading: const Icon(Icons.delete, color: Color(0xFFD9503F)),
                  title: const Text('Excluir do rung', style: TextStyle(color: Color(0xFFD9503F))),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTokens.panel,
                        title: const Text('Confirmar exclusão', style: TextStyle(color: Color(0xFFE7EBF0))),
                        content: const Text('Deseja realmente remover este elemento?', style: TextStyle(color: Color(0xFF8C98A8))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8C98A8)))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9503F)),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      setState(() {
                        rung.removeNodeAt(nodeIndex);
                        _saveProject();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 900;
        final isCompact = width < 600;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // TOP HEADER BAR (Apenas se não estiver embutido no Scaffold mestre)
              if (!widget.embedded)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 8 : 10),
                  decoration: const BoxDecoration(
                    color: AppColors.panel,
                    border: Border(bottom: BorderSide(color: AppColors.line, width: 1.0)),
                  ),
                  child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (widget.onOpenDrawer == null)
                            IconButton(
                              icon: const Icon(Icons.menu, color: Color(0xFFE7EBF0), size: 22),
                              onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                              tooltip: 'Menu',
                            )
                          else
                            const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ENDAP LADDER IEC',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFE7EBF0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  '${_project.networks.length} Rungs · ${_project.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8C98A8),
                                    fontSize: 10,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile) ...[
                      if (_mode == EditorMode.simulateLocal) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _simulationPulseMode = !_simulationPulseMode;
                            });
                          },
                          icon: Icon(
                            _simulationPulseMode ? Icons.touch_app : Icons.toggle_on,
                            size: 14,
                            color: _simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430),
                          ),
                          label: Text(
                            _simulationPulseMode ? 'Botão Pulso (400ms)' : 'Chave Retentiva',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _simulationPulseMode ? const Color(0xFF4FD1C5).withValues(alpha: 0.6) : const Color(0xFFE0A430).withValues(alpha: 0.6),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _resetSimulation,
                          icon: const Icon(Icons.restart_alt, size: 14),
                          label: const Text('Resetar Simulação', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFFF87171),
                            side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildModeSelector(isMobile: false),
                    ],
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildModeSelector(isMobile: true)),
                      if (_mode == EditorMode.simulateLocal) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _simulationPulseMode = !_simulationPulseMode;
                            });
                          },
                          icon: Icon(
                            _simulationPulseMode ? Icons.touch_app : Icons.toggle_on,
                            size: 18,
                            color: _simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430),
                          ),
                          tooltip: _simulationPulseMode ? 'Modo Botão Pulso (400ms)' : 'Modo Chave Retentiva',
                          style: IconButton.styleFrom(
                            backgroundColor: (_simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430)).withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: _simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _resetSimulation,
                          icon: const Icon(Icons.restart_alt, size: 18, color: Color(0xFFF87171)),
                          tooltip: 'Resetar Simulação',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: Color(0xFFEF4444))),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // SECONDARY TOOLBAR ACTION BAR
          Container(
            width: double.infinity,
            height: isMobile ? 44 : 48,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: AppTokens.panel,
              border: Border(bottom: BorderSide(color: AppTokens.line, width: 1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isMobile ? (width - 16).clamp(0, double.infinity) : (width - 32).clamp(0, double.infinity)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.add,
                      label: 'Rung',
                      hideLabel: isMobile,
                      onPressed: () {
                        setState(() {
                          final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
                          String defaultController = 'GATEWAY';
                          if (isExclusive) {
                            final firstField = widget.networkManager?.nodes.firstWhere(
                              (n) => n.controllerIndex > 0,
                              orElse: () => widget.networkManager!.nodes.first,
                            );
                            defaultController = (firstField != null && firstField.controllerIndex > 0)
                                ? firstField.id
                                : 'node_01';
                          }
                          if (_selectedControllerFilter != 'ALL' && _selectedControllerFilter != 'GLOBAL') {
                            if (_selectedControllerFilter == 'GATEWAY' && isExclusive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFD97706),
                                  content: Text('Intertravamento: Gateway Dedicado não executa Ladder local. Rung direcionado ao Nó de Campo.'),
                                ),
                              );
                            } else {
                              defaultController = _selectedControllerFilter;
                            }
                          }
                          _project.networks.add(LadderNetwork(
                            id: 'net_${DateTime.now().microsecondsSinceEpoch}',
                            targetControllerId: defaultController,
                          ));
                          _saveProject();
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(icon: Icons.undo, label: 'Desfazer', hideLabel: isMobile, onPressed: () {}),
                    const SizedBox(width: 4),
                    _buildActionButton(icon: Icons.redo, label: 'Refazer', hideLabel: isMobile, onPressed: () {}),
                    const SizedBox(width: 4),
                    _buildActionButton(icon: Icons.check, label: 'Validar', hideLabel: isCompact, onPressed: () => _runPassiveValidation()),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.folder_open,
                      label: 'Abrir',
                      hideLabel: isCompact,
                      onPressed: () async {
                        final imported = await importProject();
                        if (imported != null) {
                          setState(() {
                            _project = imported;
                            _simulationInputs.clear();
                            for (var tag in _project.tags.values) {
                              if (tag.type == TagType.bool) {
                                _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
                              }
                            }
                            _saveProject();
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.download,
                      label: 'Exportar',
                      hideLabel: isCompact,
                      onPressed: () async => await exportProject(_project),
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.refresh_outlined,
                      label: 'Bancada TCC',
                      hideLabel: false,
                      onPressed: () async {
                        final clean = DemoProject.createCleanTccProject();
                        await saveCurrentLadder(clean);
                        setState(() {
                          _project = clean;
                          _simulationInputs.clear();
                          for (var tag in _project.tags.values) {
                            if (tag.type == TagType.bool) {
                              _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
                            }
                          }
                          _selectedRungIndex = null;
                          _selectedNodeIndex = null;
                          _updateRuntimeProject();
                          _runPassiveValidation();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF3FBF5A),
                            content: Text('Projeto limpo da Bancada TCC carregado!', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: _showToolbox ? Icons.view_compact_alt : Icons.view_compact_alt_outlined,
                      label: _showToolbox ? 'Ocultar Paleta' : 'Paleta Componentes',
                      hideLabel: isCompact,
                      onPressed: () => setState(() => _showToolbox = !_showToolbox),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.embedded) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2A364F), width: 1.0),
                        ),
                        child: Text(
                          '${_project.networks.length} Rungs',
                          style: const TextStyle(
                            color: Color(0xFF4FD1C5),
                            fontSize: 10,
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildModeSelector(isMobile: isMobile, allowExpand: false),
                      if (_mode == EditorMode.simulateLocal) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => setState(() => _simulationPulseMode = !_simulationPulseMode),
                          icon: Icon(_simulationPulseMode ? Icons.touch_app : Icons.toggle_on, size: 16, color: _simulationPulseMode ? const Color(0xFF4FD1C5) : const Color(0xFFE0A430)),
                          tooltip: _simulationPulseMode ? 'Modo Pulso (400ms)' : 'Modo Retentivo',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        IconButton(
                          onPressed: _resetSimulation,
                          icon: const Icon(Icons.restart_alt, size: 16, color: Color(0xFFF87171)),
                          tooltip: 'Resetar Simulação',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Container(width: 1, height: 18, color: const Color(0xFF262C36)),
                      const SizedBox(width: 10),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE7EBF0),
                        side: BorderSide(color: AppTokens.line, width: 1),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: Icon(Icons.cloud_download_outlined, size: isMobile ? 16 : 18),
                      label: isMobile
                          ? const SizedBox.shrink()
                          : const Text(
                              'Baixar ESP32',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                      onPressed: () => _fetchFromEsp32(),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFF991B1B)),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                      label: const Text('Limpar CLP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _handleClearEsp32Ladder(),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final isExclusiveGw = widget.networkManager?.isExclusiveGateway ?? false;
                        final isBlockedDeploy = isExclusiveGw && _selectedControllerFilter == 'GATEWAY';
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBlockedDeploy ? const Color(0xFF64748B) : AppTokens.run,
                            foregroundColor: isBlockedDeploy ? Colors.white70 : AppTokens.bg,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          icon: Icon(isBlockedDeploy ? Icons.lock_outline : Icons.cloud_upload_outlined, size: isMobile ? 16 : 18),
                          label: Text(
                            _getDeployButtonLabel(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _handleDeploy(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

          // CONTROLLER FILTER STRIP & SEARCH
          _buildControllerFilterStrip(isMobile),

          if ((widget.networkManager?.isExclusiveGateway ?? false) && _selectedControllerFilter == 'GATEWAY')
            _buildExclusiveGatewayBanner(),

          // COMPONENT TOOLBOX (NO, NC, COIL, SET, RST, TON...)
          _buildComponentToolboxWrapper(),

          // MAIN LADDER CANVAS / RUNG LIST
          Expanded(
            child: _project.networks.isEmpty ? _buildEmptyState() : _buildRungListWrapper(),
          ),

          // BOTTOM VARIABLES MONITOR PANEL
          _buildVariablesPanelWrapper(),
        ],
      ),
    );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool hideLabel,
    required VoidCallback onPressed,
  }) {
    if (hideLabel) {
      return IconButton(
        icon: Icon(icon, color: const Color(0xFFE7EBF0), size: 18),
        tooltip: label,
        onPressed: onPressed,
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFE7EBF0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onPressed,
    );
  }

  Widget _buildVariablesPanelWrapper() {
    final liveValues = <String, bool>{};
    final liveAnalogValues = <String, String>{};
    for (final tag in _project.tags.values) {
      if (tag.type == TagType.real || tag.type == TagType.int || tag.type == TagType.dint) {
        final realVal = _runtime.tagStore.getReal(tag.id);
        final intVal = _runtime.tagStore.getInt(tag.id);
        final val = realVal != 0.0 ? realVal : intVal.toDouble();
        final unitSuffix = (tag.unit != null && tag.unit!.isNotEmpty) ? tag.unit! : '';
        liveAnalogValues[tag.id] = '${val.toStringAsFixed(1)}$unitSuffix';
        liveValues[tag.id] = val > 0.0;
      } else {
        liveValues[tag.id] = _runtime.tagStore.getBool(tag.id);
      }
    }
    final isHardware = _mode == EditorMode.simulateHardware;
    return VariablesPanel(
      tags: _project.tags,
      simulationInputs: _simulationInputs,
      isHardwareMode: isHardware,
      liveValues: liveValues,
      liveAnalogValues: liveAnalogValues,
      networkManager: widget.networkManager,
      onTagAdded: _addVariable,
      onTagRemoved: (tagId) {
        setState(() {
          _project.tags.remove(tagId);
          _simulationInputs.remove(tagId);
          _saveProject();
        });
      },
      onSimulationInputChanged: (tagId, val) {
        if (_mode == EditorMode.simulateHardware) return;
        if (_isOutputTag(tagId)) return;
        _toggleSimulationTag(tagId);
      },
    );
  }

  void _addVariable(String tagId) {
    final cleaned = tagId.trim().toUpperCase();
    if (cleaned.isNotEmpty && !_project.tags.containsKey(cleaned)) {
      setState(() {
        _project.tags[cleaned] = Tag(
          id: cleaned,
          name: cleaned,
          type: TagType.bool,
          initialValue: TagValue.boolean(false),
        );
        _simulationInputs[cleaned] = false;
        _saveProject();
      });
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTokens.bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: AppTokens.panel,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTokens.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 56, color: Color(0xFF4FD1C5)),
                    const SizedBox(height: 16),
                    const Text(
                      'Lógica Ladder IEC Vazia',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE7EBF0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nenhum degrau (rung) cadastrado no projeto',
                      style: TextStyle(fontSize: 14, color: Color(0xFF8C98A8)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
                                String defaultController = 'GATEWAY';
                                if (isExclusive) {
                                  final firstField = widget.networkManager?.nodes.firstWhere(
                                    (n) => n.controllerIndex > 0,
                                    orElse: () => widget.networkManager!.nodes.first,
                                  );
                                  defaultController = (firstField != null && firstField.controllerIndex > 0)
                                      ? firstField.id
                                      : 'node_01';
                                }
                                _project.networks.add(LadderNetwork(
                                  id: 'net_${DateTime.now().microsecondsSinceEpoch}',
                                  targetControllerId: defaultController,
                                ));
                                _saveProject();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTokens.focus,
                              foregroundColor: AppTokens.bg,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Adicionar Rung',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _fetchFromEsp32(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE7EBF0),
                              side: BorderSide(color: AppTokens.line, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: const Text(
                              'Baixar ESP32',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final clean = DemoProject.createCleanTccProject();
                          await saveCurrentLadder(clean);
                          setState(() {
                            _project = clean;
                            _simulationInputs.clear();
                            for (var tag in _project.tags.values) {
                              if (tag.type == TagType.bool) {
                                _simulationInputs[tag.id] = tag.initialValue?.boolValue ?? false;
                              }
                            }
                            _selectedRungIndex = null;
                            _selectedNodeIndex = null;
                            _updateRuntimeProject();
                            _runPassiveValidation();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF3FBF5A),
                              content: Text('Projeto limpo da Bancada TCC carregado!', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4FD1C5),
                          side: const BorderSide(color: Color(0xFF4FD1C5), width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_outlined, size: 18),
                        label: const Text(
                          'Carregar Lógica da Bancada TCC (Sensor + Relés)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getControllerRungCount(String controllerId) {
    if (controllerId == 'ALL') return _project.networks.length;
    return _project.networks
        .where((n) =>
            n.targetControllerId == controllerId ||
            (controllerId != 'GATEWAY' && n.targetControllerId == 'GLOBAL'))
        .length;
  }

  int _getDisabledRungCount() {
    return _project.networks.where((n) => !n.isEnabled).length;
  }

  String _getDeployButtonLabel() {
    final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
    if (_selectedControllerFilter == 'GATEWAY' && isExclusive) {
      return 'Bloqueado (Dedicado)';
    }
    if (_selectedControllerFilter == 'ALL') {
      final hasFieldNodes = widget.networkManager?.nodes.any((n) => n.controllerIndex > 0) ?? false;
      return hasFieldNodes ? 'Deploy Célula (Todos)' : 'Deploy (Local)';
    }
    if (_selectedControllerFilter == 'GLOBAL') {
      return 'Deploy (Global)';
    }
    if (_selectedControllerFilter == 'GATEWAY') {
      return 'Deploy (Gateway)';
    }
    if (widget.networkManager != null) {
      for (final n in widget.networkManager!.nodes) {
        if (n.id == _selectedControllerFilter) {
          return 'Deploy (Nó ${n.controllerIndex})';
        }
      }
    }
    if (_selectedControllerFilter == 'node_01') return 'Deploy (Nó 01)';
    if (_selectedControllerFilter == 'node_02') return 'Deploy (Nó 02)';
    return 'Deploy ($_selectedControllerFilter)';
  }

  Future<void> _handleDeploy() async {
    final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;

    // Intertravamento Técnico 1: Bloqueio de Deploy Direto para Gateway Dedicado
    if (_selectedControllerFilter == 'GATEWAY' && isExclusive) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTokens.line),
          ),
          title: Row(
            children: const [
              Icon(Icons.block, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 10),
              Text('Intertravamento Técnico de Engenharia', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'O Gateway está configurado no Perfil "Gateway Dedicado / Exclusivo" (Perfil 4).\n\n'
            'Por diretriz técnica de projeto, este nó dedica 100% dos seus recursos a roteamento, bridge de rede e telemetria, não possuindo o loop determinístico de 1ms de controle local ativo.\n\n'
            'Ação Necessária: Reatribua os Rungs para um Nó de Campo (Nó 1, Nó 2...) para gravação do Ladder.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              child: const Text('Compreendido', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final networkGwIp = widget.networkManager?.controller.ip.trim().isNotEmpty == true
        ? widget.networkManager!.controller.ip.trim()
        : (widget.networkManager?.gatewayIp.trim() ?? '');
    final gatewayIp = networkGwIp.isNotEmpty
        ? networkGwIp
        : await FirmwareSyncService.getSavedGatewayIp();
    final syncService = FirmwareSyncService();

    // Cenário 1: Deploy de toda a Célula ('ALL') particionando por nó
    if (_selectedControllerFilter == 'ALL') {
      int successCount = 0;
      int targetCount = 0;
      final deployedDetails = <String>[];

      // 1. Deploy para o Gateway apenas se NÃO for exclusivo
      if (!isExclusive) {
        final gwRungs = _project.networks.where((n) => 
          n.targetControllerId == 'GATEWAY' || n.targetControllerId == 'GLOBAL' || n.targetControllerId == 'ALL'
        ).length;

        if (gwRungs > 0) {
          targetCount++;
          final gwSuccess = await syncService.syncRules(
            gatewayIp,
            _project,
            targetControllerId: 'GATEWAY',
          );
          if (gwSuccess) {
            successCount++;
            deployedDetails.add('Gateway ($gwRungs rungs)');
          }
        }
      }

      // 2. Deploy para nós de campo descobertos e ativos no cluster
      if (widget.networkManager != null) {
        for (final n in widget.networkManager!.nodes) {
          if (n.ip.isNotEmpty && n.controllerIndex > 0 && n.status != NodeStatus.offline) {
            final nodeRungs = _project.networks.where((r) =>
              r.targetControllerId == n.id || r.targetControllerId == 'GLOBAL'
            ).length;

            if (nodeRungs > 0) {
              targetCount++;
              final nodeSuccess = await syncService.syncRules(
                n.ip,
                _project,
                targetControllerId: n.id,
              );
              if (nodeSuccess) {
                successCount++;
                deployedDetails.add('Nó ${n.controllerIndex} ($nodeRungs rungs)');
              }
            }
          }
        }
      }

      // Intertravamento Técnico 2: Se Gateway for Exclusivo e não há nós de campo alvo
      if (isExclusive && targetCount == 0) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTokens.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppTokens.line),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                SizedBox(width: 10),
                Text('Nenhum Nó de Campo Apto para Deploy', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'A topologia atual conta com um Gateway Dedicado (que não executa Ladder) e nenhum Nó de Campo ativo para executar as lógicas.\n\n'
              'Para realizar o deploy do programa, adote e conecte ao menos um Nó de Campo na aba de Redes.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      final allOk = successCount == targetCount && targetCount > 0;
      if (allOk) {
        _applyMode(EditorMode.simulateHardware);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: allOk ? const Color(0xFF3FBF5A) : const Color(0xFFD9503F),
          content: Text(
            allOk
                ? 'Deploy da Célula Particionada OK: ${deployedDetails.join(", ")}'
                : 'Deploy parcial ($successCount/$targetCount nós alcançados)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    // Cenário 2: Deploy direcionado para um nó específico
    String targetIp = gatewayIp;
    String targetDesc = 'Gateway ($gatewayIp)';
    String? targetControllerId = _selectedControllerFilter;

    if (_selectedControllerFilter != 'GATEWAY' && _selectedControllerFilter != 'GLOBAL' && widget.networkManager != null) {
      for (final n in widget.networkManager!.nodes) {
        if (n.id == _selectedControllerFilter && n.ip.isNotEmpty) {
          targetIp = n.ip;
          targetDesc = 'Nó ${n.controllerIndex} (${n.ip})';
          break;
        }
      }
    }

    final success = await syncService.syncRules(
      targetIp,
      _project,
      targetControllerId: targetControllerId,
    );

    if (!mounted) return;
    if (success) {
      _applyMode(EditorMode.simulateHardware);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF3FBF5A) : const Color(0xFFD9503F),
        content: Text(
          success
              ? 'Deploy particionado realizado com sucesso em $targetDesc'
              : 'Falha no deploy - verifique conexão com $targetDesc',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildExclusiveGatewayBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF451A03),
        border: Border(bottom: BorderSide(color: Color(0xFFD97706), width: 1.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'INTERTRAVAMENTO ATIVO — GATEWAY DEDICADO (PERFIL 4)',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Este nó opera exclusivamente como concentrador e roteador de rede. A execução de lógicas Ladder está bloqueada neste nó. Aloque os Rungs em Nós de Campo (Nó 1, Nó 2...).',
                  style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerFilterStrip(bool isMobile) {
    final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
    final controllers = <Map<String, dynamic>>[
      {
        'id': 'ALL',
        'label': 'Todos',
        'count': _project.networks.length,
        'color': const Color(0xFF94A3B8),
        'icon': Icons.hub_outlined,
      },
      {
        'id': 'GATEWAY',
        'label': isExclusive ? 'Gateway [DEDICADO]' : 'Gateway',
        'count': _getControllerRungCount('GATEWAY'),
        'color': isExclusive ? const Color(0xFF64748B) : const Color(0xFF38BDF8),
        'icon': isExclusive ? Icons.lock_outline : Icons.dns_outlined,
      },
    ];

    if (widget.networkManager != null && widget.networkManager!.nodes.isNotEmpty) {
      for (final n in widget.networkManager!.nodes) {
        if (!n.role.toLowerCase().contains('gateway')) {
          final label = n.role.isNotEmpty
              ? 'Nó ${n.controllerIndex} (${n.role})'
              : 'Nó ${n.controllerIndex}';
          controllers.add({
            'id': n.id,
            'label': label,
            'count': _getControllerRungCount(n.id),
            'color': const Color(0xFF10B981),
            'icon': Icons.memory,
          });
        }
      }
    } else {
      controllers.add({
        'id': 'node_01',
        'label': 'Nó 01',
        'count': _getControllerRungCount('node_01'),
        'color': const Color(0xFF10B981),
        'icon': Icons.memory,
      });
      controllers.add({
        'id': 'node_02',
        'label': 'Nó 02',
        'count': _getControllerRungCount('node_02'),
        'color': const Color(0xFFF59E0B),
        'icon': Icons.memory,
      });
    }

    final disabledCount = _getDisabledRungCount();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14181F),
        border: Border(bottom: BorderSide(color: AppTokens.line.withValues(alpha: 0.7), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...controllers.map((c) {
                    final id = c['id'] as String;
                    final isSelected = !_filterOnlyDisabled && _selectedControllerFilter == id;
                    final color = c['color'] as Color;
                    final count = c['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            _filterOnlyDisabled = false;
                            _selectedControllerFilter = id;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.18)
                                : AppTokens.panel2.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? color : AppTokens.line.withValues(alpha: 0.6),
                              width: isSelected ? 1.2 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c['icon'] as IconData, size: 12, color: isSelected ? color : AppTokens.muted),
                              const SizedBox(width: 5),
                              Text(
                                c['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? color : AppTokens.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withValues(alpha: 0.25) : AppTokens.panel,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? color : AppTokens.muted,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _filterOnlyDisabled = !_filterOnlyDisabled;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _filterOnlyDisabled
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                              : AppTokens.panel2.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _filterOnlyDisabled
                                ? const Color(0xFFF59E0B)
                                : AppTokens.line.withValues(alpha: 0.6),
                            width: _filterOnlyDisabled ? 1.2 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_outline,
                                size: 12,
                                color: _filterOnlyDisabled
                                    ? const Color(0xFFF59E0B)
                                    : AppTokens.muted),
                            const SizedBox(width: 5),
                            Text(
                              'Inativos',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _filterOnlyDisabled ? FontWeight.bold : FontWeight.w500,
                                color: _filterOnlyDisabled
                                    ? const Color(0xFFF59E0B)
                                    : AppTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _filterOnlyDisabled
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                    : AppTokens.panel,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$disabledCount',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _filterOnlyDisabled
                                      ? const Color(0xFFF59E0B)
                                      : AppTokens.muted,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showSearchBar) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: isMobile ? 130 : 190,
              height: 28,
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 11, color: AppTokens.textPrimary, fontFamily: 'JetBrains Mono'),
                decoration: InputDecoration(
                  hintText: 'Filtrar tags/nomes...',
                  hintStyle: TextStyle(fontSize: 10, color: AppTokens.muted),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTokens.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTokens.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTokens.focus)),
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 13),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _showSearchBar = false;
                      });
                    },
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.search,
                size: 16,
                color: _searchQuery.isNotEmpty ? AppTokens.focus : AppTokens.muted,
              ),
              tooltip: 'Buscar por tag ou comentário',
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => setState(() => _showSearchBar = true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRungListWrapper() {
    return RungList(
      project: _project,
      runtime: _runtime,
      networkValidationErrors: _networkValidationErrors,
      selectedRungIndex: _selectedRungIndex,
      selectedNodeIndex: _selectedNodeIndex,
      isSimulationRunning: _mode != EditorMode.editor,
      onToggleTag: _toggleSimulationTag,
      filterControllerId: _selectedControllerFilter,
      filterOnlyDisabled: _filterOnlyDisabled,
      searchQuery: _searchQuery,
      networkManager: widget.networkManager,
      onDraggingStateChanged: (isDragging) {
        setState(() {
          _isDraggingNode = isDragging;
        });
      },
      onProjectChanged: () {
        setState(() {
          _saveProject();
        });
      },
      onNodeSelectionChanged: (rung, node) {
        setState(() {
          _selectedRungIndex = rung;
          _selectedNodeIndex = node;
        });
      },
      onNodeEditRequest: _showEditNodeBottomSheet,
      onNodeOptionsRequest: _showNodeOptionsBottomSheet,
      onComponentAddRequest: (rung, [insertIndex]) => _showComponentBottomSheet(rung, insertIndex),
    );
  }

  Widget _buildComponentToolboxWrapper() {
    if (!_showToolbox) {
      return Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTokens.panel,
          border: Border(bottom: BorderSide(color: AppTokens.line, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.widgets_outlined, size: 12, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            const Text(
              'Paleta de Componentes Oculta (Mais espaço para visualização)',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _showToolbox = true),
              child: Row(
                children: const [
                  Text('Exibir Componentes', style: TextStyle(color: Color(0xFF4FD1C5), fontSize: 10, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF4FD1C5)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        LadderToolbox(
          isDraggingNode: _isDraggingNode,
          onNodeTapped: (nodeType) {
            if (_project.networks.isNotEmpty) {
              setState(() {
                final newNode = _createConfiguredNode(nodeType);
                _project.networks.first.addNode(newNode);
                _project.networks.first.rebuildConnections();
                _saveProject();
              });
            }
          },
          onNodeDeleted: (srcRung, srcNode) {
            setState(() {
              _project.networks[srcRung].removeNodeAt(srcNode);
              _saveProject();
              _isDraggingNode = false;
            });
          },
        ),
        Positioned(
          right: 8,
          top: 6,
          child: Tooltip(
            message: 'Recolher paleta para ampliar visualização do Ladder',
            child: InkWell(
              onTap: () => setState(() => _showToolbox = false),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF334155), width: 0.8),
                ),
                child: const Icon(Icons.keyboard_arrow_up, size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector({required bool isMobile, bool allowExpand = true}) {
    final modes = <({EditorMode mode, IconData icon, String label})>[
      (mode: EditorMode.editor, icon: Icons.edit_outlined, label: 'Edição'),
      (mode: EditorMode.simulateLocal, icon: Icons.play_circle_outline, label: isMobile ? 'Simular' : 'Simulação'),
      (mode: EditorMode.simulateHardware, icon: Icons.memory, label: isMobile ? 'ESP32' : 'Conectado ao ESP32'),
    ];

    return ListenableBuilder(
      listenable: TelemetrySyncService.instance,
      builder: (context, _) {
        final isOnline = TelemetrySyncService.instance.isOnline;
        final shouldUseExpanded = isMobile && allowExpand;
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTokens.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTokens.line, width: 1),
          ),
          child: Row(
            mainAxisSize: shouldUseExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final m in modes) ...[
                if (shouldUseExpanded)
                  Expanded(
                    child: _buildModeChipButton(
                      mode: m.mode,
                      icon: m.icon,
                      label: m.label,
                      isActive: _mode == m.mode,
                      isOnline: isOnline,
                      isMobile: isMobile,
                    ),
                  )
                else
                  _buildModeChipButton(
                    mode: m.mode,
                    icon: m.icon,
                    label: m.label,
                    isActive: _mode == m.mode,
                    isOnline: isOnline,
                    isMobile: isMobile,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeChipButton({
    required EditorMode mode,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isOnline,
    required bool isMobile,
  }) {
    Color activeColor = const Color(0xFF4FD1C5);
    if (mode == EditorMode.simulateLocal) {
      activeColor = const Color(0xFFE0A430); // Warn/Amber
    } else if (mode == EditorMode.simulateHardware) {
      activeColor = isOnline ? const Color(0xFF3FBF5A) : const Color(0xFFD9503F);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _applyMode(mode),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppTokens.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isActive ? Border.all(color: activeColor, width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mode == EditorMode.simulateHardware) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? const Color(0xFF3FBF5A) : const Color(0xFFD9503F),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(icon, color: isActive ? activeColor : const Color(0xFF8C98A8), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFE7EBF0) : const Color(0xFF8C98A8),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
