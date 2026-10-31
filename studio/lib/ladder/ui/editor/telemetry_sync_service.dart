import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/authenticated_http_client.dart';
import '../../../core/services/studio_event_bus.dart';
import '../../models/ladder_project.dart';
import '../../models/tag.dart';
import '../../models/enums.dart';
import '../../models/tag_value.dart';
import '../../runtime/ladder_runtime.dart';
import 'firmware_sync_service.dart';

/// Status da conexão de telemetria com o MCU
enum TelemetryConnectionStatus { online, offline }

/// Serviço responsável pelo polling periódico de telemetria do MCU (/api/io/map)
/// e alimentação do TagStateStore do LadderRuntime.
class TelemetrySyncService extends ChangeNotifier {
  static final TelemetrySyncService instance = TelemetrySyncService._internal();
  TelemetrySyncService._internal();

  http.Client? _httpClient;
  Timer? _pollingTimer;
  bool _isPolling = false;
  TelemetryConnectionStatus _status = TelemetryConnectionStatus.offline;
  DateTime? _lastTelemetryReceived;

  LadderProject? _project;
  LadderRuntime? _runtime;
  String _gatewayIp = '192.168.0.229';

  /// Lista de IPs dos controladores consultados pela telemetria.
  /// O índice do item na lista é o índice do controlador (0 = primário),
  /// usado para deslocar os canais locais para o byte de endereço global
  /// (controlador 1: I0.x/Q0.x, controlador 2: I1.x/Q1.x, ...).
  List<String> _controllerIps = [];

  /// Controla se os dados de telemetria são aplicados no runtime (TagStateStore).
  /// Fica ativo por padrão e no modo HARDWARE do editor para telemetria em tempo real.
  bool _injectEnabled = true;
  bool get injectEnabled => _injectEnabled;
  set injectEnabled(bool value) {
    _injectEnabled = value;
  }

  TelemetryConnectionStatus get status => _status;
  bool get isOnline => _status == TelemetryConnectionStatus.online;
  bool get isPolling => _isPolling;
  String get gatewayIp => _gatewayIp;
  List<String> get controllerIps => List.unmodifiable(_controllerIps);

  DateTime? get lastTelemetryReceived => _lastTelemetryReceived;

  /// Retorna true se a telemetria não tiver sido recebida ou estiver atrasada (> 2500ms)
  bool get isStale {
    if (_lastTelemetryReceived == null) return true;
    return DateTime.now().difference(_lastTelemetryReceived!) >
        const Duration(milliseconds: 2500);
  }

  @visibleForTesting
  void setLastTelemetryReceivedForTesting(DateTime timestamp) {
    _lastTelemetryReceived = timestamp;
  }

  @visibleForTesting
  set httpClient(http.Client client) => _httpClient = client;

  http.Client get _client {
    _httpClient ??= AuthenticatedHttpClient();
    return _httpClient!;
  }

  /// Inicializa o serviço com o projeto e runtime ativos
  void init({
    required LadderProject project,
    required LadderRuntime runtime,
    String? gatewayIp,
    List<String>? controllerIps,
  }) {
    _status = TelemetryConnectionStatus.offline;
    _consecutiveFailures = 0;
    _project = project;
    _runtime = runtime;
    final normalizedIp = (gatewayIp == null || gatewayIp.trim().isEmpty || gatewayIp.trim() == '192.168.4.1')
        ? '192.168.0.229'
        : gatewayIp.trim();
    _gatewayIp = normalizedIp;
    if (controllerIps != null && controllerIps.isNotEmpty) {
      _controllerIps = controllerIps
          .map((ip) => (ip == '192.168.4.1') ? '192.168.0.229' : ip.trim())
          .where((ip) => ip.isNotEmpty)
          .toSet()
          .toList();
      if (!_controllerIps.contains(_gatewayIp)) {
        _controllerIps.insert(0, _gatewayIp);
      }
    } else {
      _controllerIps = [_gatewayIp];
    }
  }

  /// Atualiza o IP do gateway e reinicia o polling se ativo
  Future<void> updateGatewayIp(String ip) async {
    final clean = (ip.trim() == '192.168.4.1' || ip.trim().isEmpty)
        ? '192.168.0.229'
        : ip.trim();
    _gatewayIp = clean;
    if (_controllerIps.isEmpty) {
      _controllerIps = [clean];
    } else if (_controllerIps.first != clean) {
      _controllerIps = [clean, ..._controllerIps.where((c) => c != clean)];
    }
    await FirmwareSyncService.saveGatewayIp(clean);
    if (_isPolling) {
      start();
    }
  }

  /// Atualiza a lista de IPs dos controladores consultados pela telemetria.
  /// Mantém o primário sempre na primeira posição (índice 0).
  void updateControllerIps(List<String> ips) {
    final cleaned = ips.where((ip) => ip.isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) return;
    if (!cleaned.contains(_gatewayIp)) {
      cleaned.insert(0, _gatewayIp);
    }
    cleaned.sort();
    if (cleaned.first != _gatewayIp) {
      cleaned.remove(_gatewayIp);
      cleaned.insert(0, _gatewayIp);
    }
    _controllerIps = cleaned;
  }

  /// Inicia o ciclo de polling periódico (250 ms para tempo real estável e leve)
  void start({Duration interval = const Duration(milliseconds: 250)}) {
    stop();
    _isPolling = true;

    // Executa a primeira chamada imediatamente
    pollOnce();

    _pollingTimer = Timer.periodic(interval, (_) {
      pollOnce();
    });
  }

  /// Para o polling e limpa o timer ativo
  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _consecutiveFailures = 0;
    _setStatus(TelemetryConnectionStatus.offline);
  }

  /// Pausa temporariamente o polling sem zerar a porta
  void pause() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  bool _isFetching = false;
  Map<String, dynamic>? _lastIoMap;
  Map<String, dynamic>? get lastIoMap => _lastIoMap;

  int _pollCycleCount = 0;
  int _consecutiveFailures = 0;
  static const int _maxFailuresBeforeOffline = 3;

  /// Executa uma única requisição de telemetria e processa o retorno de forma concorrente
  Future<bool> pollOnce() async {
    if (_gatewayIp.isEmpty || _isFetching) return false;
    if (_controllerIps.isEmpty) {
      _controllerIps = [_gatewayIp];
    }
    _isFetching = true;
    _pollCycleCount++;

    bool anyOnline = false;
    bool primaryOnline = false;
    try {
      final hostsToTry = <String>[];
      if (_gatewayIp.isNotEmpty) {
        hostsToTry.add(_gatewayIp);
      }
      for (final ip in _controllerIps) {
        if (!hostsToTry.contains(ip)) {
          hostsToTry.add(ip);
        }
      }
      if (kIsWeb &&
          Uri.base.authority.isNotEmpty &&
          !hostsToTry.contains(Uri.base.authority)) {
        hostsToTry.add(Uri.base.authority);
      }

      final futures = <Future<_HostPollResult>>[];
      for (var i = 0; i < hostsToTry.length; i++) {
        final ip = hostsToTry[i];
        if (ip.isEmpty) continue;
        futures.add(_pollHost(ip, i));
      }

      final results = await Future.wait(futures);

      for (final res in results) {
        if (res.isOnline && res.ioData != null) {
          _lastIoMap = res.ioData;
          if (_controllerIps.length <= 1 && res.ip != _gatewayIp && res.ip == '192.168.0.229') {
            _gatewayIp = res.ip;
          }
          processIoMapJson(
            res.ioData!,
            controllerIndex: res.index < _controllerIps.length ? res.index : 0,
          );
          anyOnline = true;
          if (res.index == 0 || res.ip == _gatewayIp) primaryOnline = true;
        }

        if (res.pveData != null) {
          processPveJson(res.pveData!);
        }
      }

      if (primaryOnline) {
        _consecutiveFailures = 0;
        _setStatus(TelemetryConnectionStatus.online);
      } else {
        _consecutiveFailures++;
        if (_controllerIps.length > 1 || _consecutiveFailures >= _maxFailuresBeforeOffline) {
          _setStatus(TelemetryConnectionStatus.offline);
        }
      }
      return anyOnline;
    } finally {
      _isFetching = false;
    }
  }

  Future<_HostPollResult> _pollHost(String ip, int index) async {
    Map<String, dynamic>? ioData;
    Map<String, dynamic>? pveData;
    bool isOnline = false;

    try {
      final url = Uri.parse('http://$ip/api/io/map');
      final response = await _client
          .get(url)
          .timeout(const Duration(milliseconds: 1200));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          ioData = data;
          isOnline = true;
        }
      }

      if ((index == 0 || ip == _gatewayIp) && (_pollCycleCount % 20 == 0)) {
        try {
          final pveUrl = Uri.parse('http://$ip/api/pve');
          final pveRes = await _client
              .get(pveUrl)
              .timeout(const Duration(milliseconds: 1200));
          if (pveRes.statusCode == 200) {
            final pData = jsonDecode(pveRes.body);
            if (pData is Map<String, dynamic>) {
              pveData = pData;
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // Controlador offline
    }

    return _HostPollResult(
      ip: ip,
      index: index,
      isOnline: isOnline,
      ioData: ioData,
      pveData: pveData,
    );
  }

  /// Processa o JSON retornado por /api/io/map e injeta os estados no TagStateStore.
  /// [controllerIndex] identifica de qual controlador veio o io/map:
  /// 0 = primário (endereços I0.x/Q0.x), 1 = secundário (I1.x/Q1.x), etc.
  /// Os canais reportados por cada controlador são sempre os canais locais
  /// (channel_id 10..15, 100..105); aqui eles são deslocados para o byte de
  /// endereço global correspondente ao índice do controlador.
  void processIoMapJson(Map<String, dynamic> json, {int controllerIndex = 0}) {
    _lastTelemetryReceived = DateTime.now();
    if (_runtime == null) return;
    if (!_injectEnabled) return;

    final inputs = json['inputs'];
    if (inputs is List) {
      for (var item in inputs) {
        if (item is Map) {
          _applyIoEntry(
            item,
            isOutput: false,
            controllerIndex: controllerIndex,
          );
        }
      }
    }

    // Aplica as saídas e memórias do hardware real
    final outputs = json['outputs'];
    if (outputs is List) {
      for (var item in outputs) {
        if (item is Map) {
          _applyIoEntry(item, isOutput: true, controllerIndex: controllerIndex);
        }
      }
    }

    // Memórias internas (M, T, C, AO) são exclusivas do primário
    if (controllerIndex == 0) {
      final internals = json['internals'];
      if (internals is List) {
        for (var item in internals) {
          if (item is Map) {
            _applyIoEntry(item, isOutput: false, controllerIndex: 0);
          }
        }
      }
    }

    // Avalia a topologia localmente com base nos sinais recebidos para energização dos nós
    _runtime!.singleScan(100);

    // Re-garante a autoridade do hardware sobre saídas e memórias após a varredura
    if (outputs is List) {
      for (var item in outputs) {
        if (item is Map) {
          _applyIoEntry(item, isOutput: true, controllerIndex: controllerIndex);
        }
      }
    }
    if (controllerIndex == 0) {
      final internals = json['internals'];
      if (internals is List) {
        for (var item in internals) {
          if (item is Map) {
            _applyIoEntry(item, isOutput: false, controllerIndex: 0);
          }
        }
      }
    }

    notifyListeners();
  }

  /// Processa as variáveis de processo analógicas retornadas por /api/pve
  /// e atualiza tags analógicas correspondentes no TagStateStore (ex: TEMP_AHT10, UMID_AHT10)
  void processPveJson(Map<String, dynamic> json) {
    _lastTelemetryReceived = DateTime.now();
    if (_runtime == null || _project == null) return;
    if (!_injectEnabled) return;

    final variables = json['variables'];
    if (variables is! List) return;

    for (var v in variables) {
      if (v is! Map) continue;
      final name = v['name']?.toString() ?? '';
      final source = v['source']?.toString() ?? '';
      final decimals = (v['decimals'] as num?)?.toInt() ?? 1;
      final rawScaled = (v['scaled'] as num?) ?? (v['scaled_value'] as num?);
      final rawVal = (v['raw'] as num?);

      // Ignora sensores virtuais desconectados (ex: AHT10 / DHT11 / DS18B20 com raw=0 e scaled=0)
      if (source == 'VIRTUAL' &&
          (rawVal == null || rawVal == 0) &&
          (rawScaled == null || rawScaled == 0)) {
        continue;
      }

      // No firmware, AHT10 é salvo em pve_variables[2] (Temp) e [3] (Umidade) com fator 10 (ex: 245 = 24.5°C)
      // Se scaled_value estiver disponível, calcula o float correspondente
      double? calculatedVal;
      if (rawScaled != null) {
        calculatedVal = decimals > 0
            ? (rawScaled /
                  (decimals == 1 ? 10.0 : (decimals == 2 ? 100.0 : 1.0)))
            : rawScaled.toDouble();
      } else if (rawVal != null) {
        calculatedVal = rawVal.toDouble();
      }

      if (calculatedVal == null) continue;

      // Mapeamento específico por sensor real ativo no firmware (NUNCA sobrescrever AI0.0/AI0.1 com sensores virtuais!)
      final matchedKeys = <String>{};
      final isAht10Temp = name == 'SENSOR_1_TEMP';
      final isAht10Hum = name == 'SENSOR_1_HUM';
      final isDs18b20 = name == 'TEMP_DS';
      final isDhtTemp = name == 'TEMP_DHT';
      final isDhtHum = name == 'HUM_DHT';

      final isSoilMoisture = name == 'AIN1';

      if (isSoilMoisture) {
        matchedKeys.addAll(['%IW0.0', 'AI0.0', 'AIN1', name]);
      } else if (name == 'AIN2') {
        matchedKeys.addAll(['%IW0.1', 'AI0.1', 'AIN2', name]);
      } else if (isAht10Temp) {
        matchedKeys.addAll(['TEMP_AHT10', name]);
      } else if (isAht10Hum) {
        matchedKeys.addAll(['UMID_AHT10', name]);
      } else if (isDs18b20) {
        matchedKeys.addAll(['TEMP_DS18B20', 'TEMP_DS', name]);
      } else if (isDhtTemp) {
        matchedKeys.addAll(['TEMP_DHT11', 'TEMP_DHT', 'TEMP_SENSOR', name]);
      } else if (isDhtHum) {
        matchedKeys.addAll(['UMID_DHT11', 'HUM_DHT', 'UMID_SENSOR', name]);
      } else {
        matchedKeys.add(name);
      }

      for (final key in matchedKeys) {
        if (_project!.tags.containsKey(key)) {
          final tag = _project!.tags[key]!;
          final calVal =
              (calculatedVal * (tag.calGain ?? 1.0)) + (tag.calOffset ?? 0.0);
          final tagVal = tag.type == TagType.real
              ? TagValue.real(calVal)
              : TagValue.integer(calVal.round());

          if (!_runtime!.tagStore.isForced(key)) {
            _runtime!.tagStore.setValue(key, tagVal);
          }
          if (!_runtime!.tagStore.isForced(tag.id)) {
            _runtime!.tagStore.setValue(tag.id, tagVal);
          }
          if (tag.address != null &&
              !_runtime!.tagStore.isForced(tag.address!)) {
            _runtime!.tagStore.setValue(tag.address!, tagVal);
          }
        }
      }
    }

    _runtime!.singleScan(100);
    notifyListeners();
  }

  void _applyIoEntry(
    Map entry, {
    required bool isOutput,
    int controllerIndex = 0,
  }) {
    dynamic rawValue;
    if (isOutput) {
      rawValue =
          entry['desired'] ??
          entry['reported'] ??
          entry['state'] ??
          entry['value'];
    } else {
      rawValue =
          entry['state'] ??
          entry['value'] ??
          entry['reported'] ??
          entry['desired'];
    }
    if (rawValue == null || _project == null || _runtime == null) return;

    final boolVal = _parseBool(rawValue);

    // 1. Tenta mapear pelo canal canônico numérico do firmware (channel_id)
    String? canonicalAddress;
    String? plcAddress;
    int? resolvedChannelId;

    // O canal canônico reportado pelo controlador (10..15 de I, 100..105 de Q)
    int? localChannelId;
    final rawChannelId =
        entry['channel_id'] ?? entry['channelId'] ?? entry['id'];
    if (rawChannelId is int) {
      localChannelId = rawChannelId;
    } else if (rawChannelId != null) {
      localChannelId = int.tryParse(rawChannelId.toString());
    }

    if (localChannelId != null) {
      // Desloca o canal local para o byte global do controlador (apenas I/Q digitais).
      final bool isLocalIo = (localChannelId >= 10 && localChannelId <= 25) ||
          (localChannelId >= 100 && localChannelId <= 115);
      resolvedChannelId = isLocalIo
          ? (localChannelId + controllerIndex * 8)
          : localChannelId;

      final entryName = (entry['name'] ?? entry['tagId'] ?? '').toString().toUpperCase();
      final entryType = entry['type']?.toString().toLowerCase();
      final isAnalogInput = entryType == 'analog_input' ||
          entryName.startsWith('AI') ||
          entryName.startsWith('AIN') ||
          entryName.startsWith('%IW');

      if (isAnalogInput && resolvedChannelId >= 22 && resolvedChannelId <= 25) {
        // Entradas analógicas mapeadas em inputs (22 = AI0.0 / %IW0.0, 23 = AI0.1 / %IW0.1)
        final analogIdx = resolvedChannelId - 22;
        plcAddress = 'AI0.$analogIdx';
        canonicalAddress = '%IW0.$analogIdx';
      } else if (resolvedChannelId >= 10 && resolvedChannelId <= 25) {
        final rel = resolvedChannelId - 10;
        final byteIdx = rel ~/ 8;
        final bitIdx = rel % 8;
        plcAddress = 'I$byteIdx.$bitIdx';
        canonicalAddress = 'X$rel';
      } else if (resolvedChannelId >= 26 && resolvedChannelId <= 39) {
        final rel = resolvedChannelId - 26;
        final byteIdx = rel ~/ 8;
        final bitIdx = rel % 8;
        plcAddress = 'M$byteIdx.$bitIdx';
        canonicalAddress = 'M$byteIdx.$bitIdx';
      } else if (resolvedChannelId >= 40 && resolvedChannelId <= 55) {
        final tIdx = resolvedChannelId - 40;
        plcAddress = 'T$tIdx';
        canonicalAddress = 'T$tIdx';
      } else if (resolvedChannelId >= 56 && resolvedChannelId <= 71) {
        final cIdx = resolvedChannelId - 56;
        plcAddress = 'C$cIdx';
        canonicalAddress = 'C$cIdx';
      } else if (resolvedChannelId >= 100 && resolvedChannelId <= 115) {
        final rel = resolvedChannelId - 100;
        final byteIdx = rel ~/ 8;
        final bitIdx = rel % 8;
        plcAddress = 'Q$byteIdx.$bitIdx';
        canonicalAddress = 'Y$rel';
      } else if (resolvedChannelId >= 72 && resolvedChannelId <= 79) {
        final analogIdx = resolvedChannelId - 72;
        plcAddress = 'AI0.$analogIdx';
        canonicalAddress = '%IW0.$analogIdx';
      } else if (resolvedChannelId >= 80 && resolvedChannelId <= 83) {
        final analogIdx = resolvedChannelId - 80;
        plcAddress = 'AO0.$analogIdx';
        canonicalAddress = '%QW0.$analogIdx';
      }
    }

    String? matchedTagId;

    // Busca pela chave canônica resolvida (address ou ID da Tag)
    if (canonicalAddress != null) {
      for (var mapEntry in _project!.tags.entries) {
        final addr = mapEntry.value.address?.trim().toUpperCase();
        if (addr != null && (addr == canonicalAddress || addr == plcAddress)) {
          matchedTagId = mapEntry.key;
          break;
        }
      }
      if (matchedTagId == null &&
          _project!.tags.containsKey(canonicalAddress)) {
        matchedTagId = canonicalAddress;
      }
      if (matchedTagId == null &&
          plcAddress != null &&
          _project!.tags.containsKey(plcAddress)) {
        matchedTagId = plcAddress;
      }
    }

    // 2. Fallback por 'name' / 'tagId' do JSON do ESP32 (ex: "I0.4", "Q0.0")
    final name = entry['name']?.toString() ?? entry['tagId']?.toString();
    if (name != null && name.isNotEmpty) {
      final upperName = name.trim().toUpperCase();
      if (_project!.tags.containsKey(name)) {
        matchedTagId = name;
      } else if (_project!.tags.containsKey(upperName)) {
        matchedTagId = upperName;
      } else {
        for (var mapEntry in _project!.tags.entries) {
          final addr = mapEntry.value.address?.trim().toUpperCase();
          if (addr != null &&
              (addr == upperName ||
                  mapEntry.value.name.trim().toUpperCase() == upperName)) {
            matchedTagId = mapEntry.key;
            break;
          }
        }
      }
    }

    // Se encontrou a tag correspondente e ela NÃO estiver forçada, atualiza o Store
    final keysToUpdate = <String>{};
    if (matchedTagId != null) keysToUpdate.add(matchedTagId);
    if (plcAddress != null) keysToUpdate.add(plcAddress);
    if (canonicalAddress != null) keysToUpdate.add(canonicalAddress);
    if (name != null) keysToUpdate.add(name);
    if (name != null) keysToUpdate.add(name.trim().toUpperCase());

    // Se for canal analógico do sensor de solo (GPIO 34 = ch 22 / GPIO 35 = ch 23), associar AI0.0 e AI0.1
    if (resolvedChannelId == 22 ||
        resolvedChannelId == 23 ||
        resolvedChannelId == 72 ||
        resolvedChannelId == 73 ||
        name == 'AI0.0' ||
        name == 'AI0.1') {
      // Se GPIO 34 (ch 22) estiver desconectado (< 900), ignora para não sobrescrever o sensor real conectado no GPIO 35
      final gpioNum = entry['gpio'];
      if ((resolvedChannelId == 22 || gpioNum == 34) &&
          rawValue is num &&
          rawValue < 900) {
        return;
      }
      keysToUpdate.addAll(['%IW0.0', '%IW0.1', 'AI0.0', 'AI0.1']);
    } else if (resolvedChannelId == 33 || name == 'M0.7') {
      keysToUpdate.addAll(['MV_PID', 'M0.7']);
    } else if (resolvedChannelId == 30 || name == 'M0.4') {
      keysToUpdate.addAll(['SP_PID', 'M0.4']);
    } else if (resolvedChannelId == 80 || name == 'AO0.0') {
      keysToUpdate.addAll(['AO0.0', '%QW0.0']);
    } else if (resolvedChannelId == 81 || name == 'AO0.1') {
      keysToUpdate.addAll(['AO0.1', '%QW0.1']);
    } else if (resolvedChannelId != null &&
        resolvedChannelId >= 40 &&
        resolvedChannelId <= 71 &&
        plcAddress != null) {
      keysToUpdate.addAll(['$plcAddress.DN', '$plcAddress.Q']);
    }

    Tag? targetTag;
    if (matchedTagId != null && _project!.tags.containsKey(matchedTagId)) {
      targetTag = _project!.tags[matchedTagId];
    } else {
      for (final k in keysToUpdate) {
        if (_project!.tags.containsKey(k)) {
          targetTag = _project!.tags[k];
          break;
        }
      }
    }

    if (targetTag != null) {
      final addr = targetTag.address?.trim().toUpperCase();
      if (addr != null && addr.isNotEmpty) {
        keysToUpdate.add(addr);
      }
    }

    final isAnalog =
        targetTag != null &&
        (targetTag.type == TagType.real ||
            targetTag.type == TagType.int ||
            targetTag.type == TagType.dint);

    final isCapacitiveAi =
        (resolvedChannelId == 22 ||
        resolvedChannelId == 23 ||
        resolvedChannelId == 72 ||
        resolvedChannelId == 73 ||
        name == 'AI0.0' ||
        name == 'AI0.1');

    for (final key in keysToUpdate) {
      if (!_runtime!.tagStore.isForced(key)) {
        if ((isAnalog || isCapacitiveAi) && rawValue is num) {
          double scaledVal;
          final rawDouble = rawValue.toDouble();
          // Se o projeto salvo no navegador tinha AI0.0/AI0.1 legado em 0-3.3V (scaledMax == 3.3),
          // converte automaticamente o ADC bruto (3800 seco -> 0%, 1500 água -> 100%)
          if (isCapacitiveAi) {
            if (rawDouble <= 100.0) {
              scaledVal = rawDouble;
            } else if (targetTag != null &&
                targetTag.rawMin != null &&
                targetTag.rawMax != null &&
                targetTag.scaledMax != 3.3) {
              scaledVal = targetTag.scaleValue(rawDouble).clamp(0.0, 100.0);
            } else if (rawDouble >= 3800.0) {
              scaledVal = 0.0;
            } else if (rawDouble <= 1500.0) {
              scaledVal = 100.0;
            } else {
              scaledVal = ((3800.0 - rawDouble) * 100.0) / (3800.0 - 1500.0);
            }
          } else if (targetTag != null) {
            scaledVal = targetTag.scaleValue(rawDouble);
          } else {
            scaledVal = rawDouble;
          }
          _runtime!.tagStore.setReal(key, scaledVal);
          _runtime!.tagStore.setInt(key, scaledVal.round());
        } else {
          _runtime!.tagStore.setBool(key, boolVal);
        }
      }
    }
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'on' || s == 'high';
    }
    return false;
  }

  void _setStatus(TelemetryConnectionStatus newStatus) {
    if (_status != newStatus) {
      final old = _status;
      _status = newStatus;
      notifyListeners();

      if (newStatus == TelemetryConnectionStatus.online) {
        StudioEventBus.instance.emit(
          type: 'TELEMETRY_ONLINE',
          source: 'HARDWARE',
          message: 'Telemetria do Gateway $_gatewayIp ONLINE • Sincronização 250ms ativa',
          severity: EventSeverity.info,
        );
      } else if (old == TelemetryConnectionStatus.online) {
        StudioEventBus.instance.emit(
          type: 'TELEMETRY_OFFLINE',
          source: 'HARDWARE',
          message: 'Comunicação com Gateway $_gatewayIp OFFLINE • Falha no polling de E/S',
          severity: EventSeverity.warning,
        );
      }
    }
  }

  @override
  void dispose() {
    stop();
    _httpClient?.close();
    super.dispose();
  }
}

class _HostPollResult {
  final String ip;
  final int index;
  final bool isOnline;
  final Map<String, dynamic>? ioData;
  final Map<String, dynamic>? pveData;

  const _HostPollResult({
    required this.ip,
    required this.index,
    required this.isOnline,
    this.ioData,
    this.pveData,
  });
}
