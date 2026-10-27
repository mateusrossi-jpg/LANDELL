import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/services/persona_config_service.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/ui/home_page.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/core/ui/personas/manager_analytics_view.dart';
import 'package:endap_studio/core/ui/widgets/adopt_node_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Trilha 3: PersonaConfigService Persistence', () {
    test('Salva e restaura configurações da IHM do Operador', () async {
      final service = PersonaConfigService.instance;
      var config = await service.loadKioskConfig();
      expect(config.showCycleControl, isTrue);
      expect(config.showActuators, isTrue);

      config.showCycleControl = false;
      config.showActuators = false;
      config.recipeName = 'LOTE #TEST-99';
      await service.saveKioskConfig(config);

      final reloaded = await service.loadKioskConfig();
      expect(reloaded.showCycleControl, isFalse);
      expect(reloaded.showActuators, isFalse);
      expect(reloaded.recipeName, 'LOTE #TEST-99');
    });

    test('Salva e restaura metas do Gestor / OEE', () async {
      final service = PersonaConfigService.instance;
      var config = await service.loadManagerConfig();
      expect(config.targetPerHour, 1200);

      config.targetPerHour = 2500;
      config.oeeTarget = 92.5;
      config.lineName = 'LINHA ESPECIAL 01';
      await service.saveManagerConfig(config);

      final reloaded = await service.loadManagerConfig();
      expect(reloaded.targetPerHour, 2500);
      expect(reloaded.oeeTarget, 92.5);
      expect(reloaded.lineName, 'LINHA ESPECIAL 01');
    });
  });

  group('Trilha 2: AdoptNodeDialog UI Flow', () {
    testWidgets('Renderiza modal de adoção com perfis industriais e templates', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final nm = NetworkManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AdoptNodeDialog.show(
                    context,
                    node: EndapNode(id: 'ENDAP-002', ip: '192.168.0.28', role: 'FIELD_NODE'),
                    networkManager: nm,
                  );
                },
                child: const Text('Abrir Adocao'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Adocao'));
      await tester.pumpAndSettle();

      expect(find.text('ADOTAR NÓ NO CLUSTER'), findsOneWidget);
      expect(find.text('Adotar e Provisionar'), findsOneWidget);
    });
  });

  group('Responsividade e Validação Visual (iPhone XR + Desktop)', () {
    testWidgets('OperatorKioskView renderiza sem overflow no iPhone XR (414x896)', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        // Don't crash test runner immediately
      };

      final nm = NetworkManager();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              project: LadderProject.blank(),
              runtime: LadderRuntime(),
              networkManager: nm,
              initialKioskMode: true,
              onTriggerEmergency: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('EXACT OVERFLOW CONTEXT: ${caughtDetails!.context}');
        // ignore: avoid_print
        print('EXACT OVERFLOW SUMMARY: ${caughtDetails!.summary}');
        // ignore: avoid_print
        print('EXACT OVERFLOW EXCEPTION: ${caughtDetails!.exceptionAsString()}');
        for (final item in caughtDetails!.informationCollector?.call() ?? <DiagnosticsNode>[]) {
          // ignore: avoid_print
          print('DIAGNOSTIC: ${item.toStringDeep()}');
        }
      }
      expect(caughtDetails, isNull);
    });

    testWidgets('ManagerAnalyticsView renderiza sem overflow no iPhone XR (414x896)', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final nm = NetworkManager();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagerAnalyticsView(
              networkManager: nm,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
