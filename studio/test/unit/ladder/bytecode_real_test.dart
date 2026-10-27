import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/compiler/bytecode_disassembler.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  void compileAndCheck(String address, int expectedOperand) {
    final tag = Tag(id: 'T', name: 'Tag', type: TagType.bool, address: address);
    final node = LadderNode(id: 'N', type: NodeType.coil, config: NodeConfig(tagId: 'T'));
    final network = LadderNetwork(id: 'NW', nodes: [node], connections: []);
    final project = LadderProject(id: 'P', name: 'P', tags: {'T': tag}, networks: [network]);
    final compiler = BytecodeCompiler();
    final bytecode = compiler.compile(project);
    // operand bytes are at indices 6 and 7 (0‑based after header(4), version(1), opcode(1))
    final operand = (bytecode[6] << 8) | bytecode[7];
    expect(operand, expectedOperand, reason: 'Address $address should map to operand $expectedOperand');
  }

  test('Bytecode operands for X0, X15, Y0, Y15', () {
    compileAndCheck('X0', 10);
    compileAndCheck('X15', 25);
    compileAndCheck('Y0', 100);
    compileAndCheck('Y15', 115);
  });

  test('BytecodeDisassembler correctly handles 8-byte math contract (0x50 ADD)', () {
    // Header (ENDP v1): 45 4E 44 50 01
    // Rung 1: OP_LD 14 (X4) -> 01 00 0E
    // Math 8B: OP_ADD (0x50), TagA=14 (0x000E), FlagsB=0x01 (Const), OpB=5 (0x0005), Dest=100 (0x0064)
    // Terminator: 0xFF
    final bytecode = Uint8List.fromList([
      0x45, 0x4E, 0x44, 0x50, 0x01,
      0x01, 0x00, 0x0E,
      0x50, 0x00, 0x0E, 0x01, 0x00, 0x05, 0x00, 0x64,
      0xFF
    ]);

    final disassembler = BytecodeDisassembler();
    final project = disassembler.disassemble(bytecode);

    expect(project.networks.length, equals(1));
    final network = project.networks.first;
    expect(network.nodes.length, equals(2));
    expect(network.nodes[0].type, equals(NodeType.contactNO));
    expect(network.nodes[1].type, equals(NodeType.mathADD));
    expect(network.nodes[1].config.presetValue?.intValue, equals(5));
  });
}
