// ignore_for_file: avoid_print
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

  testWidgets('StudioScaffold opens Drawer in ALL 3 main tabs: Home, Ladder IEC, GPIO/TAGS', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final nm = NetworkManager();
    final project = LadderProject(id: 'proj_test', name: 'Projeto Teste');

    await tester.pumpWidget(
      MaterialApp(
        home: StudioScaffold(
          initialProject: project,
          networkManager: nm,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // TAB 0: Home Dashboard
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.openDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaffoldState.isDrawerOpen, isTrue);

    scaffoldState.closeDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaffoldState.isDrawerOpen, isFalse);

    // SWITCH TO TAB 1: Ladder IEC
    print('Switching to Tab 1: Ladder IEC...');
    scaffoldState.openDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Lógica Ladder IEC'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    scaffoldState.openDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaffoldState.isDrawerOpen, isTrue);

    scaffoldState.closeDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaffoldState.isDrawerOpen, isFalse);

    // SWITCH TO TAB 2: GPIO / TAGS
    print('Switching to Tab 2: GPIO / TAGS...');
    scaffoldState.openDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('GPIO / TAGS').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    scaffoldState.openDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaffoldState.isDrawerOpen, isTrue);
  });
}
