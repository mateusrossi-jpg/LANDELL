import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/ui/editor/telemetry_sync_service.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  testWidgets('Mobile Viewport Audit - iPhone XR (414 x 896) on all tabs', (tester) async {
    // iPhone XR viewport: 828 x 1792 physical, 2.0 ratio = 414 x 896 logical points
    tester.view.physicalSize = const Size(828, 1792);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final demoProject = DemoProject.createDemoProject();
    final runtime = LadderRuntime();

    TelemetrySyncService.instance.init(
      project: demoProject,
      runtime: runtime,
      gatewayIp: '192.168.0.27',
    );

    // Test each tab from 0 to 7 to ensure NO RenderFlex overflow on iPhone XR screen width
    for (int tabIndex = 0; tabIndex <= 7; tabIndex++) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: StudioScaffold(
            initialProject: demoProject,
            initialIndex: tabIndex,
            networkManager: NetworkManager(autoStartPeriodicCheck: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // If any RenderFlex overflow occurs, Flutter throws an exception in the test harness
      print('Validated Tab $tabIndex renders on iPhone XR (414x896) without overflow');
    }

    print('ALL_TABS_MOBILE_IPHONE_XR_AUDIT_PASSED');
  });
}
