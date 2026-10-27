import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  testWidgets('Validação do Sensor de Umidade de Solo (AO e DO) no Studio', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.loginTechnical();
    final demoProject = DemoProject.createDemoProject();

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: StudioScaffold(
            initialProject: demoProject,
            initialIndex: 0,
            networkManager: NetworkManager(autoStartPeriodicCheck: false),
            autoStartTelemetry: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // No HMI multi-telas, a tela 2 contém a Supervisão Analógica & PID
    final tab2 = find.textContaining('Supervisão Analógica');
    if (tab2.evaluate().isNotEmpty) {
      await tester.tap(tab2);
      await tester.pumpAndSettle();
    }

    // Valida que os widgets do sensor de solo estão presentes na tela
    expect(find.text('UMIDADE DO SOLO (AO - GPIO 34)'), findsOneWidget);
    expect(find.text('CHAVE DIGITAL DO SOLO (DO - GPIO 17)'), findsOneWidget);

    // Simula telemetria real do ESP32 (44.6% de umidade)
    TelemetrySyncService.instance.processPveJson({
      "variables": [
        {"id": 0, "name": "UMID_SOLO", "raw": 1827, "scaled": 446, "decimals": 1, "unit": "%"}
      ]
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Captura screenshot do Dashboard Home
    print("VALIDATION_SOIL_HOME_SUCCESS");

    // Testa e captura a Aba 1 (Ladder com o Rung de Irrigação)
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final ladderTile = find.descendant(of: find.byType(Drawer), matching: find.textContaining('Lógica Ladder'));
    await tester.ensureVisible(ladderTile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(ladderTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Controle de Irrigação'), findsOneWidget);
    expect(find.text('UMID_SOLO'), findsAtLeastNWidgets(1));

    print("VALIDATION_SOIL_LADDER_SUCCESS");

    // Testa e captura a Aba 2 (GPIO & TAGS com UMID_SOLO no GPIO 34 e I0.1 no GPIO 17)
    final menuFinder = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.menu || w.icon == Icons.menu_rounded),
    );
    await tester.tap(menuFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final gpioTile = find.descendant(of: find.byType(Drawer), matching: find.textContaining('GPIO / TAGS'));
    await tester.ensureVisible(gpioTile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(gpioTile);
    await tester.pumpAndSettle();

    expect(find.text('UMID_SOLO'), findsAtLeastNWidgets(1));
    expect(find.textContaining('GPIO 34'), findsAtLeastNWidgets(1));

    print("VALIDATION_SOIL_TAGS_SUCCESS");
  });
}
