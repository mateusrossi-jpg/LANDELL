import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';
import 'package:endap_studio/core/ui/personas/maintenance_diagnostics_view.dart';
import 'package:endap_studio/core/ui/personas/manager_analytics_view.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/executable_graph.dart';

void main() {
  group('MaintenanceDiagnosticsView & ManagerAnalyticsView Real Data Tests', () {
    late LadderProject project;
    late LadderRuntime runtime;
    late NetworkManager networkManager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StudioEventBus.instance.clear();

      project = LadderProject(
        id: 'proj_test_01',
        name: 'Projeto Teste Real',
        tags: {
          'tag_sensor_esteira': Tag(
            id: 'tag_sensor_esteira',
            name: 'Sensor_Presenca_Esteira',
            type: TagType.bool,
            address: '%IX0.0',
            description: 'Sensor óptico de presença',
          ),
          'tag_motor_esteira': Tag(
            id: 'tag_motor_esteira',
            name: 'Motor_Esteira_Principal',
            type: TagType.bool,
            address: '%QX0.0',
            description: 'Contator de potência do motor',
          ),
          'tag_contador_pecas': Tag(
            id: 'tag_contador_pecas',
            name: 'Pecas_Produzidas_Total',
            type: TagType.int,
            address: '%MW10',
            description: 'Totalizador de peças produzidas',
          ),
        },
        networks: [
          LadderNetwork(
            id: '0',
            name: 'Controle de Partida da Esteira',
            nodes: [
              LadderNode(
                id: 'n_0',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'tag_sensor_esteira'),
              ),
              LadderNode(
                id: 'n_1',
                type: NodeType.coil,
                config: NodeConfig(tagId: 'tag_motor_esteira'),
              ),
            ],
          ),
        ],
      );

      runtime = LadderRuntime();
      runtime.loadProject(ExecutableGraph.validated(project));
      networkManager = NetworkManager();
    });

    testWidgets('MaintenanceDiagnosticsView exibe tags reais do projeto e aciona forçamento', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceDiagnosticsView(
              networkManager: networkManager,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. Deve exibir as TAGs reais do projeto
      expect(find.text('Sensor_Presenca_Esteira'), findsOneWidget);
      expect(find.text('Motor_Esteira_Principal'), findsOneWidget);
      expect(find.text('%IX0.0'), findsWidgets);
      expect(find.text('%QX0.0'), findsWidgets);

      // Não deve ter nenhum dado mock antigo
      expect(find.text('Sensor Barreira Óptica'), findsNothing);
      expect(find.text('Contator Motor Principal'), findsNothing);

      // 2. Testa Forçar ON na saída Motor_Esteira_Principal
      final onButtons = find.widgetWithText(OutlinedButton, 'ON');
      expect(onButtons, findsWidgets);

      // Clica em FORÇAR ON no primeiro botão
      await tester.tap(onButtons.first);
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica se a tag foi forçada no runtime
      expect(runtime.tagStore.isForced('tag_sensor_esteira'), isTrue);
      expect(runtime.tagStore.getBool('tag_sensor_esteira'), isTrue);

      // Verifica se o evento de auditoria foi emitido
      final events = StudioEventBus.instance.events;
      expect(events.any((e) => e.type == 'IO_FORCE' && e.message.contains('Sensor_Presenca_Esteira')), isTrue);

      // 3. Testa Liberar Todos os forçamentos
      final releaseAllBtn = find.widgetWithText(ElevatedButton, 'LIBERAR TODOS (1)');
      expect(releaseAllBtn, findsOneWidget);

      await tester.tap(releaseAllBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica se todas as tags foram liberadas
      expect(runtime.tagStore.isForced('tag_sensor_esteira'), isFalse);
      expect(StudioEventBus.instance.events.any((e) => e.type == 'IO_UNFORCE_ALL'), isTrue);
    });

    testWidgets('ManagerAnalyticsView exibe métricas reais do controlador e eventos do EventBus', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Emite um evento de auditoria prévio
      StudioEventBus.instance.emit(
        type: 'LADDER_DEPLOY',
        source: 'FIRMWARE',
        message: 'Deploy de Bytecode Ladder realizado no nó 192.168.4.1 (128 bytes)',
        severity: EventSeverity.info,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagerAnalyticsView(
              networkManager: networkManager,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Deve exibir o total de TAGs real (3 TAGs)
      expect(find.text('3 TAGs'), findsOneWidget);

      // Deve exibir a tag de produção real
      expect(find.text('PRODUÇÃO (Pecas_Produzidas_Total)'), findsOneWidget);

      // Deve exibir o evento de auditoria real
      expect(find.textContaining('Deploy de Bytecode Ladder realizado no nó'), findsOneWidget);

      // Não deve ter nenhum dado falso
      expect(find.text('14.820 pcs'), findsNothing);
      expect(find.text('518 pcs'), findsNothing);
      expect(find.text('TEC_SANTOS'), findsNothing);
    });

    testWidgets('MaintenanceDiagnosticsView e ManagerAnalyticsView renderizam sem overflow no iPhone XR', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Testa MaintenanceDiagnosticsView
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceDiagnosticsView(
              networkManager: networkManager,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Testa ManagerAnalyticsView
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagerAnalyticsView(
              networkManager: networkManager,
              project: project,
              runtime: runtime,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
