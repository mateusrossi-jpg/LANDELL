import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';

void main() {
  test('Benchmark telemetry polling latency for multiple hosts', () async {
    final project = LadderProject(id: 'bench_proj', name: 'Benchmark Project');
    final runtime = LadderRuntime();
    final service = TelemetrySyncService.instance;
    service.init(project: project, runtime: runtime, gatewayIp: '192.168.0.10');
    service.updateControllerIps([
      '192.168.0.10',
      '192.168.0.11',
      '192.168.0.12',
    ]);

    const networkDelay = Duration(milliseconds: 200);

    service.httpClient = MockClient((request) async {
      await Future.delayed(networkDelay);
      return http.Response(jsonEncode({'inputs': [], 'outputs': []}), 200);
    });

    final stopwatch = Stopwatch()..start();
    final result = await service.pollOnce();
    stopwatch.stop();

    expect(result, isTrue);
    print(
      'BENCHMARK_RESULT: Polling latency = ${stopwatch.elapsedMilliseconds} ms',
    );
  });
}
