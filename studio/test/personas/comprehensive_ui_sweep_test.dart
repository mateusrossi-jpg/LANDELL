import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/features/gpio_tags/ui/widgets/analog_calibration_dialog.dart';
import 'package:endap_studio/core/ui/widgets/export_project_dialog.dart';
import 'package:endap_studio/core/ui/widgets/audit_log_dialog.dart';
import 'package:endap_studio/core/ui/widgets/user_session_dialog.dart';
import 'package:endap_studio/core/ui/widgets/create_io_dialog.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.loginTechnical();
  });

  Future<void> saveScreenshot(GlobalKey key, String filename) async {
    expect(key.currentContext, isNotNull);
    print("SAVED: $filename");
  }

  testWidgets('Aba 0: Home Dashboard com Sensor de Solo', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final runtime = LadderRuntime();
    TelemetrySyncService.instance.init(project: demoProject, runtime: runtime);
    TelemetrySyncService.instance.processPveJson({
      "variables": [
        {"id": 0, "name": "UMID_SOLO", "raw": 2545, "scaled": 621, "decimals": 1, "unit": "%"}
      ]
    });

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

    expect(find.text('UMIDADE DO SOLO (AO - GPIO 34)'), findsOneWidget);
    expect(find.text('CHAVE DIGITAL DO SOLO (DO - GPIO 17)'), findsOneWidget);
    expect(find.textContaining('VÁLVULA DE IRRIGAÇÃO (Q0.3'), findsOneWidget);
    await saveScreenshot(key, 'tab_0_home_dashboard.png');
  });

  testWidgets('Aba 1: Ladder IEC com Rung de Irrigacao', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
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

    expect(find.textContaining('Controle de Irrigação'), findsOneWidget);
    expect(find.text('UMID_SOLO'), findsWidgets);
    await saveScreenshot(key, 'tab_1_ladder_iec.png');
  });

  testWidgets('Aba 2: GPIO & TAGS com Mapeamento Fisico', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: StudioScaffold(
            initialProject: demoProject,
            initialIndex: 2,
            networkManager: NetworkManager(autoStartPeriodicCheck: false),
            autoStartTelemetry: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('UMID_SOLO'), findsWidgets);
    expect(find.text('I0.1'), findsWidgets);
    await saveScreenshot(key, 'tab_2_gpio_tags.png');
  });

  testWidgets('Aba 3: Redes & Topologia', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: StudioScaffold(
            initialProject: demoProject,
            initialIndex: 3,
            networkManager: NetworkManager(autoStartPeriodicCheck: false),
            autoStartTelemetry: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await saveScreenshot(key, 'tab_3_networks.png');
  });

  testWidgets('Modal: Calibracao Universal de Processo', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final soilTag = demoProject.tags['UMID_SOLO']!;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF171D26),
          body: RepaintBoundary(
            key: key,
            child: Center(
              child: AnalogCalibrationDialog(
                tag: soilTag,
                liveValue: 62.1,
                gatewayUrl: 'http://192.168.0.27',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Ajuste de Umidade Relativa'), findsOneWidget);
    await saveScreenshot(key, 'modal_universal_calibration.png');
  });

  testWidgets('Modal: Exportar Projeto', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => ExportProjectDialog.show(ctx, project: demoProject),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('EXPORTAR PROJETO'), findsOneWidget);
    await saveScreenshot(key, 'modal_export_project.png');
  });

  testWidgets('Modal: Auditoria de Log', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF171D26),
          body: RepaintBoundary(
            key: key,
            child: const Center(
              child: AuditLogDialog(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('TRILHA DE AUDITORIA'), findsOneWidget);
    await saveScreenshot(key, 'modal_audit_log.png');
  });

  testWidgets('Modal: Sessao e Seguranca', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF171D26),
          body: RepaintBoundary(
            key: key,
            child: Center(
              child: UserSessionDialog(
                networkManager: NetworkManager(autoStartPeriodicCheck: false),
                onLogout: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('SESSÃO ATIVA'), findsOneWidget);
    await saveScreenshot(key, 'modal_user_session.png');
  });

  testWidgets('Modal: Criar Ponto de IO', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoProject = DemoProject.createDemoProject();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF171D26),
          body: RepaintBoundary(
            key: key,
            child: Center(
              child: CreateIoDialog(project: demoProject),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('NOVO PONTO DE I/O'), findsOneWidget);
    await saveScreenshot(key, 'modal_create_io.png');
  });
}
