import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StudioScaffold opens Drawer when clicking menu button on HomePage', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final nm = NetworkManager();
    final project = LadderProject(id: 'proj_clean', name: 'Projeto Limpo');

    await tester.pumpWidget(
      MaterialApp(
        home: StudioScaffold(
          initialProject: project,
          initialIndex: 0,
          networkManager: nm,
          autoStartTelemetry: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially Drawer is closed
    expect(find.byType(Drawer), findsNothing);

    // Find and tap the menu icon button in HomePage
    final menuButton = find.byTooltip('Menu');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Drawer should now be visible with items
    expect(find.textContaining(RegExp(r'(LANDELL|ENDAP) STUDIO', caseSensitive: false)), findsWidgets);
    expect(find.textContaining(RegExp(r'FERRAMENTAS & DIAGNÓSTICO', caseSensitive: false)), findsOneWidget);
    expect(find.textContaining('Rede & Topologia'), findsOneWidget);
  });
}
