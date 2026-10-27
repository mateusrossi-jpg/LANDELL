
import 'dart:async';

typedef ScanCallback = void Function(int deltaTimeMs);

class ScanScheduler {
  Timer? _timer;
  int _intervalMs;
  int _lastTickMs = 0;
  bool _isRunning = false;

// ignore: prefer_initializing_formals
  ScanScheduler({this._intervalMs = 100});

  void setInterval(int intervalMs) {
    _intervalMs = intervalMs;
    if (_isRunning) {
      stop();
      start(null);
    }
  }

  void start(ScanCallback? onScan) {
    if (_isRunning) return;
    _isRunning = true;
    _lastTickMs = DateTime.now().millisecondsSinceEpoch;

    _timer = Timer.periodic(Duration(milliseconds: _intervalMs), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dt = now - _lastTickMs;
      _lastTickMs = now;
      if (onScan != null) {
        onScan(dt);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  bool get isRunning => _isRunning;
}
