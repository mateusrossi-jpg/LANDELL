import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

/// Sessão interativa com o binário C real do firmware (`ladder_engine.c` + `ladder_pid.c` + `state.c`).
class CFirmwareVmSession {
  final Process _proc;
  final StreamIterator<String> _lines;

  CFirmwareVmSession._(this._proc, this._lines);

  static Future<CFirmwareVmSession> spawn(String cliPath) async {
    final proc = await Process.start(cliPath, const []);
    final lines = StreamIterator<String>(
      proc.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    return CFirmwareVmSession._(proc, lines);
  }

  Future<String> _cmd(String command) async {
    _proc.stdin.writeln(command);
    await _proc.stdin.flush();
    final ok = await _lines.moveNext();
    if (!ok) {
      throw StateError('ladder_vm_cli encerrou inesperadamente em: $command');
    }
    return _lines.current;
  }

  Future<void> reset() async {
    final resp = await _cmd('RESET');
    expect(resp, startsWith('OK RESET'));
  }

  Future<void> loadBytecode(Uint8List bytes) async {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final resp = await _cmd('LOAD $hex');
    expect(resp, equals('OK LOAD ${bytes.length}'));
  }

  Future<void> setState(int id, int value) async {
    final resp = await _cmd('SET $id $value');
    expect(resp, equals('OK SET'));
  }

  Future<void> advanceMs(int ms) async {
    if (ms > 0) {
      final resp = await _cmd('ADVANCE $ms');
      expect(resp, equals('OK ADVANCE'));
    }
  }

  Future<void> step([int count = 1]) async {
    final resp = await _cmd('STEP $count');
    expect(resp, equals('OK STEP $count'));
  }

  Future<Map<int, int>> query(List<int> ids) async {
    final resp = await _cmd('QUERY ${ids.join(' ')}');
    expect(resp, startsWith('STATE'));
    final result = <int, int>{};
    for (final part in resp.split(' ').skip(1)) {
      final kv = part.split('=');
      if (kv.length == 2) {
        result[int.parse(kv[0])] = int.parse(kv[1]);
      }
    }
    return result;
  }

  Future<void> close() async {
    _proc.stdin.writeln('QUIT');
    await _proc.stdin.close();
    await _proc.exitCode;
  }
}

void main() {
  late String hostTestsDir;
  late String cliPath;
  late CFirmwareVmSession cVm;

  setUpAll(() async {
    // Localiza firmware/host_tests a partir de studio/
    final candidates = [
      '../firmware/host_tests',
      'firmware/host_tests',
      '/home/mateus/LANDELL/firmware/host_tests',
    ];
    hostTestsDir = candidates.firstWhere(
      (p) => Directory(p).existsSync(),
      orElse: () => '/home/mateus/LANDELL/firmware/host_tests',
    );
    cliPath = '$hostTestsDir/build/ladder_vm_cli';

    if (!File(cliPath).existsSync()) {
      final buildRes = await Process.run('make', ['-s', 'all'], workingDirectory: hostTestsDir);
      expect(buildRes.exitCode, equals(0), reason: 'Falha ao compilar C host tests: ${buildRes.stderr}');
    }
    cVm = await CFirmwareVmSession.spawn(cliPath);
  });

  tearDownAll(() async {
    await cVm.close();
  });

  group('Paridade Cruzada Byte-a-Byte: Studio Dart <-> Firmware C Real (ladder_engine.c)', () {
    test('1. Partida Direta com Selo Paralelo (OR_BLOCK) e Parada NF: Dart == C ciclo a ciclo', () async {
      await cVm.reset();

      final project = LadderProject(
        id: 'seal_in_parity',
        name: 'Partida com Selo',
        tags: DemoProject.createDefaultTags(),
      );

      final parallelSeal = LadderNode(
        id: 'par_seal',
        type: NodeType.parallel,
        config: NodeConfig(),
        branches: [
          [LadderNode(id: 'c_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0'))],
          [LadderNode(id: 'c_seal', type: NodeType.contactNO, config: NodeConfig(tagId: 'Q0.0'))],
        ],
      );
      final rung0 = LadderNetwork(
        id: 'r0',
        nodes: [
          parallelSeal,
          LadderNode(id: 'c_stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'I0.1')),
          LadderNode(id: 'q_motor', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')),
        ],
      )..rebuildConnections();

      final rung1 = LadderNetwork(
        id: 'r1',
        nodes: [
          LadderNode(id: 'c_stopped', type: NodeType.contactNC, config: NodeConfig(tagId: 'Q0.0')),
          LadderNode(id: 'q_lamp', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.1')),
        ],
      )..rebuildConnections();

      project.networks.addAll([rung0, rung1]);

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);
      final runtime = LadderRuntime()..loadProject(val.executableGraph!);
      final bytecode = BytecodeCompiler().compile(project);
      await cVm.loadBytecode(bytecode);

      // Sequência de eventos reais: Repouso -> Pulso Start -> Solta Start (Selo) -> Aciona Stop -> Solta Stop
      final steps = <(bool i0, bool i1)>[
        (false, false),
        (true, false),
        (false, false),
        (false, true),
        (false, false),
      ];

      for (var s = 0; s < steps.length; s++) {
        final (i0, i1) = steps[s];
        runtime.tagStore.setBool('I0.0', i0);
        runtime.tagStore.setBool('I0.1', i1);
        runtime.singleScan(10);

        await cVm.setState(10, i0 ? 1 : 0);
        await cVm.setState(11, i1 ? 1 : 0);
        await cVm.advanceMs(10);
        await cVm.step();

        final cState = await cVm.query([100, 101]);
        final dartQ0 = runtime.tagStore.getBool('Q0.0') ? 1 : 0;
        final dartQ1 = runtime.tagStore.getBool('Q0.1') ? 1 : 0;

        expect(cState[100], equals(dartQ0), reason: 'Ciclo $s: Q0.0 divergiu entre C e Dart');
        expect(cState[101], equals(dartQ1), reason: 'Ciclo $s: Q0.1 divergiu entre C e Dart');
      }
    });

    test('2. Temporizadores TON + Contadores CTU + SET/RESET: Dart == C com precisão de 1ms', () async {
      await cVm.reset();

      final project = LadderProject(
        id: 'ton_ctu_parity',
        name: 'TON + CTU Parity',
        tags: DemoProject.createDefaultTags(),
      );

      // Rung 0: I0.0 -> TON(T0, 500ms) -> Q0.0
      final r0 = LadderNetwork(
        id: 'r0',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')),
          LadderNode(
            id: 'n2',
            type: NodeType.timerTON,
            config: NodeConfig(tagId: 'T0', presetValue: TagValue.integer(500)),
          ),
          LadderNode(id: 'n3', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')),
        ],
      )..rebuildConnections();

      // Rung 1: I0.1 -> CTU(C0, 2) -> SET Q0.1
      final r1 = LadderNetwork(
        id: 'r1',
        nodes: [
          LadderNode(id: 'n4', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.1')),
          LadderNode(
            id: 'n5',
            type: NodeType.counterCTU,
            config: NodeConfig(tagId: 'C0', presetValue: TagValue.integer(2)),
          ),
          LadderNode(id: 'n6', type: NodeType.coilSet, config: NodeConfig(tagId: 'Q0.1')),
        ],
      )..rebuildConnections();

      // Rung 2: I0.2 -> RST C0, RST Q0.1
      final r2 = LadderNetwork(
        id: 'r2',
        nodes: [
          LadderNode(id: 'n7', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.2')),
          LadderNode(id: 'n8', type: NodeType.coilReset, config: NodeConfig(tagId: 'C0')),
        ],
      )..rebuildConnections();
      final r3 = LadderNetwork(
        id: 'r3',
        nodes: [
          LadderNode(id: 'n9', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.2')),
          LadderNode(id: 'n10', type: NodeType.coilReset, config: NodeConfig(tagId: 'Q0.1')),
        ],
      )..rebuildConnections();

      project.networks.addAll([r0, r1, r2, r3]);

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);
      final runtime = LadderRuntime()..loadProject(val.executableGraph!);
      final bytecode = BytecodeCompiler().compile(project);
      await cVm.loadBytecode(bytecode);

      // (dtMs, I0.0, I0.1, I0.2)
      final trace = <(int, bool, bool, bool)>[
        (0, true, false, false),    // inicia TON (0ms)
        (250, true, true, false),   // TON 250ms, 1a borda CTU (count=1)
        (249, true, false, false),  // TON 499ms (ainda 0!)
        (1, true, true, false),     // TON 500ms -> Q0.0=1! 2a borda CTU (count=2) -> SET Q0.1=1!
        (50, false, false, false),  // I0.0 cai -> Q0.0=0, mas Q0.1 permanece em 1 (SET)!
        (50, false, false, true),   // I0.2=1 -> RESET C0 e Q0.1!
        (50, false, true, false),   // 1 novo pulso em C0 apos reset -> count=1 (<2), Q0.1 continua 0!
      ];

      for (var i = 0; i < trace.length; i++) {
        final (dt, i0, i1, i2) = trace[i];
        runtime.tagStore.setBool('I0.0', i0);
        runtime.tagStore.setBool('I0.1', i1);
        runtime.tagStore.setBool('I0.2', i2);
        runtime.singleScan(dt);

        await cVm.setState(10, i0 ? 1 : 0);
        await cVm.setState(11, i1 ? 1 : 0);
        await cVm.setState(12, i2 ? 1 : 0);
        await cVm.advanceMs(dt);
        await cVm.step();

        final cState = await cVm.query([100, 101]);
        expect(cState[100], equals(runtime.tagStore.getBool('Q0.0') ? 1 : 0),
            reason: 'Passo $i: TON Q0.0 divergiu entre C e Dart');
        expect(cState[101], equals(runtime.tagStore.getBool('Q0.1') ? 1 : 0),
            reason: 'Passo $i: CTU/SET/RST Q0.1 divergiu entre C e Dart');
      }
    });

    test('3. Projeto Oficial da Bancada TCC (DemoProject.createCleanTccProject + PIDX): Dart == C', () async {
      await cVm.reset();

      final project = DemoProject.createCleanTccProject();
      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);

      final runtime = LadderRuntime()..loadProject(val.executableGraph!);
      final bytecode = BytecodeCompiler().compile(project);
      await cVm.loadBytecode(bytecode);

      final mvAddr = project.getTagAddress('MV_PID');
      final ai0Addr = project.getTagAddress('AI0.0'); // 72

      // Liga chave geral (I0.0 = 1) e varre umidade do solo PV de 20% até 60% em degraus de 100ms
      final pvTrajectory = [20, 25, 32, 40, 48, 52, 55, 45, 30];
      runtime.tagStore.setBool('I0.0', true);
      await cVm.setState(10, 1);

      for (var stepIdx = 0; stepIdx < pvTrajectory.length; stepIdx++) {
        final pv = pvTrajectory[stepIdx];
        runtime.tagStore.setReal('AI0.0', pv.toDouble());
        runtime.singleScan(100);

        await cVm.setState(ai0Addr, pv);
        await cVm.advanceMs(100);
        await cVm.step();

        final cState = await cVm.query([mvAddr, 100]);
        final dartMv = runtime.tagStore.getInt('MV_PID');
        final dartQ0 = runtime.tagStore.getBool('Q0.0') ? 1 : 0;

        expect(cState[mvAddr], equals(dartMv),
            reason: 'TCC PID Passo $stepIdx (PV=$pv%): MV_PID divergiu entre Firmware C e Studio Dart');
        expect(cState[100], equals(dartQ0),
            reason: 'TCC PID Passo $stepIdx (PV=$pv%): Q0.0 divergiu entre Firmware C e Studio Dart');
      }
    });
  });
}
