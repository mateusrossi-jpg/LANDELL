import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/tag_value.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class TelemetryData {
  final int scanTimeMs;
  final int avgScanTimeMs;
  final double cpuUsage;
  final double packetLoss;
  final int latencyMs;
  final int packetsReceived;

  const TelemetryData({
    required this.scanTimeMs,
    required this.avgScanTimeMs,
    required this.cpuUsage,
    required this.packetLoss,
    required this.latencyMs,
    required this.packetsReceived,
  });
}

class RuntimeMonitorService extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  TelemetryData _telemetry = const TelemetryData(
    scanTimeMs: 0,
    avgScanTimeMs: 0,
    cpuUsage: 0.0,
    packetLoss: 0.0,
    latencyMs: 0,
    packetsReceived: 0,
  );

  final Map<String, TagValue> _remoteTagValues = {};
  final Map<String, bool> _forcedTags = {}; // tagId -> value

  Timer? _updateTimer;
  Timer? _reconnectTimer;
  String? _lastAddress;
  int _consecutiveLosses = 0;
  int _totalPacketsSent = 0;
  int _totalPacketsReceived = 0;
  final math.Random _random = math.Random();

  ConnectionStatus get status => _status;
  TelemetryData get telemetry => _telemetry;
  Map<String, TagValue> get remoteTagValues => _remoteTagValues;
  Map<String, bool> get forcedTags => _forcedTags;

  void connect(String address) {
    _lastAddress = address;
    _status = ConnectionStatus.connecting;
    notifyListeners();

    // Simulate link negotiation latency
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_status == ConnectionStatus.connecting) {
        _status = ConnectionStatus.connected;
        _consecutiveLosses = 0;
        _startUpdateLoop();
        notifyListeners();
      }
    });
  }

  void disconnect() {
    _status = ConnectionStatus.disconnected;
    _updateTimer?.cancel();
    _reconnectTimer?.cancel();
    _forcedTags.clear();
    _remoteTagValues.clear();
    notifyListeners();
  }

  void setForce(String tagId, bool value) {
    if (_status != ConnectionStatus.connected) return;
    _forcedTags[tagId] = value;
    _remoteTagValues[tagId] = TagValue.boolean(value);
    notifyListeners();
  }

  void clearForce(String tagId) {
    _forcedTags.remove(tagId);
    notifyListeners();
  }

  void _startUpdateLoop() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_status != ConnectionStatus.connected) {
        timer.cancel();
        return;
      }

      _totalPacketsSent++;

      // Simulate occasional communication drop / packet loss (e.g., 2% chance in field)
      final isPacketLost = _random.nextDouble() < 0.02;
      if (isPacketLost) {
        _consecutiveLosses++;
        if (_consecutiveLosses >= 5) {
          // Trigger drop and auto-reconnect
          _handleConnectionLoss();
        }
        return;
      }

      _consecutiveLosses = 0;
      _totalPacketsReceived++;

      // Simulate telemetry parameters
      final int scanTime = 2 + _random.nextInt(4); // 2-5 ms scan time
      final int latency = 15 + _random.nextInt(20); // 15-35 ms latency
      final double cpu = 12.0 + _random.nextDouble() * 5.0; // 12-17% CPU usage
      final double loss = (_totalPacketsSent - _totalPacketsReceived) / _totalPacketsSent * 100.0;

      _telemetry = TelemetryData(
        scanTimeMs: scanTime,
        avgScanTimeMs: 3,
        cpuUsage: cpu,
        packetLoss: loss,
        latencyMs: latency,
        packetsReceived: _totalPacketsReceived,
      );

      // Simulate remote variables toggling dynamically to mimic real PLC inputs (e.g. sensor pulse, toggling state)
      _remoteTagValues.forEach((key, value) {
        if (!_forcedTags.containsKey(key)) {
          // If the tag is an input sensor, simulate periodic pulsing every 3 seconds
          if (key.startsWith('I') || key.startsWith('IN') || key.startsWith('SENSOR')) {
            final cycle = (DateTime.now().millisecondsSinceEpoch ~/ 3000) % 2 == 0;
            _remoteTagValues[key] = TagValue.boolean(cycle);
          }
        }
      });

      notifyListeners();
    });
  }

  void _handleConnectionLoss() {
    _status = ConnectionStatus.disconnected;
    _updateTimer?.cancel();
    notifyListeners();

    // Trigger auto-reconnect cycle
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_status == ConnectionStatus.disconnected && _lastAddress != null) {
        connect(_lastAddress!);
      } else {
        timer.cancel();
      }
    });
  }

  // Pre-load tags for remote telemetry simulation
  void initializeRemoteTags(List<String> tagIds) {
    for (final tag in tagIds) {
      _remoteTagValues.putIfAbsent(tag, () => TagValue.boolean(false));
    }
  }
}
