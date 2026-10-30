import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';

void main() {
  group('GpioService Unit Tests', () {
    test(
      'fetchHardwareChannels fetches gateway and remote nodes concurrently',
      () async {
        final requestedUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          // Add a small delay to simulate network latency
          await Future.delayed(const Duration(milliseconds: 50));

          if (request.url.path == '/api/io/map') {
            if (request.url.host == '192.168.1.1') {
              return http.Response(
                jsonEncode({
                  'node_id': 1,
                  'inputs': [
                    {
                      'channel_id': 10,
                      'name': 'I0.0',
                      'type': 'digital_input',
                      'gpio': 16,
                      'state': 1,
                      'implemented': true,
                    },
                  ],
                  'outputs': [
                    {
                      'channel_id': 100,
                      'name': 'Q0.0',
                      'type': 'digital_output',
                      'gpio': 4,
                      'state': 0,
                      'implemented': true,
                    },
                  ],
                }),
                200,
              );
            } else if (request.url.host == '192.168.1.2') {
              return http.Response(
                jsonEncode({
                  'node_id': 2,
                  'inputs': [
                    {
                      'channel_id': 10,
                      'name': 'I1.0',
                      'type': 'digital_input',
                      'gpio': 16,
                      'state': 0,
                      'implemented': true,
                    },
                  ],
                  'outputs': [
                    {
                      'channel_id': 100,
                      'name': 'Q1.0',
                      'type': 'digital_output',
                      'gpio': 4,
                      'state': 1,
                      'implemented': true,
                    },
                  ],
                }),
                200,
              );
            } else if (request.url.host == '192.168.1.3') {
              return http.Response(
                jsonEncode({
                  'node_id': 3,
                  'inputs': [
                    {
                      'channel_id': 10,
                      'name': 'I2.0',
                      'type': 'digital_input',
                      'gpio': 16,
                      'state': 1,
                      'implemented': true,
                    },
                  ],
                  'outputs': [],
                }),
                200,
              );
            }
          }
          return http.Response('Not Found', 404);
        });

        final gpioService = GpioService(client: mockClient);
        final nodes = [
          {
            'id': 'ENDAP-2',
            'ip': '192.168.1.2',
            'status': 'online',
            'controller_index': 1,
          },
          {
            'id': 'ENDAP-3',
            'ip': '192.168.1.3',
            'status': 'online',
            'controller_index': 2,
          },
        ];

        final Stopwatch stopwatch = Stopwatch()..start();
        final channels = await gpioService.fetchHardwareChannels(
          '192.168.1.1',
          nodes: nodes,
        );
        stopwatch.stop();

        expect(
          requestedUrls,
          containsAll([
            'http://192.168.1.1/api/io/map',
            'http://192.168.1.2/api/io/map',
            'http://192.168.1.3/api/io/map',
          ]),
        );

        // Verify channels were parsed and deduplicated properly
        expect(
          channels.length,
          equals(5),
        ); // Gateway (I0.0, Q0.0) + Node 2 (I1.0, Q1.0) + Node 3 (I2.0)

        print(
          'Execution time for 2 remote nodes (50ms delay each): ${stopwatch.elapsedMilliseconds} ms',
        );
      },
    );
  });
}
