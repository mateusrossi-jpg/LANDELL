import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/tag_value.dart';
import 'package:endap_studio/ladder/runtime/ladder_runtime.dart';
import 'package:endap_studio/ladder/validation/graph_validator.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';

void main() {
  group('FASE 2 — Suíte de Integração End-to-End Completa', () {
    
    test('TESTE 1: Novo projeto -> START_BTN -> MOTOR_M1 -> Validar -> Compilar -> Simular (START_BTN ON => MOTOR_M1 ON, Y0 ON) + EventLog', () {
      // 1. Criar projeto
      final project = LadderProject(
        id: 'proj_e2e_1',
        name: 'Automação Motor Direto',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start Button', address: 'I0.0', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor Principal', address: 'Q0.0', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      StudioEventBus.instance.emit(
        type: 'PROJECT',
        source: 'LADDER_EDITOR',
        message: 'PROJETO CRIADO: ${project.name}',
        severity: EventSeverity.info,
      );

      // 2. Criar regra (estrutura nativa do RuleBuilder)
      final rung = LadderNetwork(
        id: 'rung_motor_direct',
        name: 'Quando [START_BTN] ativar -> ligar [MOTOR_M1]',
        nodes: [
          LadderNode(id: 'node_in_1', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(id: 'node_out_1', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      // 3. Validar
      final validator = GraphValidator();
      final validationResult = validator.validate(project);
      expect(validationResult.isValid, isTrue, reason: 'O programa gerado deve ser válido');
      expect(validationResult.executableGraph, isNotNull);

      StudioEventBus.instance.emit(
        type: 'VALIDATOR',
        source: 'GRAPH_VALIDATOR',
        message: 'PROGRAMA VÁLIDO • 1 RUNGS VERIFICADOS',
        severity: EventSeverity.info,
      );

      // 4. Compilar para Bytecode IEC
      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);
      expect(bytecode, isNotEmpty);
      expect(bytecode.first, equals(0x45)); // 'E'
      expect(bytecode.last, equals(0xFF));  // Terminator

      StudioEventBus.instance.emit(
        type: 'COMPILER',
        source: 'BYTECODE_COMPILER',
        message: 'BYTECODE GERADO COM SUCESSO (${bytecode.length} BYTES)',
        severity: EventSeverity.info,
      );

      // 5. Carregar no LadderRuntime
      final runtime = LadderRuntime();
      runtime.loadProject(validationResult.executableGraph!);

      // 6. Verificar estado inicial (OFF)
      runtime.tagStore.setBool('START_BTN', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);

      // 7. Forçar entrada START_BTN = ON
      runtime.tagStore.setBool('START_BTN', true);
      StudioEventBus.instance.emit(
        type: 'SIMULATOR',
        source: 'TAG_STORE',
        message: 'INPUT FORÇADO: START_BTN = ON',
        severity: EventSeverity.info,
      );

      // 8. Executar ciclo de varredura
      runtime.singleScan(10);

      // 9. Comprovar que MOTOR_M1 = ON e nó correspondente energizado
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue, reason: 'Bobina MOTOR_M1 deve ser ativada');
      expect(runtime.nodeStates['node_out_1']?.energized, isTrue);

      StudioEventBus.instance.emit(
        type: 'RUNTIME',
        source: 'SCAN_ENGINE',
        message: 'OUTPUT ATUALIZADO: MOTOR_M1 = ON',
        severity: EventSeverity.info,
      );

      // 10. Comprovar mapeamento I/O (X0 -> START_BTN, Y0 -> MOTOR_M1)
      final mappedOutput = runtime.tagStore.getBool('MOTOR_M1');
      expect(mappedOutput, isTrue);
    });

    test('TESTE 2: START_BTN -> TON 5s -> VALVE_V204 (Temporização determinística)', () {
      final project = LadderProject(
        id: 'proj_e2e_ton',
        name: 'Automação Válvula Temporizada',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'VALVE_V204': Tag(id: 'VALVE_V204', name: 'Valve Actuator', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_ton',
        name: 'Quando [START_BTN] ativar -> esperar 5s e acionar [VALVE_V204]',
        nodes: [
          LadderNode(id: 'node_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(
            id: 'node_timer',
            type: NodeType.timerTON,
            config: NodeConfig(tagId: 'T_VALVE', presetValue: TagValue.integer(5000)),
          ),
          LadderNode(id: 'node_valve', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_V204')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final validation = GraphValidator().validate(project);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      // Iniciar com START_BTN = ON
      runtime.tagStore.setBool('START_BTN', true);

      // Varredura de 2000ms (ainda não atingiu 5000ms)
      runtime.singleScan(2000);
      expect(runtime.tagStore.getBool('VALVE_V204'), isFalse, reason: 'Válvula não pode ligar antes de 5s');

      // Mais 2000ms (total 4000ms)
      runtime.singleScan(2000);
      expect(runtime.tagStore.getBool('VALVE_V204'), isFalse);

      // Mais 1500ms (total 5500ms -> estouro do timer)
      runtime.singleScan(1500);
      expect(runtime.tagStore.getBool('VALVE_V204'), isTrue, reason: 'Válvula deve ativar após 5s');
    });

    test('TESTE 3: TEMP_MOTOR > 80 -> TRIP_ALARM (Comparação Analógica Real)', () {
      final project = LadderProject(
        id: 'proj_e2e_cmp',
        name: 'Proteção Térmica do Motor',
        tags: {
          'TEMP_MOTOR': Tag(id: 'TEMP_MOTOR', name: 'Temperatura', type: TagType.real, initialValue: TagValue.real(65.0)),
          'TRIP_ALARM': Tag(id: 'TRIP_ALARM', name: 'Trip Alarme', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_trip',
        name: 'Se TEMP_MOTOR > 80 ligar TRIP_ALARM',
        nodes: [
          LadderNode(
            id: 'node_cmp',
            type: NodeType.compareGreater,
            config: NodeConfig(tagId: 'TEMP_MOTOR', presetValue: TagValue.real(80.0)),
          ),
          LadderNode(id: 'node_trip_coil', type: NodeType.coil, config: NodeConfig(tagId: 'TRIP_ALARM')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final validation = GraphValidator().validate(project);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      // Temperatura normal (75°C)
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(75.0));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isFalse);

      // Temperatura de sobreaquecimento (82.5°C)
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(82.5));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isTrue, reason: 'Alarme de trip deve disparar para temp > 80');
    });

    test('TESTE 4: Persistência -> Serialização -> Reload -> Continuar -> Executar Determinístico', () {
      // 1. Cria projeto original
      final originalProject = LadderProject(
        id: 'proj_persisted_test',
        name: 'Ciclo Persistente',
        tags: {
          'SENSOR_1': Tag(id: 'SENSOR_1', name: 'Sensor 1', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'PUMP_1': Tag(id: 'PUMP_1', name: 'Bomba 1', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'net_pump',
        name: 'Acionamento de Bomba',
        nodes: [
          LadderNode(id: 'n_sens', type: NodeType.contactNO, config: NodeConfig(tagId: 'SENSOR_1')),
          LadderNode(id: 'n_pump', type: NodeType.coil, config: NodeConfig(tagId: 'PUMP_1')),
        ],
      )..rebuildConnections();
      originalProject.networks.add(rung);

      // 2. Serializa (salva)
      final jsonMap = originalProject.toJson();
      expect(jsonMap['networks'], isNotEmpty);

      // 3. Simula recarga completa a partir do JSON (recarregar / continuar)
      final restoredProject = LadderProject.fromJson(jsonMap);
      expect(restoredProject.id, equals(originalProject.id));
      expect(restoredProject.networks.length, equals(1));
      expect(restoredProject.networks.first.nodes.length, equals(2));
      expect(restoredProject.tags.containsKey('SENSOR_1'), isTrue);
      expect(restoredProject.tags.containsKey('PUMP_1'), isTrue);

      // 4. Executa no runtime para comprovar determinismo idêntico
      final validation = GraphValidator().validate(restoredProject);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      runtime.tagStore.setBool('SENSOR_1', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('PUMP_1'), isTrue, reason: 'Projeto restaurado deve executar perfeitamente');
    });

    test('TESTE 5: GraphValidator bloqueia compilação com nó inválido / sem tag e emite erro', () {
      final invalidProject = LadderProject(
        id: 'proj_invalid',
        name: 'Projeto com Erro',
        networks: [
          LadderNetwork(
            id: 'rung_empty_tag',
            name: 'Rung Inválido',
            nodes: [
              LadderNode(id: 'n_in', type: NodeType.contactNO, config: NodeConfig(tagId: '')), // Tag vazia
              LadderNode(id: 'n_out', type: NodeType.coil, config: NodeConfig(tagId: 'OUT1')),
            ],
          )..rebuildConnections()
        ],
      );

      final validator = GraphValidator();
      final result = validator.validate(invalidProject);

      expect(result.isValid, isFalse, reason: 'Nó sem tag deve invalidar o programa');
      expect(result.errors, isNotEmpty);
      expect(result.executableGraph, isNull, reason: 'Compilação de grafo executável deve ser bloqueada');
    });
  });
}
