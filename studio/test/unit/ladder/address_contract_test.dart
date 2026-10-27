import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/models/plc_tag_contract.dart';

void main() {
  group('ENDAP PLC Tag Contract V1 — Strict Mapping Tests', () {
    test('1. Normalization of PLC addresses and legacy conversion (X/Y -> I/Q)', () {
      expect(PlcTagContract.normalizeAddress('I0.0'), equals('I0.0'));
      expect(PlcTagContract.normalizeAddress('I1.7'), equals('I1.7'));
      expect(PlcTagContract.normalizeAddress('Q0.0'), equals('Q0.0'));
      expect(PlcTagContract.normalizeAddress('Q1.7'), equals('Q1.7'));
      expect(PlcTagContract.normalizeAddress('M0.0'), equals('M0.0'));
      expect(PlcTagContract.normalizeAddress('M1.5'), equals('M1.5'));
      expect(PlcTagContract.normalizeAddress('T0'), equals('T0'));
      expect(PlcTagContract.normalizeAddress('T15'), equals('T15'));
      expect(PlcTagContract.normalizeAddress('C0'), equals('C0'));
      expect(PlcTagContract.normalizeAddress('C15'), equals('C15'));

      // Legacy conversion
      expect(PlcTagContract.normalizeAddress('X0'), equals('I0.0'));
      expect(PlcTagContract.normalizeAddress('X15'), equals('I1.7'));
      expect(PlcTagContract.normalizeAddress('Y0'), equals('Q0.0'));
      expect(PlcTagContract.normalizeAddress('Y15'), equals('Q1.7'));

      // Compact format aliases (DI00/DO00, I00/Q00, AI00/AO00)
      expect(PlcTagContract.normalizeAddress('DI00'), equals('I0.0'));
      expect(PlcTagContract.normalizeAddress('DI01'), equals('I0.1'));
      expect(PlcTagContract.normalizeAddress('DO00'), equals('Q0.0'));
      expect(PlcTagContract.normalizeAddress('DO01'), equals('Q0.1'));
      expect(PlcTagContract.normalizeAddress('I00'), equals('I0.0'));
      expect(PlcTagContract.normalizeAddress('I01'), equals('I0.1'));
      expect(PlcTagContract.normalizeAddress('Q00'), equals('Q0.0'));
      expect(PlcTagContract.normalizeAddress('Q01'), equals('Q0.1'));
      expect(PlcTagContract.normalizeAddress('AI00', allowExtended: true), equals('AI0.0'));
      expect(PlcTagContract.normalizeAddress('AO00', allowExtended: true), equals('AO0.0'));
    });

    test('2. Rejection of invalid or out-of-range PLC addresses', () {
      expect(PlcTagContract.normalizeAddress('I30.0'), isNull);
      expect(PlcTagContract.normalizeAddress('Q30.0'), isNull);
      expect(PlcTagContract.normalizeAddress('I0.8'), isNull);
      expect(PlcTagContract.normalizeAddress('Q0.9'), isNull);
      expect(PlcTagContract.normalizeAddress('T16'), isNull);
      expect(PlcTagContract.normalizeAddress('C16'), isNull);
      expect(PlcTagContract.normalizeAddress(''), isNull);
      expect(PlcTagContract.normalizeAddress('   '), isNull);
      expect(PlcTagContract.normalizeAddress('FOO'), isNull);
      expect(PlcTagContract.normalizeAddress('INVALID'), isNull);
    });

    test('3. Exact 16-bit IDs mapping required for Compiler & Firmware', () {
      expect(PlcTagContract.addressToId('I0.0'), equals(10));
      expect(PlcTagContract.addressToId('I1.7'), equals(25));
      expect(PlcTagContract.addressToId('Q0.0'), equals(100));
      expect(PlcTagContract.addressToId('Q1.7'), equals(115));
      expect(PlcTagContract.addressToId('M0.0'), equals(26));
      expect(PlcTagContract.addressToId('M1.5'), equals(39));
      expect(PlcTagContract.addressToId('T0'), equals(40));
      expect(PlcTagContract.addressToId('T15'), equals(55));
      expect(PlcTagContract.addressToId('C0'), equals(56));
      expect(PlcTagContract.addressToId('C15'), equals(71));

      // Legacy fallbacks produce identical IDs
      expect(PlcTagContract.addressToId('X0'), equals(10));
      expect(PlcTagContract.addressToId('Y0'), equals(100));
    });

    test('4. Full Compiler pipeline integration test: [I0.0] -> (Q0.0)', () {
      final tagI0 = Tag(id: 'I0.0', name: 'Start_Button', type: TagType.bool, address: 'I0.0');
      final tagQ0 = Tag(id: 'Q0.0', name: 'Motor_Output', type: TagType.bool, address: 'Q0.0');

      final nodeI0 = LadderNode(id: 'n_i0', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0'));
      final nodeQ0 = LadderNode(id: 'n_q0', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0'));

      final network = LadderNetwork(
        id: 'net1',
        nodes: [nodeI0, nodeQ0],
        connections: [],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'proj1',
        name: 'PLC Tag Test Project',
        tags: {'I0.0': tagI0, 'Q0.0': tagQ0},
        networks: [network],
      );

      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);

      final expectedBytes = [
        0x45, 0x4E, 0x44, 0x50, // Magic 'ENDP'
        0x01,                   // Version 1
        0x01, 0x00, 0x0A,       // OP_LD, operand 10 (I0.0)
        0x10, 0x00, 0x64,       // OP_ST, operand 100 (Q0.0)
        0xFF,                   // Terminator
      ];

      expect(bytecode.length, 12);
      expect(bytecode, equals(expectedBytes));
    });

    test('5. Compiler pipeline with M0.0, T0, C0 tags', () {
      final tagM0 = Tag(id: 'M0.0', name: 'Flag_System', type: TagType.bool, address: 'M0.0');
      final tagT0 = Tag(id: 'T0', name: 'Timer_On', type: TagType.timer, address: 'T0');

      final nodeM0 = LadderNode(id: 'n_m0', type: NodeType.contactNO, config: NodeConfig(tagId: 'M0.0'));
      final nodeT0 = LadderNode(id: 'n_t0', type: NodeType.timerTON, config: NodeConfig(tagId: 'T0', presetValue: TagValue.integer(5000)));

      final network = LadderNetwork(
        id: 'net2',
        nodes: [nodeM0, nodeT0],
        connections: [],
      )..rebuildConnections();

      final project = LadderProject(
        id: 'proj2',
        name: 'Timer Memory Test',
        tags: {'M0.0': tagM0, 'T0': tagT0},
        networks: [network],
      );

      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);

      // ENDP (4) + V1 (1) + LD 26 (3) + TON 40 preset=5000 (5) + 0xFF (1) = 14 bytes
      expect(bytecode.length, 14);
      expect(bytecode[5], 0x01); // OP_LD
      expect(bytecode[6], 0x00);
      expect(bytecode[7], 0x1A); // 26 = M0.0
      expect(bytecode[8], 0x30); // OP_TON
      expect(bytecode[9], 0x00);
      expect(bytecode[10], 0x28); // 40 = T0
      expect(bytecode[11], 0x13); // 5000 >> 8 = 19 (0x13)
      expect(bytecode[12], 0x88); // 5000 & 0xFF = 136 (0x88)
    });

    test('6. PROOF: UI creation of I0.0 and Q0.0 tags compiles to exact ID 10 and ID 100', () {
      final project = LadderProject(id: 'ui_proof_proj', name: 'UI Proof Project', tags: {});

      // Simulate UI creation using PlcTagContract validation
      final addrI0 = PlcTagContract.normalizeAddress('I0.0')!;
      final addrQ0 = PlcTagContract.normalizeAddress('Q0.0')!;

      final tagI0 = Tag(
        id: addrI0,
        name: 'START_BUTTON',
        type: PlcTagContract.getTagTypeForAddress(addrI0)!,
        address: addrI0,
      );
      final tagQ0 = Tag(
        id: addrQ0,
        name: 'MAIN_RELAY',
        type: PlcTagContract.getTagTypeForAddress(addrQ0)!,
        address: addrQ0,
      );

      project.tags[tagI0.id] = tagI0;
      project.tags[tagQ0.id] = tagQ0;

      // Attach to a Ladder Rung
      final nodeInput = LadderNode(id: 'n_btn', type: NodeType.contactNO, config: NodeConfig(tagId: tagI0.id));
      final nodeOutput = LadderNode(id: 'n_relay', type: NodeType.coil, config: NodeConfig(tagId: tagQ0.id));

      final network = LadderNetwork(
        id: 'net_ui',
        nodes: [nodeInput, nodeOutput],
        connections: [],
      )..rebuildConnections();

      project.networks.add(network);

      // Execute Compiler
      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);

      // Verify exact bytecode operands
      final operandInput = (bytecode[6] << 8) | bytecode[7];
      final operandOutput = (bytecode[9] << 8) | bytecode[10];

      expect(operandInput, equals(10), reason: 'I0.0 MUST compile to ID 10');
      expect(operandOutput, equals(100), reason: 'Q0.0 MUST compile to ID 100');
    });

    test('7. Multi-controller compact and canonical addressing (I00, I10, I20, I30...)', () {
      // Controller 0 (Gateway)
      expect(PlcTagContract.normalizeAddress('I00'), equals('I0.0'));
      expect(PlcTagContract.normalizeAddress('Q00'), equals('Q0.0'));
      expect(PlcTagContract.addressToId('I00'), equals(10));
      expect(PlcTagContract.addressToId('Q00'), equals(100));

      // Controller 1 (Field Node 1)
      expect(PlcTagContract.normalizeAddress('I10'), equals('I1.0'));
      expect(PlcTagContract.normalizeAddress('Q10'), equals('Q1.0'));
      expect(PlcTagContract.addressToId('I10'), equals(18));
      expect(PlcTagContract.addressToId('Q10'), equals(108));

      // Controller 2 (Field Node 2)
      expect(PlcTagContract.normalizeAddress('I20'), equals('I2.0'));
      expect(PlcTagContract.normalizeAddress('Q20'), equals('Q2.0'));
      expect(PlcTagContract.addressToId('I20'), equals(120));
      expect(PlcTagContract.addressToId('Q20'), equals(160));

      // Controller 3 (Field Node 3)
      expect(PlcTagContract.normalizeAddress('I30'), equals('I3.0'));
      expect(PlcTagContract.normalizeAddress('Q30'), equals('Q3.0'));
      expect(PlcTagContract.addressToId('I30'), equals(128));
      expect(PlcTagContract.addressToId('Q30'), equals(168));

      // Tag controller index derivation
      final tag0 = Tag(id: 'I00', name: 'I00', type: TagType.bool, address: 'I0.0');
      final tag1 = Tag(id: 'I10', name: 'I10', type: TagType.bool, address: 'I1.0');
      final tag2 = Tag(id: 'I20', name: 'I20', type: TagType.bool, address: 'I2.0');
      final tag3 = Tag(id: 'I30', name: 'I30', type: TagType.bool, address: 'I3.0');

      expect(tag0.controllerIndex, equals(0));
      expect(tag1.controllerIndex, equals(1));
      expect(tag2.controllerIndex, equals(2));
      expect(tag3.controllerIndex, equals(3));
    });
  });
}
