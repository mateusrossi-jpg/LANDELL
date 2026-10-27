import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('TON simulation counting and energization test', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final project = DemoProject.createDemoProject();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LadderEditorPage(initialProject: project),
      ),
    ));
    await tester.pumpAndSettle();

    // Find and switch to Simulate mode (tap the first play icon)
    final simButton = find.byIcon(Icons.play_circle_outline);
    await tester.tap(simButton.first);
    await tester.pumpAndSettle();

    // Find the contact I0.4
    final i04 = find.text('I0.4');
    expect(i04, findsWidgets);

    // Tap on the contact I0.4 to turn it ON
    await tester.tap(i04.first);
    await tester.pump();

    // Check ET text after 500ms
    await tester.pump(const Duration(milliseconds: 500));
    final et500 = find.text('ET:0.5s');
    expect(et500, findsWidgets);

    // Check ET text after 1500ms
    await tester.pump(const Duration(milliseconds: 1000));
    final et1500 = find.text('ET:1.5s');
    expect(et1500, findsWidgets);

    // Check ET text after 3500ms (completed at 3.0s)
    await tester.pump(const Duration(milliseconds: 2000));
    final et3000 = find.text('ET:3.0s');
    expect(et3000, findsWidgets);

    // Turn contact I0.4 OFF and verify timer resets to ET:0.0s
    await tester.tap(i04.first);
    await tester.pump(const Duration(milliseconds: 150));
    final et00 = find.text('ET:0.0s');
    expect(et00, findsWidgets);
  });
}
