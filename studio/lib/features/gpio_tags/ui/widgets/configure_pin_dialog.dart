import 'package:flutter/material.dart';
import '../../../../ladder/models/ladder_project.dart';
import '../../../../ladder/models/tag.dart';
import '../../../../ladder/models/enums.dart';
import '../../../../ladder_autosave.dart';
import '../../services/gpio_service.dart';
import 'analog_calibration_dialog.dart';
import '../../../../design_system/tokens.dart';

enum GpioFunctionType {
  digitalInput,
  digitalOutput,
  analogInput,
  analogOutput,
  i2cAht10,
  oneWireDs18b20,
  disabled,
}

class ConfigurePinDialog extends StatefulWidget {
  final GpioInventoryPin pin;
  final LadderProject project;
  final String gatewayIp;
  final GpioService gpioService;
  final VoidCallback onConfigured;

  const ConfigurePinDialog({
    super.key,
    required this.pin,
    required this.project,
    required this.gatewayIp,
    required this.gpioService,
    required this.onConfigured,
  });

  static Future<void> show(
    BuildContext context, {
    required GpioInventoryPin pin,
    required LadderProject project,
    required String gatewayIp,
    required GpioService gpioService,
    required VoidCallback onConfigured,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => ConfigurePinDialog(
        pin: pin,
        project: project,
        gatewayIp: gatewayIp,
        gpioService: gpioService,
        onConfigured: onConfigured,
      ),
    );
  }

  @override
  State<ConfigurePinDialog> createState() => _ConfigurePinDialogState();
}

class _ConfigurePinDialogState extends State<ConfigurePinDialog> {
  static const Set<int> kEsp32StrappingPins = {0, 2, 12, 15};
  late GpioFunctionType _selectedFunction;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFunction = _detectCurrentFunction();
  }

  GpioFunctionType _detectCurrentFunction() {
    final gpio = widget.pin.gpio;
    final tags = widget.project.tags.values;

    // Verifica se há tag AHT10 associada
    if (tags.any((t) => t.id == 'TEMP_AHT10' && (gpio == 16 || gpio == 17))) {
      return GpioFunctionType.i2cAht10;
    }
    // Verifica se há tag DS18B20 associada
    if (tags.any((t) => t.id == 'TEMP_DS18B20' && gpio == 33)) {
      return GpioFunctionType.oneWireDs18b20;
    }

    if (widget.pin.state == 'IN_USE_OUTPUT') {
      return GpioFunctionType.digitalOutput;
    }
    if (widget.pin.state == 'IN_USE_INPUT') {
      return GpioFunctionType.digitalInput;
    }
    if (widget.pin.analogCapable && (gpio == 25 || gpio == 26)) {
      return GpioFunctionType.analogOutput;
    }
    if (widget.pin.analogCapable && (gpio == 35 || gpio == 36 || gpio == 39)) {
      return GpioFunctionType.analogInput;
    }
    if (widget.pin.outputCapable) {
      return GpioFunctionType.digitalOutput;
    }
    return GpioFunctionType.digitalInput;
  }

  bool _isFunctionAllowed(GpioFunctionType type) {
    final gpio = widget.pin.gpio;
    switch (type) {
      case GpioFunctionType.digitalInput:
        return widget.pin.inputCapable;
      case GpioFunctionType.digitalOutput:
        return widget.pin.outputCapable;
      case GpioFunctionType.analogInput:
        return widget.pin.analogCapable && (gpio == 34 || gpio == 35 || gpio == 36 || gpio == 39);
      case GpioFunctionType.analogOutput:
        return gpio == 25 || gpio == 26;
      case GpioFunctionType.i2cAht10:
        return gpio == 16 || gpio == 17;
      case GpioFunctionType.oneWireDs18b20:
        return gpio == 33 || gpio == 4;
      case GpioFunctionType.disabled:
        return true;
    }
  }

  Future<void> _applyConfiguration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final gpio = widget.pin.gpio;

    try {
      // 1. Limpeza de Tags antigas associadas a este pino no projeto
      final defaultIec = (gpio == 16)
          ? '%IX0.0'
          : (gpio == 17
              ? '%IX0.1'
              : (gpio == 4 ? '%QX0.0' : (gpio == 2 ? '%QX0.1' : (gpio == 25 ? '%QW0.0' : (gpio == 26 ? '%QW0.1' : '')))));

      final tagsToRemove = <String>[];
      widget.project.tags.forEach((key, tag) {
        final kUpper = key.toUpperCase();
        final addrUpper = (tag.address ?? '').toUpperCase();
        final descUpper = (tag.description ?? '').toUpperCase();

        if (tag.address == 'GPIO$gpio' ||
            tag.address == 'DI0${gpio == 16 ? 0 : 1}' ||
            (defaultIec.isNotEmpty && addrUpper == defaultIec) ||
            kUpper == 'DI_$gpio' ||
            kUpper == 'DO_$gpio' ||
            kUpper == 'ADC_GPIO$gpio' ||
            kUpper == 'DAC_GPIO$gpio' ||
            kUpper.contains('GPIO$gpio') ||
            descUpper.contains('GPIO $gpio') ||
            descUpper.contains('GPIO$gpio')) {
          tagsToRemove.add(key);
        }
      });
      for (final t in tagsToRemove) {
        widget.project.tags.remove(t);
      }

      // 2. Aplicação da nova função e criação/reorganização dinâmica de Tags
      if (_selectedFunction == GpioFunctionType.i2cAht10) {
        // Habilita AHT10 no Firmware ESP32
        await widget.gpioService.updateSensorConfig(widget.gatewayIp, {
          'aht10_enabled': 1,
          'aht10_sda_gpio': 16,
          'aht10_scl_gpio': 17,
        });

        // Cria dinamicamente as Tags analógicas de processo
        widget.project.tags['TEMP_AHT10'] = Tag(
          id: 'TEMP_AHT10',
          name: 'TEMP_AHT10',
          type: TagType.int,
          address: '%IW0.0',
          unit: '°C',
          description: 'Temperatura AHT10 (I2C SDA:GPIO16 SCL:GPIO17)',
        );
        widget.project.tags['UMID_AHT10'] = Tag(
          id: 'UMID_AHT10',
          name: 'UMID_AHT10',
          type: TagType.int,
          address: '%IW0.1',
          unit: '%',
          description: 'Umidade Relativa AHT10 (I2C SDA:GPIO16 SCL:GPIO17)',
        );
      } else if (_selectedFunction == GpioFunctionType.oneWireDs18b20) {
        await widget.gpioService.updateSensorConfig(widget.gatewayIp, {
          'ds18b20_enabled': 1,
          'ds18b20_gpio': gpio,
        });
        widget.project.tags['TEMP_DS18B20'] = Tag(
          id: 'TEMP_DS18B20',
          name: 'TEMP_DS18B20',
          type: TagType.int,
          address: '%IW0.2',
          unit: '°C',
          description: 'Temperatura DS18B20 (1-Wire GPIO$gpio)',
        );
      } else if (_selectedFunction == GpioFunctionType.digitalInput) {
        // Se estava em AHT10, desabilita no firmware
        if (gpio == 16 || gpio == 17) {
          await widget.gpioService.updateSensorConfig(widget.gatewayIp, {
            'aht10_enabled': 0,
          });
          widget.project.tags.remove('TEMP_AHT10');
          widget.project.tags.remove('UMID_AHT10');
        }
        // Gera endereço sequencial dinâmico
        final tagId = 'IN_GPIO$gpio';
        widget.project.tags[tagId] = Tag(
          id: tagId,
          name: tagId,
          type: TagType.bool,
          address: 'GPIO$gpio',
          description: 'Entrada Digital Discreta (GPIO $gpio)',
        );
      } else if (_selectedFunction == GpioFunctionType.digitalOutput) {
        final tagId = 'OUT_GPIO$gpio';
        widget.project.tags[tagId] = Tag(
          id: tagId,
          name: tagId,
          type: TagType.bool,
          address: 'GPIO$gpio',
          description: 'Saída Digital Discreta (GPIO $gpio)',
        );
      } else if (_selectedFunction == GpioFunctionType.analogOutput) {
        final tagId = 'DAC_GPIO$gpio';
        final aoAddr = gpio == 25 ? '%QW0.0' : '%QW0.1';
        widget.project.tags[tagId] = Tag(
          id: tagId,
          name: tagId,
          type: TagType.int,
          address: aoAddr,
          unit: '% (DAC)',
          description: 'Saída Analógica Proporcional (GPIO $gpio)',
        );
      } else if (_selectedFunction == GpioFunctionType.analogInput) {
        final tagId = 'ADC_GPIO$gpio';
        final aiAddr = gpio == 35 ? '%IW0.0' : (gpio == 36 ? '%IW0.1' : '%IW0.2');
        widget.project.tags[tagId] = Tag(
          id: tagId,
          name: tagId,
          type: TagType.int,
          address: aiAddr,
          unit: 'mV',
          description: 'Entrada Analógica ADC (GPIO $gpio)',
        );
      }

      // Salva projeto
      await saveCurrentLadder(widget.project);
      widget.onConfigured();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao sincronizar com hardware: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpio = widget.pin.gpio;

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
              color: const Color(0xFF4FD1C5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.settings_input_composite, color: Color(0xFF4FD1C5), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONFIGURAR GPIO $gpio',
                  style: const TextStyle(
                    color: Color(0xFFE7EBF0),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hardware Setup Industrial • Atribuição Dinâmica de TAGs',
                  style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9503F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD9503F)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 11)),
                ),

              const Text(
                'SELECIONE A FUNÇÃO DO PINO:',
                style: TextStyle(color: Color(0xFF8C98A8), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),

              _buildOptionTile(
                type: GpioFunctionType.digitalInput,
                icon: Icons.login,
                color: const Color(0xFF4FD1C5),
                title: 'Entrada Digital (DI)',
                desc: 'Botão, chave fim de curso, sensor óptico/indutivo (%IX)',
              ),
              const SizedBox(height: 6),

              _buildOptionTile(
                type: GpioFunctionType.digitalOutput,
                icon: Icons.logout,
                color: const Color(0xFFFF9500),
                title: 'Saída Digital (DO)',
                desc: 'Acionamento de relé, solenoide, contator (%QX)',
              ),
              if (kEsp32StrappingPins.contains(gpio) && _selectedFunction == GpioFunctionType.digitalOutput)
                Container(
                  key: const Key('strapping_pin_warning_banner'),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B1C10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALERTA: PINO DE BOOT / STRAPPING PIN (GPIO $gpio)',
                              style: const TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'A GPIO $gpio é um pino crítico de strapping do ESP32. Durante o reset/boot, seu nível lógico define o modo de inicialização ou voltagem da memória Flash. '
                              'Evite conectar relés ou cargas pesadas que possam puxar esta linha no momento da partida.',
                              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              _buildOptionTile(
                type: GpioFunctionType.analogInput,
                icon: Icons.show_chart,
                color: const Color(0xFF8B5CF6),
                title: 'Entrada Analógica (AI / ADC)',
                desc: 'Sensor de processo linear (0-3.3V / 4-20mA via resistor) (%IW)',
              ),
              const SizedBox(height: 6),

              _buildOptionTile(
                type: GpioFunctionType.analogOutput,
                icon: Icons.speed,
                color: const Color(0xFF3B82F6),
                title: 'Saída Analógica (AO / DAC)',
                desc: 'Conversor DAC 8 bits nativo para sinal analógico (%QW)',
              ),
              const SizedBox(height: 6),

              _buildOptionTile(
                type: GpioFunctionType.i2cAht10,
                icon: Icons.thermostat,
                color: const Color(0xFF10B981),
                title: 'Sensor I2C (AHT10 Temp & Umidade)',
                desc: 'Ativa barramento I2C inteligente. Cria TAGs %IW de Temp e Umidade',
              ),
              const SizedBox(height: 6),

              _buildOptionTile(
                type: GpioFunctionType.oneWireDs18b20,
                icon: Icons.device_thermostat,
                color: const Color(0xFFEC4899),
                title: 'Sensor 1-Wire (DS18B20)',
                desc: 'Barramento digital Dallas 1-Wire para sonda térmica (%IW)',
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_selectedFunction == GpioFunctionType.i2cAht10) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.warn,
              foregroundColor: AppTokens.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.thermostat, size: 16),
            label: const Text('CALIBRAR TEMPERATURA (°C)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            onPressed: () {
              final targetTag = widget.project.tags['TEMP_AHT10'] ?? Tag(
                id: 'TEMP_AHT10',
                name: 'TEMP_AHT10',
                type: TagType.real,
                address: '%IW0.0',
                unit: '°C',
                description: 'Temperatura AHT10 (I2C SDA:GPIO16 SCL:GPIO17)',
              );
              showDialog(
                context: context,
                builder: (ctx) => AnalogCalibrationDialog(
                  tag: targetTag,
                  gatewayUrl: 'http://${widget.gatewayIp}',
                  onSaveProject: (newOffset, newGain) async {
                    widget.project.tags[targetTag.id] = Tag(
                      id: targetTag.id,
                      name: targetTag.name,
                      type: targetTag.type,
                      address: targetTag.address,
                      unit: targetTag.unit,
                      description: targetTag.description,
                      calOffset: newOffset,
                      calGain: newGain,
                    );
                    await saveCurrentLadder(widget.project);
                    widget.onConfigured();
                  },
                ),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
            ),
            icon: const Icon(Icons.water_drop, size: 16),
            label: const Text('CALIBRAR UMIDADE (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            onPressed: () {
              final targetTag = widget.project.tags['UMID_AHT10'] ?? Tag(
                id: 'UMID_AHT10',
                name: 'UMID_AHT10',
                type: TagType.real,
                address: '%IW0.1',
                unit: '%',
                description: 'Umidade Relativa AHT10 (I2C SDA:GPIO16 SCL:GPIO17)',
              );
              showDialog(
                context: context,
                builder: (ctx) => AnalogCalibrationDialog(
                  tag: targetTag,
                  gatewayUrl: 'http://${widget.gatewayIp}',
                  onSaveProject: (newOffset, newGain) async {
                    widget.project.tags[targetTag.id] = Tag(
                      id: targetTag.id,
                      name: targetTag.name,
                      type: targetTag.type,
                      address: targetTag.address,
                      unit: targetTag.unit,
                      description: targetTag.description,
                      calOffset: newOffset,
                      calGain: newGain,
                    );
                    await saveCurrentLadder(widget.project);
                    widget.onConfigured();
                  },
                ),
              );
            },
          ),
        ] else if (_selectedFunction == GpioFunctionType.analogInput ||
            _selectedFunction == GpioFunctionType.oneWireDs18b20) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.warn,
              foregroundColor: AppTokens.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('CALIBRAR VARIÁVEL', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final tagKey = _selectedFunction == GpioFunctionType.oneWireDs18b20
                  ? 'TEMP_DS18B20'
                  : 'ADC_GPIO${widget.pin.gpio}';
              final targetTag = widget.project.tags[tagKey] ?? Tag(
                id: tagKey,
                name: tagKey,
                type: TagType.real,
                address: _selectedFunction == GpioFunctionType.oneWireDs18b20 ? '%IW0.2' : '%IW0.0',
                unit: _selectedFunction == GpioFunctionType.oneWireDs18b20 ? '°C' : 'mV',
              );
              showDialog(
                context: context,
                builder: (ctx) => AnalogCalibrationDialog(
                  tag: targetTag,
                  gatewayUrl: 'http://${widget.gatewayIp}',
                  onSaveProject: (newOffset, newGain) async {
                    widget.project.tags[targetTag.id] = Tag(
                      id: targetTag.id,
                      name: targetTag.name,
                      type: targetTag.type,
                      address: targetTag.address,
                      unit: targetTag.unit,
                      description: targetTag.description,
                      calOffset: newOffset,
                      calGain: newGain,
                    );
                    await saveCurrentLadder(widget.project);
                    widget.onConfigured();
                  },
                ),
              );
            },
          ),
        ],
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTokens.muted,
            side: BorderSide(color: AppTokens.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTokens.focus,
            foregroundColor: AppTokens.bg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _applyConfiguration,
          child: _isLoading
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.bg))
              : const Text('APLICAR AO CONTROLADOR', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required GpioFunctionType type,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    final allowed = _isFunctionAllowed(type);
    final isSelected = _selectedFunction == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: allowed ? () => setState(() => _selectedFunction = type) : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : (allowed ? AppTokens.panel2 : AppTokens.bg),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? color
                  : (allowed ? AppTokens.line : AppTokens.panel),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: allowed ? color : AppTokens.muted.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: allowed ? AppTokens.textPrimary : AppTokens.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!allowed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTokens.panel,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTokens.line),
                            ),
                            child: Text('INDISPONÍVEL NESTE PINO', style: TextStyle(color: AppTokens.muted, fontSize: 8, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        color: allowed ? AppTokens.muted : AppTokens.muted.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<GpioFunctionType>(
                value: type,
                groupValue: _selectedFunction,
                activeColor: color,
                onChanged: allowed ? (v) => setState(() => _selectedFunction = v!) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
