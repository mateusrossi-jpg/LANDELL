import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/network_manager.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/models/tag.dart';
import '../../../ladder/models/plc_tag_contract.dart';
import '../../../ladder/models/enums.dart';
import '../../../ladder/models/tag_value.dart';
import '../../../ladder/ui/editor/telemetry_sync_service.dart';
import '../../../ladder_autosave.dart';
import '../services/gpio_service.dart';
import 'widgets/configure_pin_dialog.dart';
import 'widgets/analog_calibration_dialog.dart';
import '../../../design_system/tokens.dart';

class GpioTagsPage extends StatefulWidget {
  final NetworkManager networkManager;
  final LadderProject project;
  final VoidCallback? onProjectUpdated;
  final GpioService? gpioService;
  final VoidCallback? onOpenDrawer;
  final bool embedded;

  const GpioTagsPage({
    super.key,
    required this.networkManager,
    required this.project,
    this.onProjectUpdated,
    this.gpioService,
    this.onOpenDrawer,
    this.embedded = false,
  });

  @override
  State<GpioTagsPage> createState() => _GpioTagsPageState();
}

class _GpioTagsPageState extends State<GpioTagsPage> {
  late final GpioService _gpioService;
  Timer? _pollingTimer;
  List<GpioHardwareChannel> _hardwareChannels = [];
  List<GpioInventoryPin> _inventoryPins = [];
  final Map<String, bool> _commandInProgress = {};
  final Map<int, int> _remoteChannelStates = {};
  bool _isLoading = false;
  bool _showPinMap = false;
  String? _statusBanner;
  String _selectedNodeFilter = 'Todos';

  String get _gatewayIp {
    final ip = widget.networkManager.gatewayIp.trim();
    return (ip.isEmpty || ip == '192.168.4.1' || ip == '192.168.0.27') ? '192.168.0.229' : ip;
  }

  @override
  void initState() {
    super.initState();
    _gpioService = widget.gpioService ?? GpioService();
    _hardwareChannels = GpioService.defaultGatewayChannels;
    _inventoryPins = GpioService.defaultInventoryPins;
    widget.networkManager.addListener(_onNetworkManagerChanged);
    TelemetrySyncService.instance.addListener(_onTelemetryUpdated);
    _refreshHardware();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshHardware());
  }

  void _onTelemetryUpdated() {
    if (!mounted) return;
    final map = TelemetrySyncService.instance.lastIoMap;
    if (map != null) {
      _applyLocalTelemetry(map);
    }
  }

  void _applyLocalTelemetry(Map<String, dynamic> data) {
    final inputs = data['inputs'] as List<dynamic>? ?? [];
    for (var item in inputs) {
      if (item is Map) {
        final chId = item['channel_id'] is int ? item['channel_id'] as int : int.tryParse(item['channel_id'].toString());
        final state = item['state'] is int ? item['state'] as int : int.tryParse(item['state'].toString());
        if (chId != null && state != null) {
          _remoteChannelStates[chId] = state;
        }
      }
    }
    final outputs = data['outputs'] as List<dynamic>? ?? [];
    for (var item in outputs) {
      if (item is Map) {
        final chId = item['channel_id'] is int ? item['channel_id'] as int : int.tryParse(item['channel_id'].toString());
        final state = (item['desired'] ?? item['state'] ?? item['value']) as num?;
        if (chId != null && state != null) {
          _remoteChannelStates[chId] = state.toInt();
        }
      }
    }
    final internals = data['internals'] as List<dynamic>? ?? [];
    for (var item in internals) {
      if (item is Map) {
        final chId = item['channel_id'] is int ? item['channel_id'] as int : int.tryParse(item['channel_id'].toString());
        final state = (item['state'] ?? item['value']) as num?;
        if (chId != null && state != null) {
          _remoteChannelStates[chId] = state.toInt();
        }
      }
    }
    setState(() {});
  }

  void _onNetworkManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.networkManager.removeListener(_onNetworkManagerChanged);
    TelemetrySyncService.instance.removeListener(_onTelemetryUpdated);
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshHardware() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final results = await Future.wait([
        _gpioService.fetchHardwareChannels(_gatewayIp, nodes: widget.networkManager.nodes),
        _gpioService.fetchGpioInventory(_gatewayIp),
      ]);
      final channels = results[0] as List<GpioHardwareChannel>;
      final inventory = results[1] as List<GpioInventoryPin>;
      if (!mounted) return;
      setState(() {
        if (channels.isNotEmpty) {
          _hardwareChannels = channels;
          for (final ch in channels) {
            _remoteChannelStates[ch.channelId] = ch.state;
          }
        } else if (_hardwareChannels.isEmpty) {
          _hardwareChannels = GpioService.defaultGatewayChannels;
        }
        if (inventory.isNotEmpty) {
          _inventoryPins = inventory;
        } else if (_inventoryPins.isEmpty) {
          _inventoryPins = GpioService.defaultInventoryPins;
        }

        final isOnline = widget.networkManager.controller.isOnline;
        final hasOutdatedGateway = widget.networkManager.nodes.any((n) => n.role.toLowerCase().contains('field') && n.controllerIndex < 0);
        if (hasOutdatedGateway) {
          _statusBanner = 'Firmware do Gateway desatualizado — controller_index ausente, regrave o firmware';
        } else if (!isOnline) {
          _statusBanner = 'Controlador desconectado ($_gatewayIp) — Imagem estável de E/S mantida.';
        } else {
          _statusBanner = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_hardwareChannels.isEmpty) {
            _hardwareChannels = GpioService.defaultGatewayChannels;
          }
          _statusBanner = 'Comunicação instável ($e) — Imagem de E/S mantida.';
        });
      }
    } finally {
      _isLoading = false;
    }
  }


  List<GpioHardwareChannel> _buildFieldNodeChannels({int? targetCtrlIdx}) {
    final List<GpioHardwareChannel> result = [];
    final fieldNodes = widget.networkManager.nodes.where((n) =>
      n.controllerIndex > 0 &&
      n.status != NodeStatus.pending &&
      (targetCtrlIdx == null || n.controllerIndex == targetCtrlIdx)
    ).toList();

    for (final node in fieldNodes) {
      final ctrlIdx = node.controllerIndex;
      final parsedNodeId = int.tryParse(node.id.replaceAll('ENDAP-', ''));

      PlcTagContract.hardwareGpios.forEach((canonicalKey, gpioPin) {
        if (canonicalKey.startsWith('I2C')) return;

        final String type;
        final bool isOutput;
        final String prefix;
        if (canonicalKey.startsWith('AI')) {
          type = 'analog_input';
          isOutput = false;
          prefix = 'AI';
        } else if (canonicalKey.startsWith('AO')) {
          type = 'analog_output';
          isOutput = true;
          prefix = 'AO';
        } else if (canonicalKey.startsWith('I')) {
          type = 'digital_input';
          isOutput = false;
          prefix = 'I';
        } else if (canonicalKey.startsWith('Q')) {
          type = 'digital_output';
          isOutput = true;
          prefix = 'Q';
        } else {
          return;
        }

        final channelSubIdx = int.tryParse(canonicalKey.split('.').last) ?? 0;
        final chName = '$prefix$ctrlIdx.$channelSubIdx';

        int baseChId = 10;
        if (prefix == 'Q') baseChId = 100;
        if (prefix == 'AI') baseChId = 72;
        if (prefix == 'AO') baseChId = 80;
        final chId = baseChId + (ctrlIdx * 8) + channelSubIdx;

        result.add(GpioHardwareChannel(
          channelId: chId,
          name: chName,
          type: type,
          gpio: gpioPin,
          state: _remoteChannelStates[chId] ?? 0,
          isOutput: isOutput,
          controllerIndex: ctrlIdx,
          nodeId: parsedNodeId,
          implemented: true,
          clusterState: 'online',
        ));
      });
    }
    return result;
  }

  List<GpioHardwareChannel> get _filteredHardwareChannels {
    List<GpioHardwareChannel> result = [];
    final activeIndexes = widget.networkManager.activeFieldNodeIndexes;
    final hasAdopted = activeIndexes.isNotEmpty;

    if (_selectedNodeFilter == 'Gateway') {
      result = _hardwareChannels.where((ch) => ch.controllerIndex == 0).toList();
    } else if (_selectedNodeFilter == 'Field Node' || _selectedNodeFilter.startsWith('node_')) {
      final targetIdx = _selectedNodeFilter.startsWith('node_')
          ? int.tryParse(_selectedNodeFilter.replaceAll('node_', ''))
          : null;
      if (targetIdx != null) {
        result = _hardwareChannels.where((ch) => ch.controllerIndex == targetIdx).toList();
      } else {
        result = _hardwareChannels.where((ch) => ch.controllerIndex > 0).toList();
      }
      if (result.isEmpty) {
        result.addAll(_buildFieldNodeChannels(targetCtrlIdx: targetIdx));
      }
    } else {
      result = _hardwareChannels.toList();
      final hasRemote = result.any((ch) => ch.controllerIndex > 0);
      if (!hasRemote && hasAdopted) {
        result.addAll(_buildFieldNodeChannels());
      }
    }

    // Garante a presença dos canais analógicos de saída (AO / DAC) do rack local
    // caso o firmware não os tenha incluído no payload dinâmico de /api/io/map
    if (_hardwareChannels.isNotEmpty && _selectedNodeFilter != 'Field Node') {
      final hasAo00 = result.any((ch) => ch.controllerIndex == 0 && (ch.name == 'AO0.0' || ch.channelId == 80));
      if (!hasAo00) {
        result.add(const GpioHardwareChannel(
          channelId: 80,
          name: 'AO0.0',
          type: 'analog_output',
          gpio: 25,
          state: 0,
          isOutput: true,
          controllerIndex: 0,
          implemented: true,
          clusterState: 'online',
        ));
      }

      final hasAo01 = result.any((ch) => ch.controllerIndex == 0 && (ch.name == 'AO0.1' || ch.channelId == 81));
      if (!hasAo01) {
        result.add(const GpioHardwareChannel(
          channelId: 81,
          name: 'AO0.1',
          type: 'analog_output',
          gpio: 26,
          state: 0,
          isOutput: true,
          controllerIndex: 0,
          implemented: true,
          clusterState: 'online',
        ));
      }
    }

    return result;
  }

  Tag? _findTagForChannel(GpioHardwareChannel ch) {
    final tags = widget.project.tags.values;
    final nodeIdx = ch.controllerIndex;
    String? canonicalXY;
    String? canonicalPLC;
    String? canonicalIEC;
    if (ch.isAnalog) {
      canonicalIEC = ch.name;
      canonicalPLC = ch.name;
    } else if (ch.channelId >= 10 && ch.channelId <= 41) {
      final index = ch.channelId - 10;
      canonicalXY = 'X$index';
      canonicalPLC = 'I$nodeIdx.$index';
      canonicalIEC = 'I$nodeIdx.$index';
    } else if (ch.channelId >= 100 && ch.channelId <= 131) {
      final index = ch.channelId - 100;
      canonicalXY = 'Y$index';
      canonicalPLC = 'Q$nodeIdx.$index';
      canonicalIEC = 'Q$nodeIdx.$index';
    } else if (ch.channelId >= 72 && ch.channelId <= 79) {
      final index = ch.channelId - 72;
      canonicalIEC = 'AI$nodeIdx.$index';
    } else if (ch.channelId >= 80 && ch.channelId <= 87) {
      final index = ch.channelId - 80;
      canonicalIEC = 'AO$nodeIdx.$index';
    } else if (ch.channelId >= 22 && ch.channelId <= 25) {
      final index = ch.channelId - 22;
      canonicalIEC = 'AI$nodeIdx.$index';
    }

    String norm(String? s) {
      if (s == null) return '';
      var clean = s.trim().toUpperCase().replaceAll('%', '');
      if (clean.startsWith('IX')) clean = 'I${clean.substring(2)}';
      if (clean.startsWith('QX')) clean = 'Q${clean.substring(2)}';
      if (clean.startsWith('IW')) clean = 'AI${clean.substring(2)}';
      if (clean.startsWith('QW')) clean = 'AO${clean.substring(2)}';
      return clean;
    }

    final normIEC = norm(canonicalIEC);
    final normPLC = norm(canonicalPLC);
    final normXY = norm(canonicalXY);

    // 1. Busca por endereço lógico do canal com prioridade para tags customizadas
    Tag? fallbackMatch;
    for (final t in tags) {
      final addr = norm(t.address);
      final id = norm(t.id);
      final matches = (normIEC.isNotEmpty && (addr == normIEC || id == normIEC)) ||
                      (normPLC.isNotEmpty && (addr == normPLC || id == normPLC)) ||
                      (normXY.isNotEmpty && (addr == normXY || id == normXY));
      if (matches) {
        // Tag com nome customizado de processo tem prioridade sobre placeholder genérico
        final isGeneric = t.name.trim().toUpperCase() == normIEC ||
                          t.name.trim().toUpperCase() == normPLC ||
                          t.name.trim().toUpperCase() == normXY;
        if (!isGeneric) {
          return t;
        }
        fallbackMatch ??= t;
      }
    }
    if (fallbackMatch != null) return fallbackMatch;

    // 2. Busca por GPIO exato no campo address (apenas para o nó local Gateway)
    if (nodeIdx == 0 && ch.gpio != null) {
      final gpioStr = 'GPIO${ch.gpio}';
      for (final t in tags) {
        final cleanAddr = t.address?.replaceAll(' ', '').trim().toUpperCase();
        if (cleanAddr == gpioStr) return t;
      }
    }

    // 3. Busca por nome padrão ou ID
    for (final t in tags) {
      if (t.name.trim().toUpperCase() == ch.name.trim().toUpperCase() ||
          t.id.trim().toUpperCase() == ch.name.trim().toUpperCase()) {
        return t;
      }
    }

    return null;
  }

  String _resolveGpioMapping(String rawAddr) {
    var clean = rawAddr.trim().toUpperCase();
    if (clean.startsWith('%')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('IX')) {
      clean = 'I${clean.substring(2)}';
    } else if (clean.startsWith('QX')) {
      clean = 'Q${clean.substring(2)}';
    } else if (clean.startsWith('IW')) {
      clean = 'AI${clean.substring(2)}';
    } else if (clean.startsWith('QW')) {
      clean = 'AO${clean.substring(2)}';
    }

    // Normaliza qualquer rack I1.x, I2.x... para o padrão de sub-canal I0.x para resolução do pino GPIO físico
    final normalizedClean = clean.replaceAll(RegExp(r'^(I|Q|AI|AO)\d+\.'), r'$10.');
    final mappedGpio = PlcTagContract.hardwareGpios[normalizedClean];
    if (mappedGpio != null) {
      return 'GPIO $mappedGpio';
    }

    // Suporte a canais nomeados do firmware (IN1..IN6, OUT1..OUT8, AIN1..AIN4)
    final matchIn = RegExp(r'^IN(\d+)$').firstMatch(clean);
    if (matchIn != null) {
      final idx = (int.tryParse(matchIn.group(1)!) ?? 1) - 1;
      const gpios = [16, 17, 18, 19, 27, 13];
      if (idx >= 0 && idx < gpios.length) return 'GPIO ${gpios[idx]}';
    }

    final matchOut = RegExp(r'^(OUT|Q)(\d+)$').firstMatch(clean);
    if (matchOut != null) {
      final idx = (int.tryParse(matchOut.group(2)!) ?? 1) - 1;
      const gpios = [4, 21, 22, 33, 23, 32, 14, 2];
      if (idx >= 0 && idx < gpios.length) return 'GPIO ${gpios[idx]}';
    }

    final matchAin = RegExp(r'^(AIN|AI)(\d+)$').firstMatch(clean);
    if (matchAin != null) {
      final idx = (int.tryParse(matchAin.group(2)!) ?? 1) - 1;
      const gpios = ['34 (ADC1_CH6)', '35 (ADC1_CH7)', '36 (ADC1_CH0)', '39 (ADC1_CH3)'];
      if (idx >= 0 && idx < gpios.length) return 'GPIO ${gpios[idx]}';
    }

    if (clean.startsWith('M') || clean.startsWith('T') || clean.startsWith('C')) {
      return 'MEMÓRIA';
    }
    return 'VIRTUAL';
  }

  Future<void> _toggleOutput(GpioHardwareChannel ch) async {
    if (!widget.networkManager.controller.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFF991B1B),
        content: Text('Hardware offline. Conecte ao controlador para testar saída real.'),
      ));
      return;
    }

    final currentState = _remoteChannelStates[ch.channelId] ?? ch.state;
    final nextValue = currentState > 0 ? 0 : 1;
    final key = ch.uniqueKey;
    setState(() {
      _commandInProgress[key] = true;
    });

    final targetNodeId = ch.nodeId?.toString();
    final success = await _gpioService.setOutput(_gatewayIp, ch.channelId, nextValue, targetNodeId: targetNodeId);
    if (!mounted) return;

    setState(() {
      _commandInProgress[key] = false;
      if (success) {
        _remoteChannelStates[ch.channelId] = nextValue;
      }
    });

    if (success) {
      await _refreshHardware();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFF991B1B),
        content: Text('Falha ao enviar comando para a saída.'),
      ));
    }
  }

  Future<void> _openTagDialog({Tag? existingTag, GpioHardwareChannel? channel}) async {
    final isEditing = existingTag != null;
    String defaultAddress = '';
    TagType defaultType = TagType.bool;

    if (channel != null) {
      defaultAddress = channel.name;
      defaultType = channel.isAnalog ? TagType.real : TagType.bool;
    }
    final nameCtrl = TextEditingController(text: existingTag?.name ?? (defaultAddress.isNotEmpty ? defaultAddress : (channel?.name ?? '')));
    final idCtrl = TextEditingController(text: existingTag?.id ?? (defaultAddress.isNotEmpty ? defaultAddress : (channel?.name ?? '')));
    final addrCtrl = TextEditingController(
      text: existingTag?.address ?? defaultAddress,
    );
    final descCtrl = TextEditingController(text: existingTag?.description ?? '');
    TagType selectedType = existingTag?.type ?? defaultType;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTokens.line, width: 1.0),
          ),
          title: Text(
            isEditing ? 'EDITAR TAG IEC' : 'ASSOCIAR NOVA TAG',
            style: TextStyle(color: AppTokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (channel != null && channel.gpio != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTokens.panel2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTokens.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_input_composite, color: Color(0xFF4FD1C5), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pino Físico: GPIO ${channel.gpio} (${channel.name})',
                                style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Deseja mudar para I2C AHT10, Analógico ou Saída?',
                                style: TextStyle(color: Color(0xFF8C98A8), fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF4FD1C5).withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx, false);
                            final targetPin = _inventoryPins.firstWhere(
                              (p) => p.gpio == channel.gpio,
                              orElse: () => GpioInventoryPin(
                                gpio: channel.gpio!,
                                inputCapable: true,
                                outputCapable: true,
                                state: 'AVAILABLE',
                              ),
                            );
                            ConfigurePinDialog.show(
                              context,
                              pin: targetPin,
                              project: widget.project,
                              gatewayIp: _gatewayIp,
                              gpioService: _gpioService,
                              onConfigured: () {
                                _refreshHardware();
                                widget.onProjectUpdated?.call();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                          child: const Text('CONFIGURAR PINO', style: TextStyle(color: Color(0xFF4FD1C5), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: idCtrl,
                  enabled: !isEditing,
                  style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'ID ÚNICO DA TAG',
                    labelStyle: TextStyle(color: AppTokens.muted, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.focus)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppTokens.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'NOME DA VARIÁVEL (IEC)',
                    labelStyle: TextStyle(color: AppTokens.muted, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.focus)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  style: TextStyle(color: AppTokens.textPrimary, fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'ENDEREÇO / IEC (ex: I0.0, Q0.0, AI0.0)',
                    labelStyle: TextStyle(color: AppTokens.muted, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.focus)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<TagType>(
                  initialValue: selectedType,
                  dropdownColor: AppTokens.panel2,
                  style: TextStyle(color: AppTokens.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'TIPO DE DADO IEC',
                    labelStyle: TextStyle(color: AppTokens.muted, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.focus)),
                  ),
                  items: TagType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: AppTokens.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'FUNÇÃO / DESCRIÇÃO (ex: Aquecedor, Sensor)',
                    labelStyle: TextStyle(color: AppTokens.muted, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.focus)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('CANCELAR', style: TextStyle(color: AppTokens.muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.focus,
                foregroundColor: AppTokens.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final rawAddr = addrCtrl.text.trim();
                final canonicalAddr = PlcTagContract.normalizeAddress(rawAddr);
                if (canonicalAddr == null && rawAddr.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Endereço PLC inválido. Use I0.0..I1.7, Q0.0..Q1.7, M0.0..M1.5, T0..T15 ou C0..C15')),
                  );
                  return;
                }
                final id = isEditing ? existingTag.id : (canonicalAddr ?? idCtrl.text.trim().toUpperCase());
                final name = nameCtrl.text.trim();
                if (id.isEmpty || name.isEmpty) return;

                final resolvedType = canonicalAddr != null
                    ? (PlcTagContract.getTagTypeForAddress(canonicalAddr) ?? selectedType)
                    : selectedType;

                TagValue? defaultVal;
                switch (resolvedType) {
                  case TagType.bool:
                    defaultVal = TagValue.boolean(false);
                    break;
                  case TagType.int:
                  case TagType.dint:
                  case TagType.timer:
                  case TagType.counter:
                    defaultVal = TagValue.integer(0);
                    break;
                  case TagType.real:
                    defaultVal = TagValue.real(0.0);
                    break;
                  case TagType.string:
                    defaultVal = TagValue.string('');
                    break;
                }

                if (isEditing) {
                  existingTag.name = name;
                  widget.project.tags[existingTag.id] = Tag(
                    id: existingTag.id,
                    name: name,
                    type: resolvedType,
                    address: canonicalAddr ?? (rawAddr.isNotEmpty ? rawAddr : null),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    initialValue: existingTag.initialValue ?? defaultVal,
                  );
                } else {
                  widget.project.tags[id] = Tag(
                    id: id,
                    name: name,
                    type: selectedType,
                    address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    initialValue: defaultVal,
                  );
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await saveCurrentLadder(widget.project);
      widget.onProjectUpdated?.call();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.networkManager.controller.isOnline;

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: 42,
              backgroundColor: AppColors.panel,
              elevation: 0,
              automaticallyImplyLeading: false,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1.0),
                child: Divider(
                  height: 1.0,
                  thickness: 1.0,
                  color: AppColors.line,
                ),
              ),
              leading: widget.onOpenDrawer != null
                  ? const Center(
                      child: Icon(Icons.memory_outlined, color: AppColors.focus, size: 18),
                    )
                  : Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: AppColors.text, size: 20),
                        tooltip: 'Menu',
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAPEAMENTO GPIO & TAGS',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: isDesktop ? 13 : 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Text(
                    'Relação física: GPIO → TAG IEC → Função',
                    style: TextStyle(fontSize: 10, color: AppColors.textDim),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.refresh, color: Color(0xFF4FD1C5), size: 18),
                  tooltip: 'Atualizar Hardware',
                  onPressed: _refreshHardware,
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add, color: Color(0xFF4FD1C5), size: 20),
                  tooltip: 'Nova Tag',
                  onPressed: () => _openTagDialog(),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: Column(
        children: [
          if (widget.embedded) _buildEmbeddedToolbar(isDesktop),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshHardware,
              color: AppTokens.focus,
              backgroundColor: AppTokens.panel,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: [
                  if (_statusBanner != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTokens.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTokens.error.withValues(alpha: 0.6), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTokens.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusBanner!,
                              style: TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  _buildNodeFilterBar(),

                  // Mapa de Pinos (ajuda visual — todos os pinos utilizáveis)
                  if (_inventoryPins.isNotEmpty) ...[
                    _buildPinMapSection(),
                    const SizedBox(height: 8),
                  ],

                  if (_selectedNodeFilter == 'Gateway' && widget.networkManager.isExclusiveGateway) ...[
                    _buildDedicatedGatewayBanner(),
                  ],

                  // Lista unificada de GPIOs físicos ou Tags do projeto categorizadas
                  if (_selectedNodeFilter == 'Field Node' && !widget.networkManager.hasAdoptedFieldNode) ...[
                    _buildEmptyFieldNodeState(),
                  ] else if (_selectedNodeFilter == 'Memória / Tags Internas') ...[
                    _buildFallbackLocalTagsList(),
                  ] else ...[
                    ..._buildCategorizedHardwareSections(online),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedToolbar(bool isDesktop) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1.0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_outlined, color: AppColors.focus, size: 16),
          const SizedBox(width: 8),
          Text(
            'MAPEAMENTO GPIO & TAGS',
            style: TextStyle(
              color: AppColors.text,
              fontSize: isDesktop ? 12 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          IconButton(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.refresh, color: AppColors.focus, size: 17),
            tooltip: 'Atualizar Hardware',
            onPressed: _refreshHardware,
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, color: AppColors.focus, size: 19),
            tooltip: 'Nova Tag',
            onPressed: () => _openTagDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildDedicatedGatewayBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF451A03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706), width: 1.0),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock, color: Color(0xFFFBBF24), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'GATEWAY DEDICADO (PERFIL 4): Canais locais operam sob telemetria pura e não executam regras de Ladder local. '
              'Para automação distribuída, utilize os canais dos Nós de Campo (I10..I14, I20..I24, I30..I34...).',
              style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeFilterBar() {
    final isExclusive = widget.networkManager.isExclusiveGateway;
    final fieldNodes = widget.networkManager.nodes.where((n) => n.controllerIndex > 0).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTokens.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTokens.line, width: 1.0),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterSegment('Todos', Icons.devices),
            const SizedBox(width: 4),
            _buildFilterSegment(
              isExclusive ? 'Gateway [DEDICADO]' : 'Gateway',
              isExclusive ? Icons.lock_outline : Icons.router,
              filterKey: 'Gateway',
            ),
            const SizedBox(width: 4),
            if (fieldNodes.isEmpty)
              _buildFilterSegment('Field Node', Icons.developer_board, filterKey: 'Field Node')
            else
              ...fieldNodes.map((n) {
                final label = 'Nó ${n.controllerIndex}';
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildFilterSegment(label, Icons.memory, filterKey: 'node_${n.controllerIndex}'),
                );
              }),
            const SizedBox(width: 4),
            _buildFilterSegment('Memória (M)', Icons.data_object, filterKey: 'Memória / Tags Internas'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSegment(String label, IconData icon, {String? filterKey}) {
    final key = filterKey ?? label;
    final isSelected = _selectedNodeFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedNodeFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTokens.focus : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTokens.bg : AppTokens.muted),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? AppTokens.bg : AppTokens.muted,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: Color(0xFF4FD1C5), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(color: Color(0xFF4FD1C5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0x4D4FD1C5), height: 1)),
        ],
      ),
    );
  }

  Widget _buildPinMapSection() {
    final usedGpios = {for (final ch in _hardwareChannels) if (ch.gpio != null) ch.gpio!};

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4FD1C5).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showPinMap = !_showPinMap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.developer_board, color: Color(0xFF4FD1C5), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAPA DE PINOS — PINOS UTILIZÁVEIS',
                          style: TextStyle(
                            color: Color(0xFFE7EBF0),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cada pino físico do ESP32, sua função e se está em uso',
                          style: TextStyle(color: Color(0xFF8C98A8), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      const _PinLegendDot(color: Color(0xFF3FBF5A), label: 'LIVRE'),
                      const _PinLegendDot(color: Color(0xFF4FD1C5), label: 'IN'),
                      const _PinLegendDot(color: Color(0xFFFF9500), label: 'OUT'),
                      const _PinLegendDot(color: Color(0xFFF43F5E), label: 'RES'),
                      Icon(
                        _showPinMap ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF8C98A8),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showPinMap) ...[
            Divider(height: 1, color: AppTokens.line),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _inventoryPins.map((pin) => _buildPinChip(pin, isUsed: usedGpios.contains(pin.gpio))).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinChip(GpioInventoryPin pin, {required bool isUsed}) {
    final Color bgColor;
    final Color borderColor;
    final String stateText;

    if (pin.isInUse) {
      if (pin.state == 'IN_USE_OUTPUT') {
        bgColor = const Color(0x33FF9500);
        borderColor = const Color(0xFFFF9500);
        stateText = pin.plcChannel ?? 'SAÍDA';
      } else {
        bgColor = const Color(0x3338BDF8);
        borderColor = const Color(0xFF4FD1C5);
        stateText = pin.plcChannel ?? 'ENTRADA';
      }
    } else if (pin.isReserved) {
      bgColor = const Color(0x33F43F5E);
      borderColor = const Color(0xFFF43F5E);
      stateText = 'RESERVADO';
    } else {
      bgColor = isUsed ? const Color(0x3338BDF8) : const Color(0x2410B981);
      borderColor = isUsed ? const Color(0xFF4FD1C5) : const Color(0xFF3FBF5A);
      final caps = pin.capabilityLabels;
      stateText = caps.isNotEmpty ? caps.join('/') : 'LIVRE';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ConfigurePinDialog.show(
            context,
            pin: pin,
            project: widget.project,
            gatewayIp: _gatewayIp,
            gpioService: _gpioService,
            onConfigured: () {
              _refreshHardware();
              widget.onProjectUpdated?.call();
              if (mounted) setState(() {});
            },
          );
        },
        child: Container(
          width: 118,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GPIO ${pin.gpio}',
            style: const TextStyle(
              color: Color(0xFFE7EBF0),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 3,
            runSpacing: 2,
            children: [
              if (pin.analogCapable)
                const _CapBadge(label: 'ANA', color: Color(0xFF8B5CF6)),
              if (pin.inputCapable)
                const _CapBadge(label: 'IN', color: Color(0xFF4FD1C5)),
              if (pin.outputCapable)
                const _CapBadge(label: 'OUT', color: Color(0xFFFF9500)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            stateText,
            style: TextStyle(
              color: borderColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (pin.isReserved && pin.reservedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                pin.reservedBy!,
                style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 8.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  List<Widget> _buildCategorizedHardwareSections(bool online) {
    final List<Widget> widgets = [];

    final digitalInputs = _filteredHardwareChannels.where((ch) => !ch.isOutput && !ch.isAnalog).toList();
    final analogInputs = _filteredHardwareChannels.where((ch) => !ch.isOutput && ch.isAnalog).toList();
    final digitalOutputs = _filteredHardwareChannels.where((ch) => ch.isOutput && !ch.isAnalog).toList();
    final analogOutputs = _filteredHardwareChannels.where((ch) => ch.isOutput && ch.isAnalog).toList();

    final hasRemoteNodes = _filteredHardwareChannels.any((ch) => ch.controllerIndex > 0);
    final nodeLabel = _selectedNodeFilter == 'Gateway'
        ? 'Gateway (Rack 0)'
        : (_selectedNodeFilter == 'Field Node'
            ? () {
                final remoteCh = _filteredHardwareChannels.firstWhere((ch) => ch.controllerIndex > 0, orElse: () => _filteredHardwareChannels.first);
                final idx = remoteCh.controllerIndex > 0 ? remoteCh.controllerIndex : 1;
                return 'Field Node (Rack $idx)';
              }()
            : (hasRemoteNodes ? 'Cluster Detectado' : 'Controlador Local (ESP32)'));

    if (digitalInputs.isNotEmpty) {
      widgets.add(_buildSectionHeader('Entradas Digitais — $nodeLabel'));
      widgets.addAll(_buildHardwareMappingListFor(digitalInputs, online));
    }

    if (analogInputs.isNotEmpty) {
      widgets.add(_buildSectionHeader('Entradas Analógicas — $nodeLabel'));
      widgets.addAll(_buildHardwareMappingListFor(analogInputs, online));
    }

    if (digitalOutputs.isNotEmpty) {
      widgets.add(_buildSectionHeader('Saídas Digitais — $nodeLabel'));
      widgets.addAll(_buildHardwareMappingListFor(digitalOutputs, online));
    }

    if (analogOutputs.isNotEmpty) {
      widgets.add(_buildSectionHeader('Saídas Analógicas — $nodeLabel'));
      widgets.addAll(_buildHardwareMappingListFor(analogOutputs, online));
    }

    return widgets;
  }

  List<Widget> _buildHardwareMappingListFor(List<GpioHardwareChannel> channels, bool online) {
    return channels.map((ch) {
      final tag = _findTagForChannel(ch);
      final isSending = _commandInProgress[ch.uniqueKey] == true;
      final nodeIdx = ch.controllerIndex;

      final String iecCode = ch.name;

      final nodeOrigin = nodeIdx == 0
          ? 'Gateway · Local'
          : (ch.nodeId != null ? 'Field Node · ${ch.nodeId}' : 'Field Node · .229');

      final isFieldNode = nodeIdx > 0;
      final effectiveState = _remoteChannelStates[ch.channelId] ?? ch.state;
      final cardBorderColor = isFieldNode
          ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
          : (effectiveState > 0 ? AppTokens.focus.withValues(alpha: 0.4) : AppTokens.line);
      final cardBgColor = isFieldNode ? const Color(0xFF1E1A2E) : AppTokens.panel;

      return Container(
        key: Key(ch.uniqueKey),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cardBorderColor,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Indicador de Pino / Tipo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isFieldNode ? const Color(0xFF262040) : AppTokens.panel2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFieldNode
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                      : (ch.isOutput ? const Color(0xFFFF9500).withValues(alpha: 0.4) : AppTokens.focus.withValues(alpha: 0.4)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ch.nodeId != null ? 'Nó ${ch.nodeId} · ${ch.name}' : (ch.gpio != null ? 'GPIO ${ch.gpio}' : ch.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ch.isAnalog
                        ? 'ANALÓGICO'
                        : (ch.isOutput ? 'SAÍDA' : 'ENTRADA'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ch.isAnalog
                          ? const Color(0xFF8B5CF6)
                          : (ch.isOutput ? const Color(0xFFFF9500) : const Color(0xFF4FD1C5)),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Tag IEC e Função
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Text(
                        tag != null ? tag.name : iecCode,
                        style: const TextStyle(
                          color: Color(0xFFE7EBF0),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isFieldNode
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                              : const Color(0xFF4FD1C5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          isFieldNode ? 'RACK $nodeIdx (FIELD)' : 'RACK 0 (GATEWAY)',
                          style: TextStyle(
                            color: isFieldNode ? const Color(0xFFA78BFA) : const Color(0xFF4FD1C5),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FD1C5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tag?.type.name.toUpperCase() ?? (ch.isAnalog ? 'REAL' : 'BOOL'),
                          style: const TextStyle(color: Color(0xFF4FD1C5), fontSize: 9, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tag?.name != null && tag!.name != iecCode
                        ? '$nodeOrigin · ${tag.name}${tag.description?.isNotEmpty == true ? " (${tag.description})" : ""} (GPIO ${ch.gpio ?? "?"})'
                        : '$nodeOrigin · ${ch.isAnalog ? (ch.isOutput ? "Saída Analógica DAC" : "Entrada Analógica ADC") : (ch.isOutput ? "Saída Digital" : "Entrada Digital")} (GPIO ${ch.gpio ?? "?"})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFieldNode ? const Color(0xFFA78BFA) : const Color(0xFF8C98A8),
                      fontSize: 10.5,
                      fontWeight: isFieldNode ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Botão de teste real ou badge de estado
            if (ch.isOutput) ...[
              if (ch.isAnalog) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${ch.state}% (DAC)',
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: effectiveState > 0 ? const Color(0xFFB91C1C) : const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: isSending || !online || (ch.nodeId != null && ch.clusterState != 'online') ? null : () => _toggleOutput(ch),
                    child: isSending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            effectiveState > 0 ? 'DESLIGAR' : 'LIGAR',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: effectiveState > 0 ? AppTokens.run.withValues(alpha: 0.15) : AppTokens.panel2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: effectiveState > 0 ? AppTokens.run.withValues(alpha: 0.4) : AppTokens.line),
                ),
                child: Text(
                  ch.isAnalog ? '${effectiveState} mV' : (effectiveState > 0 ? 'ON' : 'OFF'),
                  style: TextStyle(
                    color: effectiveState > 0 ? AppTokens.run : AppTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            if (ch.isAnalog || tag?.type == TagType.real || (tag?.address?.startsWith('%IW') ?? false)) ...[
              IconButton(
                icon: const Icon(Icons.tune, color: Color(0xFFF59E0B), size: 18),
                tooltip: 'Calibração Universal de Processo',
                onPressed: () {
                  final targetTag = tag ?? Tag(
                    id: ch.name,
                    name: ch.name,
                    type: TagType.real,
                    address: ch.isAnalog ? '%IW0.0' : null,
                  );
                  showDialog(
                    context: context,
                    builder: (ctx) => AnalogCalibrationDialog(
                      tag: targetTag,
                      liveValue: ch.state.toDouble(),
                      gatewayUrl: 'http://$_gatewayIp',
                      onSaveProject: (newOffset, newGain) async {
                        widget.project.tags[targetTag.id] = Tag(
                          id: targetTag.id,
                          name: targetTag.name,
                          type: targetTag.type,
                          address: targetTag.address,
                          unit: targetTag.unit,
                          description: targetTag.description,
                          rawMin: targetTag.rawMin,
                          rawMax: targetTag.rawMax,
                          scaledMin: targetTag.scaledMin,
                          scaledMax: targetTag.scaledMax,
                          controllerId: targetTag.controllerId,
                          calOffset: newOffset,
                          calGain: newGain,
                        );
                        await saveCurrentLadder(widget.project);
                        widget.onProjectUpdated?.call();
                        if (mounted) setState(() {});
                      },
                    ),
                  );
                },
              ),
            ],

            // Botão de Associar/Editar Tag
            IconButton(
              icon: Icon(tag != null ? Icons.edit_outlined : Icons.link, color: const Color(0xFF4FD1C5), size: 18),
              tooltip: tag != null ? 'Editar Tag' : 'Associar Tag',
              onPressed: () => _openTagDialog(existingTag: tag, channel: ch),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildEmptyFieldNodeState() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTokens.line, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.developer_board_off, color: AppTokens.muted, size: 40),
          const SizedBox(height: 12),
          Text(
            'Nenhum Field Node adotado — adote um dispositivo na tela Rede & Topologia',
            style: TextStyle(color: AppTokens.muted, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLocalTagsList() {
    final activeIndexes = widget.networkManager.activeFieldNodeIndexes;
    String normTagAddr(Tag t) {
      var a = (t.address ?? t.id).trim().toUpperCase();
      if (a.startsWith('%')) a = a.substring(1);
      return a;
    }

    var tags = widget.project.tags.values.where((t) {
      final addr = normTagAddr(t);
      final match = RegExp(r'^(I|Q|AI|AO|IW|QW|IN|OUT|AIN|AOUT)(\d+)').firstMatch(addr);
      if (match != null) {
        final idx = int.tryParse(match.group(2)!);
        if (idx != null && idx > 0) {
          return activeIndexes.contains(idx);
        }
      }
      return true;
    }).toList();

    if (_selectedNodeFilter == 'Gateway') {
      tags = tags.where((t) {
        final addr = normTagAddr(t);
        final match = RegExp(r'^(I|Q|AI|AO|IW|QW|IN|OUT|AIN|AOUT)(\d+)').firstMatch(addr);
        if (match != null) {
          final idx = int.tryParse(match.group(2)!);
          return idx == 0;
        }
        return true;
      }).toList();
    } else if (_selectedNodeFilter == 'Field Node') {
      tags = tags.where((t) {
        final addr = normTagAddr(t);
        final match = RegExp(r'^(I|Q|AI|AO|IW|QW|IN|OUT|AIN|AOUT)(\d+)').firstMatch(addr);
        if (match != null) {
          final idx = int.tryParse(match.group(2)!);
          return idx != null && idx > 0 && activeIndexes.contains(idx);
        }
        return false;
      }).toList();
    }

    if (tags.isEmpty) {
      if (_selectedNodeFilter == 'Field Node') {
        return _buildEmptyFieldNodeState();
      }
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.developer_board_off, color: AppTokens.muted, size: 36),
            const SizedBox(height: 10),
            Text(
              'Nenhum canal físico detectado e nenhuma Tag cadastrada.',
              style: TextStyle(color: AppTokens.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.focus,
                foregroundColor: AppTokens.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Cadastrar Nova Tag'),
              onPressed: () => _openTagDialog(),
            ),
          ],
        ),
      );
    }

    final inputs = tags.where((t) {
      final a = normTagAddr(t);
      return (a.startsWith('I') || a.startsWith('IN')) && !a.startsWith('IW');
    }).toList();
    final outputs = tags.where((t) {
      final a = normTagAddr(t);
      return (a.startsWith('Q') || a.startsWith('OUT')) && !a.startsWith('QW');
    }).toList();
    final analogInputs = tags.where((t) {
      final a = normTagAddr(t);
      return a.startsWith('AI') || a.startsWith('IW') || a.startsWith('AIN');
    }).toList();
    final analogOutputs = tags.where((t) {
      final a = normTagAddr(t);
      return a.startsWith('AO') || a.startsWith('QW') || a.startsWith('AOUT');
    }).toList();
    final others = tags.where((t) {
      final a = normTagAddr(t);
      return !a.startsWith('I') && !a.startsWith('Q') && !a.startsWith('AI') &&
             !a.startsWith('AO') && !a.startsWith('IW') && !a.startsWith('QW') &&
             !a.startsWith('IN') && !a.startsWith('OUT') && !a.startsWith('AIN') && !a.startsWith('AOUT');
    }).toList();

    Widget buildSection(String title, Color headerColor, IconData icon, List<Tag> sectionTags) {
      if (sectionTags.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, color: headerColor, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(color: headerColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: headerColor.withValues(alpha: 0.3), height: 1)),
              ],
            ),
          ),
          ...sectionTags.map((t) {
            final resolvedPinStr = _resolveGpioMapping(t.address ?? t.id);
            final parsedGpio = int.tryParse(RegExp(r'\d+').firstMatch(resolvedPinStr)?.group(0) ?? '');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTokens.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTokens.line, width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTokens.panel2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: headerColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      t.address ?? t.id,
                      style: TextStyle(color: headerColor, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Badge do Pino Físico Vinculado (GPIO)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTokens.panel2,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTokens.line),
                    ),
                    child: Text(
                      resolvedPinStr,
                      style: TextStyle(color: AppTokens.muted, fontSize: 9.5, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.description ?? 'Sem descrição',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (parsedGpio != null)
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.settings_input_composite, color: Color(0xFF8C98A8), size: 16),
                          tooltip: 'Configurar Função do Pino (GPIO $parsedGpio)',
                          onPressed: () {
                            final targetPin = _inventoryPins.firstWhere(
                              (p) => p.gpio == parsedGpio,
                              orElse: () => GpioInventoryPin(
                                gpio: parsedGpio,
                                inputCapable: true,
                                outputCapable: true,
                                state: 'AVAILABLE',
                              ),
                            );
                            ConfigurePinDialog.show(
                              context,
                              pin: targetPin,
                              project: widget.project,
                              gatewayIp: _gatewayIp,
                              gpioService: _gpioService,
                              onConfigured: () {
                                _refreshHardware();
                                widget.onProjectUpdated?.call();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                      if (t.type == TagType.real || (t.address?.startsWith('%IW') ?? false) || (t.address?.startsWith('AI') ?? false))
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.tune, color: Color(0xFFF59E0B), size: 16),
                          tooltip: 'Calibração Universal de Processo',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AnalogCalibrationDialog(
                                tag: t,
                                liveValue: null,
                                gatewayUrl: 'http://$_gatewayIp',
                                onSaveProject: (newOffset, newGain) async {
                                  widget.project.tags[t.id] = Tag(
                                    id: t.id,
                                    name: t.name,
                                    type: t.type,
                                    address: t.address,
                                    unit: t.unit,
                                    description: t.description,
                                    rawMin: t.rawMin,
                                    rawMax: t.rawMax,
                                    scaledMin: t.scaledMin,
                                    scaledMax: t.scaledMax,
                                    controllerId: t.controllerId,
                                    calOffset: newOffset,
                                    calGain: newGain,
                                  );
                                  await saveCurrentLadder(widget.project);
                                  widget.onProjectUpdated?.call();
                                  if (mounted) setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF4FD1C5), size: 16),
                        tooltip: 'Editar Tag IEC',
                        onPressed: () => _openTagDialog(existingTag: t),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection('Entradas Digitais (I0.x)', const Color(0xFF4FD1C5), Icons.login, inputs),
        buildSection('Saídas Digitais (Q0.x)', const Color(0xFFFF9500), Icons.logout, outputs),
        buildSection('Entradas Analógicas (AI0.x)', const Color(0xFF8B5CF6), Icons.sensors, analogInputs),
        buildSection('Saídas Analógicas (AO0.x - DAC)', const Color(0xFFEC4899), Icons.tune, analogOutputs),
        buildSection('Outras Variáveis / Memórias', const Color(0xFFE0A430), Icons.memory, others),
      ],
    );
  }
}

class _PinLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _PinLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 8.5)),
      ],
    );
  }
}

class _CapBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CapBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
      ),
    );
  }
}
