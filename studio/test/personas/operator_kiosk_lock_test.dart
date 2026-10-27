import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/home_page.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomePage Kiosk Mode locks and exits with PIN 1234', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final nm = NetworkManager(autoStartPeriodicCheck: false);
    final project = LadderProject.blank();
    final runtime = LadderRuntime();

    bool kioskState = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return HomePage(
                project: project,
                runtime: runtime,
                networkManager: nm,
                initialKioskMode: kioskState,
                onKioskModeChanged: (val) {
                  setState(() => kioskState = val);
                },
                onTriggerEmergency: () {},
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Kiosk Exit button should be visible in kiosk mode
    final exitKioskBtn = find.byKey(const Key('btn_sair_kiosk'));
    expect(exitKioskBtn, findsOneWidget);

    // Tap to open PIN unlock dialog
    await tester.tap(exitKioskBtn);
    await tester.pumpAndSettle();

    // PIN dialog should be open
    expect(find.text('DESBLOQUEIO DE SEGURANÇA KIOSK'), findsOneWidget);

    // Enter wrong PIN: 9999
    await tester.enterText(find.byKey(const Key('kiosk_pin_field')), '9999');
    await tester.tap(find.byKey(const Key('kiosk_pin_submit_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('PIN incorreto'), findsOneWidget);

    // Enter correct PIN: 1234
    await tester.enterText(find.byKey(const Key('kiosk_pin_field')), '1234');
    await tester.tap(find.byKey(const Key('kiosk_pin_submit_button')));
    await tester.pumpAndSettle();

    // Dialog should be dismissed and kiosk mode exited
    expect(find.text('DESBLOQUEIO DE SEGURANÇA KIOSK'), findsNothing);
    expect(find.byKey(const Key('btn_sair_kiosk')), findsNothing);
    expect(find.byKey(const Key('btn_modo_kiosk')), findsOneWidget);
  });
}
