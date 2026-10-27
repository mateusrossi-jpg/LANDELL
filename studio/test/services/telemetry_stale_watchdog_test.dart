import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  test('TelemetrySyncService tracks lastTelemetryReceived and marks isStale after timeout', () async {
    final service = TelemetrySyncService.instance;
    final project = DemoProject.createDemoProject();
    final runtime = LadderRuntime();

    service.init(project: project, runtime: runtime);
    
    // Initial state before any telemetry: isStale should be true
    expect(service.isStale, isTrue);

    // Feed telemetry packet
    service.processIoMapJson({
      'inputs': [
        {'pin': 16, 'val': 1}
      ]
    });

    // Right after telemetry arrives, isStale should be false
    expect(service.isStale, isFalse);
    expect(service.lastTelemetryReceived, isNotNull);

    // Check with artificial past timestamp
    service.setLastTelemetryReceivedForTesting(DateTime.now().subtract(const Duration(seconds: 4)));
    expect(service.isStale, isTrue);
  });
}
