import 'package:flutter/material.dart';
import '../../../models/ladder_project.dart';
import '../../../models/ladder_network.dart';
import '../../../runtime/ladder_runtime.dart';
import 'ladder_network_canvas.dart';
import '../../../../design_system/tokens.dart';
import '../../../../core/services/network_manager.dart';

class RungList extends StatefulWidget {
  final LadderProject project;
  final LadderRuntime runtime;
  final Map<String, String?> networkValidationErrors;
  final int? selectedRungIndex;
  final int? selectedNodeIndex;
  final bool isSimulationRunning;
  final void Function(String tagId)? onToggleTag;
  final void Function(int rungIndex, int nodeIndex) onNodeSelectionChanged;
  final void Function(int rungIndex, int nodeIndex) onNodeEditRequest;
  final void Function(int rungIndex, int nodeIndex) onNodeOptionsRequest;
  final void Function(int rungIndex, [int? insertIndex]) onComponentAddRequest;
  final void Function(bool isDragging) onDraggingStateChanged;
  final VoidCallback onProjectChanged;

  final String? filterControllerId;
  final bool filterOnlyDisabled;
  final String? searchQuery;
  final NetworkManager? networkManager;

  const RungList({
    super.key,
    required this.project,
    required this.runtime,
    required this.networkValidationErrors,
    this.selectedRungIndex,
    this.selectedNodeIndex,
    this.isSimulationRunning = true,
    this.onToggleTag,
    required this.onNodeSelectionChanged,
    required this.onNodeEditRequest,
    required this.onNodeOptionsRequest,
    required this.onComponentAddRequest,
    required this.onDraggingStateChanged,
    required this.onProjectChanged,
    this.filterControllerId,
    this.filterOnlyDisabled = false,
    this.searchQuery,
    this.networkManager,
  });

  @override
  State<RungList> createState() => _RungListState();
}

class _RungListState extends State<RungList> {
  List<MapEntry<int, LadderNetwork>> _getFilteredNetworks() {
    final result = <MapEntry<int, LadderNetwork>>[];
    for (int i = 0; i < widget.project.networks.length; i++) {
      final net = widget.project.networks[i];

      // 1. Controller filter
      if (widget.filterControllerId != null &&
          widget.filterControllerId != 'ALL' &&
          widget.filterControllerId != 'GLOBAL') {
        if (net.targetControllerId != widget.filterControllerId &&
            net.targetControllerId != 'GLOBAL' &&
            net.targetControllerId != 'ALL') {
          continue;
        }
      }

      // 2. Disabled-only filter
      if (widget.filterOnlyDisabled && net.isEnabled) {
        continue;
      }

      // 3. Search query
      if (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty) {
        final q = widget.searchQuery!.trim().toLowerCase();
        final matchesName = net.name.toLowerCase().contains(q);
        final matchesController =
            (net.targetControllerName ?? net.targetControllerId).toLowerCase().contains(q);
        final matchesNodeTag = net.nodes.any((n) =>
            (n.config.tagId ?? '').toLowerCase().contains(q) ||
            n.id.toLowerCase().contains(q));
        if (!matchesName && !matchesController && !matchesNodeTag) {
          continue;
        }
      }

      result.add(MapEntry(i, net));
    }
    return result;
  }

  String _getControllerDisplayName(String controllerId, String? cachedName) {
    if (cachedName != null && cachedName.trim().isNotEmpty) {
      return cachedName;
    }
    final clean = controllerId.toUpperCase();
    if (clean == 'GATEWAY') {
      if (widget.networkManager?.isExclusiveGateway == true) {
        return 'GATEWAY [DEDICADO - NÃO EXECUTA]';
      }
      return 'GATEWAY';
    }
    if (clean == 'GLOBAL' || clean == 'ALL') return 'GLOBAL (TODOS)';
    if (widget.networkManager != null) {
      for (final n in widget.networkManager!.nodes) {
        if (n.id == controllerId) {
          return n.role.isNotEmpty ? 'NÓ ${n.controllerIndex} (${n.role})' : 'NÓ ${n.controllerIndex}';
        }
      }
    }
    return controllerId;
  }

  Color _getControllerColor(String controllerId) {
    final clean = controllerId.toUpperCase();
    if (clean == 'GATEWAY' || clean.contains('GW')) {
      if (widget.networkManager?.isExclusiveGateway == true) {
        return const Color(0xFFEF4444); // Vermelho de Alerta/Intertravamento
      }
      return const Color(0xFF38BDF8); // Azul Ciano
    } else if (clean == 'GLOBAL' || clean == 'ALL') {
      return const Color(0xFFA855F7); // Roxo
    } else if (clean.contains('01') || clean.contains('1')) {
      return const Color(0xFF10B981); // Verde Esmeralda
    } else if (clean.contains('02') || clean.contains('2')) {
      return const Color(0xFFF59E0B); // Âmbar
    } else if (clean.contains('03') || clean.contains('3')) {
      return const Color(0xFFEC4899); // Rosa
    } else {
      return const Color(0xFF6366F1); // Índigo
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredNetworks();
    final hasActiveFilter = (widget.filterControllerId != null &&
            widget.filterControllerId != 'ALL' &&
            widget.filterControllerId != 'GLOBAL') ||
        widget.filterOnlyDisabled ||
        (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty);

    return Container(
      color: AppTokens.bg,
      width: double.infinity,
      height: double.infinity,
      child: filtered.isEmpty && hasActiveFilter
          ? _buildFilterEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 60),
              itemCount: filtered.length + 1,
              itemBuilder: (context, listIndex) {
                if (listIndex == filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.textSecondary,
                        side: BorderSide(color: AppTokens.line, width: 1.0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: AppTokens.panel.withValues(alpha: 0.5),
                      ),
                      icon: Icon(Icons.add, size: 16, color: AppTokens.focus),
                      label: Text(
                        (widget.filterControllerId != null &&
                                widget.filterControllerId != 'ALL' &&
                                widget.filterControllerId != 'GLOBAL')
                            ? 'Adicionar Rung (${_getControllerDisplayName(widget.filterControllerId!, null)})'
                            : 'Adicionar Rung',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.textPrimary),
                      ),
                      onPressed: () {
                        setState(() {
                          final defaultController = (widget.filterControllerId != null &&
                                  widget.filterControllerId != 'ALL' &&
                                  widget.filterControllerId != 'GLOBAL')
                              ? widget.filterControllerId!
                              : 'GATEWAY';
                          final defaultName = _getControllerDisplayName(defaultController, null);
                          widget.project.networks.add(LadderNetwork(
                            id: 'net_${DateTime.now().microsecondsSinceEpoch}',
                            targetControllerId: defaultController,
                            targetControllerName: defaultName,
                          ));
                          widget.onProjectChanged();
                        });
                      },
                    ),
                  );
                }

                final entry = filtered[listIndex];
                final originalIndex = entry.key;
                final rung = entry.value;
                final isRungActive = rung.isEnabled &&
                    rung.nodes.isNotEmpty &&
                    rung.nodes.any((n) => n.isEnergized);
                final controllerColor = _getControllerColor(rung.targetControllerId);
                final controllerLabel =
                    _getControllerDisplayName(rung.targetControllerId, rung.targetControllerName);

                return Container(
                  key: ValueKey(rung.id),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rung Comment Header & Controller Badges Row
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 16, bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Comment & Edit
                            Flexible(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => _showEditCommentDialog(context, rung, originalIndex),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          rung.name.isNotEmpty
                                              ? '// ${rung.name}'
                                              : '// [Adicionar comentário...]',
                                          style: TextStyle(
                                            color: rung.name.isNotEmpty
                                                ? AppTokens.focus
                                                : AppTokens.muted,
                                            fontSize: 11,
                                            fontFamily: 'JetBrains Mono',
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 12,
                                        color:
                                            rung.name.isNotEmpty ? AppTokens.muted : AppTokens.line,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Right Action Controls: Controller Badge + Enable Toggle + Clone + Delete
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Controller Badge (Clickable to change controller or clone)
                                Tooltip(
                                  message:
                                      'Controlador executor: $controllerLabel (Clique para reatribuir ou clonar)',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _showControllerConfigDialog(
                                        context, rung, originalIndex),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: controllerColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: controllerColor.withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (widget.networkManager?.isExclusiveGateway == true && rung.targetControllerId == 'GATEWAY')
                                                ? Icons.lock
                                                : Icons.memory,
                                            size: 11,
                                            color: controllerColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            controllerLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: controllerColor,
                                              fontFamily: 'JetBrains Mono',
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(Icons.arrow_drop_down,
                                              size: 14, color: controllerColor),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Enable / Disable Toggle Chip
                                Tooltip(
                                  message: rung.isEnabled
                                      ? 'Rung ATIVO no ciclo de varredura (Clique para desativar)'
                                      : 'Rung DESATIVADO (Clique para ativar)',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () {
                                      setState(() {
                                        rung.isEnabled = !rung.isEnabled;
                                        widget.onProjectChanged();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: rung.isEnabled
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: rung.isEnabled
                                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                              : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            rung.isEnabled
                                                ? Icons.play_arrow
                                                : Icons.pause,
                                            size: 11,
                                            color: rung.isEnabled
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            rung.isEnabled ? 'ATIVO' : 'INATIVO',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: rung.isEnabled
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF59E0B),
                                              fontFamily: 'JetBrains Mono',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Delete Rung Button
                                Tooltip(
                                  message: 'Excluir Rung',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () {
                                      widget.project.networks.removeAt(originalIndex);
                                      widget.onProjectChanged();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Rung Row with horizontal overflow container
                      Opacity(
                        opacity: rung.isEnabled ? 1.0 : 0.45,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 8),
                            // Rung Index Number (Preserves original global index)
                            SizedBox(
                              width: 36,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (originalIndex + 1).toString().padLeft(4, '0'),
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isRungActive
                                          ? const Color(0xFF3FBF5A)
                                          : const Color(0xFF8C98A8),
                                    ),
                                  ),
                                  if (!rung.isEnabled)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: const Text(
                                        'OFF',
                                        style: TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Responsive horizontal container for rung diagram
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final double availableWidth =
                                      (constraints.maxWidth - 16.0).clamp(400.0, 5000.0);

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 24.0),
                                      child: LadderNetworkCanvas(
                                        project: widget.project,
                                        rungIndex: originalIndex,
                                        runtime: widget.runtime,
                                        selectedRungIndex: widget.selectedRungIndex,
                                        selectedNodeIndex: widget.selectedNodeIndex,
                                        isSimulationRunning:
                                            widget.isSimulationRunning && rung.isEnabled,
                                        onToggleTag: widget.onToggleTag,
                                        onNodeSelectionChanged: widget.onNodeSelectionChanged,
                                        onNodeEditRequest: widget.onNodeEditRequest,
                                        onNodeOptionsRequest: widget.onNodeOptionsRequest,
                                        onComponentAddRequest: widget.onComponentAddRequest,
                                        minCanvasWidth: availableWidth,
                                        onDraggingStateChanged: widget.onDraggingStateChanged,
                                        onProjectChanged: widget.onProjectChanged,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFilterEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 40, color: AppTokens.muted),
            const SizedBox(height: 12),
            Text(
              'Nenhum rung encontrado para o filtro selecionado',
              style: TextStyle(
                color: AppTokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Altere o controlador ou adicione um novo rung para este nó.',
              style: TextStyle(color: AppTokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.focus,
                foregroundColor: AppTokens.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                (widget.filterControllerId != null &&
                        widget.filterControllerId != 'ALL' &&
                        widget.filterControllerId != 'GLOBAL')
                    ? 'Adicionar Rung em ${_getControllerDisplayName(widget.filterControllerId!, null)}'
                    : 'Adicionar Rung',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  final defaultController = (widget.filterControllerId != null &&
                          widget.filterControllerId != 'ALL' &&
                          widget.filterControllerId != 'GLOBAL')
                      ? widget.filterControllerId!
                      : 'GATEWAY';
                  final defaultName = _getControllerDisplayName(defaultController, null);
                  widget.project.networks.add(LadderNetwork(
                    id: 'net_${DateTime.now().microsecondsSinceEpoch}',
                    targetControllerId: defaultController,
                    targetControllerName: defaultName,
                  ));
                  widget.onProjectChanged();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCommentDialog(BuildContext context, LadderNetwork rung, int index) {
    final controller = TextEditingController(text: rung.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTokens.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTokens.line, width: 1.0),
        ),
        title: Text(
          'Comentário do Rung ${(index + 1).toString().padLeft(4, '0')}',
          style: TextStyle(
              color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(
              color: AppTokens.textPrimary, fontSize: 13, fontFamily: 'JetBrains Mono'),
          decoration: InputDecoration(
            hintText: 'Ex: Partida do motor M1',
            hintStyle:
                TextStyle(color: AppTokens.muted.withValues(alpha: 0.6), fontSize: 12),
            filled: true,
            fillColor: AppTokens.panel2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTokens.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTokens.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTokens.focus)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: AppTokens.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.focus,
              foregroundColor: AppTokens.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                rung.name = controller.text.trim();
                widget.onProjectChanged();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showControllerConfigDialog(
      BuildContext context, LadderNetwork rung, int originalIndex) {
    showDialog(
      context: context,
      builder: (ctx) => _RungControllerAssignmentDialog(
        rung: rung,
        originalIndex: originalIndex,
        networkManager: widget.networkManager,
        onReassigned: (newId, newName) {
          setState(() {
            rung.targetControllerId = newId;
            rung.targetControllerName = newName;
            widget.onProjectChanged();
          });
        },
        onCloned: (targetId, targetName) {
          final cloned = rung.clone(
            newId: 'net_${DateTime.now().microsecondsSinceEpoch}',
            newName: '${rung.name} (Cópia $targetName)'.trim(),
            targetControllerId: targetId,
            targetControllerName: targetName,
          );
          setState(() {
            widget.project.networks.insert(originalIndex + 1, cloned);
            widget.onProjectChanged();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('Rung clonado com sucesso para $targetName!'),
            ),
          );
        },
      ),
    );
  }
}

class _RungControllerAssignmentDialog extends StatefulWidget {
  final LadderNetwork rung;
  final int originalIndex;
  final NetworkManager? networkManager;
  final void Function(String id, String name) onReassigned;
  final void Function(String id, String name) onCloned;

  const _RungControllerAssignmentDialog({
    required this.rung,
    required this.originalIndex,
    required this.networkManager,
    required this.onReassigned,
    required this.onCloned,
  });

  @override
  State<_RungControllerAssignmentDialog> createState() =>
      _RungControllerAssignmentDialogState();
}

class _RungControllerAssignmentDialogState
    extends State<_RungControllerAssignmentDialog> {
  late String _selectedControllerId;
  String? _selectedControllerName;
  bool _isCloningMode = false;

  @override
  void initState() {
    super.initState();
    final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
    if (widget.rung.targetControllerId == 'GATEWAY' && isExclusive) {
      final firstField = widget.networkManager?.nodes.firstWhere(
        (n) => n.controllerIndex > 0,
        orElse: () => widget.networkManager!.nodes.first,
      );
      _selectedControllerId = (firstField != null && firstField.controllerIndex > 0)
          ? firstField.id
          : 'node_01';
      _selectedControllerName = (firstField != null && firstField.controllerIndex > 0)
          ? 'Nó ${firstField.controllerIndex} (${firstField.role})'
          : 'Nó 01 (Field Node)';
    } else {
      _selectedControllerId = widget.rung.targetControllerId;
      _selectedControllerName = widget.rung.targetControllerName;
    }
  }

  List<Map<String, String>> _getAvailableControllers() {
    final isExclusive = widget.networkManager?.isExclusiveGateway ?? false;
    final list = <Map<String, String>>[
      {
        'id': 'GATEWAY',
        'name': isExclusive
            ? 'Gateway Dedicado [INTERTRAVADO - NÃO EXECUTA LADDER]'
            : 'Gateway Principal (ESP32 Gateway)',
        'blocked': isExclusive ? 'true' : 'false',
      },
      {'id': 'GLOBAL', 'name': 'Global / Todos os Controladores', 'blocked': 'false'},
    ];

    if (widget.networkManager != null && widget.networkManager!.nodes.isNotEmpty) {
      for (final n in widget.networkManager!.nodes) {
        if (!n.role.toLowerCase().contains('gateway')) {
          final label = n.role.isNotEmpty
              ? 'Nó ${n.controllerIndex} - ${n.role} (${n.ip})'
              : 'Nó ${n.controllerIndex} (${n.ip})';
          list.add({'id': n.id, 'name': label, 'blocked': 'false'});
        }
      }
    } else {
      // Fallback pre-sets if offline
      list.add({'id': 'node_01', 'name': 'Nó 01 (Field Node)', 'blocked': 'false'});
      list.add({'id': 'node_02', 'name': 'Nó 02 (Field Node)', 'blocked': 'false'});
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final controllers = _getAvailableControllers();

    return AlertDialog(
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTokens.line, width: 1.0),
      ),
      title: Row(
        children: [
          Icon(Icons.hub_outlined, color: AppTokens.focus, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Controlador do Rung ${(widget.originalIndex + 1).toString().padLeft(4, '0')}',
              style: TextStyle(
                  color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecione qual controlador físico é responsável por executar a lógica deste rung:',
              style: TextStyle(color: AppTokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Mode Selector: Reatribuir vs Clonar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTokens.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isCloningMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isCloningMode ? AppTokens.panel : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'Reatribuir Rung',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  !_isCloningMode ? FontWeight.bold : FontWeight.normal,
                              color: !_isCloningMode
                                  ? AppTokens.textPrimary
                                  : AppTokens.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _isCloningMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _isCloningMode ? AppTokens.panel : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'Clonar para Outro Nó',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  _isCloningMode ? FontWeight.bold : FontWeight.normal,
                              color: _isCloningMode
                                  ? AppTokens.textPrimary
                                  : AppTokens.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Controllers Radio List
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTokens.line),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: controllers.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AppTokens.line, height: 1),
                itemBuilder: (context, idx) {
                  final c = controllers[idx];
                  final isBlocked = c['blocked'] == 'true';
                  final isSelected = _selectedControllerId == c['id'];

                  return InkWell(
                    onTap: () {
                      if (isBlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFEF4444),
                            content: Text(
                              'Intertravamento Técnico: Gateway Dedicado (Perfil 4) não executa lógicas Ladder locais. Aloque este Rung em um Nó de Campo.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedControllerId = c['id']!;
                        _selectedControllerName = c['name'];
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isBlocked
                                ? Icons.lock
                                : (isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                            size: 16,
                            color: isBlocked
                                ? const Color(0xFFEF4444)
                                : (isSelected ? AppTokens.focus : AppTokens.muted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c['name']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isBlocked
                                    ? const Color(0xFFEF4444)
                                    : (isSelected
                                        ? AppTokens.textPrimary
                                        : AppTokens.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: AppTokens.muted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCloningMode ? const Color(0xFF10B981) : AppTokens.focus,
            foregroundColor: AppTokens.bg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(_isCloningMode ? Icons.copy : Icons.check, size: 14),
          label: Text(
            _isCloningMode ? 'Clonar Rung' : 'Aplicar',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (_selectedControllerId == 'GATEWAY' && (widget.networkManager?.isExclusiveGateway ?? false)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFFEF4444),
                  content: Text('Intertravamento: O Gateway Dedicado não pode receber lógicas Ladder.'),
                ),
              );
              return;
            }
            final name = _selectedControllerName ?? _selectedControllerId;
            if (_isCloningMode) {
              widget.onCloned(_selectedControllerId, name);
            } else {
              widget.onReassigned(_selectedControllerId, name);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
