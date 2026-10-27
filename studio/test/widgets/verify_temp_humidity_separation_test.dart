import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/features/gpio_tags/ui/widgets/analog_calibration_dialog.dart';

void main() {
  testWidgets('Valida diálogo de calibração para Temperatura e Umidade separadamente', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Teste 1: Tag de Temperatura
    final tempTag = Tag(
      id: 'TEMP_AHT10',
      name: 'TEMP_AHT10',
      type: TagType.real,
      address: '%IW0.0',
      unit: '°C',
      description: 'Temperatura Ambiente',
      calOffset: 0.0,
      calGain: 1.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AnalogCalibrationDialog(
            tag: tempTag,
            liveValue: 18.0,
            gatewayUrl: 'http://192.168.0.27',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verificações Temperatura
    expect(find.text('Ajuste de Temperatura'), findsOneWidget);
    expect(find.byIcon(Icons.thermostat), findsOneWidget);
    expect(find.text('Qual a temperatura real agora?'), findsOneWidget);
    expect(find.text('18.0 °C'), findsNWidgets(2)); // Leitura e corrigido

    // Teste 2: Tag de Umidade
    final humTag = Tag(
      id: 'UMID_AHT10',
      name: 'UMID_AHT10',
      type: TagType.real,
      address: '%IW0.1',
      unit: '%',
      description: 'Umidade Relativa',
      calOffset: 0.0,
      calGain: 1.0,
    );

    final keyHum = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            key: keyHum,
            child: AnalogCalibrationDialog(
              tag: humTag,
              liveValue: 42.0,
              gatewayUrl: 'http://192.168.0.27',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verificações Umidade
    expect(find.text('Ajuste de Umidade Relativa'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.text('Qual a umidade real agora?'), findsOneWidget);
    expect(find.text('42.0 %'), findsNWidgets(2));

    // Renderiza screenshot do modal de umidade (apenas se nao estiver em teste headless)
    // final boundary = keyHum.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // final image = await boundary.toImage(pixelRatio: 1.0);
    // final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    // image.dispose();
    // File('/home/mateus/.gemini/antigravity-cli/brain/37e08256-6a47-4fbd-8bc5-ab26f232a7eb/modal_calibration_humidity.png')
    //     .writeAsBytesSync(byteData!.buffer.asUint8List());

    print("VERIFICAÇÃO CONCLUÍDA COM SUCESSO: TEMPERATURA E UMIDADE TOTALMENTE SEPARADOS!");
  });
}
