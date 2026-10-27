import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder_autosave.dart';

import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/home/models/home_widget_config.dart';

void main() {
  testWidgets('Valida Widgets AHT10 e Lógica Ladder no ENDAP Studio', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final ahtProject = LadderProject(
      id: 'proj_aht10',
      name: 'Controle Térmico AHT10',
      dashboardWidgets: [
        HomeWidgetConfig(
          id: 'w_temp',
          templateType: WidgetTemplateType.gauge,
          title: 'TEMPERATURA AMBIENTE (AHT10)',
        ),
        HomeWidgetConfig(
          id: 'w_hum',
          templateType: WidgetTemplateType.gauge,
          title: 'UMIDADE RELATIVA (AHT10)',
        ),
        HomeWidgetConfig(
          id: 'w_fan',
          templateType: WidgetTemplateType.digital,
          title: 'SISTEMA DE EXAUSTÃO / RESFRIADOR',
        ),
      ],
      networks: [
        LadderNetwork(id: 'net_aht10', name: 'Controle Térmico AHT10'),
      ],
    );
    await saveCurrentLadder(ahtProject);

    await tester.pumpWidget(
      MaterialApp(
        home: StudioScaffold(
          initialProject: ahtProject,
          initialIndex: 0,
          networkManager: NetworkManager(autoStartPeriodicCheck: false),
          autoStartTelemetry: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Valida que os widgets AHT10 estao visiveis na Home
    expect(find.text('TEMPERATURA AMBIENTE (AHT10)'), findsOneWidget);
    expect(find.text('UMIDADE RELATIVA (AHT10)'), findsOneWidget);
    expect(find.text('SISTEMA DE EXAUSTÃO / RESFRIADOR'), findsOneWidget);

    // Valida que o projeto possui a rung de controle termico AHT10
    expect(ahtProject.networks.any((net) => net.name.contains('Controle Térmico AHT10')), isTrue);
  });
}
