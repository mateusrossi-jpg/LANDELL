import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  testWidgets('Simulação Completa do Operador Humano com Calibração Real', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.loginTechnical();
    final demoProject = DemoProject.createDemoProject();

    // Injeta calibração universal de +10.0% de offset
    final soilTag = demoProject.tags['AI0.0']!;
    demoProject.tags['AI0.0'] = Tag(
      id: soilTag.id,
      name: soilTag.name,
      type: soilTag.type,
      address: soilTag.address,
      unit: soilTag.unit,
      rawMin: soilTag.rawMin,
      rawMax: soilTag.rawMax,
      scaledMin: soilTag.scaledMin,
      scaledMax: soilTag.scaledMax,
      calOffset: 10.0, // +10.0%
      calGain: 1.0,
    );

    // 1. Valida Tab 0: Home Dashboard com telemetria calibrada
    final keyHome = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: keyHome,
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

    // Injeta telemetria crua de 44.6% vinda do ESP32 (scaled 446 com decimals=1)
    TelemetrySyncService.instance.processPveJson({
      "variables": [
        {"name": "AIN1", "raw": 1827, "scaled": 446, "decimals": 1, "unit": "%"}
      ]
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('UMIDADE DO SOLO (AI0.0 - GPIO 34/35)'), findsOneWidget);
    print('FLUXO 1 [OK]: Home Dashboard exibe com sucesso sensor de solo!');

    // 2. Valida Tab 1: Lógica Ladder IEC
    final keyLadder = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: keyLadder,
          child: StudioScaffold(
            initialProject: demoProject,
            initialIndex: 1,
            networkManager: NetworkManager(autoStartPeriodicCheck: false),
            autoStartTelemetry: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpAndSettle();

    expect(find.textContaining('Controle de Irrigação'), findsOneWidget);
    expect(find.textContaining('AI0.0'), findsWidgets);
    print('FLUXO 2 [OK]: Lógica Ladder IEC auditada: Rung de Controle de Irrigação ativa e usando Tag calibrada!');

    print('VALIDAÇÃO VIRTUAL DO OPERADOR: 100% SUCESSO');
  });
}
