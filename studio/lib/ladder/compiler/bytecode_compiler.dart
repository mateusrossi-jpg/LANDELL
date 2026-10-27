import 'dart:typed_data';
import '../models/ladder_project.dart';
import '../models/ladder_network.dart';
import '../models/ladder_node.dart';
import '../models/enums.dart';
import 'opcodes.dart';

class BytecodeCompiler {
  /// Compila um projeto Ladder num buffer binário.
  /// Se [targetControllerId] for especificado (e não for 'ALL' ou 'GLOBAL'),
  /// compila apenas os rungs destinados àquele controlador (ou rungs marcados como 'GLOBAL').
  /// Rungs com [isEnabled == false] são ignorados na compilação.
  Uint8List compile(LadderProject project, {String? targetControllerId}) {
    final List<int> bytecode = [];
    
    // Header Magic (ENDP)
    bytecode.addAll([0x45, 0x4E, 0x44, 0x50]);
    // Version (v1 = 0x01)
    bytecode.add(0x01);
    
    for (var network in project.networks) {
      if (!network.isEnabled) continue;
      if (targetControllerId != null &&
          targetControllerId != 'ALL' &&
          targetControllerId != 'GLOBAL') {
        if (network.targetControllerId != targetControllerId &&
            network.targetControllerId != 'GLOBAL' &&
            network.targetControllerId != 'ALL') {
          continue;
        }
      }
      _compileNetwork(network, project, bytecode);
    }
    
    // Terminator (0xFF)
    bytecode.add(0xFF);
    
    return Uint8List.fromList(bytecode);
  }

  void _compileNetwork(LadderNetwork network, LadderProject project, List<int> bytecode) {
    if (network.nodes.isEmpty) return;
    _compileNodeList(network.nodes, project, bytecode, isFirstOfNetwork: true);
  }

  void _compileNodeList(List<LadderNode> nodes, LadderProject project, List<int> bytecode, {bool isFirstOfNetwork = false}) {
    for (int i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      final isFirst = i == 0 && isFirstOfNetwork;

      if (node.type == NodeType.parallel) {
        if (node.branches != null && node.branches!.isNotEmpty) {
           bytecode.add(Opcodes.OR_BLOCK_START);
           for (int b = 0; b < node.branches!.length; b++) {
               if (b > 0) bytecode.add(Opcodes.OR_BLOCK_NEXT);
               _compileNodeList(node.branches![b], project, bytecode, isFirstOfNetwork: true);
           }
           bytecode.add(Opcodes.OR_BLOCK_END);
        }
      } 
      else if (node.type == NodeType.contactNO || node.type == NodeType.contactNC) {
        final op = isFirst ? 
            (node.type == NodeType.contactNO ? Opcodes.LD : Opcodes.LDN) :
            (node.type == NodeType.contactNO ? Opcodes.AND : Opcodes.ANDN);
        
        _emit(bytecode, op, project.getTagAddress(node.config.tagId ?? node.id));
      }
    else if (node.type == NodeType.coil || node.type == NodeType.coilSet || node.type == NodeType.coilReset) {
      int op = Opcodes.ST;
      if (node.type == NodeType.coilSet) op = Opcodes.SET;
      if (node.type == NodeType.coilReset) op = Opcodes.RST;
      
      _emit(bytecode, op, project.getTagAddress(node.config.tagId ?? node.id));
    }
    else if (node.type == NodeType.timerTON || node.type == NodeType.timerTOF) {
      final op = node.type == NodeType.timerTON ? Opcodes.TON : Opcodes.TOF;
      _emit(bytecode, op, project.getTagAddress(node.config.tagId ?? node.id));
      final preset = node.config.presetValue?.intValue ?? 0;
      bytecode.add((preset >> 8) & 0xFF);
      bytecode.add(preset & 0xFF);
    }
    else if (node.type == NodeType.counterCTU || node.type == NodeType.counterCTD) {
      final op = node.type == NodeType.counterCTU ? Opcodes.CTU : Opcodes.CTD;
      _emit(bytecode, op, project.getTagAddress(node.config.tagId ?? node.id));
      final preset = node.config.presetValue?.intValue ?? 0;
      bytecode.add((preset >> 8) & 0xFF);
      bytecode.add(preset & 0xFF);
    }
    else if (node.type == NodeType.compareEqual || node.type == NodeType.compareGreater || node.type == NodeType.compareLess) {
      int op = Opcodes.EQU;
      if (node.type == NodeType.compareGreater) op = Opcodes.GRT;
      if (node.type == NodeType.compareLess) op = Opcodes.LES;
      _emit(bytecode, op, project.getTagAddress(node.config.tagId ?? node.id));
      final preset = (node.config.presetValue?.realValue ?? node.config.presetValue?.intValue?.toDouble() ?? 0).round();
      bytecode.add((preset >> 8) & 0xFF);
      bytecode.add(preset & 0xFF);
    }
    else if (node.type == NodeType.mathADD || node.type == NodeType.mathSUB || node.type == NodeType.mathMUL || node.type == NodeType.mathDIV) {
      int op = Opcodes.ADD;
      if (node.type == NodeType.mathSUB) op = Opcodes.SUB;
      if (node.type == NodeType.mathMUL) op = Opcodes.MUL;
      if (node.type == NodeType.mathDIV) op = Opcodes.DIV;
      
      final tagAId = node.config.tagId ?? node.id;
      final tagAAddress = project.getTagAddress(tagAId);
      
      int flagsB = 0x01; // Padrão: Constante literal
      int operandB = 0;
      
      final preset = node.config.presetValue;
      if (preset != null) {
        if (preset.stringValue != null && preset.stringValue!.isNotEmpty) {
          flagsB = 0x00; // Tag ID
          operandB = project.getTagAddress(preset.stringValue!);
        } else {
          flagsB = 0x01; // Constante literal
          final numVal = preset.intValue ?? preset.realValue?.round() ?? 0;
          operandB = numVal & 0xFFFF; // int16 bit pattern
        }
      }
      
      final destTagId = (node.config.outputTagId != null && node.config.outputTagId!.isNotEmpty)
          ? node.config.outputTagId!
          : ((node.config.resetTagId != null && node.config.resetTagId!.isNotEmpty)
              ? node.config.resetTagId!
              : tagAId);
      final destAddress = project.getTagAddress(destTagId);
      
      bytecode.add(op);
      bytecode.add((tagAAddress >> 8) & 0xFF);
      bytecode.add(tagAAddress & 0xFF);
      bytecode.add(flagsB & 0xFF);
      bytecode.add((operandB >> 8) & 0xFF);
      bytecode.add(operandB & 0xFF);
      bytecode.add((destAddress >> 8) & 0xFF);
      bytecode.add(destAddress & 0xFF);
    }
    else if (node.type == NodeType.pid) {
      String pvTagId = (node.config.tagId ?? 'AI0.0').trim();
      String mvTagId = (node.config.outputTagId ?? 'MV_PID').trim();

      // Proteção contra inversão acidental de PV (Q0.x) e MV (AI0.x)
      if ((pvTagId.startsWith('Q') || pvTagId.startsWith('Y')) &&
          (mvTagId.startsWith('AI') || mvTagId.startsWith('%IW') || mvTagId == 'UMID_SOLO')) {
        pvTagId = 'AI0.0';
        mvTagId = 'MV_PID';
      } else if (mvTagId.startsWith('AI') || mvTagId.startsWith('%IW') || mvTagId == 'UMID_SOLO') {
        mvTagId = 'MV_PID';
      }
      if (pvTagId == 'UMID_SOLO') pvTagId = 'AI0.0';

      final pvAddress = project.getTagAddress(pvTagId);

      final spTagId = (node.config.setpointTagId ?? '50').replaceAll('%', '').trim();
      final spLiteral = double.tryParse(spTagId)?.round();
      final int spAddress;
      if (spLiteral != null) {
        // Bit 15 (0x8000) sinaliza constante literal de Setpoint (ex: 50 -> 50%)
        final clampedSp = spLiteral.clamp(0, 10000);
        spAddress = 0x8000 | (clampedSp & 0x7FFF);
      } else {
        spAddress = project.getTagAddress(spTagId);
      }

      final mvAddress = project.getTagAddress(mvTagId);

      final kpRaw = ((node.config.kp ?? 2.5) * 100).round() & 0xFFFF;
      final kiRaw = ((node.config.ki ?? 0.5) * 100).round() & 0xFFFF;
      final kdRaw = ((node.config.kd ?? 0.1) * 100).round() & 0xFFFF;

      bytecode.add(Opcodes.PID);
      bytecode.add((pvAddress >> 8) & 0xFF);
      bytecode.add(pvAddress & 0xFF);
      bytecode.add((spAddress >> 8) & 0xFF);
      bytecode.add(spAddress & 0xFF);
      bytecode.add((mvAddress >> 8) & 0xFF);
      bytecode.add(mvAddress & 0xFF);
      bytecode.add((kpRaw >> 8) & 0xFF);
      bytecode.add(kpRaw & 0xFF);
      bytecode.add((kiRaw >> 8) & 0xFF);
      bytecode.add(kiRaw & 0xFF);
      bytecode.add((kdRaw >> 8) & 0xFF);
      bytecode.add(kdRaw & 0xFF);
    }
  }
}

  void _emit(List<int> bytecode, int opcode, int operand) {
    bytecode.add(opcode);
    // Operando de 16-bits (Tag Address)
    bytecode.add((operand >> 8) & 0xFF);
    bytecode.add(operand & 0xFF);
  }
}
