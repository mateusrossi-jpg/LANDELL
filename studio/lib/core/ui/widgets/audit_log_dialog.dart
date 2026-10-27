import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../services/network_manager.dart';
import '../../services/studio_event_bus.dart';

class AuditLogDialog extends StatefulWidget {
  final NetworkManager? networkManager;

  const AuditLogDialog({super.key, this.networkManager});

  static Future<void> show(BuildContext context, {NetworkManager? networkManager}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AuditLogDialog(networkManager: networkManager),
    );
  }

  @override
  State<AuditLogDialog> createState() => _AuditLogDialogState();
}

class _AuditLogDialogState extends State<AuditLogDialog> {
  String _selectedSeverityFilter = 'TODOS';
  bool _isSyncingHardware = false;

  @override
  void initState() {
    super.initState();
    if (widget.networkManager?.isHardwareOnline == true) {
      widget.networkManager?.fetchHardwareAuditLogs();
    }
  }

  Future<void> _syncHardware() async {
    if (widget.networkManager == null || !widget.networkManager!.isHardwareOnline) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Controlador offline: conecte ao hardware para sincronizar logs do ESP32.'),
          backgroundColor: AppTokens.panel2,
        ),
      );
      return;
    }
    setState(() => _isSyncingHardware = true);
    final count = (await widget.networkManager!.fetchHardwareAuditLogs()).length;
    if (mounted) {
      setState(() => _isSyncingHardware = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sincronizados $count eventos de auditoria do hardware ESP32.'),
          backgroundColor: AppTokens.run,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTokens.panel2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                          ),
                          child: const Icon(Icons.history_edu, color: AppTokens.focus, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRILHA DE AUDITORIA & EVENTOS',
                                style: TextStyle(
                                  color: AppTokens.text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Registro cronológico de ações, autenticações e comandos do Studio',
                                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTokens.textDim, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Barra de filtros por severidade
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterTab('TODOS', null),
                    const SizedBox(width: 6),
                    _buildFilterTab('INFO', EventSeverity.info),
                    const SizedBox(width: 6),
                    _buildFilterTab('AVISOS', EventSeverity.warning),
                    const SizedBox(width: 6),
                    _buildFilterTab('CRÍTICOS', EventSeverity.critical),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.focus,
                        side: BorderSide(color: AppTokens.focus.withValues(alpha: 0.5), width: 1.0),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSyncingHardware
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.focus))
                          : const Icon(Icons.sync, size: 16),
                      label: const Text('Sincronizar ESP32', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      onPressed: _isSyncingHardware ? null : _syncHardware,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.textDim,
                        side: const BorderSide(color: AppTokens.line, width: 1.0),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                      label: const Text('Limpar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        StudioEventBus.instance.clear();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTokens.line, height: 1),
              const SizedBox(height: 12),

              // Lista de Eventos
              Expanded(
                child: StreamBuilder<StudioEvent>(
                  stream: StudioEventBus.instance.stream,
                  builder: (context, _) {
                    var events = StudioEventBus.instance.events;
                    if (_selectedSeverityFilter == 'INFO') {
                      events = events.where((e) => e.severity == EventSeverity.info).toList();
                    } else if (_selectedSeverityFilter == 'AVISOS') {
                      events = events.where((e) => e.severity == EventSeverity.warning).toList();
                    } else if (_selectedSeverityFilter == 'CRÍTICOS') {
                      events = events.where((e) => e.severity == EventSeverity.critical).toList();
                    }

                    if (events.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.event_note, color: AppTokens.line, size: 40),
                            SizedBox(height: 10),
                            Text(
                              'Nenhum evento registrado nesta categoria.',
                              style: TextStyle(color: AppTokens.textDim, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final evt = events[index];
                        final Color badgeColor;
                        switch (evt.severity) {
                          case EventSeverity.info:
                            badgeColor = AppTokens.focus;
                            break;
                          case EventSeverity.warning:
                            badgeColor = AppTokens.warn;
                            break;
                          case EventSeverity.critical:
                            badgeColor = AppTokens.fault;
                            break;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTokens.panel2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTokens.line, width: 1.0),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isCompact = constraints.maxWidth < 640;
                              if (isCompact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          evt.timeFormatted,
                                          style: const TextStyle(
                                            color: AppTokens.textDim,
                                            fontSize: 10.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: badgeColor, width: 0.8),
                                          ),
                                          child: Text(
                                            evt.severityLabel,
                                            style: TextStyle(
                                              color: badgeColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTokens.background,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppTokens.line, width: 1.0),
                                            ),
                                            child: Text(
                                              '${evt.type} · ${evt.source}',
                                              style: const TextStyle(
                                                color: AppTokens.text,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      evt.message,
                                      style: const TextStyle(
                                        color: AppTokens.text,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Horário
                                  Text(
                                    evt.timeFormatted,
                                    style: const TextStyle(
                                      color: AppTokens.textDim,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Severidade Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: badgeColor, width: 0.8),
                                    ),
                                    child: Text(
                                      evt.severityLabel,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Fonte / Categoria
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTokens.background,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTokens.line, width: 1.0),
                                      ),
                                      child: Text(
                                        '${evt.type} · ${evt.source}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTokens.text,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Mensagem
                                  Expanded(
                                    child: Text(
                                      evt.message,
                                      style: const TextStyle(
                                        color: AppTokens.text,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, EventSeverity? severity) {
    final isSelected = _selectedSeverityFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedSeverityFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTokens.focus.withValues(alpha: 0.15)
              : AppTokens.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTokens.focus : AppTokens.line,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTokens.focus : AppTokens.textDim,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
