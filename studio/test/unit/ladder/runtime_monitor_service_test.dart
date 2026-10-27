import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/runtime/runtime_monitor_service.dart';

void main() {
  group('RuntimeMonitorService Tests', () {
    late RuntimeMonitorService service;

    setUp(() {
      service = RuntimeMonitorService();
    });

    tearDown(() {
      service.disconnect();
    });

    test('initial status is disconnected', () {
      expect(service.status, equals(ConnectionStatus.disconnected));
      expect(service.forcedTags.isEmpty, isTrue);
    });

    test('connect status transitions to connecting then connected', () async {
      service.connect('192.168.1.50');
      expect(service.status, equals(ConnectionStatus.connecting));

      // Wait for mock connection latency (800ms)
      await Future.delayed(const Duration(milliseconds: 900));
      expect(service.status, equals(ConnectionStatus.connected));
    });

    test('setForce adds variable to forced table and clears correctly', () async {
      service.connect('192.168.1.50');
      await Future.delayed(const Duration(milliseconds: 900));

      service.setForce('I0.0', true);
      expect(service.forcedTags['I0.0'], isTrue);
      expect(service.remoteTagValues['I0.0']?.boolValue, isTrue);

      service.clearForce('I0.0');
      expect(service.forcedTags.containsKey('I0.0'), isFalse);
    });

    test('disconnect clears all forced values and status', () async {
      service.connect('192.168.1.50');
      await Future.delayed(const Duration(milliseconds: 900));

      service.setForce('M0.0', true);
      expect(service.forcedTags['M0.0'], isTrue);

      service.disconnect();
      expect(service.status, equals(ConnectionStatus.disconnected));
      expect(service.forcedTags.isEmpty, isTrue);
    });
  });
}
