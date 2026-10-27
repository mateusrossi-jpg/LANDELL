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
import 'package:endap_studio/ladder/ui/editor/widgets/ladder_node_visual.dart';

LadderNetwork _validRung() => LadderNetwork(
      id: 'net_1',
      nodes: [
        LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
        LadderNode(id: 'n_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
      ],
    )..rebuildConnections();

Map<String, Tag> _tags() => {
      'START_BTN': Tag(id: 'START_BTN', name: 'START_BTN', type: TagType.bool, address: 'I0.0', initialValue: TagValue.boolean(false)),
      'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'MOTOR_M1', type: TagType.bool, address: 'Q0.0', initialValue: TagValue.boolean(false)),
    };

Future<bool> _isEnergized(WidgetTester tester, String nodeId) async {
  for (final v in tester.widgetList<LadderNodeVisual>(find.byType(LadderNodeVisual))) {
    if (v.node.id == nodeId) return v.node.isEnergized;
  }
  return false;
}

void main() {
  testWidgets('rung energizer apos toggle no no', (tester) async {
    final project = LadderProject(
      id: 'probe',
      name: 'Probe',
      tags: _tags(),
      networks: [_validRung()],
    );
    await tester.pumpWidget(MaterialApp(home: LadderEditorPage(initialProject: project)));
    await tester.pump(const Duration(milliseconds: 400));

    // Ativar o modo Simulação para permitir o toggle interativo do contato
    await tester.tap(find.textContaining('Simula'));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('START_BTN').first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(await _isEnergized(tester, 'n_start'), isTrue);
    expect(await _isEnergized(tester, 'n_motor'), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('rung valida energiza mesmo com rung vazia no projeto', (tester) async {
    final project = LadderProject(
      id: 'probe2',
      name: 'Probe2',
      tags: _tags(),
      networks: [
        _validRung(),
        LadderNetwork(id: 'net_empty', nodes: []),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: LadderEditorPage(initialProject: project)));
    await tester.pump(const Duration(milliseconds: 400));

    // Ativar o modo Simulação para permitir o toggle interativo do contato
    await tester.tap(find.textContaining('Simula'));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('START_BTN').first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(await _isEnergized(tester, 'n_start'), isTrue);
    expect(await _isEnergized(tester, 'n_motor'), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
  });
}