import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:endap_studio/ladder/models/tag.dart';
import 'dart:convert';
import 'package:endap_studio/design_system/tokens.dart';
import '../../../../core/network/authenticated_http_client.dart';

class AnalogCalibrationDialog extends StatefulWidget {
  final Tag tag;
  final double? liveValue;
  final Function(double? offset, double? gain)? onSaveProject;
  final String gatewayUrl;
  final http.Client? httpClient;

  const AnalogCalibrationDialog({
    super.key,
    required this.tag,
    this.liveValue,
    this.onSaveProject,
    this.gatewayUrl = 'http://192.168.4.1',
    this.httpClient,
  });

  @override
  State<AnalogCalibrationDialog> createState() => _AnalogCalibrationDialogState();
}

class _AnalogCalibrationDialogState extends State<AnalogCalibrationDialog> {
  late TextEditingController _offsetController;
  late TextEditingController _gainController;
  final TextEditingController _realTempController = TextEditingController();
  late final http.Client _client;

  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isSuccess = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _client = widget.httpClient ?? AuthenticatedHttpClient();
    _offsetController = TextEditingController(
      text: (widget.tag.calOffset ?? 0.0).toStringAsFixed(1),
    );
    _gainController = TextEditingController(
      text: (widget.tag.calGain ?? 1.0).toStringAsFixed(3),
    );
    // Sugestão inicial no campo "Quanto deveria marcar?"
    if (widget.liveValue != null) {
      _realTempController.text = (widget.liveValue! + (widget.tag.calOffset ?? 0.0)).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _offsetController.dispose();
    _gainController.dispose();
    _realTempController.dispose();
    super.dispose();
  }

  double get _currentOffset => double.tryParse(_offsetController.text) ?? 0.0;
  double get _currentGain => double.tryParse(_gainController.text) ?? 1.0;

  double get _calculatedLive {
    final raw = widget.liveValue ?? 0.0;
    return (raw * _currentGain) + _currentOffset;
  }

  void _applyRealValue() {
    final target = double.tryParse(_realTempController.text.replaceAll(',', '.'));
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um número válido para o valor real.')),
      );
      return;
    }

    final raw = widget.liveValue ?? (_calculatedLive - _currentOffset);
    // target = raw * 1.0 + newOffset => newOffset = target - raw
    final newOffset = target - raw;

    setState(() {
      _offsetController.text = newOffset.toStringAsFixed(1);
      _gainController.text = '1.000';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text('Ajustado! Adicionado offset de ${newOffset >= 0 ? "+" : ""}${newOffset.toStringAsFixed(1)} ${widget.tag.unit ?? ""} para alcançar $target ${widget.tag.unit ?? ""}.'),
      ),
    );
  }

  void _quickTrim(double delta) {
    final current = _currentOffset;
    final updated = current + delta;
    setState(() {
      _offsetController.text = updated.toStringAsFixed(1);
    });
  }

  Future<void> _sendToController() async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final url = Uri.parse('${widget.gatewayUrl}/api/pve/calibrate');
      
      // Mapeia o tag para o ID numérico correspondente no runtime PVE do firmware:
      // ID 0 = AIN1 (GPIO34)
      // ID 1 = AIN2 (GPIO35)
      // ID 2 = SENSOR_1_TEMP (AHT10 / %IW0.0 / AI0.0)
      // ID 3 = SENSOR_1_HUM (AHT10 / %IW0.1 / AI0.1)
      // ID 4 = TEMP_DS (DS18B20 / %IW0.2)
      // ID 5 = TEMP_DHT
      // ID 6 = HUM_DHT
      int varNumericId = 2; // Default Temp AHT10
      final tagUpper = widget.tag.id.toUpperCase();
      final addrUpper = (widget.tag.address ?? '').toUpperCase();
      if (tagUpper.contains('HUM') || tagUpper.contains('UMID') || addrUpper == '%IW0.1' || addrUpper == 'AI0.1') {
        varNumericId = 3;
      } else if (tagUpper.contains('DS18B20') || tagUpper.contains('TEMP_DS') || addrUpper == '%IW0.2') {
        varNumericId = 4;
      } else if (tagUpper.contains('ADC_GPIO34') || addrUpper == '%IW0.0' && !tagUpper.contains('TEMP')) {
        varNumericId = 0;
      } else if (tagUpper.contains('ADC_GPIO35')) {
        varNumericId = 1;
      }

      final payload = {
        'id': varNumericId,
        'tag': widget.tag.id,
        'address': widget.tag.address,
        'offset': (_currentOffset * 10).round(), // Fator x10 de escala de processo
        'gain': (_currentGain * 1000).round(),
      };

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Gravado no CLP com sucesso!';
        });
      } else {
        setState(() {
          _isSuccess = false;
          _statusMessage = 'Resposta do CLP: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Ajuste salvo localmente (Controlador offline no momento).';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _saveAll() {
    if (widget.onSaveProject != null) {
      widget.onSaveProject!(_currentOffset, _currentGain);
    }
    _sendToController();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text('Calibração salva! Novo valor: ${_calculatedLive.toStringAsFixed(1)} ${widget.tag.unit ?? ""}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.tag.unit ?? '°C';
    final live = widget.liveValue ?? 18.0;

    final isHumidity = unit == '%' ||
        widget.tag.id.toUpperCase().contains('HUM') ||
        widget.tag.id.toUpperCase().contains('UMID') ||
        widget.tag.name.toUpperCase().contains('UMID');
    final isTemperature = unit.contains('°C') ||
        unit == 'C' ||
        widget.tag.id.toUpperCase().contains('TEMP') ||
        widget.tag.name.toUpperCase().contains('TEMP');

    final Color themeColor = isHumidity
        ? const Color(0xFF38BDF8)
        : (isTemperature ? const Color(0xFFF59E0B) : const Color(0xFF4FD1C5));
    final IconData themeIcon = isHumidity
        ? Icons.water_drop
        : (isTemperature ? Icons.thermostat : Icons.speed);
    final String titleText = isHumidity
        ? 'Ajuste de Umidade Relativa'
        : (isTemperature ? 'Ajuste de Temperatura' : 'Ajustar Sensor / Calibração');
    final String exampleRef = isHumidity ? '55' : (isTemperature ? '28' : '100');
    final String fieldLabel = isHumidity
        ? 'Qual a umidade real agora?'
        : (isTemperature ? 'Qual a temperatura real agora?' : 'Qual o valor real medido?');

    return AlertDialog(
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTokens.line, width: 1.0),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(themeIcon, color: themeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.tag.name} (${widget.tag.address ?? "Canal Analógico"})',
                  style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Comparativo Visual: Leitura Atual vs Resultado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131922),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2C384A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LEITURA ATUAL DO SENSOR', style: TextStyle(color: Color(0xFF8C98A8), fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${live.toStringAsFixed(1)} $unit',
                            style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: Color(0xFF4FD1C5), size: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('VALOR CORRIGIDO NA TELA', style: TextStyle(color: Color(0xFF4FD1C5), fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${_calculatedLive.toStringAsFixed(1)} $unit',
                            style: const TextStyle(color: Color(0xFF4FD1C5), fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // MÉTODO 1 (SUPER SIMPLES): "O ambiente está em quanto? Digite aqui"
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF263242),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3FBF5A).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_outline, color: Color(0xFF3FBF5A), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Ajuste Direto (Mais Fácil)',
                          style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se está marcando ${live.toStringAsFixed(1)}$unit mas você sabe que está em $exampleRef$unit, digite o valor real abaixo:',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _realTempController,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              labelText: fieldLabel,
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              suffixText: unit,
                              suffixStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: AppTokens.panel2,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTokens.line)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTokens.line)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTokens.focus)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _applyRealValue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Corrigir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botões Rápidos de Trim (+0.5, +1.0, -0.5, -1.0)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text('Ajuste fino rápido:', style: TextStyle(color: Color(0xFF8C98A8), fontSize: 11)),
                  _buildQuickButton('-1.0', () => _quickTrim(-1.0)),
                  _buildQuickButton('-0.1', () => _quickTrim(-0.1)),
                  _buildQuickButton('+0.1', () => _quickTrim(0.1)),
                  _buildQuickButton('+1.0', () => _quickTrim(1.0)),
                ],
              ),

              const SizedBox(height: 12),

              // Botão para mostrar modo de engenharia avançado (escondido por padrão)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.tune, size: 16, color: const Color(0xFF8C98A8)),
                  label: Text(
                    _showAdvanced ? 'Ocultar Detalhes Técnicos' : 'Opções Avançadas (Ganho e Offset manual)',
                    style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11),
                  ),
                ),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _offsetController,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            labelText: 'Offset / Bias ($unit)',
                            labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _gainController,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            labelText: 'Ganho / Multiplicador',
                            labelStyle: TextStyle(color: Color(0xFF8C98A8), fontSize: 11),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusMessage!, style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () {
                  setState(() {
                    _offsetController.text = '0.0';
                    _gainController.text = '1.000';
                    if (widget.liveValue != null) {
                      _realTempController.text = widget.liveValue!.toStringAsFixed(1);
                    }
                  });
                },
          icon: const Icon(Icons.restore, size: 16, color: Color(0xFFE2E8F0)),
          label: const Text('Restaurar Fábrica', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8C98A8))),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _saveAll,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.focus,
            foregroundColor: AppTokens.bg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isSubmitting
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.bg))
              : const Icon(Icons.check, size: 18),
          label: const Text('APLICAR E SALVAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTokens.panel2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTokens.line),
        ),
        child: Text(label, style: TextStyle(color: AppTokens.textPrimary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
      ),
    );
  }
}
