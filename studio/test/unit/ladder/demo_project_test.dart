import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';

void main() {
  test('DemoProject builds valid graph and executes motor start with latch and pump', () {
    final project = DemoProject.createDemoProject();
    expect(project.networks.length, 9);
    expect(project.tags.containsKey('I0.0'), isTrue);
    expect(project.tags.containsKey('I0.1'), isTrue);
    expect(project.tags.containsKey('AI0.0'), isTrue);
    expect(project.tags.containsKey('AI0.1'), isTrue);
    expect(project.tags.containsKey('AI0.2'), isTrue);
    expect(project.tags.containsKey('Q0.0'), isTrue);
    expect(project.tags.containsKey('Q0.1'), isTrue);
    expect(project.tags.containsKey('Q0.2'), isTrue);
    expect(project.tags.containsKey('Q0.3'), isTrue);
    expect(project.tags.containsKey('Q0.4'), isTrue);

    final validator = GraphValidator();
    final valResult = validator.validate(project);
    expect(valResult.isValid, isTrue);
    expect(valResult.executableGraph, isNotNull);

    final runtime = LadderRuntime();
    runtime.loadProject(valResult.executableGraph!);

    // 1. Testa Rung 0: Contato NA Simples (I0.0) -> Bobina Q0.0
    runtime.tagStore.setBool('I0.0', false);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.0'), isFalse);
    runtime.tagStore.setBool('I0.0', true);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.0'), isTrue);
    runtime.tagStore.setBool('I0.0', false);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.0'), isFalse);

    // 2. Testa Rung 2 & 3: Malha de Irrigação PID e Comparador [MV_PID > 20%] -> Válvula Q0.1
    // Com solo seco (AI0.0 = 0.0 < SP_PID 50.0), PID gera MV_PID = 100% -> Q0.1 = true (abre irrigação)
    runtime.tagStore.setReal('AI0.0', 0.0);
    runtime.singleScan(100);
    expect(runtime.tagStore.getReal('MV_PID') > 20.0, isTrue);
    expect(runtime.tagStore.getBool('Q0.1'), isTrue);

    // Quando o solo é irrigado (AI0.0 = 85.0 > SP_PID 50.0), erro < 0 -> MV_PID = 0% -> Q0.1 = false (fecha irrigação)
    runtime.tagStore.setReal('AI0.0', 85.0);
    runtime.singleScan(100);
    expect(runtime.tagStore.getReal('MV_PID') <= 20.0, isTrue);
    expect(runtime.tagStore.getBool('Q0.1'), isFalse);

    // 3. Testa Rung 2 & 3: Bobina SET (I0.2) e Bobina RESET (I0.3) em Q0.2
    runtime.tagStore.setBool('I0.2', true); // Pulso SET
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.2'), isTrue);
    runtime.tagStore.setBool('I0.2', false); // Entrada abre após pulso
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.2'), isTrue); // Q0.2 permanece retida!

    runtime.tagStore.setBool('I0.3', true); // Pulso RESET
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.2'), isFalse); // Q0.2 desativa na hora!
    runtime.tagStore.setBool('I0.3', false); // Entrada abre após pulso
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.2'), isFalse); // Permanece desligada!

    // 4. Testa Rung 4: Temporizador TON (I0.4) -> T0 (3s) -> Q0.3
    runtime.tagStore.setBool('I0.4', true);
    runtime.singleScan(1000);
    expect(runtime.tagStore.getBool('Q0.3'), isFalse);
    runtime.singleScan(2000); // Total 3000ms atingido
    expect(runtime.tagStore.getBool('Q0.3'), isTrue);
    runtime.tagStore.setBool('I0.4', false); // Desliga entrada
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.3'), isFalse); // Zera e desliga Q0.3!
  });

  test('createCleanTccProject builds valid 5-rung bench graph with all restored GPIOs', () {
    final project = DemoProject.createCleanTccProject();
    expect(project.networks.length, 5);
    for (int i = 0; i <= 5; i++) {
      expect(project.tags.containsKey('I0.$i'), isTrue);
    }
    for (int i = 0; i <= 3; i++) {
      expect(project.tags.containsKey('AI0.$i'), isTrue);
    }
    expect(project.tags.containsKey('UMID_SOLO'), isFalse);
    for (int i = 0; i <= 7; i++) {
      expect(project.tags.containsKey('Q0.$i'), isTrue);
    }
    expect(project.tags.containsKey('AO0.0'), isTrue);
    expect(project.tags.containsKey('AO0.1'), isTrue);

    final validator = GraphValidator();
    final valResult = validator.validate(project);
    expect(valResult.isValid, isTrue);
    expect(valResult.executableGraph, isNotNull);

    final runtime = LadderRuntime();
    runtime.loadProject(valResult.executableGraph!);

    // Rung 2: Sensor Capacitivo AI0.0 < 50% -> Q0.1 = true; >= 50% -> Q0.1 = false
    runtime.tagStore.setReal('AI0.0', 10.0);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.1'), isTrue);

    runtime.tagStore.setReal('AI0.0', 85.0);
    runtime.singleScan(100);
    expect(runtime.tagStore.getBool('Q0.1'), isFalse);
  });
}
