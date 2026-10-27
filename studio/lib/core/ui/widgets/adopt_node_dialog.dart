import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../design_system/industrial_tokens.dart';
import '../../services/network_manager.dart';
import '../../network/authenticated_http_client.dart';

enum IndustrialNodeProfile {
  fieldNode,
  sensorNode,
  relayNode,
  gatewaySecondary,
}

enum IndustrialClusterTransport {
  espNow,
  wifiUdp,
}

enum IndustrialTemplatePreset {
  motorDirectStart,
  pidTankControl,
  irrigationSoil,
  pureRemoteIo,
}

class AdoptNodeDialog extends StatefulWidget {
  final EndapNode node;
  final NetworkManager networkManager;

  const AdoptNodeDialog({
    super.key,
    required this.node,
    required this.networkManager,
  });

  static Future<bool?> show(
    BuildContext context, {
    required EndapNode node,
    required NetworkManager networkManager,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdoptNodeDialog(
        node: node,
        networkManager: networkManager,
      ),
    );
  }

  @override
  State<AdoptNodeDialog> createState() => _AdoptNodeDialogState();
}

class _AdoptNodeDialogState extends State<AdoptNodeDialog> {
  late final TextEditingController _nameController;
  IndustrialNodeProfile _selectedProfile = IndustrialNodeProfile.fieldNode;
  IndustrialClusterTransport _selectedTransport = IndustrialClusterTransport.espNow;
  IndustrialTemplatePreset _selectedTemplate = IndustrialTemplatePreset.motorDirectStart;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final defaultName = 'Nó Remoto ${widget.node.id.replaceAll('ENDAP-', '')}';
    _nameController = TextEditingController(text: defaultName);
    final t = widget.node.transport.toLowerCase();
    if (t.contains('udp') || t.contains('infra')) {
      _selectedTransport = IndustrialClusterTransport.wifiUdp;
    } else {
      _selectedTransport = IndustrialClusterTransport.espNow;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _profileToString(IndustrialNodeProfile profile) {
    switch (profile) {
      case IndustrialNodeProfile.fieldNode:
        return 'Field Node (I/O Misto)';
      case IndustrialNodeProfile.sensorNode:
        return 'Sensor Node (Instrumentação)';
      case IndustrialNodeProfile.relayNode:
        return 'Relay Node (Atuadores)';
      case IndustrialNodeProfile.gatewaySecondary:
        return 'Gateway Secundário';
    }
  }

  String _templateToString(IndustrialTemplatePreset template) {
    switch (template) {
      case IndustrialTemplatePreset.motorDirectStart:
        return 'Partida Direta de Motores (Selo + Térmico)';
      case IndustrialTemplatePreset.pidTankControl:
        return 'Controle de Nível / Vazão (PID Determinístico)';
      case IndustrialTemplatePreset.irrigationSoil:
        return 'Estação de Solo & Irrigação Automática';
      case IndustrialTemplatePreset.pureRemoteIo:
        return 'E/S Remota Pura (Fieldbus Transparente)';
    }
  }

  Future<void> _handleAdopt() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim().isEmpty
        ? 'ENDAP-${widget.node.id}'
        : _nameController.text.trim();

    try {
      final success = await widget.networkManager.adoptNode(
        widget.node.id,
        _profileToString(_selectedProfile),
      );

      if (!success) {
        final err = widget.networkManager.errorMessage;
        throw Exception(err.isNotEmpty ? err : 'Falha ao adotar nó via claim.');
      }

      // Aplica template de aplicação no nó
      final gatewayIp = widget.networkManager.gatewayIp.trim();
      if (gatewayIp.isNotEmpty) {
        final client = AuthenticatedHttpClient();
        final templatePayload = {
          'target_node_id': widget.node.id.replaceAll('ENDAP-', ''),
          'template': _selectedTemplate.name,
          'node_name': name,
          'profile': _selectedProfile.name,
        };

        try {
          await client.post(
            Uri.parse('http://$gatewayIp/api/nodes/template/apply'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(templatePayload),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}

        // Aplica meio de transporte escolhido (ESP-NOW vs Wi-Fi UDP)
        final transportStr = _selectedTransport == IndustrialClusterTransport.espNow ? 'wifi-now' : 'wifi-udp';
        await widget.networkManager.setNodeTransport(widget.node.id, transportStr);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: IndustrialTokens.bgPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: IndustrialTokens.borderSubtle, width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: IndustrialTokens.bgSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: IndustrialTokens.telemetryCyan),
                    ),
                    child: const Icon(Icons.hub_outlined, color: IndustrialTokens.telemetryCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADOTAR NÓ NO CLUSTER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'ID: ${widget.node.id} • IP: ${widget.node.ip}',
                          style: const TextStyle(
                            color: IndustrialTokens.infoBlue,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSubmitting)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: IndustrialTokens.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // Erro se houver
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: IndustrialTokens.faultRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: IndustrialTokens.faultRed),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: IndustrialTokens.faultRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: IndustrialTokens.faultRed, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 1. Nome Amigável
              const Text(
                'NOME DE IDENTIFICAÇÃO DO NÓ',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                enabled: !_isSubmitting,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Ex: Nó 02 - Esteira de Separação',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                  filled: true,
                  fillColor: IndustrialTokens.bgCanvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: IndustrialTokens.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: IndustrialTokens.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: IndustrialTokens.telemetryCyan)),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Seleção de Perfil
              const Text(
                'PERFIL INDUSTRIAL DE OPERAÇÃO',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: IndustrialTokens.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: IndustrialTokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<IndustrialNodeProfile>(
                    value: _selectedProfile,
                    isExpanded: true,
                    dropdownColor: IndustrialTokens.bgPanel,
                    items: IndustrialNodeProfile.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          _profileToString(p),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: _isSubmitting ? null : (v) {
                      if (v != null) setState(() => _selectedProfile = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Template Inicial
              const Text(
                'TEMPLATE INICIAL DE APLICAÇÃO (AUTOMAÇÃO)',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: IndustrialTokens.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: IndustrialTokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<IndustrialTemplatePreset>(
                    value: _selectedTemplate,
                    isExpanded: true,
                    dropdownColor: IndustrialTokens.bgPanel,
                    items: IndustrialTemplatePreset.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(
                          _templateToString(t),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: _isSubmitting ? null : (v) {
                      if (v != null) setState(() => _selectedTemplate = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Meio de Transporte do Cluster
              const Text(
                'MEIO DE TRANSPORTE DO CLUSTER (COMUNICAÇÃO)',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: IndustrialTokens.bgCanvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: IndustrialTokens.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<IndustrialClusterTransport>(
                    value: _selectedTransport,
                    isExpanded: true,
                    dropdownColor: IndustrialTokens.bgPanel,
                    items: const [
                      DropdownMenuItem(
                        value: IndustrialClusterTransport.espNow,
                        child: Text(
                          'ESP-NOW (Rádio Ponto a Ponto sem Roteador)',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: IndustrialClusterTransport.wifiUdp,
                        child: Text(
                          'Wi-Fi UDP (Rede Local com Roteador)',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: _isSubmitting ? null : (v) {
                      if (v != null) setState(() => _selectedTransport = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IndustrialTokens.telemetryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _isSubmitting ? 'Adotando Nó...' : 'Adotar e Provisionar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _isSubmitting ? null : _handleAdopt,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
