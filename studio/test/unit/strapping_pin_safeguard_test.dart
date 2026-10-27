import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/features/gpio_tags/ui/widgets/configure_pin_dialog.dart';
import 'package:endap_studio/features/gpio_tags/services/gpio_service.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';

void main() {
  testWidgets('ConfigurePinDialog shows warning banner for ESP32 strapping pins when output is selected', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final project = LadderProject.blank();
    const strappingPin = GpioInventoryPin(
      gpio: 12, // MTDI strapping pin
      state: 'AVAILABLE',
      analogCapable: false,
      outputCapable: true,
      inputCapable: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigurePinDialog(
            pin: strappingPin,
            project: project,
            gatewayIp: '192.168.4.1',
            gpioService: GpioService(),
            onConfigured: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on Saída Digital (DO)
    final outputRadio = find.textContaining('Saída Digital');
    expect(outputRadio, findsOneWidget);
    await tester.tap(outputRadio);
    await tester.pumpAndSettle();

    // Should display strapping pin warning banner
    expect(find.byKey(const Key('strapping_pin_warning_banner')), findsOneWidget);
    expect(find.textContaining('STRAPPING PIN'), findsOneWidget);
  });
}
