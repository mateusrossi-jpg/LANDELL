import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/compiler/bytecode_disassembler.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/runtime/evaluators/pid_evaluator.dart';
import 'package:endap_studio/ladder/runtime/node_runtime_state.dart';
import 'package:endap_studio/ladder/runtime/pid_math.dart';
import 'package:endap_studio/ladder/runtime/tag_state_store.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';

/// Os vetores "GOLDEN" abaixo foram gerados pelo teste de mesa C do firmware
/// (firmware/components/runtime/ladder/host_test/ladder_pid_host_test.c).
/// O simulador do Studio precisa reproduzi-los exatamente.
PidParams _base({
  int kp = 250,
  int ki = 50,
  int kd = 10,
  bool direct = false,
  int outMin = 0,
  int outMax = 100,
  int deadbandX10 = 0,
  int safe = 0,
}) =>
    PidParams(
      kpX100: kp,
      kiX100: ki,
      kdX100: kd,
      direct: direct,
      manualEnable: true,
      outMin: outMin,
      outMax: outMax,
      deadbandX10: deadbandX10,
      enoThreshold: 20,
      enoHysteresis: 5,
      safeOut: safe,
    );

void main() {
  group('PidMath == firmware (vetores dourados)', () {
    test('A: seguimento de solo seco, ação reversa, ENO com histerese', () {
      final p = _base();
      final s = PidState();
      PidMath.disable(p, s);
      const pv = [20, 20, 22, 25, 30, 35, 40, 44, 47, 49, 50, 51, 52, 52, 50, 48];
      const expected = [
        '76500:1', '78000:1', '74067:1', '67373:1', '55169:1', '42833:1', '30344:1', '20403:1',
        '13020:0', '8208:0', '5990:0', '3675:0', '1271:0', '1501:0', '7109:0', '12716:0',
      ];
      final got = <String>[];
      for (final v in pv) {
        PidMath.step(p, s, pvPct: v, spPct: 50);
        got.add('${s.mvM}:${s.eno ? 1 : 0}');
      }
      expect(got, expected);
    });

    test('B: anti-windup — sai da saturação imediatamente', () {
      final p = _base();
      final s = PidState();
      PidMath.disable(p, s);
      for (var i = 0; i < 200; i++) {
        PidMath.step(p, s, pvPct: 0, spPct: 50);
      }
      expect(s.mvM, 100000);
      PidMath.step(p, s, pvPct: 100, spPct: 50);
      expect('${s.mvM}:${s.eno ? 1 : 0}:${s.integM}', '0:0:0');
    });

    test('C: banda morta', () {
      final p = _base(ki: 0, kd: 0, deadbandX10: 20);
      final s = PidState();
      PidMath.disable(p, s);
      PidMath.step(p, s, pvPct: 49, spPct: 50);
      expect(s.mvM, 0);
      PidMath.step(p, s, pvPct: 40, spPct: 50);
      expect(s.mvM, 25000);
    });

    test('D: manual -> auto sem solavanco', () {
      final p = _base(kd: 0);
      final s = PidState();
      PidMath.disable(p, s);
      for (var i = 0; i < 5; i++) {
        PidMath.step(p, s, pvPct: 30, spPct: 50, manual: true, manPct: 70);
      }
      expect(s.mvM, 70000);
      PidMath.step(p, s, pvPct: 30, spPct: 50);
      expect(s.mvM, 71000);
    });

    test('E: histerese do ENO (liga >20%, desliga <=15%)', () {
      final p = PidParams(kpX100: 100, kiX100: 0, kdX100: 0, enoThreshold: 20, enoHysteresis: 5);
      final s = PidState();
      PidMath.disable(p, s);
      const pv = [50, 35, 25, 31, 33, 34, 35, 36, 40, 50];
      const expected = [
        '0:0', '15000:0', '25000:1', '19000:1', '17000:1', '16000:1', '15000:0', '14000:0', '10000:0', '0:0',
      ];
      final got = <String>[];
      for (final v in pv) {
        PidMath.step(p, s, pvPct: v, spPct: 50);
        got.add('${s.mvM}:${s.eno ? 1 : 0}');
      }
      expect(got, expected);
    });

    test('F/G/H: ação direta, saída segura e limites de saída', () {
      var p = _base(direct: true, ki: 0, kd: 0);
      var s = PidState();
      PidMath.disable(p, s);
      PidMath.step(p, s, pvPct: 60, spPct: 50);
      expect(s.mvM, 25000);
      PidMath.step(p, s, pvPct: 40, spPct: 50);
      expect(s.mvM, 0);

      p = _base(safe: 30);
      s = PidState();
      PidMath.disable(p, s);
      expect(s.mvM, 30000);
      expect(s.eno, isFalse);

      p = _base(ki: 0, kd: 0, outMin: 10, outMax: 80);
      s = PidState();
      PidMath.disable(p, s);
      PidMath.step(p, s, pvPct: 0, spPct: 100);
      expect(s.mvM, 80000);
      PidMath.step(p, s, pvPct: 100, spPct: 0);
      expect(s.mvM, 10000);
    });

    test('validação de parâmetros (igual ao firmware)', () {
      expect(_base().isValid, isTrue);
      expect(_base(outMin: 90, outMax: 80).isValid, isFalse);
      expect(_base(deadbandX10: 251).isValid, isFalse);
    });
  });

  group('PidEvaluator (bloco no Ladder)', () {
    LadderNode node(NodeConfig c) => LadderNode(id: 'pid1', type: NodeType.pid, config: c);

    test('amostra a cada 100 ms e mantém a saída entre amostras', () {
      final ev = PidEvaluator();
      final store = TagStateStore();
      final st = NodeRuntimeState(nodeId: 'pid1');
      final n = node(NodeConfig.pid());
      store.setReal('AI0.0', 20);

      ev.evaluate(n, st, true, store, 50); // 1ª varredura: amostra imediata
      final first = store.getInt('MV_PID');
      expect(first, 77); // P=75 + I=1,5 (arredondado)
      store.setReal('AI0.0', 40);
      ev.evaluate(n, st, true, store, 50); // acumula 50 ms -> ainda não amostra
      expect(store.getInt('MV_PID'), first);
      ev.evaluate(n, st, true, store, 50); // 100 ms -> amostra
      expect(store.getInt('MV_PID'), isNot(first));
    });

    test('EN desligado -> saída segura e ENO falso', () {
      final ev = PidEvaluator();
      final store = TagStateStore();
      final st = NodeRuntimeState(nodeId: 'pid1');
      final cfg = NodeConfig.pid()..pidSafeOut = 15;
      store.setReal('AI0.0', 10);
      expect(ev.evaluate(node(cfg), st, true, store, 100), isTrue);
      expect(ev.evaluate(node(cfg), st, false, store, 100), isFalse);
      expect(store.getInt('MV_PID'), 15);
    });

    test('MV em saída digital Q0.x atua pelo ENO (liga/desliga com histerese)', () {
      final ev = PidEvaluator();
      final store = TagStateStore();
      final st = NodeRuntimeState(nodeId: 'pid1');
      final cfg = NodeConfig.pid()
        ..outputTagId = 'Q0.1'
        ..kp = 1.0
        ..ki = 0
        ..kd = 0;
      store.setReal('AI0.0', 25); // erro 25 -> MV 25 > 20 -> liga
      ev.evaluate(node(cfg), st, true, store, 100);
      expect(store.getBool('Q0.1'), isTrue);
      store.setReal('AI0.0', 33); // MV 17 (entre 15 e 20) -> mantém ligado
      ev.evaluate(node(cfg), st, true, store, 100);
      expect(store.getBool('Q0.1'), isTrue);
      store.setReal('AI0.0', 40); // MV 10 (<=15) -> desliga
      ev.evaluate(node(cfg), st, true, store, 100);
      expect(store.getBool('Q0.1'), isFalse);
    });

    test('modo manual segue a saída manual', () {
      final ev = PidEvaluator();
      final store = TagStateStore();
      final st = NodeRuntimeState(nodeId: 'pid1');
      final cfg = NodeConfig.pid()
        ..pidManualTagId = 'M0.0'
        ..pidManualOut = '60';
      store.setReal('AI0.0', 30);
      store.setBool('M0.0', true);
      ev.evaluate(node(cfg), st, true, store, 100);
      expect(store.getInt('MV_PID'), 60);
      expect(st.runtimeFlags['MAN'], isTrue);
    });
  });

  group('Compilador / Disassembler (OP_PIDX)', () {
    test('ida e volta preserva todos os parâmetros industriais', () {
      final project = DemoProject.createCleanTccProject();
      final pidNode = project.networks
          .expand((n) => n.nodes)
          .firstWhere((n) => n.type == NodeType.pid);
      pidNode.config
        ..pidDirect = true
        ..pidDerivativeOnError = true
        ..pidOutMin = 5
        ..pidOutMax = 90
        ..pidDeadband = 1.5
        ..pidEnoThreshold = 30
        ..pidEnoHysteresis = 10
        ..pidSafeOut = 12
        ..pidManualTagId = 'M0.0'
        ..pidManualOut = '40';

      final bytes = BytecodeCompiler().compile(project);
      expect(bytes.contains(0x61), isTrue);

      final back = BytecodeDisassembler().disassemble(bytes);
      final c = back.networks.expand((n) => n.nodes).firstWhere((n) => n.type == NodeType.pid).config;
      expect(c.kp, 2.5);
      expect(c.pidDirect, isTrue);
      expect(c.pidDerivativeOnError, isTrue);
      expect(c.pidOutMin, 5);
      expect(c.pidOutMax, 90);
      expect(c.pidDeadband, 1.5);
      expect(c.pidEnoThreshold, 30);
      expect(c.pidEnoHysteresis, 10);
      expect(c.pidSafeOut, 12);
      expect(c.pidManualTagId, 'M0.0');
      expect(c.pidManualOut, '40');
      expect(c.tagId, 'AI0.0');
      expect(c.outputTagId, 'MV_PID');
    });

    test('projeto limpo da bancada compila o PID com operando de 23 bytes', () {
      final project = DemoProject.createCleanTccProject();
      final bytes = BytecodeCompiler().compile(project);
      final i = bytes.indexOf(0x61, 5);
      expect(i, greaterThan(4));
      // pv(2) = AI0.0 (72), mv(2) = MV_PID (33)
      expect((bytes[i + 1] << 8) | bytes[i + 2], 72);
      expect((bytes[i + 5] << 8) | bytes[i + 6], 33);
    });
  });

  group('Validação do PID (erros explícitos, sem correção silenciosa)', () {
    bool valid(void Function(NodeConfig) tweak) {
      final project = DemoProject.createCleanTccProject();
      final pid = project.networks.expand((n) => n.nodes).firstWhere((n) => n.type == NodeType.pid);
      tweak(pid.config);
      return GraphValidator().validate(project).isValid;
    }

    test('configuração padrão da bancada é válida', () {
      expect(valid((_) {}), isTrue);
    });

    test('PV não pode ser saída', () => expect(valid((c) => c.tagId = 'Q0.0'), isFalse));
    test('MV não pode ser entrada analógica', () => expect(valid((c) => c.outputTagId = 'AI0.1'), isFalse));
    test('PV e MV não podem coincidir', () => expect(valid((c) => c.outputTagId = c.tagId), isFalse));
    test('SP fora de 0..100', () => expect(valid((c) => c.setpointTagId = '150'), isFalse));
    test('limites de saída incoerentes', () {
      expect(valid((c) {
        c.pidOutMin = 80;
        c.pidOutMax = 20;
      }), isFalse);
    });
    test('chave manual inexistente', () => expect(valid((c) {
          c.pidManualTagId = 'NAO_EXISTE';
          c.pidManualOut = '10';
        }), isFalse));
  });
}
