import 'ladder_project.dart';
import 'ladder_network.dart';
import 'ladder_node.dart';
import 'node_config.dart';
import 'tag.dart';
import 'tag_value.dart';
import 'enums.dart';
import 'project_metadata.dart';
import '../../home/models/home_widget_config.dart';
import '../../home/models/hmi_screen.dart';

class DemoProject {
  static Map<String, Tag> createDefaultTags() {
    final tags = <String, Tag>{};

    // Mapeamento dos 6 canais de entradas digitais físicas no ESP32 (I0.0 .. I0.5)
    final inputGpios = [
      {'iec': 'I0.0', 'gpio': 'GPIO16', 'desc': 'Entrada Digital I0.0 (GPIO 16)'},
      {'iec': 'I0.1', 'gpio': 'GPIO17', 'desc': 'Entrada Digital I0.1 (GPIO 17)'},
      {'iec': 'I0.2', 'gpio': 'GPIO18', 'desc': 'Entrada Digital I0.2 (GPIO 18)'},
      {'iec': 'I0.3', 'gpio': 'GPIO19', 'desc': 'Entrada Digital I0.3 (GPIO 19)'},
      {'iec': 'I0.4', 'gpio': 'GPIO27', 'desc': 'Entrada Digital I0.4 (GPIO 27)'},
      {'iec': 'I0.5', 'gpio': 'GPIO13', 'desc': 'Entrada Digital I0.5 (GPIO 13)'},
    ];

    for (var inCfg in inputGpios) {
      final iecName = inCfg['iec'] as String;
      final gpioStr = inCfg['gpio'] as String;
      final descStr = inCfg['desc'] as String;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.bool,
        address: iecName,
        description: '$descStr ($gpioStr)',
        initialValue: TagValue.boolean(false),
      );
    }

    // Mapeamento dos canais de saídas digitais físicas no ESP32 (Q0.0 .. Q0.7)
    final outputGpios = [
      {'iec': 'Q0.0', 'gpio': 'GPIO4',  'desc': 'Saída Digital Q0.0 (GPIO 4 - Relé 1)'},
      {'iec': 'Q0.1', 'gpio': 'GPIO21', 'desc': 'Saída Digital Q0.1 (GPIO 21 - Relé 2)'},
      {'iec': 'Q0.2', 'gpio': 'GPIO22', 'desc': 'Saída Digital Q0.2 (GPIO 22 - Relé 3)'},
      {'iec': 'Q0.3', 'gpio': 'GPIO33', 'desc': 'Saída Digital Q0.3 (GPIO 33 - Relé 4)'},
      {'iec': 'Q0.4', 'gpio': 'GPIO23', 'desc': 'Saída Digital Q0.4 (GPIO 23 - Relé 5)'},
      {'iec': 'Q0.5', 'gpio': 'GPIO32', 'desc': 'Saída Digital Q0.5 (GPIO 32 - Relé 6)'},
      {'iec': 'Q0.6', 'gpio': 'GPIO14', 'desc': 'Saída Digital Q0.6 (GPIO 14 - Relé 7)'},
      {'iec': 'Q0.7', 'gpio': 'GPIO2',  'desc': 'Saída Digital Q0.7 (GPIO 2 - LED/Aux)'},
    ];

    for (var outCfg in outputGpios) {
      final iecName = outCfg['iec'] as String;
      final gpioStr = outCfg['gpio'] as String;
      final descStr = outCfg['desc'] as String;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.bool,
        address: iecName,
        description: '$descStr ($gpioStr)',
        initialValue: TagValue.boolean(false),
      );
    }



    // Mapeamento dos canais de E/S Analógicas Reais do Controlador (AI0.0 .. AI0.3)
    tags['AI0.0'] = Tag(
      id: 'AI0.0',
      name: 'AI0.0',
      type: TagType.real,
      address: 'AI0.0',
      description: 'Entrada Analógica 0 — Sensor Capacitivo 0-100% (GPIO 34 / 35)',
      unit: '%',
      rawMin: 1500,
      rawMax: 3800,
      scaledMin: 100,
      scaledMax: 0,
      initialValue: TagValue.real(0.0),
    );

    tags['AI0.1'] = Tag(
      id: 'AI0.1',
      name: 'AI0.1',
      type: TagType.real,
      address: 'AI0.1',
      description: 'Entrada Analógica 1 — Sensor Capacitivo 0-100% (GPIO 35)',
      unit: '%',
      rawMin: 1500,
      rawMax: 3800,
      scaledMin: 100,
      scaledMax: 0,
      initialValue: TagValue.real(0.0),
    );

    tags['AI0.2'] = Tag(
      id: 'AI0.2',
      name: 'AI0.2',
      type: TagType.real,
      address: 'AI0.2',
      description: 'Entrada Analógica 0-3.3V (ADC1_CH0 / GPIO 36 VP)',
      unit: 'V',
      rawMin: 0,
      rawMax: 4095,
      scaledMin: 0,
      scaledMax: 3.3,
      initialValue: TagValue.real(0.0),
    );

    tags['AI0.3'] = Tag(
      id: 'AI0.3',
      name: 'AI0.3',
      type: TagType.real,
      address: 'AI0.3',
      description: 'Entrada Analógica 0-3.3V (ADC1_CH3 / GPIO 39 VN)',
      unit: 'V',
      rawMin: 0,
      rawMax: 4095,
      scaledMin: 0,
      scaledMax: 3.3,
      initialValue: TagValue.real(0.0),
    );

    tags['AO0.0'] = Tag(
      id: 'AO0.0',
      name: 'AO0.0',
      type: TagType.real,
      address: 'AO0.0',
      description: 'Saída Analógica Proporcional 0-100% (DAC1 / GPIO 25 / 0-3,3V)',
      unit: '%',
      rawMin: 0,
      rawMax: 100,
      scaledMin: 0,
      scaledMax: 100,
      initialValue: TagValue.real(0.0),
    );

    tags['AO0.1'] = Tag(
      id: 'AO0.1',
      name: 'AO0.1',
      type: TagType.real,
      address: 'AO0.1',
      description: 'Saída Analógica Proporcional 0-100% (DAC2 / GPIO 26 / 0-3,3V)',
      unit: '%',
      rawMin: 0,
      rawMax: 100,
      scaledMin: 0,
      scaledMax: 100,
      initialValue: TagValue.real(0.0),
    );

    tags['I0.1'] = Tag(
      id: 'I0.1',
      name: 'I0.1',
      type: TagType.bool,
      address: 'I0.1',
      description: 'Chave Digital de Solo Seco DO (GPIO 17)',
      initialValue: TagValue.boolean(false),
    );

    // Tags de Temporização e Contagem Industrial
    tags['T0'] = Tag(
      id: 'T0',
      name: 'T0',
      type: TagType.timer,
      address: 'T0',
      description: 'Temporizador TON Cascata Segundo Estágio (3s / 3000ms)',
      initialValue: TagValue.integer(3000),
    );

    tags['T1'] = Tag(
      id: 'T1',
      name: 'T1',
      type: TagType.timer,
      address: 'T1',
      description: 'Temporizador TOF Retardo Desligamento Exaustor (4s / 4000ms)',
      initialValue: TagValue.integer(4000),
    );

    tags['C0'] = Tag(
      id: 'C0',
      name: 'C0',
      type: TagType.counter,
      address: 'C0',
      description: 'Contador CTU Ciclos/Peças de Produção (Preset 5)',
      initialValue: TagValue.integer(5),
    );

    tags['M0.0'] = Tag(
      id: 'M0.0',
      name: 'M0.0',
      type: TagType.bool,
      address: 'M0.0',
      description: 'Chave Habilita Temporizador TOF',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.1'] = Tag(
      id: 'M0.1',
      name: 'M0.1',
      type: TagType.bool,
      address: 'M0.1',
      description: 'Pulso de Entrada Contador CTU',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.2'] = Tag(
      id: 'M0.2',
      name: 'M0.2',
      type: TagType.bool,
      address: 'M0.2',
      description: 'Flag de Contagem Atingida (CTU Concluído)',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.3'] = Tag(
      id: 'M0.3',
      name: 'M0.3',
      type: TagType.bool,
      address: 'M0.3',
      description: 'Comando Reset Flag de Contagem',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.4_A'] = Tag(
      id: 'M0.4_A',
      name: 'M0.4_A',
      type: TagType.bool,
      address: 'M0.4_A',
      description: 'Entrada A do Ramo Paralelo (OR)',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.4_B'] = Tag(
      id: 'M0.4_B',
      name: 'M0.4_B',
      type: TagType.bool,
      address: 'M0.4_B',
      description: 'Entrada B do Ramo Paralelo (OR)',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.4'] = Tag(
      id: 'M0.4',
      name: 'M0.4',
      type: TagType.bool,
      address: 'M0.4',
      description: 'Saída do Ramo Paralelo (OR)',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.5'] = Tag(
      id: 'M0.5',
      name: 'M0.5',
      type: TagType.bool,
      address: 'M0.5',
      description: 'Saída do Comparador de Processo',
      initialValue: TagValue.boolean(false),
    );

    tags['M0.6'] = Tag(
      id: 'M0.6',
      name: 'M0.6',
      type: TagType.bool,
      address: 'M0.6',
      description: 'Flag de Habilitação Geral',
      initialValue: TagValue.boolean(false),
    );

    // Tags de Controle PID
    tags['SP_PID'] = Tag(
      id: 'SP_PID',
      name: 'SP_PID',
      type: TagType.real,
      address: 'SP_PID',
      description: 'Setpoint de Umidade / Temperatura PID (%)',
      unit: '%',
      initialValue: TagValue.real(70.0),
    );

    tags['MV_PID'] = Tag(
      id: 'MV_PID',
      name: 'MV_PID',
      type: TagType.real,
      address: 'M0.7',
      description: 'Saída de Controle Manipulada PID (0-100% gravada em M0.7)',
      unit: '%',
      initialValue: TagValue.real(0.0),
    );

    // Garante o surgimento de tags individuais de cada controlador (I00, I10, I20, I30...)
    _populateIndividualControllerTags(tags, const [0, 1, 2, 3]);

    return tags;
  }

  /// Popula tags canônicas e individuais por controlador (I00, I10, I20, I30...)
  static void _populateIndividualControllerTags(
    Map<String, Tag> tags,
    List<int> controllerIndexes, {
    bool isExclusiveGateway = false,
  }) {
    for (final c in controllerIndexes) {
      final isGw = c == 0;
      final rolePrefix = isGw
          ? (isExclusiveGateway ? 'Gateway Dedicado' : 'Gateway Principal')
          : 'Nó de Campo $c';
      final ladderNote = (isGw && isExclusiveGateway)
          ? '[Telemetria Gateway / Não-Ladder]'
          : '[Execução Ladder Local/Distribuído]';

      // Entradas Digitais (I00..I04 / I10..I14 / I20..I24 / I30..I34...)
      for (int bit = 0; bit <= 4; bit++) {
        final compactKey = 'I$c$bit';
        final dottedAddr = 'I$c.$bit';
        tags[compactKey] = Tag(
          id: compactKey,
          name: compactKey,
          type: TagType.bool,
          address: dottedAddr,
          description: '$rolePrefix — Entrada Digital $compactKey ($dottedAddr) $ladderNote',
          initialValue: TagValue.boolean(false),
          controllerId: '$c',
        );
        if (!tags.containsKey(dottedAddr)) {
          tags[dottedAddr] = Tag(
            id: dottedAddr,
            name: dottedAddr,
            type: TagType.bool,
            address: dottedAddr,
            description: '$rolePrefix — Entrada Digital $dottedAddr $ladderNote',
            initialValue: TagValue.boolean(false),
            controllerId: '$c',
          );
        }
      }

      // Saídas Digitais (Q00..Q04 / Q10..Q14 / Q20..Q24 / Q30..Q34...)
      for (int bit = 0; bit <= 4; bit++) {
        final compactKey = 'Q$c$bit';
        final dottedAddr = 'Q$c.$bit';
        tags[compactKey] = Tag(
          id: compactKey,
          name: compactKey,
          type: TagType.bool,
          address: dottedAddr,
          description: '$rolePrefix — Saída Digital $compactKey ($dottedAddr) $ladderNote',
          initialValue: TagValue.boolean(false),
          controllerId: '$c',
        );
        if (!tags.containsKey(dottedAddr)) {
          tags[dottedAddr] = Tag(
            id: dottedAddr,
            name: dottedAddr,
            type: TagType.bool,
            address: dottedAddr,
            description: '$rolePrefix — Saída Digital $dottedAddr $ladderNote',
            initialValue: TagValue.boolean(false),
            controllerId: '$c',
          );
        }
      }

      // Analógicas (AI00..AI02 / AO00..AO01)
      for (int ch = 0; ch <= 2; ch++) {
        final compactKey = 'AI$c$ch';
        final dottedAddr = 'AI$c.$ch';
        if (!tags.containsKey(compactKey)) {
          tags[compactKey] = Tag(
            id: compactKey,
            name: compactKey,
            type: TagType.real,
            address: dottedAddr,
            description: '$rolePrefix — Entrada Analógica $compactKey ($dottedAddr)',
            unit: 'V',
            rawMin: 0,
            rawMax: 4095,
            scaledMin: 0,
            scaledMax: 3.3,
            initialValue: TagValue.real(0.0),
            controllerId: '$c',
          );
        }
      }

      for (int ch = 0; ch <= 1; ch++) {
        final compactKey = 'AO$c$ch';
        final dottedAddr = 'AO$c.$ch';
        if (!tags.containsKey(compactKey)) {
          tags[compactKey] = Tag(
            id: compactKey,
            name: compactKey,
            type: TagType.real,
            address: dottedAddr,
            description: '$rolePrefix — Saída Analógica $compactKey ($dottedAddr)',
            unit: '%',
            rawMin: 0,
            rawMax: 255,
            scaledMin: 0,
            scaledMax: 100,
            initialValue: TagValue.real(0.0),
            controllerId: '$c',
          );
        }
      }
    }
  }

  /// Garante que tags canônicas individuais (I00, I10, I20, I30...) existam no projeto
  static void ensureClusterControllerTags(
    LadderProject project, {
    List<int>? controllerIndexes,
    bool isExclusiveGateway = false,
  }) {
    _populateIndividualControllerTags(
      project.tags,
      controllerIndexes ?? const [0, 1, 2, 3],
      isExclusiveGateway: isExclusiveGateway,
    );
  }

  static LadderProject createCleanTccProject() {
    final tags = <String, Tag>{};

    final digitalInputs = [
      {'iec': 'I0.0', 'gpio': 'GPIO16', 'desc': 'Botão de Pulso 1 NA - Partida Bomba (GPIO 16)'},
      {'iec': 'I0.1', 'gpio': 'GPIO17', 'desc': 'Botão de Pulso 2 NA - Comando Auxiliar (GPIO 17)'},
      {'iec': 'I0.2', 'gpio': 'GPIO18', 'desc': 'Botão de Pulso 3 NA - Liga Retenção SET (GPIO 18)'},
      {'iec': 'I0.3', 'gpio': 'GPIO19', 'desc': 'Botão de Pulso 4 NA - Desliga Retenção RESET (GPIO 19)'},
      {'iec': 'I0.4', 'gpio': 'GPIO27', 'desc': 'Botão de Pulso 5 NA - Temporizador TON 3s (GPIO 27)'},
      {'iec': 'I0.5', 'gpio': 'GPIO13', 'desc': 'Botão de Pulso 6 NA - Reserva / Emergência (GPIO 13)'},
    ];

    for (var inCfg in digitalInputs) {
      final iecName = inCfg['iec'] as String;
      final gpioStr = inCfg['gpio'] as String;
      final descStr = inCfg['desc'] as String;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.bool,
        address: iecName,
        description: '$descStr ($gpioStr)',
        initialValue: TagValue.boolean(false),
      );
    }

    final analogInputs = [
      {'iec': 'AI0.0', 'gpio': 'GPIO34/35', 'desc': 'Entrada Analógica Direta AI0.0 — Sensor Capacitivo 0-100%', 'unit': '%', 'rMin': 1500.0, 'rMax': 3800.0, 'sMin': 100.0, 'sMax': 0.0},
      {'iec': 'AI0.1', 'gpio': 'GPIO35', 'desc': 'Entrada Analógica Direta AI0.1 — Sensor Capacitivo 0-100%', 'unit': '%', 'rMin': 1500.0, 'rMax': 3800.0, 'sMin': 100.0, 'sMax': 0.0},
      {'iec': 'AI0.2', 'gpio': 'GPIO36', 'desc': 'Entrada Analógica AI0.2 - ADC1 VP (GPIO 36)', 'unit': 'V', 'rMin': 0.0, 'rMax': 4095.0, 'sMin': 0.0, 'sMax': 3.3},
      {'iec': 'AI0.3', 'gpio': 'GPIO39', 'desc': 'Entrada Analógica AI0.3 - ADC1 VN (GPIO 39)', 'unit': 'V', 'rMin': 0.0, 'rMax': 4095.0, 'sMin': 0.0, 'sMax': 3.3},
    ];

    for (var inCfg in analogInputs) {
      final iecName = inCfg['iec'] as String;
      final gpioStr = inCfg['gpio'] as String;
      final descStr = inCfg['desc'] as String;
      final unitStr = inCfg['unit'] as String;
      final rMinVal = inCfg['rMin'] as double;
      final rMaxVal = inCfg['rMax'] as double;
      final sMinVal = inCfg['sMin'] as double;
      final sMaxVal = inCfg['sMax'] as double;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.real,
        address: iecName,
        description: '$descStr ($gpioStr)',
        unit: unitStr,
        rawMin: rMinVal,
        rawMax: rMaxVal,
        scaledMin: sMinVal,
        scaledMax: sMaxVal,
        initialValue: TagValue.real(0.0),
      );
    }

    final outputGpios = [
      {'iec': 'Q0.0', 'gpio': 'GPIO4',  'desc': 'Relé 1 - Bomba de Irrigação Q0.0 (GPIO 4)'},
      {'iec': 'Q0.1', 'gpio': 'GPIO21', 'desc': 'Relé 2 - Válvula Solenoide Q0.1 (GPIO 21)'},
      {'iec': 'Q0.2', 'gpio': 'GPIO22', 'desc': 'Relé 3 - Exaustor com Retenção Q0.2 (GPIO 22)'},
      {'iec': 'Q0.3', 'gpio': 'GPIO33', 'desc': 'Relé 4 - Sinalizador / Alarme Q0.3 (GPIO 33)'},
      {'iec': 'Q0.4', 'gpio': 'GPIO23', 'desc': 'Saída Digital Auxiliar 5 Q0.4 (GPIO 23)'},
      {'iec': 'Q0.5', 'gpio': 'GPIO32', 'desc': 'Saída Digital Auxiliar 6 Q0.5 (GPIO 32)'},
      {'iec': 'Q0.6', 'gpio': 'GPIO14', 'desc': 'Saída Digital Auxiliar 7 Q0.6 (GPIO 14)'},
      {'iec': 'Q0.7', 'gpio': 'GPIO2',  'desc': 'LED Status Onboard Q0.7 (GPIO 2)'},
    ];

    for (var outCfg in outputGpios) {
      final iecName = outCfg['iec'] as String;
      final gpioStr = outCfg['gpio'] as String;
      final descStr = outCfg['desc'] as String;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.bool,
        address: iecName,
        description: '$descStr ($gpioStr)',
        initialValue: TagValue.boolean(false),
      );
    }

    final analogOutputs = [
      {'iec': 'AO0.0', 'gpio': 'GPIO25', 'desc': 'Saída Analógica DAC1 AO0.0 (GPIO 25)'},
      {'iec': 'AO0.1', 'gpio': 'GPIO26', 'desc': 'Saída Analógica DAC2 AO0.1 (GPIO 26)'},
    ];

    for (var aoCfg in analogOutputs) {
      final iecName = aoCfg['iec'] as String;
      final gpioStr = aoCfg['gpio'] as String;
      final descStr = aoCfg['desc'] as String;
      tags[iecName] = Tag(
        id: iecName,
        name: iecName,
        type: TagType.real,
        address: iecName,
        description: '$descStr ($gpioStr)',
        unit: '%',
        rawMin: 0,
        rawMax: 255,
        scaledMin: 0,
        scaledMax: 100,
        initialValue: TagValue.real(0.0),
      );
    }

    tags['T0'] = Tag(
      id: 'T0',
      name: 'T0',
      type: TagType.timer,
      address: '%TM0',
      description: 'Temporizador TON de Segurança 3s (T0)',
      initialValue: TagValue.integer(0),
    );

    tags['C0'] = Tag(
      id: 'C0',
      name: 'C0',
      type: TagType.counter,
      address: '%CT0',
      description: 'Contador de Pulsos de Operação (C0)',
      initialValue: TagValue.integer(0),
    );

    tags['SP_PID'] = Tag(
      id: 'SP_PID',
      name: 'SP_PID',
      type: TagType.real,
      address: 'M0.4',
      description: 'Setpoint de Umidade Desejada do Controlador PID (0 a 100%)',
      unit: '%',
      rawMin: 0,
      rawMax: 100,
      scaledMin: 0,
      scaledMax: 100,
      initialValue: TagValue.real(50.0),
    );

    tags['MV_PID'] = Tag(
      id: 'MV_PID',
      name: 'MV_PID',
      type: TagType.real,
      address: 'M0.7',
      description: 'Saída de Controle Calculada pelo Bloco PID (0 a 100%)',
      unit: '%',
      rawMin: 0,
      rawMax: 100,
      scaledMin: 0,
      scaledMax: 100,
      initialValue: TagValue.real(0.0),
    );

    final network1 = LadderNetwork(
      id: 'net_bancada_01',
      name: '1. Botão de Pulso 1 [I0.0 / GPIO 16] -> Liga Relé 1 Bomba de Irrigação (Q0.0 / GPIO 4)',
      nodes: [
        LadderNode(
          id: 'node_btn_i00',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.0'),
        ),
        LadderNode(
          id: 'node_rele_bomba',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.0'),
        ),
      ],
    )..rebuildConnections();

    final network2 = LadderNetwork(
      id: 'net_bancada_02',
      name: '2. Controle PID de Irrigação [PV: AI0.0 | SP: 50% | MV: MV_PID] -> Liga Relé 2 Válvula Solenoide (Q0.1 / GPIO 21)',
      nodes: [
        LadderNode(
          id: 'node_pid_umidade',
          type: NodeType.pid,
          config: NodeConfig(
            tagId: 'AI0.0',
            setpointTagId: '50',
            outputTagId: 'MV_PID',
            kp: 2.5,
            ki: 0.5,
            kd: 0.1,
            // PID industrial: ação reversa (solo seco -> MV sobe), ENO liga o relé acima de 20%
            // e só desliga abaixo de 15% (histerese evita trepidar a válvula).
            pidDirect: false,
            pidOutMin: 0,
            pidOutMax: 100,
            pidDeadband: 1.0,
            pidEnoThreshold: 20,
            pidEnoHysteresis: 5,
            pidSafeOut: 0,
          ),
        ),
        LadderNode(
          id: 'node_rele_valvula',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.1'),
        ),
      ],
    )..rebuildConnections();

    final network3 = LadderNetwork(
      id: 'net_bancada_03',
      name: '3. Botão de Pulso 3 [I0.2 / GPIO 18] -> Liga com Retenção Relé 3 Exaustor (SET Q0.2 / GPIO 22)',
      nodes: [
        LadderNode(
          id: 'node_btn_i02_set',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.2'),
        ),
        LadderNode(
          id: 'node_rele_exaustor_set',
          type: NodeType.coilSet,
          config: NodeConfig(tagId: 'Q0.2'),
        ),
      ],
    )..rebuildConnections();

    final network4 = LadderNetwork(
      id: 'net_bancada_04',
      name: '4. Botão de Pulso 4 [I0.3 / GPIO 19] -> Desliga Retenção Relé 3 Exaustor (RESET Q0.2 / GPIO 22)',
      nodes: [
        LadderNode(
          id: 'node_btn_i03_rst',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.3'),
        ),
        LadderNode(
          id: 'node_rele_exaustor_rst',
          type: NodeType.coilReset,
          config: NodeConfig(tagId: 'Q0.2'),
        ),
      ],
    )..rebuildConnections();

    final network5 = LadderNetwork(
      id: 'net_bancada_05',
      name: '5. Botão de Pulso 5 [I0.4 / GPIO 27] -> Temporizador TON T0 (3s) -> Liga Relé 4 Sinalizador (Q0.3 / GPIO 33)',
      nodes: [
        LadderNode(
          id: 'node_btn_i04_ton',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.4'),
        ),
        LadderNode(
          id: 'node_ton_t0',
          type: NodeType.timerTON,
          config: NodeConfig(
            tagId: 'T0',
            presetValue: TagValue.integer(3000),
          ),
        ),
        LadderNode(
          id: 'node_rele_alarme',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.3'),
        ),
      ],
    )..rebuildConnections();

    final hmiWidgets = [
      HomeWidgetConfig(
        id: 'w_io_matrix',
        tagId: null,
        templateType: WidgetTemplateType.ioMatrix,
        title: 'ESTADO DOS CANAIS DE I/O FÍSICOS (ESP32 • FONTE ATX)',
        order: 0,
        sizePreset: WidgetSizePreset.wide,
      ),
      HomeWidgetConfig(
        id: 'w_umid_solo',
        tagId: 'AI0.0',
        templateType: WidgetTemplateType.gauge,
        title: 'ENTRADA ANALÓGICA AI0.0 — UMIDADE (GPIO 34 / 35)',
        unit: '%',
        minValue: 0,
        maxValue: 100,
        warningMin: 30,
        criticalMin: 15,
        order: 1,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_btn_i00',
        tagId: 'I0.0',
        templateType: WidgetTemplateType.digital,
        title: 'BOTÃO DE PULSO 1 - PARTIDA (I0.0 / GPIO 16)',
        onText: 'ACIONADO (FECHADO)',
        offText: 'REPOUSO (ABERTO)',
        order: 2,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_btn_i01',
        tagId: 'I0.1',
        templateType: WidgetTemplateType.digital,
        title: 'BOTÃO DE PULSO 2 - COMANDO (I0.1 / GPIO 17)',
        onText: 'ACIONADO (FECHADO)',
        offText: 'REPOUSO (ABERTO)',
        order: 3,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_rele_bomba',
        tagId: 'Q0.0',
        templateType: WidgetTemplateType.digital,
        title: 'RELÉ 1 - BOMBA DE IRRIGAÇÃO (Q0.0 / GPIO 4)',
        onText: 'LIGADO (EM OPERAÇÃO)',
        offText: 'DESLIGADO',
        order: 4,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_rele_valvula',
        tagId: 'Q0.1',
        templateType: WidgetTemplateType.digital,
        title: 'RELÉ 2 - VÁLVULA SOLENOIDE (Q0.1 / GPIO 21)',
        onText: 'ABERTA (IRRIGANDO < 40%)',
        offText: 'FECHADA (SOLO ÚMIDO)',
        order: 5,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_rele_exaustor',
        tagId: 'Q0.2',
        templateType: WidgetTemplateType.digital,
        title: 'RELÉ 3 - EXAUSTOR SET/RESET (Q0.2 / GPIO 22)',
        onText: 'RETIDO (LIGADO)',
        offText: 'DESLIGADO',
        order: 6,
        sizePreset: WidgetSizePreset.standard,
      ),
      HomeWidgetConfig(
        id: 'w_rele_alarme',
        tagId: 'Q0.3',
        templateType: WidgetTemplateType.digital,
        title: 'RELÉ 4 - SINALIZADOR TON 3S (Q0.3 / GPIO 33)',
        onText: 'ALARME ATIVO',
        offText: 'SILENCIOSO',
        order: 7,
        sizePreset: WidgetSizePreset.standard,
      ),
    ];

    return LadderProject(
      id: 'proj_bancada_tcc_v5_pid_industrial',
      name: 'Bancada Didática ENDAP (Fonte ATX + Sensor Capacitivo AI0.0 + Botoeiras + 4 Relés)',
      tags: tags,
      networks: [
        network1,
        network2,
        network3,
        network4,
        network5,
      ],
      metadata: ProjectMetadata(
        author: 'ENDAP Industrial TCC',
        version: '1.0.0',
        targetPlatform: 'EndapRuntime',
      ),
      dashboardWidgets: hmiWidgets,
      hmiScreens: [
        HmiScreen(
          id: 'screen_bancada_tcc',
          title: '01 - Bancada Experimental TCC (Fonte ATX + Sensor Capacitivo + 4 Relés)',
          iconName: 'precision_manufacturing',
          allowedRoles: ['OPERADOR', 'INTEGRADOR', 'MANUTENÇÃO', 'GESTOR'],
          description: 'Supervisão e acionamento do Sensor Capacitivo de Umidade, Botões de Pulso NA e Módulo de 4 Relés.',
          widgets: hmiWidgets,
        ),
      ],
    );
  }

  static LadderProject createDemoProject() {
    final tags = createDefaultTags();

    // Rung 0: I0.0 (NA) -> Liga Saída Q0.0 (GPIO 23)
    final network1 = LadderNetwork(
      id: 'net_demo_01',
      name: '1. Entrada [I0.0] -> Liga Saída (Q0.0 / GPIO 23)',
      nodes: [
        LadderNode(
          id: 'node_demo_i00_no',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.0'),
        ),
        LadderNode(
          id: 'node_demo_coil_q00',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.0'),
        ),
      ],
    )..rebuildConnections();

    // Rung 1: Malha PID Automática (Processo Solo AI0.0/GPIO 34 -> MV_PID)
    final network2 = LadderNetwork(
      id: 'net_demo_02',
      name: '2. Controle de Irrigação PID: (SP: SP_PID 70%, PV: AI0.0 -> MV_PID)',
      nodes: [
        LadderNode(
          id: 'node_demo_pid_loop',
          type: NodeType.pid,
          config: NodeConfig(
            tagId: 'AI0.0',
            setpointTagId: 'SP_PID',
            outputTagId: 'MV_PID',
            kp: 2.5,
            ki: 0.5,
            kd: 0.1,
          ),
        ),
      ],
    )..rebuildConnections();

    // Rung 2: Saída do PID: [MV_PID > 20%] -> Liga Diretamente Saída Q0.1 (GPIO 4)
    final network3 = LadderNetwork(
      id: 'net_demo_03',
      name: '3. Saída PID: [MV_PID > 20%] -> Ativa Relé (Q0.1 / GPIO 4)',
      nodes: [
        LadderNode(
          id: 'node_demo_cmp_mv',
          type: NodeType.compareGreater,
          config: NodeConfig(
            tagId: 'MV_PID',
            presetValue: TagValue.integer(20),
          ),
        ),
        LadderNode(
          id: 'node_demo_coil_q01_pid',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.1'),
        ),
      ],
    )..rebuildConnections();

    // Rung 3: I0.2 (NA) -> Bobina SET Q0.2 (GPIO 32)
    final network4 = LadderNetwork(
      id: 'net_demo_04',
      name: '4. Entrada [I0.2] -> Liga com Retenção (SET Q0.2 / GPIO 32)',
      nodes: [
        LadderNode(
          id: 'node_demo_i02_set',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.2'),
        ),
        LadderNode(
          id: 'node_demo_coil_q02_set',
          type: NodeType.coilSet,
          config: NodeConfig(tagId: 'Q0.2'),
        ),
      ],
    )..rebuildConnections();

    // Rung 4: I0.3 (NA) -> Bobina RESET Q0.2 (GPIO 32)
    final network5 = LadderNetwork(
      id: 'net_demo_05',
      name: '5. Entrada [I0.3] -> Desliga Saída (RESET Q0.2 / GPIO 32)',
      nodes: [
        LadderNode(
          id: 'node_demo_i03_rst',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.3'),
        ),
        LadderNode(
          id: 'node_demo_coil_q02_rst',
          type: NodeType.coilReset,
          config: NodeConfig(tagId: 'Q0.2'),
        ),
      ],
    )..rebuildConnections();

    // Rung 5: I0.4 (NA) -> Temporizador TON 3s -> Liga Saída Q0.3 (GPIO 14)
    final network6 = LadderNetwork(
      id: 'net_demo_06',
      name: '6. Temporizador TON [I0.4] -> TON T0 (3s) -> Liga Saída (Q0.3 / GPIO 14)',
      nodes: [
        LadderNode(
          id: 'node_demo_i04_ton',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'I0.4'),
        ),
        LadderNode(
          id: 'node_demo_ton',
          type: NodeType.timerTON,
          config: NodeConfig(
            tagId: 'T0',
            presetValue: TagValue.integer(3000),
          ),
        ),
        LadderNode(
          id: 'node_demo_coil_q03',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.3'),
        ),
      ],
    )..rebuildConnections();

    // Rung 6: Ramo Paralelo (I0.0 OU I0.1) -> Liga Saída Q0.4 (GPIO 33)
    final network7 = LadderNetwork(
      id: 'net_demo_07',
      name: '7. Ramo Paralelo OR [I0.0 // I0.1] -> Liga Saída (Q0.4 / GPIO 33)',
      nodes: [
        LadderNode(
          id: 'node_demo_par_or',
          type: NodeType.parallel,
          config: NodeConfig(),
          branches: [
            [
              LadderNode(
                id: 'node_demo_par_i00',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'I0.0'),
              ),
            ],
            [
              LadderNode(
                id: 'node_demo_par_i01',
                type: NodeType.contactNO,
                config: NodeConfig(tagId: 'I0.1'),
              ),
            ],
          ],
        ),
        LadderNode(
          id: 'node_demo_coil_q04',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'Q0.4'),
        ),
      ],
    )..rebuildConnections();

    // Rung 7: M0.0 (NA) -> Temporizador TOF (4s) -> Liga Bobina M0.6
    final network8 = LadderNetwork(
      id: 'net_demo_08',
      name: '8. Temporizador TOF [M0.0] -> TOF T1 (4s) -> Ativa Flag (M0.6)',
      nodes: [
        LadderNode(
          id: 'node_demo_m00_tof',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'M0.0'),
        ),
        LadderNode(
          id: 'node_demo_tof',
          type: NodeType.timerTOF,
          config: NodeConfig(
            tagId: 'T1',
            presetValue: TagValue.integer(4000),
          ),
        ),
        LadderNode(
          id: 'node_demo_coil_m06',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'M0.6'),
        ),
      ],
    )..rebuildConnections();

    // Rung 8: M0.1 (NA) -> Contador CTU (5 pulsos) -> Liga Bobina M0.2
    final network9 = LadderNetwork(
      id: 'net_demo_09',
      name: '9. Contador CTU [M0.1] -> CTU C0 (PV: 5) -> Ativa Flag (M0.2)',
      nodes: [
        LadderNode(
          id: 'node_demo_m01_ctu',
          type: NodeType.contactNO,
          config: NodeConfig(tagId: 'M0.1'),
        ),
        LadderNode(
          id: 'node_demo_ctu',
          type: NodeType.counterCTU,
          config: NodeConfig(
            tagId: 'C0',
            presetValue: TagValue.integer(5),
            resetTagId: 'M0.3',
          ),
        ),
        LadderNode(
          id: 'node_demo_coil_m02',
          type: NodeType.coil,
          config: NodeConfig(tagId: 'M0.2'),
        ),
      ],
    )..rebuildConnections();

    return LadderProject(
      id: 'proj_demo_industrial_full',
      name: 'Validação Geral ENDAP PLC - Hardware & Lógica Completa',
      tags: tags,
      networks: [
        network1,   // 1. I0.0 -> Q0.0
        network2,   // 2. PID (AI0.0 & SP -> MV_PID)
        network3,   // 3. [MV_PID > 20%] -> Q0.1
        network4,   // 4. I0.2 -> SET Q0.2
        network5,   // 5. I0.3 -> RESET Q0.2
        network6,   // 6. I0.4 -> TON T0 -> Q0.3
        network7,   // 7. [I0.0 // I0.1] -> Q0.4
        network8,   // 8. M0.0 -> TOF T1 -> M0.6
        network9,   // 9. M0.1 -> CTU C0 -> M0.2
      ],
      metadata: ProjectMetadata(
        author: 'Endap Studio TCC',
        version: '1.0.0',
        targetPlatform: 'EndapRuntime',
      ),
      dashboardWidgets: [
        HomeWidgetConfig(
          id: 'w_io_matrix',
          tagId: null,
          templateType: WidgetTemplateType.ioMatrix,
          title: 'ESTADO DOS CANAIS DE I/O FÍSICOS (ESP32)',
          order: 0,
          sizePreset: WidgetSizePreset.wide,
        ),
        HomeWidgetConfig(
          id: 'w_umid_solo',
          tagId: 'AI0.0',
          templateType: WidgetTemplateType.gauge,
          title: 'ENTRADA ANALÓGICA AI0.0 (GPIO 34 / 35)',
          unit: '%',
          minValue: 0,
          maxValue: 100,
          warningMin: 30,
          criticalMin: 15,
          order: 1,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_btn_i00',
          tagId: 'I0.0',
          templateType: WidgetTemplateType.digital,
          title: 'ENTRADA NA (I0.0 / GPIO 16)',
          onText: 'ACIONADO (FECHADO)',
          offText: 'REPOUSO (ABERTO)',
          order: 2,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_status_do_solo',
          tagId: 'I0.1',
          templateType: WidgetTemplateType.digital,
          title: 'CHAVE DIGITAL DO SOLO (DO - GPIO 17)',
          onText: 'ABERTO (DESLIGADO)',
          offText: 'FECHADO (NORMAL)',
          order: 2,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_start_button',
          tagId: 'I0.2',
          templateType: WidgetTemplateType.digital,
          title: 'BOTÃO PARTIDA MANUAL (I0.2 / GPIO 19)',
          onText: 'ACIONADO',
          offText: 'REPOUSO',
          order: 3,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_reset_button',
          tagId: 'I0.3',
          templateType: WidgetTemplateType.digital,
          title: 'ENTRADA RESET (I0.3 / GPIO 18)',
          onText: 'ACIONADO',
          offText: 'REPOUSO',
          order: 4,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_motor_q0',
          tagId: 'Q0.0',
          templateType: WidgetTemplateType.digital,
          title: 'MOTOR PRINCIPAL / BOMBA (Q0.0 / GPIO 23)',
          onText: 'LIGADO (ACIONADO)',
          offText: 'DESLIGADO',
          order: 5,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_valvula_q03',
          tagId: 'Q0.3',
          templateType: WidgetTemplateType.digital,
          title: 'VÁLVULA DE IRRIGAÇÃO (Q0.3 / GPIO 14)',
          onText: 'ABERTA (IRRIGANDO)',
          offText: 'FECHADA',
          order: 6,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_pid_sp',
          tagId: 'SP_PID',
          templateType: WidgetTemplateType.gauge,
          title: 'SETPOINT PID (SP_PID)',
          unit: '%',
          minValue: 0,
          maxValue: 100,
          order: 6,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_pid_mv',
          tagId: 'MV_PID',
          templateType: WidgetTemplateType.gauge,
          title: 'SAÍDA MANIPULADA PID (MV_PID / M0.7)',
          unit: '%',
          minValue: 0,
          maxValue: 100,
          order: 7,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_pid_acting',
          tagId: 'M0.6',
          templateType: WidgetTemplateType.digital,
          title: 'STATUS ATUAÇÃO PID (M0.6)',
          onText: 'CORREÇÃO ATIVA (>20%)',
          offText: 'REPOUSO (NORMAL)',
          order: 8,
          sizePreset: WidgetSizePreset.standard,
        ),
        HomeWidgetConfig(
          id: 'w_saida_set_reset',
          tagId: 'Q0.2',
          templateType: WidgetTemplateType.digital,
          title: 'SAÍDA SET/RESET (Q0.2 / GPIO 32)',
          onText: 'RETIDO (LIGADO)',
          offText: 'DESLIGADO',
          order: 7,
          sizePreset: WidgetSizePreset.wide,
        ),
      ],
      hmiScreens: [
        HmiScreen(
          id: 'screen_operacao_chao_fabrica',
          title: '01 - Operação Chão de Fábrica',
          iconName: 'touch_app',
          allowedRoles: ['OPERADOR', 'INTEGRADOR', 'MANUTENÇÃO', 'GESTOR'],
          description: 'Comandos operacionais de acionamento, botoeiras e saídas de potência.',
          widgets: [
            HomeWidgetConfig(
              id: 'w_motor_q0',
              tagId: 'Q0.0',
              templateType: WidgetTemplateType.digital,
              title: 'MOTOR PRINCIPAL / BOMBA (Q0.0 / GPIO 23)',
              onText: 'LIGADO (ACIONADO)',
              offText: 'DESLIGADO',
              order: 0,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_valvula_q03',
              tagId: 'Q0.3',
              templateType: WidgetTemplateType.digital,
              title: 'VÁLVULA DE IRRIGAÇÃO (Q0.3 / GPIO 14)',
              onText: 'ABERTA (IRRIGANDO)',
              offText: 'FECHADA',
              order: 1,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_saida_set_reset',
              tagId: 'Q0.2',
              templateType: WidgetTemplateType.digital,
              title: 'SAÍDA SET/RESET (Q0.2 / GPIO 32)',
              onText: 'RETIDO (LIGADO)',
              offText: 'DESLIGADO',
              order: 2,
              sizePreset: WidgetSizePreset.wide,
            ),
            HomeWidgetConfig(
              id: 'w_start_button',
              tagId: 'I0.2',
              templateType: WidgetTemplateType.digital,
              title: 'BOTÃO PARTIDA MANUAL (I0.2 / GPIO 19)',
              onText: 'ACIONADO',
              offText: 'REPOUSO',
              order: 3,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_reset_button',
              tagId: 'I0.3',
              templateType: WidgetTemplateType.digital,
              title: 'ENTRADA RESET (I0.3 / GPIO 18)',
              onText: 'ACIONADO',
              offText: 'REPOUSO',
              order: 4,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_io_matrix',
              tagId: null,
              templateType: WidgetTemplateType.ioMatrix,
              title: 'ESTADO DOS CANAIS DE I/O FÍSICOS (ESP32)',
              order: 5,
              sizePreset: WidgetSizePreset.wide,
            ),
            HomeWidgetConfig(
              id: 'w_umid_solo',
              tagId: 'AI0.0',
              templateType: WidgetTemplateType.gauge,
              title: 'UMIDADE DO SOLO (AI0.0 - GPIO 34/35)',
              unit: '%',
              minValue: 0,
              maxValue: 100,
              warningMin: 30,
              criticalMin: 15,
              order: 6,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_status_do_solo',
              tagId: 'I0.1',
              templateType: WidgetTemplateType.digital,
              title: 'CHAVE DIGITAL DO SOLO (DO - GPIO 17)',
              onText: 'ABERTO (DESLIGADO)',
              offText: 'FECHADO (NORMAL)',
              order: 7,
              sizePreset: WidgetSizePreset.wide,
            ),
          ],
        ),
        HmiScreen(
          id: 'screen_supervisao_pid',
          title: '02 - Supervisão Analógica & PID',
          iconName: 'speed',
          allowedRoles: ['INTEGRADOR', 'MANUTENÇÃO', 'GESTOR'],
          description: 'Malha de controle em malha fechada, setpoints e monitoramento analógico.',
          widgets: [
            HomeWidgetConfig(
              id: 'w_umid_solo',
              tagId: 'AI0.0',
              templateType: WidgetTemplateType.gauge,
              title: 'UMIDADE DO SOLO (AI0.0 - GPIO 34/35)',
              unit: '%',
              minValue: 0,
              maxValue: 100,
              warningMin: 30,
              criticalMin: 15,
              order: 0,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_pid_sp',
              tagId: 'SP_PID',
              templateType: WidgetTemplateType.gauge,
              title: 'SETPOINT PID (SP_PID)',
              unit: '%',
              minValue: 0,
              maxValue: 100,
              order: 1,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_pid_mv',
              tagId: 'MV_PID',
              templateType: WidgetTemplateType.gauge,
              title: 'SAÍDA MANIPULADA PID (MV_PID / M0.7)',
              unit: '%',
              minValue: 0,
              maxValue: 100,
              order: 2,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_pid_acting',
              tagId: 'M0.6',
              templateType: WidgetTemplateType.digital,
              title: 'STATUS ATUAÇÃO PID (M0.6)',
              onText: 'CORREÇÃO ATIVA (>20%)',
              offText: 'REPOUSO (NORMAL)',
              order: 3,
              sizePreset: WidgetSizePreset.standard,
            ),
            HomeWidgetConfig(
              id: 'w_status_do_solo',
              tagId: 'I0.1',
              templateType: WidgetTemplateType.digital,
              title: 'CHAVE DIGITAL DO SOLO (DO - GPIO 17)',
              onText: 'ABERTO (DESLIGADO)',
              offText: 'FECHADO (NORMAL)',
              order: 4,
              sizePreset: WidgetSizePreset.wide,
            ),
          ],
        ),
      ],
    );
  }
}
