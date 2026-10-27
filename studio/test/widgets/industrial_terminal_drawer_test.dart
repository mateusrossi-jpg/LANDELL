import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/core/ui/widgets/industrial_terminal_drawer.dart';

void main() {
  testWidgets('IndustrialTerminalDrawer expands, shows events and filters', (tester) async {
    // Reset event bus
    StudioEventBus.instance.clear();
    StudioEventBus.instance.emit(
      type: 'SYSTEM',
      source: 'ENDAP_CORE',
      message: 'CORE RUNNING DETERMINISTIC 1MS',
      severity: EventSeverity.info,
    );
    StudioEventBus.instance.emit(
      type: 'NETWORK',
      source: 'HTTP_CLIENT',
      message: 'GATEWAY DISCOVERED AT 192.168.0.27',
      severity: EventSeverity.info,
    );
    StudioEventBus.instance.emit(
      type: 'FAULT',
      source: 'IO_FAULT',
      message: 'OVERCURRENT DETECTED ON Q0.1',
      severity: EventSeverity.critical,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: SizedBox()),
              IndustrialTerminalDrawer(initiallyExpanded: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In collapsed state, should show "TERMINAL"
    expect(find.text('TERMINAL'), findsOneWidget);
    // Should show count badge 3
    expect(find.text('3'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('TERMINAL'));
    await tester.pumpAndSettle();

    // Verify all 3 events are present in chronological order
    expect(find.text('CORE RUNNING DETERMINISTIC 1MS'), findsOneWidget);
    expect(find.text('GATEWAY DISCOVERED AT 192.168.0.27'), findsOneWidget);
    expect(find.text('OVERCURRENT DETECTED ON Q0.1'), findsOneWidget);

    // Switch filter to FALHAS
    await tester.tap(find.text('FALHAS'));
    await tester.pumpAndSettle();

    // Only fault should be visible
    expect(find.text('OVERCURRENT DETECTED ON Q0.1'), findsOneWidget);
    expect(find.text('GATEWAY DISCOVERED AT 192.168.0.27'), findsNothing);

    // Switch filter back to TODOS
    await tester.tap(find.text('TODOS'));
    await tester.pumpAndSettle();

    // Collapse
    await tester.tap(find.byTooltip('Recolher Terminal'));
    await tester.pumpAndSettle();

    // In collapsed state, filter chips are gone
    expect(find.text('FALHAS'), findsNothing);
  });
}
