import 'dart:async';

enum EventSeverity { info, warning, critical }

class StudioEvent {
  final DateTime timestamp;
  final String type;
  final String source;
  final String message;
  final EventSeverity severity;

  StudioEvent({
    DateTime? timestamp,
    required this.type,
    required this.source,
    required this.message,
    this.severity = EventSeverity.info,
  }) : timestamp = timestamp ?? DateTime.now();

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get severityLabel {
    switch (severity) {
      case EventSeverity.info:
        return 'INFO';
      case EventSeverity.warning:
        return 'WARNING';
      case EventSeverity.critical:
        return 'CRITICAL';
    }
  }
}

class StudioEventBus {
  static final StudioEventBus instance = StudioEventBus._();
  StudioEventBus._() {
    // Initial system event
    emit(
      type: 'SYSTEM',
      source: 'ENDAP_CORE',
      message: 'STUDIO INICIALIZADO • RUNTIME PRONTO',
      severity: EventSeverity.info,
    );
  }

  final List<StudioEvent> _history = [];
  final StreamController<StudioEvent> _controller = StreamController<StudioEvent>.broadcast();

  List<StudioEvent> get events => List.unmodifiable(_history.reversed);
  Stream<StudioEvent> get stream => _controller.stream;

  void emit({
    required String type,
    required String source,
    required String message,
    EventSeverity severity = EventSeverity.info,
  }) {
    final event = StudioEvent(
      type: type,
      source: source,
      message: message,
      severity: severity,
    );
    _history.add(event);
    if (_history.length > 200) {
      _history.removeAt(0);
    }
    _controller.add(event);
  }

  void clear() {
    _history.clear();
  }
}
