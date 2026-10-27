import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';
import 'package:endap_studio/features/gpio_tags/ui/widgets/configure_pin_dialog.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  testWidgets('ConfigurePinDialog reorganiza tags dinamicamente para AHT10 e envia config de firmware', (tester) async {
    Map<String, dynamic>? lastPostedJson;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/sensors/config') {
        if (request.method == 'GET') {
          return http.Response(
            json.encode({
              'aht10_enabled': 0,
              'aht10_sda_gpio': 16,
              'aht10_scl_gpio': 17,
              'ds18b20_enabled': 0,
              'ds18b20_gpio': 18,
            }),
            200,
          );
        } else if (request.method == 'POST') {
          lastPostedJson = json.decode(request.body) as Map<String, dynamic>;
          return http.Response(json.encode({'status': 'ok'}), 200);
        }
      }
      return http.Response('{}', 404);
    });

    final gpioService = GpioService(client: mockClient);
    final project = LadderProject(
      id: 'proj1',
      name: 'Dynamic Tags Project',
      tags: {
        'DI_16': Tag(
          id: 'DI_16',
          name: 'DI_16',
          type: TagType.bool,
          address: '%IX0.0',
          description: 'Entrada digital botão',
        ),
      },
    );

    final pin = const GpioInventoryPin(
      gpio: 16,
      inputCapable: true,
      outputCapable: true,
      analogCapable: false,
      state: 'AVAILABLE',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ConfigurePinDialog.show(
                    context,
                    pin: pin,
                    project: project,
                    gatewayIp: '192.168.4.1',
                    gpioService: gpioService,
                    onConfigured: () {},
                  );
                },
                child: const Text('Configurar Pino'),
              );
            },
          ),
        ),
      ),
    );

    // Clica para abrir o modal
    await tester.tap(find.text('Configurar Pino'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIGURAR GPIO 16'), findsOneWidget);

    // Seleciona a opção Sensor I2C (AHT10 Temp & Umidade)
    await tester.tap(find.text('Sensor I2C (AHT10 Temp & Umidade)'));
    await tester.pumpAndSettle();

    // Aplica a configuração ao controlador
    await tester.tap(find.text('APLICAR AO CONTROLADOR'));
    await tester.pumpAndSettle();

    // Verifica que a tag antiga DI_16 associada ao GPIO 16 foi removida/substituída
    expect(project.tags.containsKey('DI_16'), isFalse);

    // Verifica que as novas tags de medição analógica foram criadas dinamicamente
    expect(project.tags.containsKey('TEMP_AHT10'), isTrue);
    expect(project.tags.containsKey('UMID_AHT10'), isTrue);
    expect(project.tags['TEMP_AHT10']!.type, equals(TagType.int));
    expect(project.tags['TEMP_AHT10']!.address, equals('%IW0.0'));
    expect(project.tags['UMID_AHT10']!.address, equals('%IW0.1'));

    // Verifica que a requisição de configuração foi disparada para o firmware
    expect(lastPostedJson, isNotNull);
    expect(lastPostedJson!['aht10_enabled'], equals(1));
    expect(lastPostedJson!['aht10_sda_gpio'], equals(16));
    expect(lastPostedJson!['aht10_scl_gpio'], equals(17));
  });
}
