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

void main() {
  group('VALIDAÇÃO FUNCIONAL COMPLETA — NOVO LADDER INDUSTRIAL', () {
    
    test('1. Criar Rung Real + Inserir NO + Inserir COIL + Conectar Nós + Validar + Compilar + Executar + Forçar', () {
      // Criação de projeto real
      final project = LadderProject(
        id: 'proj_industrial_real',
        name: 'Controle Motor Industrial',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Botão Partida', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor Principal', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      // 1. Tocar em ADICIONAR RUNG cria LadderNetwork real
      final network = LadderNetwork(
        id: 'rung_0001',
        name: 'Partida Direta',
      );
      project.networks.add(network);
      expect(project.networks.length, equals(1));

      // 2. Inserção direta de NO [ ]
      final noNode = LadderNode(
        id: 'node_start',
        type: NodeType.contactNO,
        config: NodeConfig(tagId: 'START_BTN'),
      );
      project.networks[0].insertNode(noNode, 0);

      // 3. Inserção direta de COIL ( )
      final coilNode = LadderNode(
        id: 'node_motor',
        type: NodeType.coil,
        config: NodeConfig(tagId: 'MOTOR_M1'),
      );
      project.networks[0].insertNode(coilNode, 1);

      // 4. Conexões reconstruídas automaticamente
      project.networks[0].rebuildConnections();
      expect(project.networks[0].nodes.length, equals(2));
      expect(project.networks[0].connections.length, equals(1));
      expect(project.networks[0].connections.first.fromNodeId, equals('node_start'));
      expect(project.networks[0].connections.first.toNodeId, equals('node_motor'));

      // 5. Validar via GraphValidator
      final validator = GraphValidator();
      final validation = validator.validate(project);
      expect(validation.isValid, isTrue, reason: 'O diagrama deve ser 100% válido');
      expect(validation.executableGraph, isNotNull);

      // 6. Compilar Bytecode
      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);
      expect(bytecode, isNotEmpty);
      expect(bytecode[0], equals(0x45)); // Header 'E'

      // 7. Simular com LadderRuntime real
      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      // 8. Forçar START_BTN = OFF
      runtime.tagStore.setBool('START_BTN', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);

      // 9. Forçar START_BTN = ON
      runtime.tagStore.setBool('START_BTN', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue, reason: 'MOTOR_M1 deve ativar');
      expect(runtime.nodeStates['node_motor']?.energized, isTrue);

      // 10. Mapeamento I/O unificado (Y0 -> MOTOR_M1)
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue);
    });

    test('2. Comportamento determinístico de Temporizador TON (5s)', () {
      final project = LadderProject(
        id: 'proj_ton_test',
        name: 'Temporização Válvula',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'VALVE_V204': Tag(id: 'VALVE_V204', name: 'Valvula', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_ton_1',
        nodes: [
          LadderNode(id: 'n_in', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(id: 'n_ton', type: NodeType.timerTON, config: NodeConfig(tagId: 'T_VALVE', presetValue: TagValue.integer(5000))),
          LadderNode(id: 'n_out', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_V204')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final validation = GraphValidator().validate(project);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      runtime.tagStore.setBool('START_BTN', true);

      // Passam 3s (3000ms) -> Válvula desligada
      runtime.singleScan(3000);
      expect(runtime.tagStore.getBool('VALVE_V204'), isFalse);

      // Passam mais 2.5s (total 5500ms) -> Válvula ligada
      runtime.singleScan(2500);
      expect(runtime.tagStore.getBool('VALVE_V204'), isTrue);
    });

    test('3. Contador CTU de pulsos com borda de subida (Preset = 3)', () {
      final project = LadderProject(
        id: 'proj_ctu_test',
        name: 'Contador Peças',
        tags: {
          'SENSOR': Tag(id: 'SENSOR', name: 'Sensor', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'ALARM': Tag(id: 'ALARM', name: 'Alarme', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_ctu_1',
        nodes: [
          LadderNode(id: 'n_sens', type: NodeType.contactNO, config: NodeConfig(tagId: 'SENSOR')),
          LadderNode(id: 'n_ctu', type: NodeType.counterCTU, config: NodeConfig(tagId: 'C_PIECES', presetValue: TagValue.integer(3))),
          LadderNode(id: 'n_alarm', type: NodeType.coil, config: NodeConfig(tagId: 'ALARM')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final validation = GraphValidator().validate(project);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      // Pulso 1
      runtime.tagStore.setBool('SENSOR', true);
      runtime.singleScan(10);
      runtime.tagStore.setBool('SENSOR', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM'), isFalse);

      // Pulso 2
      runtime.tagStore.setBool('SENSOR', true);
      runtime.singleScan(10);
      runtime.tagStore.setBool('SENSOR', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM'), isFalse);

      // Pulso 3 (Atinge Preset)
      runtime.tagStore.setBool('SENSOR', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('ALARM'), isTrue, reason: 'Alarme deve acionar no 3º pulso');
    });

    test('4. Comparador Analógico Real (TEMP_MOTOR > 80 -> TRIP_ALARM)', () {
      final project = LadderProject(
        id: 'proj_cmp_test',
        name: 'Proteção Térmica',
        tags: {
          'TEMP_MOTOR': Tag(id: 'TEMP_MOTOR', name: 'Temperatura', type: TagType.real, initialValue: TagValue.real(60.0)),
          'TRIP_ALARM': Tag(id: 'TRIP_ALARM', name: 'Trip', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_cmp_1',
        nodes: [
          LadderNode(id: 'n_cmp', type: NodeType.compareGreater, config: NodeConfig(tagId: 'TEMP_MOTOR', presetValue: TagValue.real(80.0))),
          LadderNode(id: 'n_trip', type: NodeType.coil, config: NodeConfig(tagId: 'TRIP_ALARM')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final validation = GraphValidator().validate(project);
      expect(validation.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(validation.executableGraph!);

      // Temperatura segura (78.0°C)
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(78.0));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isFalse);

      // Sobreaquecimento (83.2°C)
      runtime.tagStore.setValue('TEMP_MOTOR', TagValue.real(83.2));
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('TRIP_ALARM'), isTrue);
    });

    test('5. Persistência -> Salvar -> Recarregar -> Continuar -> Executar', () {
      final original = LadderProject(
        id: 'proj_persistent_flow',
        name: 'Automação Salva',
        tags: {
          'BTN_IN': Tag(id: 'BTN_IN', name: 'Input', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'LAMP_OUT': Tag(id: 'LAMP_OUT', name: 'Output', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );
      final rung = LadderNetwork(
        id: 'net_lamp',
        nodes: [
          LadderNode(id: 'n1', type: NodeType.contactNO, config: NodeConfig(tagId: 'BTN_IN')),
          LadderNode(id: 'n2', type: NodeType.coil, config: NodeConfig(tagId: 'LAMP_OUT')),
        ],
      )..rebuildConnections();
      original.networks.add(rung);

      // Salvar (Serializar JSON)
      final json = original.toJson();

      // Recarregar / Continuar (Desserializar JSON)
      final restored = LadderProject.fromJson(json);
      expect(restored.networks.length, equals(1));
      expect(restored.networks.first.nodes.length, equals(2));

      // Executar no Runtime
      final val = GraphValidator().validate(restored);
      expect(val.isValid, isTrue);

      final rt = LadderRuntime();
      rt.loadProject(val.executableGraph!);
      rt.tagStore.setBool('BTN_IN', true);
      rt.singleScan(10);
      expect(rt.tagStore.getBool('LAMP_OUT'), isTrue);
    });

    test('6. Gesto de Arrastar/Mover Nó + Arrastar Tag para Nó + rebuildConnections', () {
      final project = LadderProject(
        id: 'proj_drag_test',
        name: 'Teste Gesto Drag and Drop',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'STOP_BTN': Tag(id: 'STOP_BTN', name: 'Stop', type: TagType.bool, initialValue: TagValue.boolean(true)),
          'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_1',
        nodes: [
          LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
          LadderNode(id: 'n_stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP_BTN')),
          LadderNode(id: 'n_motor', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      expect(project.networks[0].nodes[0].id, equals('n_start'));
      expect(project.networks[0].nodes[1].id, equals('n_stop'));
      expect(project.networks[0].nodes[2].id, equals('n_motor'));

      // Simular gesto de arrastar o nó 'n_start' da posição 0 para a posição 2 (após n_stop)
      final movedNode = project.networks[0].nodes[0];
      project.networks[0].removeNodeAt(0);
      project.networks[0].insertNode(movedNode, 1);
      project.networks[0].rebuildConnections();

      expect(project.networks[0].nodes[0].id, equals('n_stop'));
      expect(project.networks[0].nodes[1].id, equals('n_start'));
      expect(project.networks[0].nodes[2].id, equals('n_motor'));
      expect(project.networks[0].connections.length, equals(2));
      expect(project.networks[0].connections[0].fromNodeId, equals('n_stop'));
      expect(project.networks[0].connections[0].toNodeId, equals('n_start'));
      expect(project.networks[0].connections[1].fromNodeId, equals('n_start'));
      expect(project.networks[0].connections[1].toNodeId, equals('n_motor'));

      // Validar que o grafo continua válido e determinístico
      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);

      final rt = LadderRuntime();
      rt.loadProject(val.executableGraph!);
      rt.tagStore.setBool('STOP_BTN', false); // NC deixará passar se tag for false
      rt.tagStore.setBool('START_BTN', true);
      rt.singleScan(10);
      expect(rt.tagStore.getBool('MOTOR_M1'), isTrue);
    });

    test('7. Semântica IEC Contato NC: STOP OFF conduz, STOP ON bloqueia', () {
      final project = LadderProject(
        id: 'proj_nc_test',
        name: 'Teste NC IEC',
        tags: {
          'STOP_BTN': Tag(id: 'STOP_BTN', name: 'Stop', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'VALVE_OUT': Tag(id: 'VALVE_OUT', name: 'Valvula', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      final rung = LadderNetwork(
        id: 'rung_nc',
        nodes: [
          LadderNode(id: 'n_nc', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP_BTN')),
          LadderNode(id: 'n_out', type: NodeType.coil, config: NodeConfig(tagId: 'VALVE_OUT')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue);

      final runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);

      // Cenário 1: STOP_BTN = OFF (false) -> NC conduz -> VALVE_OUT = ON (true)
      runtime.tagStore.setBool('STOP_BTN', false);
      runtime.singleScan(10);
      expect(runtime.nodeStates['n_nc']?.energized, isTrue, reason: 'NC deve conduzir quando tag está em OFF');
      expect(runtime.tagStore.getBool('VALVE_OUT'), isTrue);

      // Cenário 2: STOP_BTN = ON (true) -> NC bloqueia -> VALVE_OUT = OFF (false)
      runtime.tagStore.setBool('STOP_BTN', true);
      runtime.singleScan(10);
      expect(runtime.nodeStates['n_nc']?.energized, isFalse, reason: 'NC deve bloquear quando tag está em ON');
      expect(runtime.tagStore.getBool('VALVE_OUT'), isFalse);
    });

    test('8. Validação: Comparador/Contato sozinho sem saída é INVÁLIDO; com COIL é VÁLIDO', () {
      final invalidProject = LadderProject(
        id: 'proj_invalid_cmp',
        name: 'Comparador sem saida',
        tags: {
          'TEMP_MOTOR': Tag(id: 'TEMP_MOTOR', name: 'Temp', type: TagType.real, initialValue: TagValue.real(50.0)),
        },
      );
      final invalidRung = LadderNetwork(
        id: 'rung_no_out',
        nodes: [
          LadderNode(id: 'n_les', type: NodeType.compareLess, config: NodeConfig(tagId: 'TEMP_MOTOR', presetValue: TagValue.real(80.0))),
        ],
      )..rebuildConnections();
      invalidProject.networks.add(invalidRung);

      // 1. Validator deve rejeitar porque falta saída (Bobina/Temporizador/Contador)
      final valInvalid = GraphValidator().validate(invalidProject);
      expect(valInvalid.isValid, isFalse);
      expect(valInvalid.errors.any((e) => e.message.contains('ao menos uma saída')), isTrue);

      // 2. Ao adicionar uma bobina de saída (COIL) e reconstruir conexões -> Válido
      invalidProject.tags['COOLING_FAN'] = Tag(id: 'COOLING_FAN', name: 'Fan', type: TagType.bool);
      invalidProject.networks[0].insertNode(
        LadderNode(id: 'n_fan', type: NodeType.coil, config: NodeConfig(tagId: 'COOLING_FAN')),
        1,
      );
      invalidProject.networks[0].rebuildConnections();

      final valValid = GraphValidator().validate(invalidProject);
      expect(valValid.isValid, isTrue);
    });

    test('9. Circuito de Selo (Latch): START liga MOTOR_M1, ao soltar START selo mantém MOTOR_M1 ativo, STOP desliga', () {
      final project = LadderProject(
        id: 'proj_selo_test',
        name: 'Partida com Selo',
        tags: {
          'START_BTN': Tag(id: 'START_BTN', name: 'Start', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'STOP_BTN': Tag(id: 'STOP_BTN', name: 'Stop', type: TagType.bool, initialValue: TagValue.boolean(false)),
          'MOTOR_M1': Tag(id: 'MOTOR_M1', name: 'Motor M1', type: TagType.bool, initialValue: TagValue.boolean(false)),
        },
      );

      // Rung: [ (START_BTN) || (MOTOR_M1) ] -> [ / STOP_BTN / ] -> ( MOTOR_M1 )
      final rung = LadderNetwork(
        id: 'rung_selo',
        nodes: [
          LadderNode(
            id: 'n_parallel',
            type: NodeType.parallel,
            config: NodeConfig(),
            branches: [
              [
                LadderNode(id: 'n_start', type: NodeType.contactNO, config: NodeConfig(tagId: 'START_BTN')),
              ],
              [
                LadderNode(id: 'n_selo', type: NodeType.contactNO, config: NodeConfig(tagId: 'MOTOR_M1')),
              ],
            ],
          ),
          LadderNode(id: 'n_stop', type: NodeType.contactNC, config: NodeConfig(tagId: 'STOP_BTN')),
          LadderNode(id: 'n_coil', type: NodeType.coil, config: NodeConfig(tagId: 'MOTOR_M1')),
        ],
      )..rebuildConnections();
      project.networks.add(rung);

      final val = GraphValidator().validate(project);
      expect(val.isValid, isTrue, reason: 'Circuito com ramo paralelo e selo deve ser válido');

      final runtime = LadderRuntime();
      runtime.loadProject(val.executableGraph!);

      // Estado inicial: tudo desligado
      runtime.tagStore.setBool('START_BTN', false);
      runtime.tagStore.setBool('STOP_BTN', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse);
      expect(runtime.nodeStates['n_coil']?.energized, isFalse);
      expect(runtime.nodeStates['n_selo']?.energized, isFalse);

      // Passo 1: Pressiona START_BTN (true) -> MOTOR_M1 liga
      runtime.tagStore.setBool('START_BTN', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue, reason: 'MOTOR_M1 deve ligar com START_BTN');
      expect(runtime.nodeStates['n_coil']?.energized, isTrue);

      // Passo 2: Solta START_BTN (false) -> Selo mantém MOTOR_M1 ligado
      runtime.tagStore.setBool('START_BTN', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isTrue, reason: 'Selo deve manter MOTOR_M1 ligado após soltar START');
      expect(runtime.nodeStates['n_selo']?.energized, isTrue, reason: 'Contato de selo MOTOR_M1 deve estar energizado');
      expect(runtime.nodeStates['n_coil']?.energized, isTrue, reason: 'Bobina MOTOR_M1 deve permanecer energizada');

      // Passo 3: Pressiona STOP_BTN (true) -> NC abre -> MOTOR_M1 desliga e quebra o selo
      runtime.tagStore.setBool('STOP_BTN', true);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse, reason: 'STOP_BTN deve desarmar MOTOR_M1');
      expect(runtime.nodeStates['n_coil']?.energized, isFalse);

      // Passo 4: Solta STOP_BTN (false) -> MOTOR_M1 continua desligado (selo foi quebrado)
      runtime.tagStore.setBool('STOP_BTN', false);
      runtime.singleScan(10);
      expect(runtime.tagStore.getBool('MOTOR_M1'), isFalse, reason: 'MOTOR_M1 deve continuar desligado até novo pulso de START');
    });
  });
}
