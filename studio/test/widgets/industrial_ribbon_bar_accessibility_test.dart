import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/core/ui/widgets/industrial_ribbon_bar.dart';
import 'package:endap_studio/core/services/network_manager.dart';

void main() {
  testWidgets('IndustrialRibbonBar renders tooltips and semantics in desktop mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final networkManager = NetworkManager(autoStartPeriodicCheck: false);
    addTearDown(() => networkManager.dispose());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndustrialRibbonBar(
            plcMode: IndustrialPlcMode.run,
            networkManager: networkManager,
            activePersona: 'ENGENHEIRO',
            onPersonaChanged: (_) {},
            onDeploy: () {},
            onFetch: () {},
            onTriggerFailsafe: () {},
            onToggleTerminal: () {},
            isTerminalVisible: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    final failsafeFinder = find.byTooltip('Parada de Emergência (Failsafe)');
    expect(failsafeFinder, findsOneWidget);

    final failsafeTextFinder = find.text('FAILSAFE');
    expect(failsafeTextFinder, findsOneWidget);

    final semantics = tester.getSemantics(failsafeTextFinder);
    expect(semantics.label, contains('Parada de Emergência (Failsafe)'));

    final terminalFinder = find.byTooltip('Terminal de Diagnóstico');
    expect(terminalFinder, findsOneWidget);
  });

  testWidgets('IndustrialRibbonBar renders tooltips and semantics in mobile mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final networkManager = NetworkManager(autoStartPeriodicCheck: false);
    addTearDown(() => networkManager.dispose());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndustrialRibbonBar(
            plcMode: IndustrialPlcMode.run,
            networkManager: networkManager,
            activePersona: 'HOME',
            onPersonaChanged: (_) {},
            onDeploy: () {},
            onFetch: () {},
            onTriggerFailsafe: () {},
            onToggleTerminal: () {},
            isTerminalVisible: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    final stopFinder = find.byTooltip('Parada de Emergência (Failsafe)');
    expect(stopFinder, findsOneWidget);

    final stopTextFinder = find.text('STOP');
    expect(stopTextFinder, findsOneWidget);

    final semanticsStop = tester.getSemantics(stopTextFinder);
    expect(semanticsStop.label, contains('Parada de Emergência (Failsafe)'));

    final terminalMobileFinder = find.byTooltip('Terminal de Diagnóstico');
    expect(terminalMobileFinder, findsOneWidget);

    final terminalIconFinder = find.descendant(
      of: terminalMobileFinder,
      matching: find.byIcon(Icons.terminal_rounded),
    );
    expect(terminalIconFinder, findsOneWidget);

    final semanticsTerminal = tester.getSemantics(terminalIconFinder);
    expect(semanticsTerminal.label, contains('Terminal de Diagnóstico'));
  });
}
