import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/authenticated_http_client.dart';

class GpioHardwareChannel {
  final int channelId;
  final String name;
  final String
  type; // 'digital_input', 'digital_output', 'analog_input', 'analog_output'
  final int? gpio;
  final int state;
  final bool isOutput;
  final bool isPhysical;

  /// Índice do controlador reportado pelo firmware no /api/io/map
  /// (0 = controlador 1 -> I/Q 0.x, 1 = controlador 2 -> I/Q 1.x).
  final int controllerIndex;
  final int? nodeId;
  final bool implemented;
  final String clusterState;

  const GpioHardwareChannel({
    required this.channelId,
    required this.name,
    required this.type,
    this.gpio,
    required this.state,
    required this.isOutput,
    this.isPhysical = true,
    this.controllerIndex = 0,
    this.nodeId,
    this.implemented = true,
    this.clusterState = 'online',
  });

  String get uniqueKey => '${nodeId ?? controllerIndex}_$channelId';

  bool get isOn => state > 0;

  bool get isAnalog => type == 'analog_input' || type == 'analog_output';
}

class GpioInventoryPin {
  final int gpio;
  final bool inputCapable;
  final bool outputCapable;
  final bool analogCapable;
  final String
  state; // 'AVAILABLE', 'IN_USE_INPUT', 'IN_USE_OUTPUT', 'RESERVED', 'DISABLED_BY_PROFILE'
  final String? reservedBy;
  final int? boundId;
  final String? plcChannel;

  const GpioInventoryPin({
    required this.gpio,
    this.inputCapable = false,
    this.outputCapable = false,
    this.analogCapable = false,
    this.state = 'AVAILABLE',
    this.reservedBy,
    this.boundId,
    this.plcChannel,
  });

  factory GpioInventoryPin.fromJson(Map<String, dynamic> json) {
    final caps = (json['capabilities'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .toSet();
    return GpioInventoryPin(
      gpio: (json['gpio'] ?? 0) as int,
      inputCapable: caps.contains('input'),
      outputCapable: caps.contains('output'),
      analogCapable: caps.contains('analog'),
      state: (json['state'] ?? 'AVAILABLE').toString(),
      reservedBy: json['reserved_by']?.toString(),
      boundId: json['bound_id'] is int
          ? json['bound_id'] as int
          : json['bound_id']?.toString().isEmpty == false
          ? int.tryParse(json['bound_id'].toString())
          : null,
      plcChannel: json['plc_channel']?.toString(),
    );
  }

  bool get isInUse => state == 'IN_USE_INPUT' || state == 'IN_USE_OUTPUT';

  bool get isReserved => state == 'RESERVED';

  List<String> get capabilityLabels {
    final labels = <String>[];
    if (inputCapable) labels.add('ENTRADA');
    if (outputCapable) labels.add('SAÍDA');
    if (analogCapable) labels.add('ANALÓGICO');
    return labels;
  }
}

class GpioService {
  static final GpioService instance = GpioService();

  static String buildUrl(String host, String path) {
    final cleanHost = host.trim();
    if (kIsWeb &&
        Uri.base.scheme == 'https' &&
        (cleanHost == Uri.base.authority || cleanHost == Uri.base.host)) {
      return 'https://$cleanHost$path';
    }
    return 'http://$cleanHost$path';
  }

  final http.Client _client;
  http.Client? _testClient;
  static const Duration _timeout = Duration(seconds: 3);

  set httpClientForTesting(http.Client? client) => _testClient = client;
  http.Client get _activeClient => _testClient ?? _client;

  GpioService({http.Client? client})
    : _client = client ?? AuthenticatedHttpClient();

  /// Busca o mapeamento real de I/O retornado pelo ESP32 em /api/io/map (multinó)
  Future<List<GpioHardwareChannel>> fetchHardwareChannels(
    String gatewayIp, {
    List<dynamic>? nodes,
  }) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return [];

    final List<GpioHardwareChannel> allChannels = [];

    // 1. Task for Gateway (controllerIndex 0)
    final gatewayFuture = () async {
      final gwChannels = <GpioHardwareChannel>[];
      try {
        final url = Uri.parse(buildUrl(cleanIp, '/api/io/map'));
        final res = await _activeClient.get(url).timeout(_timeout);

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          _parseChannelsInto(
            data,
            defaultControllerIndex: 0,
            targetList: gwChannels,
          );
        }
      } catch (_) {}
      return gwChannels;
    }();

    // 2. Tasks for Remote Nodes if provided (controllerIndex > 0)
    final remoteFutures = (nodes ?? []).map((dynamic node) async {
      final nodeChannels = <GpioHardwareChannel>[];
      try {
        String nodeIp = '';
        String nodeStatusStr = '';
        String rawNodeIdStr = '';
        int? nodeCtrlIdx;

        if (node is Map) {
          nodeIp = (node['ip'] ?? '').toString().trim();
          nodeStatusStr =
              (node['status'] ??
                      node['cluster_state'] ??
                      node['registry_state'] ??
                      '')
                  .toString()
                  .toLowerCase();
          rawNodeIdStr = (node['id'] ?? node['node_id'] ?? '').toString();
          if (node['controller_index'] != null) {
            nodeCtrlIdx = int.tryParse(node['controller_index'].toString());
          } else if (node['controllerIndex'] != null) {
            nodeCtrlIdx = int.tryParse(node['controllerIndex'].toString());
          }
        } else {
          try {
            dynamic ipVal = (node as dynamic).ip;
            nodeIp = (ipVal as String? ?? '').trim();
          } catch (_) {}
          try {
            dynamic statusVal = (node as dynamic).status;
            nodeStatusStr = statusVal?.toString().toLowerCase() ?? '';
          } catch (_) {}
          try {
            dynamic idVal = (node as dynamic).id;
            rawNodeIdStr = idVal?.toString() ?? '';
          } catch (_) {}
          try {
            dynamic ctrlIdxVal = (node as dynamic).controllerIndex;
            if (ctrlIdxVal != null)
              nodeCtrlIdx = int.tryParse(ctrlIdxVal.toString());
          } catch (_) {}
        }

        final isOnline =
            nodeStatusStr.isEmpty ||
            nodeStatusStr.contains('online') ||
            nodeStatusStr.contains('pending') ||
            nodeStatusStr.contains('active') ||
            nodeStatusStr.contains('nodestatus.online');

        debugPrint(
          '[GpioService] Checking node $rawNodeIdStr @ $nodeIp (status: $nodeStatusStr, isOnline: $isOnline, ctrlIdx: $nodeCtrlIdx)',
        );

        if (!isOnline ||
            nodeIp.isEmpty ||
            nodeIp == 'Sem IP' ||
            nodeIp == cleanIp)
          return nodeChannels;
        if (nodeCtrlIdx == null || nodeCtrlIdx <= 0) {
          debugPrint(
            '[GpioService] Node $rawNodeIdStr @ $nodeIp does NOT have a controller_index from Gateway; skipping index invention.',
          );
          return nodeChannels;
        }

        final nodeUrl = Uri.parse('http://$nodeIp/api/io/map');
        debugPrint('[GpioService] Fetching remote IO map from $nodeUrl');
        final res = await _activeClient
            .get(nodeUrl)
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final cleanRawId = rawNodeIdStr.replaceAll('ENDAP-', '');
          final parsedNodeId = int.tryParse(cleanRawId);

          _parseChannelsInto(
            data,
            defaultControllerIndex: nodeCtrlIdx,
            overrideNodeId: parsedNodeId,
            targetList: nodeChannels,
          );
          debugPrint(
            '[GpioService] Parsed ${nodeChannels.length} channels from node $rawNodeIdStr (rack $nodeCtrlIdx)',
          );
        } else {
          debugPrint(
            '[GpioService] Failed to fetch remote IO map from $nodeUrl (HTTP ${res.statusCode})',
          );
        }
      } catch (e) {
        debugPrint('[GpioService] Exception fetching remote node IO map: $e');
      }
      return nodeChannels;
    });

    final results = await Future.wait([gatewayFuture, ...remoteFutures]);
    for (final channelList in results) {
      allChannels.addAll(channelList);
    }

    // Deduplica por uniqueKey / (controllerIndex + isOutput + channelId)
    final List<GpioHardwareChannel> uniqueChannels = [];
    final Set<String> seenKeys = {};
    for (var ch in allChannels) {
      final key =
          '${ch.controllerIndex}_${ch.isOutput ? "Q" : "I"}_${ch.gpio ?? ch.channelId}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      uniqueChannels.add(ch);
    }

    return uniqueChannels;
  }

  void _parseChannelsInto(
    Map<String, dynamic> data, {
    required int defaultControllerIndex,
    int? overrideNodeId,
    required List<GpioHardwareChannel> targetList,
  }) {
    final gwNodeId = data['node_id'] is int
        ? data['node_id'] as int
        : int.tryParse(data['node_id']?.toString() ?? '');

    final inputs = data['inputs'] as List<dynamic>? ?? [];
    for (var item in inputs) {
      if (item is Map<String, dynamic>) {
        final channelId = (item['channel_id'] ?? item['channelId'] ?? 0) as int;
        final name = (item['name'] ?? 'I0.0').toString();
        final type = (item['type'] ?? 'digital_input').toString();
        final gpio = item['gpio'] is int
            ? item['gpio'] as int
            : int.tryParse(item['gpio']?.toString() ?? '');
        final state = (item['state'] ?? item['value'] ?? 0) as int;
        final implemented = item['implemented'] != false;
        final rawNodeId = item['node_id'] is int
            ? item['node_id'] as int
            : int.tryParse(item['node_id']?.toString() ?? '');
        final nodeId = overrideNodeId ?? rawNodeId;
        final clusterState = (item['cluster_state'] ?? 'online').toString();

        if (gpio == -1 || !implemented) continue;

        int controllerIdx = defaultControllerIndex;
        if (controllerIdx == 0 &&
            nodeId != null &&
            gwNodeId != null &&
            nodeId != gwNodeId) {
          controllerIdx = 1;
        }

        targetList.add(
          GpioHardwareChannel(
            channelId: channelId,
            name: name,
            type: type,
            gpio: gpio,
            state: state,
            isOutput: false,
            controllerIndex: controllerIdx,
            nodeId: nodeId,
            implemented: implemented,
            clusterState: clusterState,
          ),
        );
      }
    }

    final outputs = data['outputs'] as List<dynamic>? ?? [];
    for (var item in outputs) {
      if (item is Map<String, dynamic>) {
        final channelId = (item['channel_id'] ?? item['channelId'] ?? 0) as int;
        final name = (item['name'] ?? 'Q0.0').toString();
        final type = (item['type'] ?? 'digital_output').toString();
        final gpio = item['gpio'] is int
            ? item['gpio'] as int
            : int.tryParse(item['gpio']?.toString() ?? '');
        final state =
            (item['desired'] ?? item['state'] ?? item['value'] ?? 0) as int;
        final physicalPresent =
            item['physical_present'] != false &&
            item['physical_present']?.toString() != 'false';
        final implemented = item['implemented'] != false;
        final rawNodeId = item['node_id'] is int
            ? item['node_id'] as int
            : int.tryParse(item['node_id']?.toString() ?? '');
        final nodeId = overrideNodeId ?? rawNodeId;
        final clusterState = (item['cluster_state'] ?? 'online').toString();

        if (gpio == -1 || !implemented) continue;

        int controllerIdx = defaultControllerIndex;
        if (controllerIdx == 0 &&
            nodeId != null &&
            gwNodeId != null &&
            nodeId != gwNodeId) {
          controllerIdx = 1;
        }

        targetList.add(
          GpioHardwareChannel(
            channelId: channelId,
            name: name,
            type: type,
            gpio: gpio,
            state: state,
            isOutput: true,
            isPhysical: physicalPresent,
            controllerIndex: controllerIdx,
            nodeId: nodeId,
            implemented: implemented,
            clusterState: clusterState,
          ),
        );
      }
    }

    final internals = data['internals'] as List<dynamic>? ?? [];
    for (var item in internals) {
      if (item is Map<String, dynamic>) {
        final channelId = (item['channel_id'] ?? item['channelId'] ?? 0) as int;
        final type = (item['type'] ?? '').toString();
        if (channelId == 80 || channelId == 81 || type == 'analog_output') {
          final name = (item['name'] ?? (channelId == 80 ? 'AO0.0' : 'AO0.1'))
              .toString();
          final gpio = item['gpio'] is int
              ? item['gpio'] as int
              : (channelId == 80 ? 25 : 26);
          final state = (item['state'] ?? item['value'] ?? 0) as int;
          targetList.add(
            GpioHardwareChannel(
              channelId: channelId,
              name: name,
              type: 'analog_output',
              gpio: gpio,
              state: state,
              isOutput: true,
              controllerIndex: defaultControllerIndex,
              nodeId: gwNodeId,
              implemented: true,
              clusterState: 'online',
            ),
          );
        }
      }
    }
  }

  /// Busca o inventário completo de pinos utilizáveis a partir de /api/public/profile (sem autenticação),
  /// incluindo capacidades (entrada/saída/analog) e estado de cada GPIO físico.
  Future<List<GpioInventoryPin>> fetchGpioInventory(String gatewayIp) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return [];

    try {
      final url = Uri.parse(buildUrl(cleanIp, '/api/public/profile'));
      final res = await _client.get(url).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawList = (data['gpio_inventory'] as List<dynamic>? ?? []);
        final pins = <GpioInventoryPin>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            final pin = GpioInventoryPin.fromJson(item);
            if (pin.gpio != 2)
              pins.add(pin); // GPIO2 = LED onboard, não utilizável
          }
        }
        if (pins.isNotEmpty) return pins;
      }
    } catch (_) {
      // Offline ou erro de rede
    }
    return [];
  }

  /// Canais padrão de hardware do Gateway (Rack 0) para exibição contínua e sem oscilação
  static const List<GpioHardwareChannel> defaultGatewayChannels = [
    // Entradas Digitais (DI00..DI05)
    GpioHardwareChannel(
      channelId: 10,
      name: 'I0.0',
      type: 'digital_input',
      gpio: 16,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 11,
      name: 'I0.1',
      type: 'digital_input',
      gpio: 17,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 12,
      name: 'I0.2',
      type: 'digital_input',
      gpio: 18,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 13,
      name: 'I0.3',
      type: 'digital_input',
      gpio: 19,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 14,
      name: 'I0.4',
      type: 'digital_input',
      gpio: 27,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 15,
      name: 'I0.5',
      type: 'digital_input',
      gpio: 13,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    // Entradas Analógicas (AI00..AI03)
    GpioHardwareChannel(
      channelId: 22,
      name: 'AI0.0',
      type: 'analog_input',
      gpio: 34,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 23,
      name: 'AI0.1',
      type: 'analog_input',
      gpio: 35,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 24,
      name: 'AI0.2',
      type: 'analog_input',
      gpio: 36,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 25,
      name: 'AI0.3',
      type: 'analog_input',
      gpio: 39,
      state: 0,
      isOutput: false,
      controllerIndex: 0,
    ),
    // Saídas Digitais (Relés e Atuadores Q0.0..Q0.7)
    GpioHardwareChannel(
      channelId: 100,
      name: 'Q0.0',
      type: 'digital_output',
      gpio: 4,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 101,
      name: 'Q0.1',
      type: 'digital_output',
      gpio: 21,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 102,
      name: 'Q0.2',
      type: 'digital_output',
      gpio: 22,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 103,
      name: 'Q0.3',
      type: 'digital_output',
      gpio: 33,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 104,
      name: 'Q0.4',
      type: 'digital_output',
      gpio: 23,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 105,
      name: 'Q0.5',
      type: 'digital_output',
      gpio: 32,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 106,
      name: 'Q0.6',
      type: 'digital_output',
      gpio: 14,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 107,
      name: 'Q0.7',
      type: 'digital_output',
      gpio: 2,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    // Saídas Analógicas (DAC)
    GpioHardwareChannel(
      channelId: 80,
      name: 'AO0.0',
      type: 'analog_output',
      gpio: 25,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
    GpioHardwareChannel(
      channelId: 81,
      name: 'AO0.1',
      type: 'analog_output',
      gpio: 26,
      state: 0,
      isOutput: true,
      controllerIndex: 0,
    ),
  ];

  /// Pinos físicos padrão do ESP32 para parametrização industrial
  static const List<GpioInventoryPin> defaultInventoryPins = [
    GpioInventoryPin(
      gpio: 16,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.0',
    ),
    GpioInventoryPin(
      gpio: 17,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.1',
    ),
    GpioInventoryPin(
      gpio: 18,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.2',
    ),
    GpioInventoryPin(
      gpio: 19,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.3',
    ),
    GpioInventoryPin(
      gpio: 27,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.4',
    ),
    GpioInventoryPin(
      gpio: 13,
      inputCapable: true,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'I0.5',
    ),
    GpioInventoryPin(
      gpio: 4,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.0',
    ),
    GpioInventoryPin(
      gpio: 21,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.1',
    ),
    GpioInventoryPin(
      gpio: 22,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.2',
    ),
    GpioInventoryPin(
      gpio: 33,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.3',
    ),
    GpioInventoryPin(
      gpio: 23,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.4',
    ),
    GpioInventoryPin(
      gpio: 32,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.5',
    ),
    GpioInventoryPin(
      gpio: 14,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.6',
    ),
    GpioInventoryPin(
      gpio: 2,
      inputCapable: false,
      outputCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'Q0.7',
    ),
    GpioInventoryPin(
      gpio: 25,
      inputCapable: false,
      outputCapable: true,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AO0.0',
    ),
    GpioInventoryPin(
      gpio: 26,
      inputCapable: false,
      outputCapable: true,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AO0.1',
    ),
    GpioInventoryPin(
      gpio: 34,
      inputCapable: true,
      outputCapable: false,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AI0.0',
    ),
    GpioInventoryPin(
      gpio: 35,
      inputCapable: true,
      outputCapable: false,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AI0.1',
    ),
    GpioInventoryPin(
      gpio: 36,
      inputCapable: true,
      outputCapable: false,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AI0.2',
    ),
    GpioInventoryPin(
      gpio: 39,
      inputCapable: true,
      outputCapable: false,
      analogCapable: true,
      state: 'AVAILABLE',
      plcChannel: 'AI0.3',
    ),
  ];

  /// Forçamento REAL no firmware via POST /api/io/force.
  /// Retorna o status HTTP (200 ok, 404 canal não forçável, 409 fail-safe ativo) ou null em erro de rede.
  Future<int?> postForce(String gatewayIp, Map<String, dynamic> body) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return null;
    try {
      final url = Uri.parse(buildUrl(cleanIp, '/api/io/force'));
      final res = await _activeClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);
      return res.statusCode;
    } catch (_) {
      return null;
    }
  }

  /// Executa o comando real no hardware via /api/set?id=...&value=0|1&target_node=...
  Future<bool> setOutput(
    String gatewayIp,
    int channelId,
    int value, {
    String? targetNodeId,
  }) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return false;

    try {
      final String nodeParam = (targetNodeId != null && targetNodeId.isNotEmpty)
          ? '&target_node=${targetNodeId.replaceAll("ENDAP-", "")}'
          : '';
      final url = Uri.parse(
        buildUrl(cleanIp, '/api/set?id=$channelId&value=$value$nodeParam'),
      );
      final res = await _activeClient.get(url).timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (_) {
      return false;
    }
  }

  /// Lê o estado em tempo real da saída a partir de /api/public/status ou /api/io/map
  Future<int?> fetchOutputState(String gatewayIp, int channelId) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return null;

    try {
      final url = Uri.parse(buildUrl(cleanIp, '/api/public/status'));
      final res = await _activeClient.get(url).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final outputs = data['outputs'] as List<dynamic>? ?? [];
        for (var item in outputs) {
          if (item is Map<String, dynamic>) {
            final id = (item['id'] ?? item['channel_id']) as num?;
            if (id?.toInt() == channelId) {
              return (item['value'] ?? item['reported']) as int?;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Lê a configuração de sensores (AHT10, DS18B20, DHT11) do firmware
  Future<Map<String, dynamic>?> fetchSensorConfig(String gatewayIp) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return null;
    try {
      final url = Uri.parse(buildUrl(cleanIp, '/api/sensors/config'));
      final res = await _activeClient.get(url).timeout(_timeout);
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Salva a configuração de sensores (ex: habilitar AHT10 em GPIO 16/17)
  Future<bool> updateSensorConfig(
    String gatewayIp,
    Map<String, dynamic> config,
  ) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return false;
    try {
      final query = config.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
          )
          .join('&');
      final pathWithQuery = query.isNotEmpty
          ? '/api/sensors/config?$query'
          : '/api/sensors/config';
      final url = Uri.parse(buildUrl(cleanIp, pathWithQuery));
      final res = await _activeClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(config),
          )
          .timeout(_timeout);
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
