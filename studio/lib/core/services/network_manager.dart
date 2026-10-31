import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../network/authenticated_http_client.dart';
import 'studio_event_bus.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';
import '../../ladder/ui/editor/firmware_sync_service.dart';
import '../models/io_channel_mapping.dart';

enum NodeStatus { online, offline, suspect, error, pending }

enum ControllerOnboardingState {
  unknown,
  pending,      // UNPROVISIONED / PENDING
  discovered,
  claimed,
  active,       // READY / ACTIVE
}
enum ConnectionState { simulationLocal, reconnecting, hardwareOnline, offline }

class ControllerInfo {
  final String id;
  final String ip;
  final bool isOnline;
  final ControllerOnboardingState onboardingState;
  final String onboardingStateRaw;
  final String nodeName;
  final String? transport;
  final int profile;

  bool get isReady => isOnline && onboardingState == ControllerOnboardingState.active;
  bool get isPending => isOnline && (onboardingState == ControllerOnboardingState.pending || onboardingState == ControllerOnboardingState.discovered);

  /// Perfil 4 = Gateway Dedicado / Exclusivo (Roteamento e Telemetria pura, sem controle local cíclico / Ladder)
  bool get isExclusiveGateway => profile == 4 || nodeName.toLowerCase().contains('dedicado');

  /// Perfil 0 = Gateway Híbrido (Roteador + CLP Local com execução determinística de 1ms)
  bool get isHybridGateway => profile == 0 || (profile != 4 && !nodeName.toLowerCase().contains('dedicado'));

  /// Capacidade de executar lógica ladder local (intertravamento técnico)
  bool get canExecuteLadder => !isExclusiveGateway;

  ControllerInfo({
    required this.id,
    required this.ip,
    required this.isOnline,
    required this.onboardingState,
    required this.onboardingStateRaw,
    required this.nodeName,
    required this.transport,
    required this.profile,
  });

  factory ControllerInfo.offline(String ip) {
    return ControllerInfo(
      id: '',
      ip: ip,
      isOnline: false,
      onboardingState: ControllerOnboardingState.unknown,
      onboardingStateRaw: 'OFFLINE',
      nodeName: '',
      transport: 'NONE',
      profile: 1,
    );
  }
}

class EndapNode {
  final String id;
  final String ip;
  final String role;
  NodeStatus status;
  int pingMs;
  final String transport;
  final String version;
  final int controllerIndex;

  EndapNode({
    required this.id,
    required this.ip,
    required this.role,
    this.status = NodeStatus.online,
    this.pingMs = 0,
    this.transport = 'WIFI',
    this.version = 'N/D',
    this.controllerIndex = 0,
  });
}

class NetworkManager extends ChangeNotifier {
  static String buildUrl(String host, String path) {
    final cleanHost = host.trim();
    if (kIsWeb && Uri.base.scheme == 'https' && (cleanHost == Uri.base.authority || cleanHost == Uri.base.host)) {
      return 'https://$cleanHost$path';
    }
    return 'http://$cleanHost$path';
  }

  static const String _prefGatewayIpKey = 'firmware_gateway_ip';
  static const String _defaultGatewayIp = '192.168.0.229';

  static const String mdnsHost = 'endap.local';

  ConnectionState _connectionState = ConnectionState.simulationLocal;
  ConnectionState get connectionState => _connectionState;
  bool get isHardwareOnline => _connectionState == ConnectionState.hardwareOnline;

  bool isScanning = false;
  bool isProvisioning = false;
  List<EndapNode> nodes = [];
  List<ControllerInfo> discoveredControllers = [];
  String gatewayIp = _defaultGatewayIp;
  String errorMessage = '';

  String _lastStaIp = '';
  String get lastStaIp => _lastStaIp;
  bool get hasAlternativeControllerIp => _lastStaIp.isNotEmpty && _lastStaIp != gatewayIp;

  bool get hasAdoptedFieldNode => activeFieldNodeIndexes.isNotEmpty;

  Set<int> get activeFieldNodeIndexes {
    return nodes
        .where((n) =>
            n.controllerIndex > 0 &&
            n.status != NodeStatus.pending &&
            !n.role.toLowerCase().contains('gateway'))
        .map((n) => n.controllerIndex)
        .toSet();
  }

  List<EndapNode> get unclaimedNodes =>
      nodes.where((n) => n.status == NodeStatus.pending && n.controllerIndex > 0).toList();

  /// Papel e Intertravamentos do Gateway
  bool get isExclusiveGateway => controller.isExclusiveGateway;
  bool get isHybridGateway => controller.isHybridGateway;
  bool get canGatewayExecuteLadder => controller.canExecuteLadder;

  ControllerInfo controller = ControllerInfo.offline(_defaultGatewayIp);
  IoMapResponse? ioMap;

  // Métricas Reais do Kernel Determinístico lidas via /api/status do ESP32
  int kernelJitterMaxUs = 0;
  int kernelExecMaxUs = 0;
  int kernelDeadlineMiss = 0;
  int kernelOverruns = 0;

  final Set<String> _seenHardwareAuditSigs = {};

  http.Client? _httpClient;

  @visibleForTesting
  set httpClient(http.Client client) => _httpClient = client;

  http.Client get _client => _httpClient ??= AuthenticatedHttpClient();
  Timer? _pollingTimer;
  int _heartbeatCount = 0;
  int _consecutiveHeartbeatFailures = 0;
  static const int _maxHeartbeatFailures = 2;
  static const int _rescanEveryNHeartbeats = 10;

  NetworkManager({http.Client? client, bool autoStartPeriodicCheck = false}) : _httpClient = client {
    _initAndCheck(autoStartPeriodicCheck: autoStartPeriodicCheck);
  }

  Future<void> _initAndCheck({bool autoStartPeriodicCheck = false}) async {
    await _loadGatewayIp();
    await checkControllerAndScan();
    if (autoStartPeriodicCheck) {
      startPeriodicCheck();
    }
  }

  void startPeriodicCheck({Duration interval = const Duration(seconds: 3)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      if (!isScanning && !isProvisioning) {
        _silentHeartbeat();
      }
    });
  }

  void stopPeriodicCheck() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPeriodicCheck();
    super.dispose();
  }

  Future<void> _silentHeartbeat() async {
    try {
      final pubStatusUri = Uri.parse(buildUrl(gatewayIp, '/api/public/status'));
      final pubResponse = await _client.get(pubStatusUri).timeout(const Duration(seconds: 2));

      if (pubResponse.statusCode == 200) {
        _consecutiveHeartbeatFailures = 0;
        if (_connectionState != ConnectionState.hardwareOnline) {
          await _checkController();
          await _scanFieldNodes();
          notifyListeners();
        }
        _heartbeatCount++;
        if (_heartbeatCount >= _rescanEveryNHeartbeats) {
          _heartbeatCount = 0;
          await discoverControllers();
          await _scanFieldNodes();
          notifyListeners();
        }
      } else {
        _heartbeatCount = 0;
        _consecutiveHeartbeatFailures++;
        if (_consecutiveHeartbeatFailures >= _maxHeartbeatFailures) {
          await _handleHeartbeatFailure();
        }
      }
    } catch (_) {
      _heartbeatCount = 0;
      _consecutiveHeartbeatFailures++;
      if (_consecutiveHeartbeatFailures >= _maxHeartbeatFailures) {
        await _handleHeartbeatFailure();
      }
    }
  }

  Future<void> _handleHeartbeatFailure() async {
    final discovered = await _discoverControllerAddress();
    if (discovered != null) {
      if (discovered != gatewayIp) {
        debugPrint('[NetworkManager] Controlador encontrado em $discovered. Falover para ele.');
        await updateGatewayIp(discovered);
      }
      return;
    }

    if (_connectionState != ConnectionState.offline) {
      _setConnectionState(ConnectionState.offline);
      controller = ControllerInfo.offline(gatewayIp);
      nodes.clear();
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<String?> discoverControllerAddress() => _discoverControllerAddress();

  /// Descobre TODOS os controladores ENDAP acessíveis na rede (mDNS local,
  /// IP configurado e STA IPs conhecidos), preenchendo [discoveredControllers].
  Future<List<ControllerInfo>> discoverControllers() async {
    final found = <ControllerInfo>[];
    final candidates = <String>{
      if (gatewayIp.isNotEmpty) gatewayIp,
      mdnsHost,
      if (kIsWeb && Uri.base.authority.isNotEmpty) Uri.base.authority,
      if (_lastStaIp.isNotEmpty && _lastStaIp != gatewayIp) _lastStaIp,
      '192.168.0.229',
      '192.168.0.27',
    };

    // IPs peers conhecidos via registro da rede (endap.local sabe a STA IP)
    for (final peerIp in _knownPeerIpsFromNodes()) {
      if (peerIp.isNotEmpty) candidates.add(peerIp);
    }

    for (final address in candidates) {
      final info = await _probeControllerInfo(address);
      if (info != null && info.isOnline) {
        found.add(info);
      }
    }

    // Deduplica por Node ID normalizado (sem prefixo 'ENDAP-').
    // Mantém preferencialmente a instância do gateway principal (ip == gatewayIp).
    final uniqueById = <String, ControllerInfo>{};
    for (final info in found) {
      final key = info.id.replaceAll('ENDAP-', '').trim().toUpperCase();
      if (!uniqueById.containsKey(key)) {
        uniqueById[key] = info;
      } else if (info.ip == gatewayIp) {
        uniqueById[key] = info;
      }
    }
    final list = uniqueById.values.toList()
      ..sort((a, b) {
        if (a.ip == gatewayIp) return -1;
        if (b.ip == gatewayIp) return 1;
        return a.ip.compareTo(b.ip);
      });

    discoveredControllers = list;
    notifyListeners();
    return list;
  }

  List<String> _knownPeerIpsFromNodes() {
    final ips = <String>{};
    for (final node in nodes) {
      final ip = node.ip.trim();
      if (ip.isNotEmpty && ip != 'Sem IP') ips.add(ip);
    }
    return ips.toList();
  }

  Future<ControllerInfo?> _probeControllerInfo(String address) async {
    try {
      final pubUri = Uri.parse(buildUrl(address, '/api/public/status'));
      final response = await _client.get(pubUri).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;

      final pubData = json.decode(response.body) as Map<String, dynamic>;
      final rawNodeId = pubData['node_id']?.toString() ?? '';
      final transportName = pubData['transport_name']?.toString();

      if (rawNodeId.isEmpty) return null;

      var obStateRaw = 'PENDING';
      var nodeName = 'ENDAP-Controller';
      var profile = 1;
      try {
        final obUri = Uri.parse(buildUrl(address, '/api/onboarding/status'));
        final obResponse = await _client.get(obUri).timeout(const Duration(seconds: 2));
        if (obResponse.statusCode == 200) {
          final obData = json.decode(obResponse.body) as Map<String, dynamic>;
          obStateRaw = (obData['state'] as String? ?? 'PENDING').toUpperCase();
          nodeName = obData['node_name'] as String? ?? nodeName;
          profile = (obData['profile'] as num?)?.toInt() ?? 1;
        }
      } catch (_) {}

      ControllerOnboardingState obState = ControllerOnboardingState.pending;
      switch (obStateRaw) {
        case 'ACTIVE':
          obState = ControllerOnboardingState.active;
          break;
        case 'DISCOVERED':
          obState = ControllerOnboardingState.discovered;
          break;
        case 'CLAIMED':
          obState = ControllerOnboardingState.claimed;
          break;
      }

      return ControllerInfo(
        id: 'ENDAP-$rawNodeId',
        ip: address,
        isOnline: true,
        onboardingState: obState,
        onboardingStateRaw: obStateRaw,
        nodeName: nodeName,
        transport: transportName,
        profile: profile,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _discoverControllerAddress() async {
    final candidates = <String>{
      if (kIsWeb && Uri.base.authority.isNotEmpty) Uri.base.authority,
      '192.168.0.229',
      '192.168.0.27',
      mdnsHost,
      gatewayIp,
      if (_lastStaIp.isNotEmpty) _lastStaIp,
    };
    for (final address in candidates) {
      if (await _probeController(address)) {
        return address;
      }
    }
    return null;
  }

  Future<bool> _probeController(String address) async {
    try {
      final uri = Uri.parse(buildUrl(address, '/api/public/status'));
      final response = await _client.get(uri).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadGatewayIp() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 500));
      final saved = prefs.getString(_prefGatewayIpKey)?.trim();
      if (saved != null && saved.isNotEmpty && saved != '192.168.4.1' && saved != '192.168.0.27') {
        gatewayIp = saved;
      } else {
        gatewayIp = _defaultGatewayIp;
        await prefs.setString(_prefGatewayIpKey, _defaultGatewayIp);
      }
      controller = ControllerInfo.offline(gatewayIp);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar IP do Gateway: $e');
    }
  }

  Future<void> _persistGatewayIp(String newIp) async {
    final cleanIp = newIp.trim();
    if (cleanIp.isEmpty) return;
    gatewayIp = cleanIp;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 500));
      await prefs.setString(_prefGatewayIpKey, gatewayIp);
      await FirmwareSyncService.saveGatewayIp(gatewayIp);
      await TelemetrySyncService.instance.updateGatewayIp(gatewayIp);
    } catch (e) {
      debugPrint('Erro ao salvar IP do Gateway: $e');
    }
  }

  Future<void> updateGatewayIp(String newIp) async {
    final cleanIp = newIp.trim();
    if (cleanIp.isEmpty || cleanIp == gatewayIp) return;
    await _persistGatewayIp(cleanIp);
    await checkControllerAndScan();
  }

  Future<bool> discoverAndConnect() async {
    final discovered = await _discoverControllerAddress();
    if (discovered == null) {
      return false;
    }
    if (discovered != gatewayIp) {
      await updateGatewayIp(discovered);
    } else {
      await checkControllerAndScan();
    }
    return controller.isOnline;
  }

  Future<void> checkControllerAndScan() async {
    isScanning = true;
    errorMessage = '';
    notifyListeners();

    try {
      await _checkController();

      if (!controller.isOnline) {
        final discovered = await _discoverControllerAddress();
        if (discovered != null && discovered != gatewayIp) {
          debugPrint('[NetworkManager] Check inicial: controlador encontrado em $discovered via descoberta.');
          await _persistGatewayIp(discovered);
          await _checkController();
        }
      }

      if (controller.isOnline) {
        await _scanFieldNodes();
        await discoverControllers();
        await fetchIoMap();
        await fetchHardwareAuditLogs();
      } else {
        // Preserva nós conhecidos marcando-os como offline para evitar salto de layout
        for (final n in nodes) {
          n.status = NodeStatus.offline;
        }
      }
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  /// Consulta os logs de auditoria reais gravados no anel de memória do ESP32 (/api/auth/audit)
  /// e ingere novos eventos no StudioEventBus.
  Future<List<Map<String, dynamic>>> fetchHardwareAuditLogs() async {
    if (!isHardwareOnline && !controller.isOnline) return [];
    try {
      final url = Uri.parse(buildUrl(gatewayIp, '/api/auth/audit'));
      final res = await _client.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>? ?? [];
        final parsed = <Map<String, dynamic>>[];
        for (final item in events) {
          if (item is Map<String, dynamic>) {
            parsed.add(item);
            _ingestHardwareAuditEvent(item);
          }
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  @visibleForTesting
  void setConnectionStateForTesting(ConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  void _ingestHardwareAuditEvent(Map<String, dynamic> item) {
    final tsMs = (item['timestamp_ms'] as num?)?.toInt() ?? 0;
    final action = item['action']?.toString() ?? 'event';
    final detail = item['detail']?.toString() ?? '';
    final sig = '${tsMs}_${action}_$detail';
    if (_seenHardwareAuditSigs.contains(sig)) return;
    _seenHardwareAuditSigs.add(sig);

    final isWarning = action.contains('fail') || action.contains('weak') || action.contains('unauthorized') || action.contains('error');
    final isCritical = action.contains('crash') || action.contains('panic') || action.contains('corrupt') || action.contains('emergency');

    StudioEventBus.instance.emit(
      type: 'HW_${action.toUpperCase()}',
      source: 'ESP32 HARDWARE',
      message: 'ESP32 [${tsMs}ms]: $action - $detail',
      severity: isCritical ? EventSeverity.critical : (isWarning ? EventSeverity.warning : EventSeverity.info),
    );
  }

  Future<void> scanNetwork() async {
    await checkControllerAndScan();
  }

  void _setConnectionState(ConnectionState state) {
    if (_connectionState != state) {
      final old = _connectionState;
      _connectionState = state;
      notifyListeners();

      if (state == ConnectionState.hardwareOnline && old != ConnectionState.hardwareOnline) {
        StudioEventBus.instance.emit(
          type: 'HARDWARE_ONLINE',
          source: 'REDE',
          message: 'Controlador Gateway $gatewayIp CONECTADO e ONLINE',
          severity: EventSeverity.info,
        );
      } else if (state == ConnectionState.offline && old == ConnectionState.hardwareOnline) {
        StudioEventBus.instance.emit(
          type: 'HARDWARE_OFFLINE',
          source: 'REDE',
          message: 'Controlador Gateway $gatewayIp DESCONECTADO (Offline)',
          severity: EventSeverity.critical,
        );
      }
    }
  }

  Future<void> _checkController() async {
    _setConnectionState(ConnectionState.reconnecting);
    try {
      final pubStatusUri = Uri.parse(buildUrl(gatewayIp, '/api/public/status'));
      final pubResponse = await _client.get(pubStatusUri).timeout(const Duration(seconds: 3));

      if (pubResponse.statusCode != 200) {
        _setConnectionState(ConnectionState.offline);
        controller = ControllerInfo.offline(gatewayIp);
        errorMessage = 'Controller inacessível (HTTP ${pubResponse.statusCode})';
        return;
      }

      final pubData = json.decode(pubResponse.body) as Map<String, dynamic>;
      _setConnectionState(ConnectionState.hardwareOnline);
      final rawNodeId = pubData['node_id']?.toString() ?? '';
      final transportName = pubData['transport_name']?.toString();

      final staIpFromStatus = pubData['net_wifi_sta_ip_text']?.toString().trim() ?? '';
      if (staIpFromStatus.isNotEmpty) {
        _lastStaIp = staIpFromStatus;
      }

      ControllerOnboardingState obState = ControllerOnboardingState.unknown;
      String obStateRaw = 'UNKNOWN';
      String nodeName = 'ENDAP-Controller';
      int profile = 1;

      final obUri = Uri.parse(buildUrl(gatewayIp, '/api/onboarding/status'));
      try {
        final obResponse = await _client.get(obUri).timeout(const Duration(seconds: 3));
        if (obResponse.statusCode == 200) {
          final obData = json.decode(obResponse.body) as Map<String, dynamic>;
          obStateRaw = (obData['state'] as String? ?? 'PENDING').toUpperCase();
          nodeName = obData['node_name'] as String? ?? nodeName;
          profile = (obData['profile'] as num?)?.toInt() ?? 1;

          switch (obStateRaw) {
            case 'ACTIVE':
              obState = ControllerOnboardingState.active;
              break;
            case 'PENDING':
              obState = ControllerOnboardingState.pending;
              break;
            case 'DISCOVERED':
              obState = ControllerOnboardingState.discovered;
              break;
            case 'CLAIMED':
              obState = ControllerOnboardingState.claimed;
              break;
            default:
              obState = ControllerOnboardingState.pending;
          }
        } else {
          obStateRaw = 'HTTP_${obResponse.statusCode}';
          debugPrint('[NetworkManager] Erro HTTP ao consultar $obUri: status ${obResponse.statusCode} - ${obResponse.body}');
        }
      } catch (e) {
        obStateRaw = 'ERRO_CONEXAO';
        debugPrint('[NetworkManager] Exceção ao consultar $obUri: $e');
      }

      controller = ControllerInfo(
        id: rawNodeId.isNotEmpty ? 'ENDAP-$rawNodeId' : 'ID NÃO INFORMADO',
        ip: gatewayIp,
        isOnline: _connectionState == ConnectionState.hardwareOnline,
        onboardingState: obState,
        onboardingStateRaw: obStateRaw,
        nodeName: nodeName,
        transport: transportName,
        profile: profile,
      );
    } catch (e) {
      _setConnectionState(ConnectionState.offline);
      controller = ControllerInfo.offline(gatewayIp);
      errorMessage = 'Falha ao conectar no Controller ($gatewayIp)';
      debugPrint('Falha ao checar Controller: $e');
    }
  }

  Future<void> fetchIoMap() async {
    try {
      final statusResp = await _client.get(Uri.parse(buildUrl(gatewayIp, '/api/status'))).timeout(const Duration(seconds: 3));
      if (statusResp.statusCode == 200) {
        final data = json.decode(statusResp.body) as Map<String, dynamic>;
        ioMap = IoMapResponse.fromJson(data);
        kernelJitterMaxUs = (data['k_jitter_max'] as num?)?.toInt() ?? 0;
        kernelExecMaxUs = (data['k_exec_max'] as num?)?.toInt() ?? 0;
        kernelDeadlineMiss = (data['k_deadline_miss'] as num?)?.toInt() ?? 0;
        kernelOverruns = (data['k_overrun'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[NetworkManager] Falha ao ler I/O map: $e');
    }
  }

  String _cleanNodeId(String raw) =>
      raw.replaceAll('ENDAP-', '').replaceAll('endap-', '').trim().toUpperCase();

  Future<void> _scanFieldNodes() async {
    final listedIds = <String>{};
    final primaryCleanId = _cleanNodeId(controller.id);
    final remoteNodes = <EndapNode>[];

    bool isPrimaryNode(String cleanId, String ipStr) {
      if (primaryCleanId.isNotEmpty && cleanId == primaryCleanId) return true;
      if (ipStr.isEmpty || ipStr == 'Sem IP') return false;
      if (ipStr == gatewayIp) return true;
      if (controller.ip.isNotEmpty && ipStr == controller.ip) return true;
      if (_lastStaIp.isNotEmpty && ipStr == _lastStaIp) return true;
      return false;
    }

    try {
      final response = await _client.get(Uri.parse(buildUrl(gatewayIp, '/api/nodes')))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nodesList = data['nodes'] as List<dynamic>? ?? [];

        for (var n in nodesList) {
          final id = (n['id'] ?? n['node_id'])?.toString() ?? '';
          final ipStr = (n['ip'] as String? ?? '').trim();
          final stateStr = n['cluster_state'] ?? n['state'] ?? 'offline';
          final registryState = (n['registry_state'] as String? ?? '').toLowerCase();
          final admissionPhase = (n['admission_phase'] as String? ?? '').toLowerCase();
          final transport = n['last_transport'] ?? n['transport'] ?? 'none';
          final version = n['version'] as String? ?? 'N/D';

          final cleanId = _cleanNodeId(id);
          if (cleanId.isEmpty) continue;

          // Se for o controlador primário (Gateway), ignora aqui
          if (isPrimaryNode(cleanId, ipStr)) {
            continue;
          }

          if (listedIds.contains(cleanId)) continue;

          final needsAdoption = registryState.isNotEmpty
              ? (registryState != 'active' && registryState != 'operational')
              : (admissionPhase.isEmpty || admissionPhase != 'active');

          NodeStatus status = NodeStatus.offline;
          if (stateStr == 'online') {
            status = needsAdoption ? NodeStatus.pending : NodeStatus.online;
          } else if (stateStr == 'suspect') {
            status = NodeStatus.suspect;
          } else if (stateStr == 'pending') {
            status = NodeStatus.pending;
          }

          remoteNodes.add(EndapNode(
            id: 'ENDAP-$cleanId',
            ip: ipStr.isEmpty ? 'Sem IP' : ipStr,
            role: 'Controlador Remoto',
            status: status,
            transport: transport.toString(),
            version: version,
            pingMs: 0,
          ));
          listedIds.add(cleanId);
        }
      }
    } catch (e) {
      debugPrint('Aviso ao consultar /api/nodes: $e');
    }

    // Garante visibilidade de controladores adicionais realmente distintos
    for (final ctrl in discoveredControllers) {
      final cleanCtrlId = _cleanNodeId(ctrl.id);
      if (cleanCtrlId.isEmpty) continue;
      if (!ctrl.isOnline || isPrimaryNode(cleanCtrlId, ctrl.ip) || listedIds.contains(cleanCtrlId)) {
        continue;
      }
      remoteNodes.add(EndapNode(
        id: 'ENDAP-$cleanCtrlId',
        ip: ctrl.ip,
        role: 'Controlador Remoto',
        status: ctrl.isPending ? NodeStatus.pending : NodeStatus.online,
        transport: ctrl.transport ?? 'WIFI',
        version: 'N/D',
        pingMs: 0,
      ));
      listedIds.add(cleanCtrlId);
    }

    // Atribui controllerIndex sequencial (1, 2, 3...) para os nós remotos válidos
    final indexedRemoteNodes = <EndapNode>[];
    for (int i = 0; i < remoteNodes.length; i++) {
      final r = remoteNodes[i];
      indexedRemoteNodes.add(EndapNode(
        id: r.id,
        ip: r.ip,
        role: r.role,
        status: r.status,
        transport: r.transport,
        version: r.version,
        pingMs: r.pingMs,
        controllerIndex: i + 1,
      ));
    }

    nodes.clear();

    // O controlador primário (Gateway) é SEMPRE adicionado como único na posição 0
    if (controller.isOnline && primaryCleanId.isNotEmpty) {
      nodes.add(EndapNode(
        id: 'ENDAP-$primaryCleanId',
        ip: controller.ip.isEmpty ? gatewayIp : controller.ip,
        role: controller.isExclusiveGateway ? 'Gateway Dedicado' : 'Gateway Principal',
        status: NodeStatus.online,
        transport: controller.transport ?? 'WIFI',
        version: 'N/D',
        controllerIndex: 0,
        pingMs: 0,
      ));
    }

    nodes.addAll(indexedRemoteNodes);
  }

  Future<bool> provisionController({String? name, int profile = 0}) async {
    isProvisioning = true;
    notifyListeners();

    try {
      final url = Uri.parse(buildUrl(gatewayIp, '/api/onboarding/claim'));
      final nodeName = name ?? (controller.nodeName.isNotEmpty ? controller.nodeName : 'ENDAP-Controlador');
      final rawId = controller.id.replaceAll('ENDAP-', '');

      final body = 'target_node_id=$rawId&profile=$profile&gateway_id=$rawId&node_name=${Uri.encodeComponent(nodeName)}';

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await checkControllerAndScan();
        return true;
      } else {
        errorMessage = 'Erro no provisionamento: HTTP ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Falha ao provisionar Controller: $e';
      debugPrint(errorMessage);
    } finally {
      isProvisioning = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> adoptNode(String nodeId, String role) async {
    try {
      final realId = nodeId.replaceAll('ENDAP-', '');
      final gwId = controller.id.replaceAll('ENDAP-', '');
      final profile = _roleToProfile(role);
      final safeName = role.isEmpty ? 'ENDAP-Controlador' : role.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

      final url = Uri.parse(buildUrl(gatewayIp, '/api/onboarding/claim'));
      final body = 'target_node_id=$realId&profile=$profile&gateway_id=$gwId&node_name=${Uri.encodeComponent(safeName)}';

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await scanNetwork();
        return true;
      } else {
        errorMessage = 'Falha na adoção: HTTP ${response.statusCode} (use claim remoto)';
        debugPrint('Falha ao adotar nó via claim: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      errorMessage = 'Falha ao adotar nó: $e';
      debugPrint(errorMessage);
    }
    return false;
  }

  Future<bool> setNodeTransport(String nodeId, String transport) async {
    try {
      final realId = nodeId.replaceAll('ENDAP-', '');
      final isEspNow = transport.toLowerCase().contains('now') || transport.toLowerCase().contains('esp');
      final wifiMode = isEspNow ? 'now' : 'infra';
      final primary = isEspNow ? 'wifi-now' : 'wifi-udp';

      final url = Uri.parse(buildUrl(gatewayIp, '/api/nodes/$realId/transport'));
      final payload = jsonEncode({
        'primary': primary,
        'wifi_mode': wifiMode,
        'wifi_enabled': true,
      });

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await scanNetwork();
        return true;
      } else {
        errorMessage = 'Falha ao alterar transporte: HTTP ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Falha ao alterar transporte: $e';
      debugPrint(errorMessage);
    }
    notifyListeners();
    return false;
  }

  Future<bool> revokeNode(String nodeId) async {
    try {
      final realId = nodeId.replaceAll('ENDAP-', '');
      final url = Uri.parse(buildUrl(gatewayIp, '/api/nodes/revoke?id=$realId'));
      final response = await _client.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.body.contains('REVOKED')) {
        nodes.removeWhere((n) => n.id == nodeId || n.id == realId || n.id == 'ENDAP-$realId');
        await scanNetwork();
        return true;
      } else {
        errorMessage = 'Falha ao remover nó: HTTP ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Erro ao remover dispositivo. Tente novamente.';
    }
    notifyListeners();
    return false;
  }

  static int _roleToProfile(String role) {
    final r = role.toLowerCase();
    if (r.contains('gateway')) return 0;
    if (r.contains('relay')) return 2;
    if (r.contains('sensor')) return 3;
    return 1;
  }
}
