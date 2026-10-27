import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/studio_event_bus.dart';

enum TerminalFilter { all, kernel, network, errors }

class IndustrialTerminalDrawer extends StatefulWidget {
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback? onClose;

  const IndustrialTerminalDrawer({
    super.key,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.onClose,
  });

  @override
  State<IndustrialTerminalDrawer> createState() => _IndustrialTerminalDrawerState();
}

class _IndustrialTerminalDrawerState extends State<IndustrialTerminalDrawer> {
  late bool _isExpanded;
  TerminalFilter _currentFilter = TerminalFilter.all;
  bool _autoScroll = true;
  bool _isPaused = false;

  final ScrollController _scrollController = ScrollController();
  StreamSubscription<StudioEvent>? _eventSubscription;
  List<StudioEvent> _cachedEvents = [];

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _cachedEvents = List.of(StudioEventBus.instance.events);

    _eventSubscription = StudioEventBus.instance.stream.listen((event) {
      if (!mounted || _isPaused) return;
      setState(() {
        _cachedEvents = List.of(StudioEventBus.instance.events);
      });
      if (_autoScroll && _isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
    if (_isExpanded && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  List<StudioEvent> get _filteredEvents {
    // Note: StudioEventBus.events is reversed (latest first).
    // In the console, we display chronological order (oldest to newest, scrolling down).
    final chronological = _cachedEvents.reversed.toList();
    switch (_currentFilter) {
      case TerminalFilter.all:
        return chronological;
      case TerminalFilter.kernel:
        return chronological
            .where((e) =>
                e.type.toUpperCase().contains('KERNEL') ||
                e.source.toUpperCase().contains('KERNEL') ||
                e.source.toUpperCase().contains('CORE') ||
                e.type.toUpperCase().contains('SYSTEM'))
            .toList();
      case TerminalFilter.network:
        return chronological
            .where((e) =>
                e.type.toUpperCase().contains('NET') ||
                e.source.toUpperCase().contains('NET') ||
                e.type.toUpperCase().contains('HTTP') ||
                e.type.toUpperCase().contains('SYNC') ||
                e.type.toUpperCase().contains('TELEMETRY'))
            .toList();
      case TerminalFilter.errors:
        return chronological
            .where((e) =>
                e.severity == EventSeverity.critical ||
                e.severity == EventSeverity.warning)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: _isExpanded ? 190.0 : 26.0,
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        border: Border(
          top: BorderSide(
            color: _isExpanded ? const Color(0xFF0284C7).withValues(alpha: 0.5) : const Color(0xFF353B4A),
            width: 1.0,
          ),
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Control Bar / Header
          _buildControlBar(context),
          // Expanded Log Console
          if (_isExpanded)
            Expanded(
              child: _buildConsoleBody(context),
            ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    final latestEvent = _cachedEvents.isNotEmpty ? _cachedEvents.first : null;

    return Container(
      height: 25.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      color: const Color(0xFF252A36),
      child: Row(
        children: [
          // Left: clickable expand toggle + title
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 13,
                  color: _isExpanded ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                const Text(
                  'TERMINAL',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B303C),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF353B4A), width: 1.0),
                  ),
                  child: Text(
                    '${_cachedEvents.length}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Pulse live indicator
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isPaused ? const Color(0xFFEAB308) : const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isPaused ? const Color(0xFFEAB308) : const Color(0xFF22C55E)).withValues(alpha: 0.6),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Middle: In collapsed state, show preview of latest log.
          // In expanded state, show filter chips with horizontal scroll to prevent overflow.
          Expanded(
            child: !_isExpanded
                ? InkWell(
                    onTap: _toggleExpanded,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: latestEvent != null
                          ? Text(
                              '[${latestEvent.timeFormatted}] ${latestEvent.message}',
                              style: TextStyle(
                                color: _colorForSeverity(latestEvent.severity).withValues(alpha: 0.85),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Text(
                              'Nenhum evento registrado',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip('TODOS', TerminalFilter.all),
                        _buildFilterChip('KERNEL', TerminalFilter.kernel),
                        _buildFilterChip('REDE', TerminalFilter.network),
                        _buildFilterChip('FALHAS', TerminalFilter.errors),
                      ],
                    ),
                  ),
          ),

          // Right: Action buttons
          if (_isExpanded) ...[
            // Auto scroll toggle
            IconButton(
              icon: Icon(
                Icons.vertical_align_bottom_rounded,
                size: 14,
                color: _autoScroll ? const Color(0xFF0EA5E9) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: _autoScroll ? 'Auto-scroll Ativo' : 'Auto-scroll Pausado',
              onPressed: () {
                setState(() => _autoScroll = !_autoScroll);
              },
            ),
            // Pause/Play stream
            IconButton(
              icon: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 14,
                color: _isPaused ? const Color(0xFFEAB308) : const Color(0xFF8C98A8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: _isPaused ? 'Retomar Logs' : 'Congelar Logs',
              onPressed: () {
                setState(() => _isPaused = !_isPaused);
              },
            ),
            // Clear logs
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: Color(0xFF8C98A8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Limpar Histórico',
              onPressed: () {
                StudioEventBus.instance.clear();
                setState(() {
                  _cachedEvents = [];
                });
              },
            ),
          ],

          // Expand/collapse chevron
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
              size: 16,
              color: const Color(0xFF8C98A8),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: _isExpanded ? 'Recolher Terminal' : 'Expandir Terminal',
            onPressed: _toggleExpanded,
          ),

          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Ocultar Barra',
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TerminalFilter filter) {
    final isSelected = _currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: InkWell(
        onTap: () {
          setState(() => _currentFilter = filter);
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B303C) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF353B4A),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'monospace',
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleBody(BuildContext context) {
    final filtered = _filteredEvents;

    if (filtered.isEmpty) {
      return Container(
        color: const Color(0xFF1E222B),
        alignment: Alignment.center,
        child: const Text(
          'Nenhum evento registrado no filtro selecionado.',
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 11,
            fontFamily: 'monospace',
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E222B),
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final ev = filtered[index];
            final color = _colorForSeverity(ev.severity);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${ev.timeFormatted}] ',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6.0),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: _colorForSource(ev.source).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      ev.source,
                      style: TextStyle(
                        color: _colorForSource(ev.source),
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ev.message,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorForSeverity(EventSeverity severity) {
    switch (severity) {
      case EventSeverity.critical:
        return const Color(0xFFF87171); // Red
      case EventSeverity.warning:
        return const Color(0xFFFBBF24); // Amber
      case EventSeverity.info:
        return const Color(0xFFE2E8F0); // Crisp light slate
    }
  }

  Color _colorForSource(String source) {
    final s = source.toUpperCase();
    if (s.contains('KERNEL') || s.contains('CORE')) return const Color(0xFF34D399); // Emerald
    if (s.contains('NET') || s.contains('HTTP')) return const Color(0xFF38BDF8); // Sky blue
    if (s.contains('TELEMETRY') || s.contains('SYNC')) return const Color(0xFFA78BFA); // Purple
    if (s.contains('SESSION') || s.contains('AUTH')) return const Color(0xFFF472B6); // Pink
    return const Color(0xFF94A3B8); // Slate
  }
}
