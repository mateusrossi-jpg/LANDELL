import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../auth/session_manager.dart';
import '../../services/network_manager.dart';
import '../../services/persona_config_service.dart';
import '../../services/studio_event_bus.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/models/tag.dart';
import '../../../ladder/runtime/ladder_runtime.dart';
import '../widgets/audit_log_dialog.dart';

/// Tela do GESTOR / SUPERVISOR INDUSTRIAL: Análise Real do Controlador, Frota de Nós e Auditoria
/// 100% conectada ao NetworkManager, TagStateStore e EventBus (Zero dados mockados).
/// Responsiva para Telas Industriais, Tablets e Celulares (iPhone XR)
class ManagerAnalyticsView extends StatefulWidget {
  final NetworkManager networkManager;
  final LadderProject? project;
  final LadderRuntime? runtime;

  const ManagerAnalyticsView({
    super.key,
    required this.networkManager,
    this.project,
    this.runtime,
  });

  @override
  State<ManagerAnalyticsView> createState() => _ManagerAnalyticsViewState();
}

class _ManagerAnalyticsViewState extends State<ManagerAnalyticsView> {
  ManagerAnalyticsConfig _config = ManagerAnalyticsConfig();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final loaded = await PersonaConfigService.instance.loadManagerConfig();
    if (mounted) {
      setState(() => _config = loaded);
    }
  }

  List<Tag> get _tags => widget.project?.tags.values.toList() ?? [];

  Tag? _findProductionTag() {
    for (final t in _tags) {
      final name = t.name.toLowerCase();
      if (name.contains('peca') || name.contains('prod') || name.contains('cont') || name.contains('count')) {
        return t;
      }
    }
    return null;
  }

  dynamic _getProductionValue(Tag tag) {
    final rt = widget.runtime;
    if (rt == null) return 0;
    return rt.tagStore.getInt(tag.id);
  }

  void _showConfigDialog() {
    final lineCtrl = TextEditingController(text: _config.lineName);
    final targetCtrl = TextEditingController(text: _config.targetPerHour.toString());
    final oeeCtrl = TextEditingController(text: _config.oeeTarget.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IndustrialTokens.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: IndustrialTokens.borderSubtle, width: 1.0),
        ),
        title: Row(
          children: const [
            Icon(Icons.tune, color: IndustrialTokens.telemetryCyan, size: 20),
            SizedBox(width: 10),
            Text(
              'Parâmetros da Célula de Produção',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identificação da célula e metas operacionais do controlador:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lineCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Identificação da Linha / Célula',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                    filled: true,
                    fillColor: IndustrialTokens.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Meta Nominal (peças/hora)',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                    filled: true,
                    fillColor: IndustrialTokens.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: oeeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Meta Alvo de Disponibilidade (%)',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                    filled: true,
                    fillColor: IndustrialTokens.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: IndustrialTokens.telemetryCyan,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Salvar Metas', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final newTarget = int.tryParse(targetCtrl.text.trim()) ?? _config.targetPerHour;
              final newOee = double.tryParse(oeeCtrl.text.trim()) ?? _config.oeeTarget;
              setState(() {
                _config.lineName = lineCtrl.text.trim().isEmpty ? 'CÉLULA 01' : lineCtrl.text.trim();
                _config.targetPerHour = newTarget;
                _config.oeeTarget = newOee;
              });
              await PersonaConfigService.instance.saveManagerConfig(_config);
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Parâmetros de gestão atualizados com sucesso.'),
                    backgroundColor: IndustrialTokens.bgSurface,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return Container(
          color: IndustrialTokens.bgCanvas,
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            children: [
              _buildExecutiveHeader(isMobile),
              const SizedBox(height: 12),
              Expanded(
                child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
              ),
            ],
          ),
        );
      },
    );
  }

  // 1. Cabeçalho Executivo
  Widget _buildExecutiveHeader(bool isMobile) {
    final isOnline = widget.networkManager.isHardwareOnline;
    final gatewayIp = widget.networkManager.gatewayIp;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: 7),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: IndustrialTokens.telemetryCyan, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAINEL DE OPERAÇÃO & GESTÃO DO CONTROLADOR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_config.lineName} • GATEWAY $gatewayIp • ${isOnline ? "HARDWARE ONLINE" : "EMULAÇÃO LOCAL"}',
                  style: TextStyle(
                    color: isOnline ? IndustrialTokens.runGreen : Colors.white60,
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (SessionManager.instance.isIntegrator) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.tune, color: IndustrialTokens.telemetryCyan, size: 20),
              tooltip: 'Configurar Metas da Célula',
              onPressed: _showConfigDialog,
            ),
          ],
        ],
      ),
    );
  }

  // Layout Mobile (iPhone XR)
  Widget _buildMobileLayout() {
    final isOnline = widget.networkManager.isHardwareOnline;
    final gatewayIp = widget.networkManager.gatewayIp;
    final scanUs = widget.runtime?.lastScanDurationUs ?? 0;
    final tags = _tags;
    final forcedCount = tags.where((t) => widget.runtime?.tagStore.isForced(t.id) ?? false).length;
    final totalNodes = widget.networkManager.nodes.isEmpty ? 1 : widget.networkManager.nodes.length;
    final prodTag = _findProductionTag();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricCard(
            title: 'ENLACE / HARDWARE',
            value: isOnline ? 'ONLINE' : 'LOCAL',
            meta: 'Gateway: $gatewayIp',
            icon: Icons.developer_board,
            accentColor: isOnline ? IndustrialTokens.runGreen : IndustrialTokens.telemetryCyan,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            title: 'DETERMINISMO (SCAN TIME)',
            value: scanUs > 0 ? '$scanUs µs' : '< 1.0 ms',
            meta: 'Loop determinístico alvo: 1.0 ms',
            icon: Icons.speed,
            accentColor: IndustrialTokens.runGreen,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            title: 'INVENTÁRIO DE E/S',
            value: '${tags.length} TAGs',
            meta: '$forcedCount canais com forçamento ativo',
            icon: Icons.tune,
            accentColor: forcedCount > 0 ? IndustrialTokens.progYellow : IndustrialTokens.runGreen,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            title: 'CONTROLADOR ENDAP',
            value: '$totalNodes Controlador(es)',
            meta: 'Modo Gateway Híbrido Local-First',
            icon: Icons.hub_outlined,
            accentColor: IndustrialTokens.infoBlue,
          ),
          if (prodTag != null) ...[
            const SizedBox(height: 8),
            _buildMetricCard(
              title: 'PRODUÇÃO REAL (TAG: ${prodTag.name})',
              value: '${_getProductionValue(prodTag)} pcs',
              meta: 'Meta Nominal: ${_config.targetPerHour * 8} pcs/turno',
              icon: Icons.check_circle_outline,
              accentColor: IndustrialTokens.runGreen,
            ),
          ],
          const SizedBox(height: 14),
          _buildClusterFleetCard(isMobile: true),
          const SizedBox(height: 14),
          _buildAuditLogCard(isMobile: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Layout Desktop
  Widget _buildDesktopLayout() {
    final isOnline = widget.networkManager.isHardwareOnline;
    final gatewayIp = widget.networkManager.gatewayIp;
    final scanUs = widget.runtime?.lastScanDurationUs ?? 0;
    final tags = _tags;
    final forcedCount = tags.where((t) => widget.runtime?.tagStore.isForced(t.id) ?? false).length;
    final totalNodes = widget.networkManager.nodes.isEmpty ? 1 : widget.networkManager.nodes.length;
    final prodTag = _findProductionTag();

    return Column(
      children: [
        // Linha Principal de Indicadores Reais do CLP
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildMetricCard(
                title: 'ENLACE / HARDWARE',
                value: isOnline ? 'ONLINE' : 'LOCAL',
                meta: 'Gateway: $gatewayIp',
                icon: Icons.developer_board,
                accentColor: isOnline ? IndustrialTokens.runGreen : IndustrialTokens.telemetryCyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildMetricCard(
                title: 'DETERMINISMO (SCAN)',
                value: scanUs > 0 ? '$scanUs µs' : '< 1.0 ms',
                meta: 'Loop determinístico: 1.0 ms',
                icon: Icons.speed,
                accentColor: IndustrialTokens.runGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildMetricCard(
                title: 'INVENTÁRIO DE E/S',
                value: '${tags.length} TAGs',
                meta: '$forcedCount forçamentos ativos',
                icon: Icons.tune,
                accentColor: forcedCount > 0 ? IndustrialTokens.progYellow : IndustrialTokens.runGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: prodTag != null
                  ? _buildMetricCard(
                      title: 'PRODUÇÃO (${prodTag.name})',
                      value: '${_getProductionValue(prodTag)} pcs',
                      meta: 'Meta: ${_config.targetPerHour * 8} pcs/turno',
                      icon: Icons.check_circle_outline,
                      accentColor: IndustrialTokens.runGreen,
                    )
                  : _buildMetricCard(
                      title: 'CONTROLADOR ENDAP',
                      value: '$totalNodes Controlador(es)',
                      meta: 'Modo Gateway Híbrido Local-First',
                      icon: Icons.hub_outlined,
                      accentColor: IndustrialTokens.infoBlue,
                    ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Grid Inferior: Frota Real e Auditoria Real
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _buildClusterFleetCard(),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _buildAuditLogCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String meta,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  meta,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterFleetCard({bool isMobile = false}) {
    final gatewayIp = widget.networkManager.gatewayIp;
    final isOnline = widget.networkManager.isHardwareOnline;
    final isExclusive = widget.networkManager.isExclusiveGateway;
    final fieldNodes = widget.networkManager.nodes.where((n) => n.controllerIndex > 0 && !n.role.toLowerCase().contains('gateway')).toList();

    final content = ListView(
      shrinkWrap: isMobile,
      physics: isMobile ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      children: [
        // Nó 0: Gateway Principal / Dedicado Real
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isOnline ? IndustrialTokens.runGreen : IndustrialTokens.telemetryCyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isExclusive ? 'GATEWAY DEDICADO (Roteador)' : 'GATEWAY PRINCIPAL (Híbrido)',
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(gatewayIp, style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (isOnline ? IndustrialTokens.runGreen : IndustrialTokens.telemetryCyan).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isExclusive ? 'DEDICADO' : (isOnline ? 'ONLINE' : 'LOCAL'),
                  style: TextStyle(
                    color: isOnline ? IndustrialTokens.runGreen : IndustrialTokens.telemetryCyan,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: IndustrialTokens.borderSubtle, height: 8),
        if (fieldNodes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nenhum nó de campo secundário conectado no cluster.\nPara adotar nós, use a aba Rede & Topologia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          )
        else
          ...fieldNodes.map((n) {
            final nodeOnline = n.status == NodeStatus.online;
            final nodeColor = nodeOnline ? IndustrialTokens.runGreen : IndustrialTokens.faultRed;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: nodeColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(n.id, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                  Text(n.ip, style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(color: nodeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text(n.status.name.toUpperCase(), style: TextStyle(color: nodeColor, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              const Icon(Icons.device_hub, color: IndustrialTokens.infoBlue, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'SAÚDE OPERACIONAL DO CONTROLADOR (ENDAP)',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: IndustrialTokens.infoBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${fieldNodes.length + 1} NÓS ATIVOS',
                  style: const TextStyle(color: IndustrialTokens.infoBlue, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isMobile)
            content
          else
            Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard({bool isMobile = false}) {
    final streamContent = StreamBuilder<StudioEvent>(
      stream: StudioEventBus.instance.stream,
      builder: (context, _) {
        final events = StudioEventBus.instance.events;
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nenhum evento registrado nesta sessão.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: isMobile,
          physics: isMobile ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          itemCount: isMobile ? (events.length > 5 ? 5 : events.length) : (events.length > 20 ? 20 : events.length),
          separatorBuilder: (ctx, index) => const Divider(color: IndustrialTokens.borderSubtle, height: 6),
          itemBuilder: (ctx, i) {
            final log = events[i];
            final Color color;
            switch (log.severity) {
              case EventSeverity.info:
                color = IndustrialTokens.telemetryCyan;
                break;
              case EventSeverity.warning:
                color = IndustrialTokens.progYellow;
                break;
              case EventSeverity.critical:
                color = IndustrialTokens.faultRed;
                break;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(log.timeFormatted, style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      log.source,
                      style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.message,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialTokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IndustrialTokens.borderSubtle, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: IndustrialTokens.runGreen, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'TRILHA DE AUDITORIA & EVENTOS REAIS',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: IndustrialTokens.telemetryCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: 12),
                label: const Text('Ver Completa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () => AuditLogDialog.show(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isMobile)
            streamContent
          else
            Expanded(child: streamContent),
        ],
      ),
    );
  }
}
