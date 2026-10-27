import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';
import 'package:endap_studio/features/gpio_tags/ui/gpio_tags_page.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  testWidgets('GpioTagsPage lista canais do hardware e associa a tags', (tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/io/map') {
        return http.Response(
          json.encode({
            'inputs': [
              {'channel_id': 10, 'name': 'IN1', 'type': 'digital_input', 'gpio': 16, 'state': 1},
            ],
            'outputs': [
              {'channel_id': 101, 'name': 'OUT2', 'type': 'digital_output', 'gpio': 4, 'reported': 0, 'physical_present': true},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final gpioService = GpioService(client: mockClient);
    final nm = NetworkManager(client: mockClient);
    final project = LadderProject(
      id: 'test_p',
      name: 'Test Project',
      tags: {
        'AQUECEDOR': Tag(
          id: 'AQUECEDOR',
          name: 'AQUECEDOR',
          type: TagType.bool,
          address: 'GPIO4',
          description: 'Aquecimento do terrário',
        ),
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: GpioTagsPage(
        networkManager: nm,
        project: project,
        gpioService: gpioService,
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('MAPEAMENTO GPIO & TAGS'), findsOneWidget);
    expect(find.text('GPIO 16'), findsOneWidget);
    expect(find.text('GPIO 4'), findsOneWidget);
    expect(find.text('AQUECEDOR'), findsOneWidget);
  });
}
