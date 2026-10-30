import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/util/logger.dart';

void main() {
  group('SimpleLogger Unit Tests', () {
    test('can be instantiated as a const object', () {
      const logger1 = SimpleLogger();
      const logger2 = SimpleLogger();

      expect(logger1, isA<SimpleLogger>());
      expect(identical(logger1, logger2), isTrue);
    });

    test('log() prints message formatted with [LOG] prefix', () {
      final printLogs = <String>[];
      runZoned(
        () {
          const logger = SimpleLogger();
          logger.log('System initialized successfully');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printLogs.add(line);
          },
        ),
      );

      expect(printLogs, hasLength(1));
      expect(printLogs.first, equals('[LOG] System initialized successfully'));
    });

    test('log() handles empty string message correctly', () {
      final printLogs = <String>[];
      runZoned(
        () {
          const logger = SimpleLogger();
          logger.log('');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printLogs.add(line);
          },
        ),
      );

      expect(printLogs, hasLength(1));
      expect(printLogs.first, equals('[LOG] '));
    });

    test('log() handles multiline strings and special characters', () {
      final printLogs = <String>[];
      runZoned(
        () {
          const logger = SimpleLogger();
          logger.log('Status: OK\nPLC Address: I0.0 = 1\nTag: "PUMP_CTRL"');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printLogs.add(line);
          },
        ),
      );

      expect(printLogs, hasLength(1));
      expect(
        printLogs.first,
        equals('[LOG] Status: OK\nPLC Address: I0.0 = 1\nTag: "PUMP_CTRL"'),
      );
    });

    test('log() handles multiple log invocations in sequence', () {
      final printLogs = <String>[];
      runZoned(
        () {
          const logger = SimpleLogger();
          logger.log('First log');
          logger.log('Second log');
          logger.log('Third log');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printLogs.add(line);
          },
        ),
      );

      expect(printLogs, equals([
        '[LOG] First log',
        '[LOG] Second log',
        '[LOG] Third log',
      ]));
    });
  });
}
