// ignore_for_file: unused_import, unused_element
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';

void main() {
  const artifactDir = '/home/mateus/.gemini/antigravity-cli/brain/2c6c5571-2549-4f73-8e3e-43ab14e0a6e1';

  Future<void> captureWidget(WidgetTester tester, GlobalKey key, String filename) async {
    await tester.pump(const Duration(milliseconds: 100));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    
    final file = File('$artifactDir/$filename');
    if (file.parent.existsSync()) {
      await file.writeAsBytes(buffer);
    }
  }

  testWidgets('Capture 5 Ladder Geometry Scenarios in Editor', (tester) async {
  }, skip: true);
  /* testWidgets('Capture 5 Ladder Geometry Scenarios in Editor', (tester) async {
    tester.view.physicalSize = const Size(393 * 2.0, 852 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Scenario 1: Contato -> Bobina
    final project1 = LadderProject(
      id: 'p1',
      name: 'Cenário 1: Contato -> Bobina',
      networks: [
        LadderNetwork(
          id: 'net_1',
          name: 'Partida Direta Simples',
          nodes: [
            LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
            LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
          ],
        ),
      ],
    );

    final key1 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key1,
          child: Scaffold(
            body: LadderEditorPage(initialProject: project1),
          ),
        ),
      ),
    );
    await captureWidget(tester, key1, 'ladder_scenario_1_single_branch.png');

    // 2. Scenario 2: Paralelo com 2 ramos (A || B) -> Bobina
    final project2 = LadderProject(
      id: 'p2',
      name: 'Cenário 2: Paralelo 2 Ramos',
      networks: [
        LadderNetwork(
          id: 'net_2',
          name: 'Circuito OU (2 Ramos)',
          nodes: [
            LadderNode(
              id: 'par_1',
              type: NodeType.parallel,
              config: NodeConfig(),
              branches: [
                [LadderNode(id: 'a', type: NodeType.contactNO, config: NodeConfig(tagId: 'LOCAL_BTN'))],
                [LadderNode(id: 'b', type: NodeType.contactNO, config: NodeConfig(tagId: 'REMOTE_BTN'))],
              ],
            ),
            LadderNode(id: 'coil_2', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_V1')),
          ],
        ),
      ],
    );

    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key2,
          child: Scaffold(
            body: LadderEditorPage(initialProject: project2),
          ),
        ),
      ),
    );
    await captureWidget(tester, key2, 'ladder_scenario_2_two_branches.png');

    // 3. Scenario 3: Paralelo com 3 ramos (A || B || C) -> Bobina
    final project3 = LadderProject(
      id: 'p3',
      name: 'Cenário 3: Paralelo 3 Ramos',
      networks: [
        LadderNetwork(
          id: 'net_3',
          name: 'Circuito Multi-Ponto (3 Ramos)',
          nodes: [
            LadderNode(
              id: 'par_3',
              type: NodeType.parallel,
              config: NodeConfig(),
              branches: [
                [LadderNode(id: 'a3', type: NodeType.contactNO, config: NodeConfig(tagId: 'MANUAL_SW'))],
                [LadderNode(id: 'b3', type: NodeType.contactNO, config: NodeConfig(tagId: 'AUTO_CMD'))],
                [LadderNode(id: 'c3', type: NodeType.contactNO, config: NodeConfig(tagId: 'EMERG_BYPASS'))],
              ],
            ),
            LadderNode(id: 'coil_3', type: NodeType.coil, config: NodeConfig(tagId: 'HEATER_H1')),
          ],
        ),
      ],
    );

    final key3 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key3,
          child: Scaffold(
            body: LadderEditorPage(initialProject: project3),
          ),
        ),
      ),
    );
    await captureWidget(tester, key3, 'ladder_scenario_3_three_branches.png');

    // 4. Scenario 4: Paralelo -> Contato -> Bobina
    final project4 = LadderProject(
      id: 'p4',
      name: 'Cenário 4: Paralelo -> Contato -> Bobina',
      networks: [
        LadderNetwork(
          id: 'net_4',
          name: 'Selo com Botão Desliga',
          nodes: [
            LadderNode(
              id: 'par_4',
              type: NodeType.parallel,
              config: NodeConfig(),
              branches: [
                [LadderNode(id: 'start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_PB'))],
                [LadderNode(id: 'latch', type: NodeType.contactNO, config: NodeConfig(tagId: 'PUMP_RUN'))],
              ],
            ),
            LadderNode(id: 'stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP_PB')),
            LadderNode(id: 'coil_4', type: NodeType.coil, config: NodeConfig(tagId: 'PUMP_RUN')),
          ],
        ),
      ],
    );

    final key4 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key4,
          child: Scaffold(
            body: LadderEditorPage(initialProject: project4),
          ),
        ),
      ),
    );
    await captureWidget(tester, key4, 'ladder_scenario_4_parallel_series_coil.png');

    // 5. Scenario 5: Dois grupos paralelos em série ((A || B) -> (C || D) -> Bobina)
    final project5 = LadderProject(
      id: 'p5',
      name: 'Cenário 5: Dois Grupos Paralelos em Série',
      networks: [
        LadderNetwork(
          id: 'net_5',
          name: 'Cascata de Paralelos em Série',
          nodes: [
            LadderNode(
              id: 'g1',
              type: NodeType.parallel,
              config: NodeConfig(),
              branches: [
                [LadderNode(id: 'g1_a', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_A1'))],
                [LadderNode(id: 'g1_b', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_A2'))],
              ],
            ),
            LadderNode(
              id: 'g2',
              type: NodeType.parallel,
              config: NodeConfig(),
              branches: [
                [LadderNode(id: 'g2_c', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_B1'))],
                [LadderNode(id: 'g2_d', type: NodeType.contactNO, config: NodeConfig(tagId: 'IN_B2'))],
              ],
            ),
            LadderNode(id: 'coil_5', type: NodeType.coil, config: NodeConfig(tagId: 'SYSTEM_READY')),
          ],
        ),
      ],
    );

    final key5 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key5,
          child: Scaffold(
            body: LadderEditorPage(initialProject: project5),
          ),
        ),
      ),
    );
    await captureWidget(tester, key5, 'ladder_scenario_5_two_parallel_groups_series.png');

    // Desmonta widgets para chamar dispose() de LadderEditorPage e cancelar os timers periódicos
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }); */
}
