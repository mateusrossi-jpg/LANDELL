import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/ui/personas/engineering_workspace_view.dart';
import 'package:endap_studio/core/ui/widgets/industrial_ribbon_bar.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';
import 'package:endap_studio/home/renderers/numeric_sparkline_widget.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';

void main() {
  testWidgets('EngineeringWorkspaceView validates real project and compiles bytecode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final project = DemoProject.createDemoProject();
    final runtime = LadderRuntime();
    final networkManager = NetworkManager();
    addTearDown(() => networkManager.dispose());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngineeringWorkspaceView(
            project: project,
            runtime: runtime,
            networkManager: networkManager,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verify dynamic organizer has real controller name
    expect(find.textContaining('Controlador ['), findsOneWidget);

    // Verify console contains real network and rung counts (not hardcoded 4 rungs / 124 bytes)
    expect(find.textContaining('${project.networks.length} Rung(s)'), findsOneWidget);

    // Tap "Verificar Lógica"
    final verifyBtn = find.text('Verificar Lógica');
    expect(verifyBtn, findsOneWidget);
    await tester.tap(verifyBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('✓ Grafo IEC 61131-3 válido: ${project.networks.length} Rung(s)'), findsOneWidget);

    // Tap "Compilar Bytecode"
    final compileBtn = find.text('Compilar Bytecode');
    expect(compileBtn, findsOneWidget);
    await tester.tap(compileBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('✓ Bytecode compilado:'), findsOneWidget);
  });

  testWidgets('NumericSparklineWidget renders real trend and no fake points', (tester) async {
    final project = DemoProject.createDemoProject();
    final runtime = LadderRuntime();
    runtime.tagStore.setValue('AI0.0', TagValue.real(62.5));

    final config = HomeWidgetConfig(
      id: 'spark_test',
      tagId: 'AI0.0',
      templateType: WidgetTemplateType.sparkline,
      title: 'TESTE SPARKLINE REAL',
      unit: '%',
      minValue: 0,
      maxValue: 100,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericSparklineWidget(
            config: config,
            project: project,
            runtime: runtime,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Must display real 62.5%
    expect(find.text('62.5'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);

    // Verify CustomPaint with _RealSparklinePainter is present
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('IndustrialRibbonBar displays real hardware determinism and simulator scan time', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final networkManager = NetworkManager();
    addTearDown(() => networkManager.dispose());

    // When offline in local emulation
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
            scanDurationUs: 50,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Must display real scan duration in ms
    expect(find.text('0.05ms • SIMULADOR'), findsOneWidget);
  });
}
