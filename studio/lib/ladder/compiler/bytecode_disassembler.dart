import 'dart:typed_data';
import '../models/ladder_project.dart';
import '../models/demo_project.dart';
import '../models/ladder_network.dart';
import '../models/ladder_node.dart';
import '../models/node_config.dart';
import '../models/tag.dart';
import '../models/tag_value.dart';
import '../models/enums.dart';
import 'opcodes.dart';

/// BytecodeDisassembler converte o bytecode binário retornado pelo ESP32 (GET /api/automation/ladder)
/// de volta para uma estrutura de `LadderProject` editável no ENDAP Studio.
class BytecodeDisassembler {
  LadderProject disassemble(Uint8List bytecode, {String projectName = 'Firmware Project'}) {
    final project = LadderProject(
      id: 'fw_project',
      name: projectName,
      tags: DemoProject.createDefaultTags(),
      networks: [],
    );

    // Valida Header Magic (ENDP = 0x45, 0x4E, 0x44, 0x50)
    if (bytecode.length < 5 ||
        bytecode[0] != 0x45 ||
        bytecode[1] != 0x4E ||
        bytecode[2] != 0x44 ||
        bytecode[3] != 0x50) {
      return project;
    }

    int pc = 5; // Pula Magic (4 bytes) + Version (1 byte)
    LadderNetwork? currentNetwork;
    int nodeCounter = 1;
    List<LadderNode>? currentBranch;
    LadderNode? currentParallelNode;

    while (pc < bytecode.length) {
      final opcode = bytecode[pc++];
      if (opcode == 0xFF) break; // End of program

      currentNetwork ??= LadderNetwork(
        id: 'net_${project.networks.length + 1}',
        name: 'Network ${project.networks.length + 1}',
        nodes: [],
      );

      final activeNetwork = currentNetwork;

      // Se estamos dentro de um bloco paralelo, os nos vao para o branch ativo
      final targetNodeList = currentBranch ?? activeNetwork.nodes;

      if (opcode == Opcodes.OR_BLOCK_START) {
        final parNode = LadderNode(
          id: 'node_${nodeCounter++}',
          type: NodeType.parallel,
          config: NodeConfig(),
          branches: [[]],
        );
        activeNetwork.nodes.add(parNode);
        currentParallelNode = parNode;
        currentBranch = parNode.branches!.first;
      } else if (opcode == Opcodes.OR_BLOCK_NEXT) {
        if (currentParallelNode != null) {
          final newBranch = <LadderNode>[];
          currentParallelNode.branches!.add(newBranch);
          currentBranch = newBranch;
        }
      } else if (opcode == Opcodes.OR_BLOCK_END) {
        currentParallelNode = null;
        currentBranch = null;
      } else if (opcode == Opcodes.LD || opcode == Opcodes.LDN || opcode == Opcodes.AND || opcode == Opcodes.ANDN) {
        if (pc + 2 > bytecode.length) break;
        final address = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final tagId = _getOrCreateTag(project, address, TagType.bool);
        final isNO = (opcode == Opcodes.LD || opcode == Opcodes.AND);
        
        targetNodeList.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: isNO ? NodeType.contactNO : NodeType.contactNC,
          config: NodeConfig(tagId: tagId),
        ));
      } else if (opcode == Opcodes.ST || opcode == Opcodes.SET || opcode == Opcodes.RST) {
        if (pc + 2 > bytecode.length) break;
        final address = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final tagId = _getOrCreateTag(project, address, TagType.bool);
        NodeType type = NodeType.coil;
        if (opcode == Opcodes.SET) type = NodeType.coilSet;
        if (opcode == Opcodes.RST) type = NodeType.coilReset;

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: type,
          config: NodeConfig(tagId: tagId),
        ));

        // Rung finalizado na bobina (ST/SET/RST)
        activeNetwork.rebuildConnections();
        project.networks.add(activeNetwork);
        currentNetwork = null;
        currentParallelNode = null;
        currentBranch = null;
      } else if (opcode == Opcodes.TON || opcode == Opcodes.TOF) {
        if (pc + 4 > bytecode.length) break;
        final address = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final preset = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;

        final tagId = _getOrCreateTag(project, address, TagType.timer);
        final type = (opcode == Opcodes.TON) ? NodeType.timerTON : NodeType.timerTOF;

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: type,
          config: NodeConfig(
            tagId: tagId,
            presetValue: TagValue.integer(preset),
          ),
        ));

        if (pc >= bytecode.length || bytecode[pc] == Opcodes.LD || bytecode[pc] == Opcodes.LDN || bytecode[pc] == 0xFF) {
          activeNetwork.rebuildConnections();
          project.networks.add(activeNetwork);
          currentNetwork = null;
        }
      } else if (opcode == Opcodes.CTU || opcode == Opcodes.CTD) {
        if (pc + 4 > bytecode.length) break;
        final address = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final preset = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;

        final tagId = _getOrCreateTag(project, address, TagType.counter);
        final type = (opcode == Opcodes.CTU) ? NodeType.counterCTU : NodeType.counterCTD;

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: type,
          config: NodeConfig(
            tagId: tagId,
            presetValue: TagValue.integer(preset),
          ),
        ));

        if (pc >= bytecode.length || bytecode[pc] == Opcodes.LD || bytecode[pc] == Opcodes.LDN || bytecode[pc] == 0xFF) {
          activeNetwork.rebuildConnections();
          project.networks.add(activeNetwork);
          currentNetwork = null;
        }
      } else if (opcode == Opcodes.EQU || opcode == Opcodes.GRT || opcode == Opcodes.LES) {
        if (pc + 4 > bytecode.length) break;
        final address = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final preset = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;

        final tagId = _getOrCreateTag(project, address, TagType.int);
        NodeType type = NodeType.compareEqual;
        if (opcode == Opcodes.GRT) type = NodeType.compareGreater;
        if (opcode == Opcodes.LES) type = NodeType.compareLess;

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: type,
          config: NodeConfig(
            tagId: tagId,
            presetValue: TagValue.integer(preset),
          ),
        ));
      } else if (opcode == Opcodes.ADD || opcode == Opcodes.SUB || opcode == Opcodes.MUL || opcode == Opcodes.DIV) {
        if (pc + 7 > bytecode.length) break;
        final tagAAddress = (bytecode[pc] << 8) | bytecode[pc + 1];
        final flagsB = bytecode[pc + 2];
        final operandBRaw = (bytecode[pc + 3] << 8) | bytecode[pc + 4];
        final destAddress = (bytecode[pc + 5] << 8) | bytecode[pc + 6];
        pc += 7;

        final tagAId = _getOrCreateTag(project, tagAAddress, TagType.int);
        final destTagId = _getOrCreateTag(project, destAddress, TagType.int);

        TagValue presetVal;
        if (flagsB == 0x00) {
          final tagBId = _getOrCreateTag(project, operandBRaw, TagType.int);
          presetVal = TagValue.string(tagBId);
        } else {
          final signedConst = (operandBRaw & 0x8000) != 0 ? (operandBRaw - 0x10000) : operandBRaw;
          presetVal = TagValue.integer(signedConst);
        }

        NodeType type = NodeType.mathADD;
        if (opcode == Opcodes.SUB) type = NodeType.mathSUB;
        if (opcode == Opcodes.MUL) type = NodeType.mathMUL;
        if (opcode == Opcodes.DIV) type = NodeType.mathDIV;

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: type,
          config: NodeConfig(
            tagId: tagAId,
            presetValue: presetVal,
            resetTagId: destTagId,
          ),
        ));

        activeNetwork.rebuildConnections();
        project.networks.add(activeNetwork);
        currentNetwork = null;
      } else if (opcode == Opcodes.PID) {
        if (pc + 12 > bytecode.length) break;
        final pvAddr = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final spAddr = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final mvAddr = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final kpRaw = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final kiRaw = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;
        final kdRaw = (bytecode[pc] << 8) | bytecode[pc + 1];
        pc += 2;

        final pvTag = _getOrCreateTag(project, pvAddr, TagType.real);
        final String spTag = (spAddr & 0x8000) != 0
            ? (spAddr & 0x7FFF).toString()
            : _getOrCreateTag(project, spAddr, TagType.real);
        final mvTag = _getOrCreateTag(project, mvAddr, TagType.real);

        activeNetwork.nodes.add(LadderNode(
          id: 'node_${nodeCounter++}',
          type: NodeType.pid,
          config: NodeConfig(
            tagId: pvTag,
            setpointTagId: spTag,
            outputTagId: mvTag,
            kp: kpRaw / 100.0,
            ki: kiRaw / 100.0,
            kd: kdRaw / 100.0,
          ),
        ));

        // Se o próximo opcode na sequência for uma Bobina (ST/SET/RST) na mesma rung, mantém a rung aberta
        final nextOp = pc < bytecode.length ? bytecode[pc] : 0xFF;
        final hasDownstreamCoil = nextOp == Opcodes.ST || nextOp == Opcodes.SET || nextOp == Opcodes.RST;
        if (!hasDownstreamCoil) {
          activeNetwork.rebuildConnections();
          project.networks.add(activeNetwork);
          currentNetwork = null;
        }
      }
    }

    if (currentNetwork != null && currentNetwork.nodes.isNotEmpty) {
      currentNetwork.rebuildConnections();
      project.networks.add(currentNetwork);
    }

    return project;
  }

  String _getOrCreateTag(LadderProject project, int address, TagType defaultType) {
    String canonicalName;
    TagType type = defaultType;
    if (address >= 10 && address <= 25) {
      final rel = address - 10;
      final bit = rel % 8;
      final byte = rel ~/ 8;
      canonicalName = 'I$byte.$bit';
      type = TagType.bool;
    } else if (address == 33) {
      canonicalName = 'MV_PID';
      type = TagType.real;
    } else if (address == 30 && defaultType == TagType.real) {
      canonicalName = 'SP_PID';
      type = TagType.real;
    } else if (address >= 26 && address <= 39) {
      final rel = address - 26;
      final bit = rel % 8;
      final byte = rel ~/ 8;
      canonicalName = 'M$byte.$bit';
      type = TagType.bool;
    } else if (address >= 40 && address <= 55) {
      canonicalName = 'T${address - 40}';
      type = TagType.timer;
    } else if (address >= 56 && address <= 71) {
      canonicalName = 'C${address - 56}';
      type = TagType.counter;
    } else if (address >= 72 && address <= 75) {
      canonicalName = 'AI0.${address - 72}';
      type = TagType.real;
    } else if (address >= 80 && address <= 81) {
      canonicalName = 'AO0.${address - 80}';
      type = TagType.real;
    } else if (address >= 100 && address <= 115) {
      final rel = address - 100;
      final bit = rel % 8;
      final byte = rel ~/ 8;
      canonicalName = 'Q$byte.$bit';
      type = TagType.bool;
    } else {
      canonicalName = 'TAG_$address';
    }

    // Tenta encontrar primeiramente a tag com id exato igual ao nome canônico
    if (project.tags.containsKey(canonicalName)) {
      return canonicalName;
    }

    final existingTag = project.tags.values.firstWhere(
      (t) => project.getTagAddress(t.id) == address,
      orElse: () {
        final isCapacitiveAi = canonicalName.startsWith('AI0.');
        final isPercentTag = isCapacitiveAi ||
            canonicalName == 'MV_PID' ||
            canonicalName == 'SP_PID' ||
            canonicalName.startsWith('AO0.');
        final newTag = Tag(
          id: canonicalName,
          name: canonicalName,
          type: type,
          address: canonicalName,
          unit: isPercentTag ? '%' : null,
          rawMin: isCapacitiveAi ? 1500 : null,
          rawMax: isCapacitiveAi ? 3800 : null,
          scaledMin: isCapacitiveAi ? 100 : null,
          scaledMax: isCapacitiveAi ? 0 : null,
        );
        project.tags[newTag.id] = newTag;
        return newTag;
      },
    );

    return existingTag.id;
  }
}
