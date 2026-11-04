import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../design_system/tokens.dart';
import '../network/authenticated_http_client.dart';
import '../services/network_manager.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';
import 'widgets/adopt_node_dialog.dart';

class NetworksPage extends StatefulWidget {
  final NetworkManager networkManager;
  final VoidCallback? onOpenDrawer;
  final bool embedded;
  final http.Client? httpClient;

  const NetworksPage({
    super.key,
    required this.networkManager,
    this.onOpenDrawer,
    this.embedded = false,
    this.httpClient,
  });

  @override
  State<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends State<NetworksPage> {
  late final http.Client _client = widget.httpClient ?? AuthenticatedHttpClient();
  int _provisionStep = 0;
  late TextEditingController _ipController;
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _isScanning = false;
  bool _isConnecting = false;
  String _connectionStatusText = '';
  double _progressValue = 0.0;
  List<dynamic> _scannedNetworks = [];

  // MQTT Integration State
  bool _mqttLoading = false;
  bool _mqttSaving = false;
  bool _mqttEnabled = false;
  bool _mqttHaDiscovery = true;
  bool _mqttConnected = false;
  final TextEditingController _mqttBrokerController = TextEditingController(text: 'mqtt://192.168.0.50:1883');
  final TextEditingController _mqttClientIdController = TextEditingController();
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();
  final TextEditingController _mqttBaseTopicController = TextEditingController(text: 'endap');
  final TextEditingController _mqttIntervalController = TextEditingController(text: '100');
  int _mqttMessagesPub = 0;
  int _mqttMessagesRecv = 0;
  int _mqttReconnects = 0;
  bool get _isHybridGateway => widget.networkManager.isHybridGateway;

  // Firmware OTA State
  bool _otaUploading = false;
  bool _otaDownloading = false;
  double _otaProgress = 0.0;
  String _otaStatusMessage = '';
  String? _selectedFirmwareName;
  Uint8List? _selectedFirmwareBytes;
  Map<String, dynamic>? _remoteOtaInfo;
  bool _fetchingOtaInfo = false;
  final TextEditingController _githubOtaUrlController = TextEditingController(
    text: 'https://raw.githubusercontent.com/mateusrossi-jpg/LANDELL/main/firmware/build/ENDAP.bin',
  );

  @override
  void initState() {
    super.initState();
    final initialIp = widget.networkManager.controller.ip.trim().isNotEmpty
        ? widget.networkManager.controller.ip.trim()
        : widget.networkManager.gatewayIp.trim();
    _ipController = TextEditingController(text: initialIp);
    _fetchMqttConfig();
    _fetchOtaInfo();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    _mqttBrokerController.dispose();
    _mqttClientIdController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _mqttBaseTopicController.dispose();
    _mqttIntervalController.dispose();
    _githubOtaUrlController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _scanNetworks() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;
    setState(() => _isScanning = true);
    try {
      final res = await _client
          .get(Uri.parse('http://$targetIp/api/wifi/scan'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _scannedNetworks = data['networks'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        final hint = targetIp != '192.168.4.1'
            ? ' No celular/PC, conecte ao Wi-Fi LANDELL_SETUP-xxxx (senha 12345678). Se o Android avisar "Sem internet", confirme MANTER CONEXÃO, ou use o IP 192.168.4.1.'
            : ' No celular/PC, confirme estar conectado ao Wi-Fi do CLP (LANDELL_SETUP-xxxx) e confirme manter a conexão mesmo sem internet.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD9503F),
            duration: const Duration(seconds: 7),
            content: Text('Falha ao escanear Wi-Fi em $targetIp: $e.$hint'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _sendCredentialsAndPoll() async {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();
    final targetIp = _ipController.text.trim();

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ou selecione o nome da rede Wi-Fi.')),
      );
      return;
    }

    setState(() {
      _provisionStep = 3;
      _isConnecting = true;
      _connectionStatusText = 'Enviando credenciais para $targetIp...';
      _progressValue = 0.2;
    });

    try {
      final getUrl = Uri.parse('http://$targetIp/api/wifi?ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(pass)}');
      var response = await _client.get(getUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        final postUrl = Uri.parse('http://$targetIp/api/wifi/connect');
        response = await _client
            .post(
              postUrl,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'ssid=${Uri.encodeComponent(ssid)}&password=${Uri.encodeComponent(pass)}',
            )
            .timeout(const Duration(seconds: 4));
      }

      setState(() {
        _connectionStatusText = 'Aguardando o ESP32 conectar à rede "$ssid"...';
        _progressValue = 0.5;
      });

      bool connected = false;
      String lastReason = '';
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        try {
          final statusRes = await _client
              .get(Uri.parse('http://$targetIp/api/wifi/status'))
              .timeout(const Duration(seconds: 3));
          if (statusRes.statusCode == 200) {
            final data = json.decode(statusRes.body);
            final staConnected = data['sta_connected'] == 1 || data['state'] == 'sta-connected';
            final disconnectReason = data['last_disconnect_reason'] ?? 0;
            final retryCount = data['retry_count'] ?? 0;

            if (staConnected) {
              connected = true;
              break;
            } else if (disconnectReason == 201) {
              lastReason = 'Senha incorreta ou rede Wi-Fi não encontrada (Erro 201).';
            } else {
              lastReason = 'Tentativa ${retryCount + 1}/5 de conexão...';
            }

            setState(() {
              _connectionStatusText = 'ESP32 tentando conectar... ($lastReason)';
              _progressValue = 0.5 + ((i + 1) * 0.08);
            });
          }
        } catch (_) {
          connected = true;
          break;
        }
      }

      if (!mounted) return;

      if (connected) {
        setState(() {
          _progressValue = 1.0;
          _isConnecting = false;
          _connectionStatusText = 'Conectado com sucesso! O ESP32 ingressou na rede Wi-Fi.';
        });
        try {
          await _client
              .post(Uri.parse('http://$targetIp/api/onboarding/wifi/confirm'))
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
        await widget.networkManager.discoverAndConnect();
      } else {
        setState(() {
          _isConnecting = false;
          _connectionStatusText = 'Falha na conexão: ${lastReason.isNotEmpty ? lastReason : "Verifique as credenciais digitadas."}';
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String userFriendlyError = 'Não foi possível provisionar: dispositivo não respondeu a tempo.';
        if (!errStr.contains('TimeoutException') && !errStr.contains('Future not completed')) {
          userFriendlyError = 'Falha na comunicação com o dispositivo. Verifique a conexão e tente novamente.';
        }
        setState(() {
          _isConnecting = false;
          _connectionStatusText = userFriendlyError;
        });
      }
    }
  }

  Future<void> _fetchMqttConfig() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;
    setState(() => _mqttLoading = true);
    try {
      final res = await _client.get(Uri.parse('http://$targetIp/api/mqtt/config')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _mqttEnabled = data['enabled'] == true;
          if (data['broker_url'] != null && (data['broker_url'] as String).isNotEmpty) {
            _mqttBrokerController.text = data['broker_url'];
          }
          if (data['client_id'] != null && (data['client_id'] as String).isNotEmpty) {
            _mqttClientIdController.text = data['client_id'];
          }
          if (data['username'] != null) {
            _mqttUserController.text = data['username'];
          }
          if (data['base_topic'] != null && (data['base_topic'] as String).isNotEmpty) {
            _mqttBaseTopicController.text = data['base_topic'];
          }
          _mqttHaDiscovery = data['ha_discovery'] != false;
          if (data['publish_interval_ms'] != null) {
            _mqttIntervalController.text = data['publish_interval_ms'].toString();
          }
          _mqttConnected = data['connected'] == true;
        });
      }
      final statRes = await _client.get(Uri.parse('http://$targetIp/api/mqtt/status')).timeout(const Duration(seconds: 3));
      if (statRes.statusCode == 200) {
        final statData = json.decode(statRes.body);
        setState(() {
          _mqttConnected = statData['connected'] == true;
          _mqttMessagesPub = statData['messages_published'] ?? 0;
          _mqttMessagesRecv = statData['messages_received'] ?? 0;
          _mqttReconnects = statData['reconnect_count'] ?? 0;
        });
      }
    } catch (_) {
      // Ignora erro se nó estiver offline
    } finally {
      if (mounted) setState(() => _mqttLoading = false);
    }
  }

  Future<void> _saveMqttConfig() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;
    setState(() => _mqttSaving = true);
    try {
      final payload = json.encode({
        'enabled': _mqttEnabled,
        'broker_url': _mqttBrokerController.text.trim(),
        'client_id': _mqttClientIdController.text.trim(),
        'username': _mqttUserController.text.trim(),
        'password': _mqttPassController.text.trim(),
        'base_topic': _mqttBaseTopicController.text.trim(),
        'ha_discovery': _mqttHaDiscovery,
        'publish_interval_ms': int.tryParse(_mqttIntervalController.text.trim()) ?? 100,
      });
      final res = await _client.post(
        Uri.parse('http://$targetIp/api/mqtt/config'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Color(0xFF3FBF5A), content: Text('Configuração MQTT salva e aplicada no CLP!')),
          );
        }
        await _fetchMqttConfig();
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFD9503F), content: Text('Erro ao salvar MQTT: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _mqttSaving = false);
    }
  }

  Future<void> _triggerHaDiscovery() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;
    try {
      final res = await _client.post(Uri.parse('http://$targetIp/api/mqtt/discovery')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Color(0xFF3FBF5A), content: Text('Descoberta Home Assistant publicada no Broker MQTT!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFD9503F), content: Text('Falha ao enviar descoberta: $e')),
        );
      }
    }
  }

  String _onboardingLabel(ControllerOnboardingState state) {
    switch (state) {
      case ControllerOnboardingState.active:
        return 'Ativo';
      case ControllerOnboardingState.pending:
        return 'Pendente';
      case ControllerOnboardingState.discovered:
        return 'Descoberto';
      case ControllerOnboardingState.claimed:
        return 'Reivindicado';
      case ControllerOnboardingState.unknown:
        return 'Desconhecido';
    }
  }

  Color _nodeStatusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.online:
        return const Color(0xFF3FBF5A);
      case NodeStatus.suspect:
        return const Color(0xFFE0A430);
      case NodeStatus.pending:
        return const Color(0xFF4FD1C5);
      case NodeStatus.error:
        return const Color(0xFFD9503F);
      case NodeStatus.offline:
        return const Color(0xFF8C98A8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.networkManager,
                builder: (context, _) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await widget.networkManager.scanNetwork();
                      await _fetchMqttConfig();
                      await _fetchOtaInfo();
                    },
                    color: AppTokens.focus,
                    backgroundColor: AppTokens.panel,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _buildControllerCard(),
                        const SizedBox(height: 14),
                        _buildNodesSection(),
                        const SizedBox(height: 14),
                        _buildWifiSection(),
                        const SizedBox(height: 14),
                        _buildMqttSection(),
                        const SizedBox(height: 14),
                        _buildFirmwareOtaSection(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Container(
      width: double.infinity,
      height: widget.embedded ? 36 : null,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: widget.embedded ? 4 : 8),
      decoration: const BoxDecoration(
        color: AppTokens.panel,
        border: Border(bottom: BorderSide(color: AppTokens.line, width: 1.0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: AppTokens.focus, size: 16),
          const SizedBox(width: 8),
          Text(
            'Rede & Topologia',
            style: TextStyle(
              color: AppTokens.text,
              fontSize: isDesktop ? 12 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          if (!widget.embedded) ...[
            const SizedBox(width: 8),
            const Text(
              '· Descoberta e provisionamento',
              style: TextStyle(color: AppTokens.muted, fontSize: 10),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: widget.networkManager.isScanning ? null : () => widget.networkManager.scanNetwork(),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: widget.networkManager.isScanning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.focus),
                  )
                : const Icon(Icons.refresh, color: AppTokens.focus, size: 16),
            tooltip: 'Escanear rede',
          ),
        ],
      ),
    );
  }

  Widget _buildControllerCard() {
    final nm = widget.networkManager;
    final controller = nm.controller;
    final statusColor = _nodeStatusColor(controller.isOnline ? NodeStatus.online : NodeStatus.offline);

    return Card(
      color: AppTokens.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dns, color: AppTokens.focus, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              controller.nodeName.isEmpty ? 'Controlador Principal' : controller.nodeName,
                              style: TextStyle(
                                color: AppTokens.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              controller.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'IP: ${nm.gatewayIp} · ID: ${controller.id.isEmpty ? "esp32-gw" : controller.id}',
                        style: TextStyle(
                          color: AppTokens.muted,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppTokens.line, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildMetricItem('Status AP', controller.isOnline ? 'Ativo (AP+STA)' : 'Sem resposta'),
                _buildMetricItem('Onboarding', _onboardingLabel(controller.onboardingState)),
                _buildMetricItem('Telemetria', TelemetrySyncService.instance.isPolling ? 'Ativa' : 'Pausada'),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: AppTokens.line, height: 1),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'PAPEL DO GATEWAY',
                  style: TextStyle(
                    color: AppTokens.focus,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (_isHybridGateway ? AppTokens.focus : AppTokens.warn).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: (_isHybridGateway ? AppTokens.focus : AppTokens.warn).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _isHybridGateway ? 'MODO HÍBRIDO' : 'MODO DEDICADO',
                    style: TextStyle(
                      color: _isHybridGateway ? AppTokens.focus : AppTokens.warn,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                final hybridCard = _buildGatewayRoleCard(
                  title: 'Gateway Híbrido',
                  desc: 'CLP Local 1ms + Rede. Aciona relés locais e gerencia a planta.',
                  isSelected: _isHybridGateway,
                  color: AppTokens.focus,
                  onTap: () => _switchGatewayMode(true),
                );
                final dedicatedCard = _buildGatewayRoleCard(
                  title: 'Gateway Dedicado',
                  desc: 'Apenas Comunicação. Concentrador puro com foco total em nós remotos.',
                  isSelected: !_isHybridGateway,
                  color: AppTokens.warn,
                  onTap: () => _switchGatewayMode(false),
                );

                if (isCompact) {
                  return Column(
                    children: [
                      hybridCard,
                      const SizedBox(height: 8),
                      dedicatedCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: hybridCard),
                    const SizedBox(width: 8),
                    Expanded(child: dedicatedCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayRoleCard({
    required String title,
    required String desc,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppTokens.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTokens.line,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 14,
                  color: isSelected ? color : AppTokens.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTokens.textPrimary : AppTokens.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(color: AppTokens.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchGatewayMode(bool hybrid) async {
    if (_isHybridGateway == hybrid) return;
    final profile = hybrid ? 0 : 4;
    final roleName = hybrid ? 'Gateway Híbrido' : 'Gateway Dedicado';
    final success = await widget.networkManager.provisionController(
      name: roleName,
      profile: profile,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppTokens.run : AppTokens.fault,
          content: Text(
            success
                ? 'Papel operacional alterado para: $roleName'
                : 'Falha ao atualizar papel do gateway.',
          ),
        ),
      );
    }
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFE7EBF0),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ],
    );
  }

  Widget _buildNodesSection() {
    final primaryId = widget.networkManager.controller.id.replaceAll('ENDAP-', '').trim().toUpperCase();
    final gatewayIp = widget.networkManager.gatewayIp.trim();
    final controllerIp = widget.networkManager.controller.ip.trim();

    // Filtra para exibir apenas nós de campo/remotos, pois o Gateway Principal
    // já é apresentado em destaque exclusivo no card superior (_buildControllerCard).
    final nodes = widget.networkManager.nodes.where((n) {
      final cleanId = n.id.replaceAll('ENDAP-', '').trim().toUpperCase();
      final ip = n.ip.trim();
      final isPrimary = (primaryId.isNotEmpty && cleanId == primaryId) ||
          ip == gatewayIp ||
          (controllerIp.isNotEmpty && ip == controllerIp) ||
          n.role.toLowerCase().contains('gateway');
      return !isPrimary;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Dispositivos de Campo / Remotos (${nodes.length})',
              style: const TextStyle(
                color: Color(0xFFE7EBF0),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4FD1C5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.search, size: 14),
              label: const Text('Buscar', style: TextStyle(fontSize: 11)),
              onPressed: () => widget.networkManager.scanNetwork(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (nodes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTokens.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTokens.line, width: 1.0),
            ),
            child: const Center(
              child: Text(
                'Nenhum outro nó de campo ou remoto detectado na topologia.',
                style: TextStyle(color: AppTokens.textDim, fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final n = nodes[idx];
              final c = _nodeStatusColor(n.status);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                n.id,
                                style: const TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: n.transport.toLowerCase().contains('now') || n.transport.toLowerCase().contains('esp')
                                      ? Colors.amber.withOpacity(0.18)
                                      : Colors.cyan.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: n.transport.toLowerCase().contains('now') || n.transport.toLowerCase().contains('esp')
                                        ? Colors.amber.shade700
                                        : Colors.cyan.shade600,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  n.transport.toUpperCase(),
                                  style: TextStyle(
                                    color: n.transport.toLowerCase().contains('now') || n.transport.toLowerCase().contains('esp')
                                        ? Colors.amber.shade300
                                        : Colors.cyan.shade300,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IP: ${n.ip.isEmpty ? "Sem IP (Rádio L2)" : n.ip} · Papel: ${n.role}',
                            style: const TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontFamily: 'JetBrains Mono'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (n.status == NodeStatus.pending) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.focus,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final adopted = await AdoptNodeDialog.show(
                            context,
                            node: n,
                            networkManager: widget.networkManager,
                          );
                          if (ctx.mounted && adopted == true) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTokens.run,
                                content: Text('Nó ${n.id} adotado e provisionado com sucesso!'),
                              ),
                            );
                          }
                        },
                        child: const Text('Adotar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.panel2,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTokens.line, width: 1.0),
                      ),
                      child: Text(
                        n.status.name.toUpperCase(),
                        style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono'),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppTokens.textDim, size: 18),
                      color: AppTokens.panel,
                      onSelected: (val) async {
                        if (val == 'transport_wifi' || val == 'transport_espnow') {
                          final targetTransport = val == 'transport_wifi' ? 'wifi-udp' : 'wifi-now';
                          final label = val == 'transport_wifi' ? 'Wi-Fi UDP' : 'ESP-NOW';
                          final ok = await widget.networkManager.setNodeTransport(n.id, targetTransport);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: ok ? AppTokens.run : const Color(0xFFD9503F),
                                content: Text(ok
                                    ? 'Transporte do nó ${n.id} alterado para $label com sucesso!'
                                    : 'Falha ao alterar transporte: ${widget.networkManager.errorMessage}'),
                              ),
                            );
                          }
                        } else if (val == 'revoke') {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: AppTokens.panel,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppTokens.line, width: 1.0),
                              ),
                              actionsOverflowDirection: VerticalDirection.down,
                              actionsOverflowButtonSpacing: 8,
                              title: const Text('Remover Dispositivo', style: TextStyle(color: AppTokens.text, fontSize: 15)),
                              content: Text(
                                'Deseja realmente remover o dispositivo ${n.id} (${n.ip}) da topologia?',
                                style: const TextStyle(color: AppTokens.textDim, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8C98A8))),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9503F)),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Remover', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && ctx.mounted) {
                            final ok = await widget.networkManager.revokeNode(n.id);
                            if (ctx.mounted) {
                              final err = widget.networkManager.errorMessage;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  backgroundColor: ok ? const Color(0xFF3FBF5A) : const Color(0xFFD9503F),
                                  content: Text(ok ? 'Nó ${n.id} removido do registry com sucesso.' : (err.isNotEmpty ? err : 'Erro ao remover dispositivo.')),
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (pCtx) => [
                        PopupMenuItem(
                          value: 'transport_espnow',
                          child: Row(
                            children: const [
                              Icon(Icons.sensors, color: Colors.amber, size: 16),
                              SizedBox(width: 8),
                              Text('Usar ESP-NOW (Rádio L2)', style: TextStyle(color: AppTokens.text, fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'transport_wifi',
                          child: Row(
                            children: const [
                              Icon(Icons.wifi, color: Colors.cyan, size: 16),
                              SizedBox(width: 8),
                              Text('Usar Wi-Fi UDP (IP Direto)', style: TextStyle(color: AppTokens.text, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'revoke',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Color(0xFFD9503F), size: 16),
                              SizedBox(width: 8),
                              Text('Remover / Esquecer', style: TextStyle(color: Color(0xFFD9503F), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWifiSection() {
    return Card(
      color: AppTokens.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, color: AppTokens.focus, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Provisionamento Wi-Fi',
                      style: TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.focus,
                    side: const BorderSide(color: AppTokens.line, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.connect_without_contact, size: 14),
                  label: Text(_provisionStep == 0 ? 'Conectar Wi-Fi' : 'Fechar', style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      if (_provisionStep == 0) {
                        final currentIp = widget.networkManager.controller.ip.trim().isNotEmpty
                            ? widget.networkManager.controller.ip.trim()
                            : widget.networkManager.gatewayIp.trim();
                        // Se o IP estiver vazio ou não for da rede local, sugere o IP padrão do modo AP
                        if (currentIp.isNotEmpty) {
                           _ipController.text = currentIp;
                        } else {
                           _ipController.text = '192.168.4.1';
                        }
                        _provisionStep = 1;
                      } else {
                        _provisionStep = 0;
                      }
                    });
                  },
                ),
              ],
            ),
            if (_provisionStep > 0) ...[
              const SizedBox(height: 14),
              const Divider(color: AppTokens.line, height: 1),
              const SizedBox(height: 14),
              if (_provisionStep == 1) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTokens.focus),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Passo 1: Se o CLP estiver em modo de configuração (SSID LANDELL_SETUP-xxxx ou ENDAP_SETUP-xxxx, senha: 12345678), conecte o Wi-Fi do computador ou celular nesta rede e utilize o IP 192.168.4.1.',
                          style: TextStyle(color: AppTokens.textDim, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text('IP do Controlador Alvo (em modo AP):', style: TextStyle(color: AppTokens.textDim, fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _ipController,
                          style: const TextStyle(color: AppTokens.text, fontFamily: 'JetBrains Mono', fontSize: 12),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: AppTokens.panel2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.focus,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() => _provisionStep = 2);
                        _scanNetworks();
                      },
                      child: const Text('Próximo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      backgroundColor: AppTokens.panel2,
                      side: const BorderSide(color: AppTokens.line),
                      label: const Text('192.168.4.1 (Modo AP)', style: TextStyle(fontSize: 10, color: AppTokens.text)),
                      onPressed: () => setState(() => _ipController.text = '192.168.4.1'),
                    ),
                    ActionChip(
                      backgroundColor: AppTokens.panel2,
                      side: const BorderSide(color: AppTokens.line),
                      label: const Text('192.168.0.229 (Bancada STA)', style: TextStyle(fontSize: 10, color: AppTokens.text)),
                      onPressed: () => setState(() => _ipController.text = '192.168.0.229'),
                    ),
                    ActionChip(
                      backgroundColor: AppTokens.panel2,
                      side: const BorderSide(color: AppTokens.line),
                      label: const Text('landell.local (mDNS PC/Mac)', style: TextStyle(fontSize: 10, color: AppTokens.text)),
                      onPressed: () => setState(() => _ipController.text = 'landell.local'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0369A1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.phone_android, size: 14, color: Color(0xFF38BDF8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No Android: O sistema bloqueia nomes ".local" no navegador. Conecte no Wi-Fi LANDELL_SETUP-xxxx e use 192.168.4.1, ou acesse pelo IP do CLP na rede (ex: 192.168.0.229). No PC ou iPhone, landell.local funciona normalmente.',
                          style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_provisionStep == 2) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Redes Wi-Fi encontradas via ${_ipController.text}:', style: const TextStyle(color: AppTokens.textDim, fontSize: 11)),
                    IconButton(
                      icon: _isScanning
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.focus))
                          : const Icon(Icons.refresh, size: 16, color: AppTokens.focus),
                      tooltip: 'Escanear novamente',
                      onPressed: _isScanning ? null : _scanNetworks,
                    ),
                  ],
                ),
                if (_isScanning) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(color: AppTokens.focus, backgroundColor: AppTokens.panel2),
                  const SizedBox(height: 8),
                  const Text('Varrendo canais de rádio 2.4 GHz...', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontStyle: FontStyle.italic)),
                ] else if (_scannedNetworks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTokens.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: AppTokens.panel2,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _scannedNetworks.length,
                        itemBuilder: (ctx, i) {
                          final net = _scannedNetworks[i];
                          final ssid = net['ssid'] ?? '';
                          final rssi = net['rssi'] ?? 0;
                          final isSelected = _ssidController.text == ssid;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: const Icon(Icons.wifi, size: 16, color: AppTokens.focus),
                            title: Text(ssid, style: TextStyle(color: isSelected ? AppTokens.focus : AppTokens.text, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text('Sinal: $rssi dBm', style: const TextStyle(color: AppTokens.textDim, fontSize: 9.5)),
                            trailing: isSelected ? const Icon(Icons.check, size: 14, color: AppTokens.focus) : null,
                            onTap: () {
                              setState(() => _ssidController.text = ssid);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.panel2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTokens.line),
                    ),
                    child: Column(
                      children: [
                        const Text('Nenhuma rede encontrada na última varredura.', style: TextStyle(color: AppTokens.textDim, fontSize: 11)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _scanNetworks,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('Tentar Novamente', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _ssidController,
                    style: const TextStyle(color: AppTokens.text, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Nome da rede Wi-Fi (SSID)',
                      hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: AppTokens.panel2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTokens.text, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Senha da rede Wi-Fi',
                      hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: AppTokens.panel2,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTokens.textDim, size: 16),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _provisionStep = 1),
                      child: const Text('Voltar', style: TextStyle(color: AppTokens.textDim, fontSize: 11)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.run,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _sendCredentialsAndPoll,
                      child: const Text('Conectar ESP32', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ] else if (_provisionStep == 3) ...[
                if (_isConnecting) ...[
                  LinearProgressIndicator(value: _progressValue, backgroundColor: AppTokens.panel2, color: AppTokens.focus),
                  const SizedBox(height: 10),
                ],
                Text(
                  _connectionStatusText,
                  style: const TextStyle(color: AppTokens.text, fontSize: 11, fontFamily: 'JetBrains Mono'),
                ),
                const SizedBox(height: 12),
                if (!_isConnecting)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _provisionStep = 0),
                      child: const Text('Concluir', style: TextStyle(color: AppTokens.focus, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMqttSection() {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final statusColor = !_mqttEnabled
        ? const Color(0xFF8C98A8)
        : _mqttConnected
            ? const Color(0xFF3FBF5A)
            : const Color(0xFFE0A430);
    final statusText = !_mqttEnabled
        ? 'DESATIVADO'
        : _mqttConnected
            ? 'CONECTADO'
            : 'DESCONECTADO';

    return Card(
      color: AppTokens.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _mqttConnected ? const Color(0xFF3FBF5A).withOpacity(0.4) : AppTokens.panel2,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF03A9F4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_sync, color: Color(0xFF03A9F4), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Integração MQTT & Home Assistant',
                        style: TextStyle(
                          color: AppTokens.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Telemetria e controle assíncrono via Core 0 (preserva o ciclo determinístico de 1 ms).',
                        style: TextStyle(color: AppTokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _mqttLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.focus))
                      : const Icon(Icons.refresh, size: 18, color: AppTokens.muted),
                  tooltip: 'Atualizar Status MQTT',
                  onPressed: _fetchMqttConfig,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTokens.panel2, height: 1),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Habilitar Cliente MQTT', style: TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Conecta o CLP ao Broker MQTT (ex: Mosquitto no Home Assistant)', style: TextStyle(color: AppTokens.muted, fontSize: 11)),
              value: _mqttEnabled,
              activeColor: AppTokens.focus,
              onChanged: (val) => setState(() => _mqttEnabled = val),
            ),

            if (_mqttEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _mqttBrokerController,
                style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'JetBrains Mono'),
                decoration: InputDecoration(
                  labelText: 'URL do Broker MQTT',
                  hintText: 'mqtt://192.168.0.50:1883',
                  labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                  hintStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  prefixIcon: const Icon(Icons.link, size: 18, color: AppTokens.muted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mqttClientIdController,
                        style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'JetBrains Mono'),
                        decoration: InputDecoration(
                          labelText: 'Client ID (Opcional)',
                          hintText: 'endap_xxxxxx',
                          labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                          filled: true,
                          fillColor: AppTokens.panel2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _mqttBaseTopicController,
                        style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'JetBrains Mono'),
                        decoration: InputDecoration(
                          labelText: 'Tópico Base',
                          hintText: 'endap',
                          labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                          filled: true,
                          fillColor: AppTokens.panel2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                TextField(
                  controller: _mqttClientIdController,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'JetBrains Mono'),
                  decoration: InputDecoration(
                    labelText: 'Client ID (Opcional)',
                    hintText: 'endap_xxxxxx',
                    labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AppTokens.panel2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mqttBaseTopicController,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'JetBrains Mono'),
                  decoration: InputDecoration(
                    labelText: 'Tópico Base',
                    hintText: 'endap',
                    labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AppTokens.panel2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mqttUserController,
                        style: const TextStyle(color: AppTokens.text, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Usuário (Opcional)',
                          labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                          filled: true,
                          fillColor: AppTokens.panel2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _mqttPassController,
                        obscureText: true,
                        style: const TextStyle(color: AppTokens.text, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Senha (Opcional)',
                          labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                          filled: true,
                          fillColor: AppTokens.panel2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                TextField(
                  controller: _mqttUserController,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Usuário (Opcional)',
                    labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AppTokens.panel2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mqttPassController,
                  obscureText: true,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Senha (Opcional)',
                    labelStyle: const TextStyle(color: AppTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AppTokens.panel2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Home Assistant Auto-Discovery', style: TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Cria automaticamente os botões (Switches) e sensores no Home Assistant via padrão MQTT Discovery.', style: TextStyle(color: AppTokens.muted, fontSize: 11)),
                value: _mqttHaDiscovery,
                activeColor: const Color(0xFF03A9F4),
                onChanged: (val) => setState(() => _mqttHaDiscovery = val),
              ),

              if (_mqttConnected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3FBF5A).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMqttStat('Publicados', '$_mqttMessagesPub', Icons.upload),
                      _buildMqttStat('Recebidos', '$_mqttMessagesRecv', Icons.download),
                      _buildMqttStat('Reconexões', '$_mqttReconnects', Icons.sync),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.focus,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _mqttSaving ? null : _saveMqttConfig,
                    icon: _mqttSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Salvar no CLP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  if (_mqttConnected && _mqttHaDiscovery)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF03A9F4),
                        side: const BorderSide(color: Color(0xFF03A9F4)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _triggerHaDiscovery,
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('Publicar Descoberta no HA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMqttStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTokens.muted),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: AppTokens.text, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'JetBrains Mono')),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTokens.muted, fontSize: 10)),
      ],
    );
  }

  Future<void> _fetchOtaInfo() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) return;
    setState(() => _fetchingOtaInfo = true);
    try {
      final res = await _client
          .get(Uri.parse('http://$targetIp/api/system/ota/status'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() => _remoteOtaInfo = data);
        }
      }
    } catch (_) {
      // Offline ou rota antiga
    } finally {
      if (mounted) setState(() => _fetchingOtaInfo = false);
    }
  }

  Future<void> _pickLocalFirmware() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Selecionar Binário de Firmware (.bin)',
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null && !kIsWeb) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes != null) {
          final nonNullBytes = bytes;
          setState(() {
            _selectedFirmwareBytes = nonNullBytes;
            _selectedFirmwareName = file.name;
            _otaStatusMessage = 'Binário selecionado: ${file.name} (${(nonNullBytes.length / 1024).toStringAsFixed(1)} KB)';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTokens.error, content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  Future<void> _downloadFromGithubAndDeploy() async {
    final urlStr = _githubOtaUrlController.text.trim();
    if (urlStr.isEmpty) return;
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTokens.error, content: Text('Informe o IP do CLP antes de iniciar o OTA.')),
      );
      return;
    }

    setState(() {
      _otaDownloading = true;
      _otaProgress = 0.0;
      _otaStatusMessage = 'Conectando ao GitHub para download do firmware...';
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(urlStr));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode} ao baixar do GitHub');
      }

      final contentLength = streamedResponse.contentLength ?? 1550000;
      final bytesBuilder = BytesBuilder(copy: false);
      int downloaded = 0;

      await for (final chunk in streamedResponse.stream) {
        bytesBuilder.add(chunk);
        downloaded += chunk.length;
        if (mounted) {
          setState(() {
            _otaProgress = (downloaded / contentLength).clamp(0.0, 1.0);
            _otaStatusMessage = 'Baixando do GitHub: ${(downloaded / 1024).toStringAsFixed(0)} KB / ${(contentLength / 1024).toStringAsFixed(0)} KB (${(_otaProgress * 100).toStringAsFixed(0)}%)';
          });
        }
      }

      final firmwareBytes = bytesBuilder.takeBytes();
      setState(() {
        _selectedFirmwareBytes = firmwareBytes;
        _selectedFirmwareName = 'GitHub (ENDAP.bin)';
        _otaDownloading = false;
      });

      // Inicia imediatamente o envio OTA para o CLP
      await _uploadFirmwareOta(firmwareBytes, targetIp);
    } catch (e) {
      if (mounted) {
        setState(() {
          _otaDownloading = false;
          _otaStatusMessage = 'Falha no download do GitHub: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTokens.error, content: Text('Erro no download: $e')),
        );
      }
    }
  }

  Future<void> _uploadFirmwareOta(Uint8List bytes, String targetIp) async {
    setState(() {
      _otaUploading = true;
      _otaProgress = 0.0;
      _otaStatusMessage = 'Iniciando gravação OTA no CLP ($targetIp)...';
    });

    try {
      final uri = Uri.parse('http://$targetIp/api/system/ota');
      
      final request = http.StreamedRequest('POST', uri);
      request.headers['Content-Type'] = 'application/octet-stream';
      request.contentLength = bytes.length;

      final uploadFuture = request.send();

      const chunkSize = 4096;
      int uploaded = 0;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final slice = bytes.sublist(i, end);
        request.sink.add(slice);
        uploaded += slice.length;
        if (mounted) {
          setState(() {
            _otaProgress = (uploaded / bytes.length).clamp(0.0, 1.0);
            _otaStatusMessage = 'Gravando OTA no CLP: ${(uploaded / 1024).toStringAsFixed(0)} KB / ${(bytes.length / 1024).toStringAsFixed(0)} KB (${(_otaProgress * 100).toStringAsFixed(0)}%)';
          });
        }
        await Future.delayed(const Duration(milliseconds: 2));
      }
      await request.sink.close();

      final response = await uploadFuture;
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        Map<String, dynamic>? data;
        try {
          data = json.decode(responseBody) as Map<String, dynamic>;
        } catch (_) {}
        setState(() {
          _otaUploading = false;
          _otaProgress = 1.0;
          _otaStatusMessage = data?['message'] ?? 'Firmware gravado com sucesso! Reiniciando CLP...';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text(_otaStatusMessage),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } else {
        throw Exception('Falha na gravação OTA (HTTP ${response.statusCode}): $responseBody');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _otaUploading = false;
          _otaStatusMessage = 'Falha no OTA: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTokens.error, content: Text('Erro ao enviar OTA: $e')),
        );
      }
    }
  }

  Widget _buildFirmwareOtaSection() {
    final isBusy = _otaUploading || _otaDownloading;
    final statusColor = isBusy
        ? const Color(0xFFE0A430)
        : (_remoteOtaInfo != null && _remoteOtaInfo!['ok'] == true)
            ? const Color(0xFF3FBF5A)
            : const Color(0xFF8C98A8);
    final statusText = isBusy
        ? (_otaDownloading ? 'BAIXANDO...' : 'GRAVANDO...')
        : (_remoteOtaInfo != null && _remoteOtaInfo!['ok'] == true)
            ? 'OTA DISPONÍVEL'
            : 'CLP OFFLINE';

    return Card(
      color: AppTokens.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBusy ? const Color(0xFFE0A430).withOpacity(0.5) : AppTokens.panel2,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.system_update_alt, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deploy de Firmware OTA (ESP32)',
                        style: TextStyle(
                          color: AppTokens.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _remoteOtaInfo != null
                            ? 'Partição ativa: ${_remoteOtaInfo!['running_partition'] ?? 'ota_0'} (Próxima: ${_remoteOtaInfo!['next_partition'] ?? 'ota_1'}) · Versão: ${_remoteOtaInfo!['running_version'] ?? 'dev'}'
                            : 'Atualização Over-The-Air do FreeRTOS/ESP-IDF via Wi-Fi sem necessidade de cabo USB.',
                        style: const TextStyle(color: AppTokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isBusy ? null : _fetchOtaInfo,
                  icon: _fetchingOtaInfo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.focus),
                        )
                      : const Icon(Icons.refresh, color: AppTokens.muted, size: 16),
                  tooltip: 'Atualizar status do firmware',
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTokens.line, height: 1),
            const SizedBox(height: 16),

            // Barra de Progresso quando ocupado
            if (isBusy || _otaStatusMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isBusy ? const Color(0xFFE0A430).withOpacity(0.4) : AppTokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBusy ? Icons.sync : Icons.info_outline,
                          size: 16,
                          color: isBusy ? const Color(0xFFE0A430) : AppTokens.focus,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _otaStatusMessage,
                            style: const TextStyle(
                              color: AppTokens.text,
                              fontSize: 12,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ),
                        if (isBusy)
                          Text(
                            '${(_otaProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFFE0A430),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                      ],
                    ),
                    if (isBusy) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _otaProgress > 0 ? _otaProgress : null,
                          minHeight: 6,
                          backgroundColor: AppTokens.panel2,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Opção 1: Arquivo Local (.bin)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.folder_open, size: 16, color: AppTokens.focus),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Upload de Binário Local (.bin)',
                          style: TextStyle(
                            color: AppTokens.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isBusy ? null : _pickLocalFirmware,
                        icon: const Icon(Icons.file_upload_outlined, size: 14),
                        label: const Text('Selecionar .bin', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.panel,
                          foregroundColor: AppTokens.text,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                      if (_selectedFirmwareBytes != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              '${_selectedFirmwareName ?? 'ENDAP.bin'} (${((_selectedFirmwareBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB)',
                              style: const TextStyle(color: AppTokens.muted, fontSize: 11, fontFamily: 'JetBrains Mono'),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () {
                                  final ip = _ipController.text.trim();
                                  if (ip.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTokens.error,
                                        content: Text('Informe o IP do CLP antes de gravar.'),
                                      ),
                                    );
                                    return;
                                  }
                                  _uploadFirmwareOta(_selectedFirmwareBytes!, ip);
                                },
                          icon: const Icon(Icons.bolt, size: 14),
                          label: const Text('Gravar no CLP via OTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opção 2: Baixar do GitHub e Gravar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.cloud_download_outlined, size: 16, color: Color(0xFF03A9F4)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2. Baixar Atualização do GitHub & Gravar OTA',
                          style: TextStyle(
                            color: AppTokens.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 180, maxWidth: 420),
                        child: TextField(
                          controller: _githubOtaUrlController,
                          enabled: !isBusy,
                          style: const TextStyle(color: AppTokens.text, fontSize: 11, fontFamily: 'JetBrains Mono'),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            hintText: 'https://raw.githubusercontent.com/.../ENDAP.bin',
                            hintStyle: const TextStyle(color: AppTokens.muted, fontSize: 10),
                            fillColor: AppTokens.panel,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTokens.line),
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isBusy ? null : _downloadFromGithubAndDeploy,
                        icon: const Icon(Icons.download_for_offline_outlined, size: 14),
                        label: const Text('Baixar & Gravar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}