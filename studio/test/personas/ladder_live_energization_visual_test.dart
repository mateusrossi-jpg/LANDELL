import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/ui/editor/ladder_editor_page.dart';
import 'package:endap_studio/ladder/ui/editor/widgets/ladder_network_canvas.dart';

void main() {
  testWidgets('LadderNetworkCanvas renders with isSimulationRunning true and false', (tester) async {
    final net = LadderNetwork(
      id: 'net_1',
      nodes: [
        LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
        LadderNode(id: 'n_ton', type: NodeType.timerTON, config: NodeConfig(presetValue: TagValue.integer(2500))),
        LadderNode(id: 'n_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
      ],
    )..rebuildConnections();

    final project = LadderProject(
      id: 'proj_rails',
      name: 'Power Rails Test',
      tags: {
        'START_BTN': Tag(id: 'START_BTN', name: 'START_BTN', type: TagType.bool, address: 'I0.0', initialValue: TagValue.boolean(false)),
        'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'MOTOR_M1', type: TagType.bool, address: 'Q0.0', initialValue: TagValue.boolean(false)),
      },
      networks: [net],
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LadderEditorPage(initialProject: project))));
    await tester.pump(const Duration(milliseconds: 400));

    // Initially offline: canvas should exist
    expect(find.byType(LadderNetworkCanvas), findsWidgets);

    // TON block formatted preset should display formatted in seconds: PT:2.5s
    expect(find.text('PT:2.5s'), findsOneWidget);

    // Turn on simulation
    await tester.tap(find.textContaining('Simula'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify canvas is still rendering without errors
    expect(find.byType(LadderNetworkCanvas), findsWidgets);
  });
}
