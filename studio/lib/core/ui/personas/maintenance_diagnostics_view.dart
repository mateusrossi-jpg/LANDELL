import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../auth/session_manager.dart';
import '../../services/network_manager.dart';
import '../../services/studio_event_bus.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/models/ladder_network.dart';
import '../../../ladder/models/ladder_node.dart';
import '../../../ladder/models/tag.dart';
import '../../../ladder/models/plc_tag_contract.dart';
import '../../../ladder/models/enums.dart';
import '../../../ladder/runtime/ladder_runtime.dart';
import '../../services/hardware_force_bridge.dart';

/// Tela de MANUTENÇÃO & DIAGNÓSTICO (Field Troubleshooting & Real I/O Forcing)
/// 100% conectada às TAGs do projeto, ao LadderRuntime e ao Hardware ESP32.
/// Responsiva para Telas Industriais e Celulares (iPhone XR)
class MaintenanceDiagnosticsView extends StatefulWidget {
  final NetworkManager networkManager;
  final LadderProject? project;
  final LadderRuntime? runtime;

  const MaintenanceDiagnosticsView({
    super.key,
    required this.networkManager,
    this.project,
    this.runtime,
  });

  @override
  State<MaintenanceDiagnosticsView> createState() => _MaintenanceDiagnosticsViewState();
}

class _MaintenanceDiagnosticsViewState extends State<MaintenanceDiagnosticsView> {
  Timer? _refreshTimer;
  String _filterType = 'TODOS';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Atualização em tempo real (100 ms) dos sinais do CLP
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Tag> get _allTags => widget.project?.tags.values.toList() ?? [];

  bool _isTagForced(Tag tag) {
    return widget.runtime?.tagStore.isForced(tag.id) ?? false;
  }

  int get _forcedCount => _allTags.where(_isTagForced).length;

  dynamic _getTagLiveValue(Tag tag) {
    final rt = widget.runtime;
    if (rt == null) return false;
    if (tag.type == TagType.bool) {
      return rt.tagStore.getBool(tag.id);
    } else if (tag.type == TagType.real) {
      return rt.tagStore.getReal(tag.id);
    } else {
      return rt.tagStore.getInt(tag.id);
    }
  }

  String _formatTagType(Tag tag) {
    final addr = tag.address ?? '';
    if (addr.startsWith('%I')) {
      return tag.type == TagType.bool ? 'DI' : 'AI';
    } else if (addr.startsWith('%Q')) {
      return tag.type == TagType.bool ? 'DO' : 'AO';
    } else if (addr.startsWith('%M')) {
      return 'MEM';
    }
    return tag.type.name.toUpperCase();
  }

  String _resolveGpioString(Tag tag) {
    final addr = tag.address;
    if (addr != null && addr.isNotEmpty) {
      final canon = PlcTagContract.normalizeAddress(addr);
      if (canon != null && PlcTagContract.hardwareGpios.containsKey(canon)) {
        return 'Hardware GPIO ${PlcTagContract.hardwareGpios[canon]}';
      }
    }
    if (tag.description != null && tag.description!.isNotEmpty) {
      return tag.description!;
    }
    return 'Lógica / Memória';
  }

  Future<void> _forceBool(Tag tag, bool value) async {
    final rt = widget.runtime;
    if (rt == null) return;
    final user = SessionManager.instance.currentUser ?? 'TÉCNICO';
    rt.tagStore.forceBool(tag.id, value);
    rt.singleScan(50);
    StudioEventBus.instance.emit(
      type: 'IO_FORCE',
      source: 'MANUTENÇÃO',
      message: 'FORÇAMENTO ATIVO: Tag ${tag.name} (${tag.address ?? tag.id}) FORÇADA para ${value ? "TRUE" : "FALSE"} por $user',
      severity: EventSeverity.warning,
    );

    // Envia forçamento real ao hardware (entradas e saídas via POST /api/io/force)
    await HardwareForceBridge.force(
      widget.networkManager,
      tag.address,
      value,
    );

    if (mounted) setState(() {});
  }

  Future<void> _unforceTag(Tag tag) async {
    final rt = widget.runtime;
    if (rt == null) return;
    final user = SessionManager.instance.currentUser ?? 'TÉCNICO';
    rt.tagStore.releaseForce(tag.id);
    rt.singleScan(50);
    StudioEventBus.instance.emit(
      type: 'IO_UNFORCE',
      source: 'MANUTENÇÃO',
      message: 'FORÇAMENTO LIBERADO: Tag ${tag.name} (${tag.address ?? tag.id}) por $user',
      severity: EventSeverity.info,
    );

    // Libera forçamento real no hardware via POST /api/io/force
    await HardwareForceBridge.release(
      widget.networkManager,
      tag.address,
    );

    if (mounted) setState(() {});
  }

  Future<void> _releaseAllForces() async {
    final rt = widget.runtime;
    if (rt == null) return;
    final user = SessionManager.instance.currentUser ?? 'TÉCNICO';
    rt.tagStore.releaseAllForces();
    rt.singleScan(50);
    StudioEventBus.instance.emit(
      type: 'IO_UNFORCE_ALL',
      source: 'MANUTENÇÃO',
      message: 'LIBERAÇÃO GERAL: Todos os canais forçados foram liberados por $user',
      severity: EventSeverity.warning,
    );

    // Libera todos os forçamentos reais no hardware em lote (POST /api/io/force release_all)
    await HardwareForceBridge.releaseAll(widget.networkManager);

    if (mounted) setState(() {});
  }

  bool _isNodeConducting(LadderNode node) {
    final rt = widget.runtime;
    if (rt == null) return false;
    final tagId = node.config.tagId;
    if (tagId == null || tagId.isEmpty) return false;
    final val = rt.tagStore.getBool(tagId);

    switch (node.type) {
      case NodeType.contactNO:
        return val == true;
      case NodeType.contactNC:
        return val == false;
      case NodeType.coil:
      case NodeType.coilSet:
      case NodeType.coilReset:
        return val == true;
      case NodeType.timerTON:
      case NodeType.timerTOF:
      case NodeType.counterCTU:
      case NodeType.counterCTD:
        return node.isConducting || node.isEnergized;
      default:
        return val == true;
    }
  }

  String _getNodeSymbol(LadderNode node) {
    switch (node.type) {
      case NodeType.contactNO:
        return '[ | | ]';
      case NodeType.contactNC:
        return '[ / ]';
      case NodeType.coil:
        return '(   )';
      case NodeType.coilSet:
        return '( S )';
      case NodeType.coilReset:
        return '( R )';
      case NodeType.timerTON:
        return '[ TON ]';
      case NodeType.timerTOF:
        return '[ TOF ]';
      case NodeType.counterCTU:
        return '[ CTU ]';
      case NodeType.counterCTD:
        return '[ CTD ]';
      default:
        return '[ ? ]';
    }
  }

  List<Tag> get _filteredTags {
    final query = _searchController.text.trim().toLowerCase();
    return _allTags.where((tag) {
      if (_filterType == 'FORÇADOS' && !_isTagForced(tag)) return false;
      final typeStr = _formatTagType(tag);
      if (_filterType == 'DI' && typeStr != 'DI') return false;
      if (_filterType == 'DO' && typeStr != 'DO') return false;
      if (_filterType == 'AI' && typeStr != 'AI') return false;
      if (_filterType == 'AO' && typeStr != 'AO') return false;

      if (query.isNotEmpty) {
        final matchName = tag.name.toLowerCase().contains(query);
        final matchAddr = (tag.address ?? '').toLowerCase().contains(query);
        final matchDesc = (tag.description ?? '').toLowerCase().contains(query);
        return matchName || matchAddr || matchDesc;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Container(
          color: IndustrialTokens.bgCanvas,
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            children: [
              if (_forcedCount > 0) _buildForcingAlertBanner(isMobile),
              if (_forcedCount > 0) const SizedBox(height: 12),
              Expanded(
                child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Layout Mobile (iPhone XR)
  Widget _buildMobileLayout() {
    final networks = widget.project?.networks ?? [];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Energy Flow (Visualizador Ladder Real)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IndustrialTokens.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: IndustrialTokens.runGreen, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE ENERGY FLOW',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${networks.length} RUNGS',
                      style: const TextStyle(color: IndustrialTokens.telemetryCyan, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (networks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'Nenhum diagrama Ladder carregado no projeto.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                else
                  ...networks.map((net) => _buildLiveLadderRung(net)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Forçamento de E/S
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IndustrialTokens.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: IndustrialTokens.progYellow, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'FORÇAMENTO DE E/S',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_forcedCount > 0)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: IndustrialTokens.progYellow,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _releaseAllForces,
                        child: const Text('LIBERAR TODOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_filteredTags.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'Nenhuma TAG física ou lógica cadastrada no projeto.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                else
                  ..._filteredTags.map((tag) => _buildMobileChannelCard(tag)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Layout Desktop
  Widget _buildDesktopLayout() {
    final networks = widget.project?.networks ?? [];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Coluna Esquerda: Live Energy Flow Monitor (Fluxo de Continuidade Real)
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: IndustrialTokens.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: IndustrialTokens.runGreen, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'LIVE ENERGY FLOW',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${networks.length} RUNGS • 1ms SCAN',
                      style: const TextStyle(color: IndustrialTokens.telemetryCyan, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Linhas verdes brilhantes indicam continuidade energizada ao vivo pelo motor do CLP.',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: networks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.account_tree_outlined, color: Colors.white24, size: 36),
                              SizedBox(height: 10),
                              Text(
                                'Nenhum diagrama Ladder carregado.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: networks.length,
                          itemBuilder: (ctx, i) => _buildLiveLadderRung(networks[i]),
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Coluna Direita: Forçamento de E/S Real
        Expanded(
          flex: 7,
          child: Container(
            decoration: BoxDecoration(
              color: IndustrialTokens.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: IndustrialTokens.progYellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TABELA DE FORÇAMENTO (${_allTags.length} TAGS)',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_forcedCount > 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IndustrialTokens.progYellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.lock_open, size: 14),
                        label: Text('LIBERAR TODOS ($_forcedCount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        onPressed: _releaseAllForces,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barra de Busca e Filtro de Tipo
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nome, endereço (%IX, %QX) ou GPIO...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                            filled: true,
                            fillColor: IndustrialTokens.bgCanvas,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildFilterChip('TODOS'),
                    const SizedBox(width: 4),
                    _buildFilterChip('DI'),
                    const SizedBox(width: 4),
                    _buildFilterChip('DO'),
                    const SizedBox(width: 4),
                    _buildFilterChip('FORÇADOS'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filteredTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.playlist_add_check, color: Colors.white24, size: 36),
                              SizedBox(height: 10),
                              Text(
                                'Nenhuma TAG corresponde aos filtros ativos.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredTags.length,
                          separatorBuilder: (ctx, index) => const Divider(color: IndustrialTokens.borderSubtle, height: 8),
                          itemBuilder: (ctx, i) => _buildDesktopChannelRow(_filteredTags[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterType == label;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _filterType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? IndustrialTokens.telemetryCyan.withValues(alpha: 0.2) : IndustrialTokens.bgCanvas,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? IndustrialTokens.telemetryCyan : IndustrialTokens.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? IndustrialTokens.telemetryCyan : Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildForcingAlertBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: IndustrialTokens.forceActiveBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IndustrialTokens.forceActiveBorder.withValues(alpha: 0.5), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: IndustrialTokens.forceActiveBorder, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATENÇÃO: $_forcedCount CANAL(IS) COM FORÇAMENTO DE HARDWARE ATIVO',
                  style: const TextStyle(color: IndustrialTokens.forceActiveText, fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const Text(
                  'As saídas e memórias forçadas ignoram a lógica ladder até serem liberadas pelo operador.',
                  style: TextStyle(color: IndustrialTokens.forceActiveText, fontSize: 9.5),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IndustrialTokens.forceActiveBorder,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: _releaseAllForces,
            child: const Text('LIBERAR TODOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileChannelCard(Tag tag) {
    final isForced = _isTagForced(tag);
    final val = _getTagLiveValue(tag);
    final typeStr = _formatTagType(tag);
    final isDO = typeStr == 'DO';
    final isBool = tag.type == TagType.bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isForced ? IndustrialTokens.progYellow.withValues(alpha: 0.6) : IndustrialTokens.borderSubtle,
          width: isForced ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDO ? const Color(0xFF1E2638) : const Color(0xFF132A24),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDO ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : IndustrialTokens.runGreen.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  tag.address ?? tag.id,
                  style: TextStyle(
                    color: isDO ? const Color(0xFF38BDF8) : IndustrialTokens.runGreen,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isForced)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: IndustrialTokens.progYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('FORÇADO', style: TextStyle(color: IndustrialTokens.progYellow, fontSize: 8.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _resolveGpioString(tag),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Valor: $val',
                style: TextStyle(
                  color: val == true ? IndustrialTokens.runGreen : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isBool)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: IndustrialTokens.runGreen,
                      side: const BorderSide(color: IndustrialTokens.runGreen),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () => _forceBool(tag, true),
                    child: const Text('FORÇAR ON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () => _forceBool(tag, false),
                    child: const Text('FORÇAR OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (isForced) ...[
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IndustrialTokens.progYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () => _unforceTag(tag),
                    child: const Text('LIBERAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopChannelRow(Tag tag) {
    final isForced = _isTagForced(tag);
    final val = _getTagLiveValue(tag);
    final typeStr = _formatTagType(tag);
    final isDO = typeStr == 'DO';
    final isBool = tag.type == TagType.bool;

    return Row(
      children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isDO ? const Color(0xFF1E2638) : const Color(0xFF132A24),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDO ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : IndustrialTokens.runGreen.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Text(
            tag.address ?? tag.id,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDO ? const Color(0xFF38BDF8) : IndustrialTokens.runGreen,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                '${_resolveGpioString(tag)} • $typeStr',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9.5, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: val == true ? IndustrialTokens.runGreen : Colors.white24,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$val',
                style: TextStyle(
                  color: val == true ? IndustrialTokens.runGreen : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (isBool) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: IndustrialTokens.runGreen,
              side: const BorderSide(color: IndustrialTokens.runGreen, width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () => _forceBool(tag, true),
            child: const Text('ON', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30, width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () => _forceBool(tag, false),
            child: const Text('OFF', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
        if (isForced)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IndustrialTokens.progYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            onPressed: () => _unforceTag(tag),
            child: const Text('LIBERAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildLiveLadderRung(LadderNetwork net) {
    final elements = net.nodes;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RUNG ${net.id}: ${net.name.isNotEmpty ? net.name : "Rede de Controle"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: net.isEnabled ? IndustrialTokens.runGreen.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  net.isEnabled ? 'SCAN ATIVO' : 'IGNORADO',
                  style: TextStyle(
                    color: net.isEnabled ? IndustrialTokens.runGreen : Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Power Rail Esquerdo
                Container(width: 4, height: 38, color: IndustrialTokens.runGreenGlow),
                Container(width: 16, height: 3, color: IndustrialTokens.runGreenGlow),
                if (elements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Rung sem instruções', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                  )
                else
                  ...elements.map((node) {
                    final isConducting = _isNodeConducting(node);
                    final color = isConducting ? IndustrialTokens.runGreenGlow : Colors.grey.shade700;
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isConducting ? IndustrialTokens.runGreen.withValues(alpha: 0.2) : IndustrialTokens.bgSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                node.config.tagId ?? node.type.name,
                                style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getNodeSymbol(node),
                                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 16, height: 3, color: color),
                      ],
                    );
                  }),
                // Return Rail Direito
                Container(width: 4, height: 38, color: IndustrialTokens.runGreenGlow),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
