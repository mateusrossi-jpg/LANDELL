import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/models/tag.dart';
import '../../../ladder/models/plc_tag_contract.dart';
import '../../../ladder/models/tag_value.dart';
import '../../../ladder/models/enums.dart';
import '../../services/studio_event_bus.dart';
import '../../../ladder_autosave.dart';

enum IoPointType {
  digitalInput('Digital Input'),
  digitalOutput('Digital Output'),
  analogInput('Analog Input'),
  analogOutput('Analog Output');

  final String label;
  const IoPointType(this.label);
}

class CreateIoDialog extends StatefulWidget {
  final LadderProject project;
  final ValueChanged<Tag>? onTagCreated;

  const CreateIoDialog({
    super.key,
    required this.project,
    this.onTagCreated,
  });

  static Future<Tag?> show(BuildContext context, {
    required LadderProject project,
    ValueChanged<Tag>? onTagCreated,
  }) {
    return showDialog<Tag>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateIoDialog(
        project: project,
        onTagCreated: onTagCreated,
      ),
    );
  }

  @override
  State<CreateIoDialog> createState() => _CreateIoDialogState();
}

class _CreateIoDialogState extends State<CreateIoDialog> {
  IoPointType _selectedType = IoPointType.digitalInput;
  final TextEditingController _addressController = TextEditingController(text: 'I0.0');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _suggestAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _suggestAddress() {
    final tags = widget.project.tags.values;
    switch (_selectedType) {
      case IoPointType.digitalInput:
        int next = 0;
        while (tags.any((t) => PlcTagContract.normalizeAddress(t.address ?? t.id) == 'I${next ~/ 8}.${next % 8}')) {
          next++;
        }
        if (next <= 15) {
          _addressController.text = 'I${next ~/ 8}.${next % 8}';
        }
        break;
      case IoPointType.digitalOutput:
        int next = 0;
        while (tags.any((t) => PlcTagContract.normalizeAddress(t.address ?? t.id) == 'Q${next ~/ 8}.${next % 8}')) {
          next++;
        }
        if (next <= 15) {
          _addressController.text = 'Q${next ~/ 8}.${next % 8}';
        }
        break;
      case IoPointType.analogInput:
        int nextAi = 0;
        while (tags.any((t) {
          final a = (t.address ?? t.id).toUpperCase();
          return a == 'AI0.$nextAi' || a == 'AI$nextAi';
        })) {
          nextAi++;
        }
        if (nextAi <= 7) {
          _addressController.text = 'AI0.$nextAi';
        }
        break;
      case IoPointType.analogOutput:
        int nextAo = 0;
        while (tags.any((t) {
          final a = (t.address ?? t.id).toUpperCase();
          return a == 'AO0.$nextAo' || a == 'AO$nextAo';
        })) {
          nextAo++;
        }
        if (nextAo <= 7) {
          _addressController.text = 'AO0.$nextAo';
        }
        break;
    }
  }

  String? _validateAddressCompatibility(String address, IoPointType type) {
    final canonical = PlcTagContract.normalizeAddress(address, allowExtended: true) ?? PlcTagContract.normalizeAddress(address);
    if (canonical == null) {
      return 'Endereço PLC inválido ou fora da faixa contratual (Ex: I0.0, Q0.0, AI0.0, AO0.0).';
    }

    switch (type) {
      case IoPointType.digitalInput:
        if (!canonical.startsWith('I')) {
          return 'Endereço incompatível com Entrada Digital. Use o padrão Ix.y (Ex: I0.0, I1.0).';
        }
        break;
      case IoPointType.digitalOutput:
        if (!canonical.startsWith('Q')) {
          return 'Endereço incompatível com Saída Digital. Use o padrão Qx.y (Ex: Q0.0, Q1.0).';
        }
        break;
      case IoPointType.analogInput:
        if (!canonical.startsWith('AI')) {
          return 'Endereço incompatível com Entrada Analógica. Use o padrão AIx.y (Ex: AI0.0, AI0.1).';
        }
        break;
      case IoPointType.analogOutput:
        if (!canonical.startsWith('AO')) {
          return 'Endereço incompatível com Saída Analógica. Use o padrão AOx.y (Ex: AO0.0, AO0.1).';
        }
        break;
    }
    return null;
  }

  void _submit() async {
    final address = _addressController.text.trim().toUpperCase();
    final name = _nameController.text.trim().replaceAll(' ', '_').toUpperCase();
    final unit = _unitController.text.trim();
    final desc = _descController.text.trim();

    // 1. Validations
    if (address.isEmpty) {
      setState(() => _errorMessage = 'Endereço é obrigatório (ex: I0.0, Q0.0, AI0.0).');
      return;
    }

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Nome simbólico é obrigatório (ex: I0.0, SENSOR_NIVEL).');
      return;
    }

    // Check address compatibility
    final compatError = _validateAddressCompatibility(address, _selectedType);
    if (compatError != null) {
      setState(() => _errorMessage = compatError);
      return;
    }

    // Check address duplication
    final existingAddress = widget.project.tags.values.any((t) =>
        (t.address != null && t.address!.toUpperCase() == address) ||
        t.id.toUpperCase() == address);
    if (existingAddress) {
      setState(() => _errorMessage = 'Endereço "$address" já está em uso.');
      return;
    }

    // Check name duplication
    final existingName = widget.project.tags.containsKey(name) ||
        widget.project.tags.values.any((t) => t.name.toUpperCase() == name || t.id.toUpperCase() == name);
    if (existingName) {
      setState(() => _errorMessage = 'Nome simbólico "$name" já existe no projeto.');
      return;
    }

    // Check unit for analog
    final isAnalog = _selectedType == IoPointType.analogInput || _selectedType == IoPointType.analogOutput;
    final finalUnit = unit.isNotEmpty ? unit : (isAnalog ? '°C' : '');

    // 2. Determine TagType and initial value
    final TagType tagType = isAnalog ? TagType.real : TagType.bool;
    final initialVal = tagType == TagType.bool ? TagValue.boolean(false) : TagValue.real(0.0);

    final newTag = Tag(
      id: name,
      name: name,
      type: tagType,
      address: address,
      description: desc.isNotEmpty ? desc : null,
      unit: finalUnit.isNotEmpty ? finalUnit : null,
      rawMin: isAnalog ? 0.0 : null,
      rawMax: isAnalog ? 10.0 : null,
      scaledMin: isAnalog ? 0.0 : null,
      scaledMax: isAnalog ? 100.0 : null,
      initialValue: initialVal,
    );

    // 3. Register in project model
    widget.project.tags[newTag.id] = newTag;

    // 4. Persist
    await saveCurrentLadder(widget.project);

    // 5. Emit event log
    StudioEventBus.instance.emit(
      type: 'I/O_CREATED',
      source: 'I/O_MANAGER',
      message: 'I/O CRIADO: ${newTag.name} (${newTag.address ?? newTag.type.name})',
      severity: EventSeverity.info,
    );

    if (widget.onTagCreated != null) {
      widget.onTagCreated!(newTag);
    }

    if (mounted) {
      Navigator.of(context).pop(newTag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnalog = _selectedType == IoPointType.analogInput || _selectedType == IoPointType.analogOutput;

    return Dialog(
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTokens.panel2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                        ),
                        child: const Icon(Icons.add_circle_outline, color: AppTokens.focus, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'NOVO PONTO DE I/O',
                        style: TextStyle(
                          color: AppTokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTokens.textDim, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppTokens.line, height: 20),

              // 1. TIPO
              const Text(
                'TIPO DE I/O',
                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<IoPointType>(
                    value: _selectedType,
                    dropdownColor: AppTokens.panel,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTokens.focus),
                    isExpanded: true,
                    items: IoPointType.values.map((type) {
                      return DropdownMenuItem<IoPointType>(
                        value: type,
                        child: Text(
                          type.label,
                          style: const TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (newType) {
                      if (newType != null) {
                        setState(() {
                          _selectedType = newType;
                          _suggestAddress();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. ENDEREÇO
              const Text(
                'ENDEREÇO DE HARDWARE (ex: I0.0, Q0.0, AI0.0, AO0.0)',
                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                style: const TextStyle(color: AppTokens.focus, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'I0.0',
                  hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 12),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                ),
              ),
              const SizedBox(height: 14),

              // 3. NOME SIMBÓLICO
              const Text(
                'NOME SIMBÓLICO (ex: I0.0, Q0.0, SENSOR_PRESSAO)',
                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'I0.0',
                  hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 12),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                ),
              ),
              const SizedBox(height: 14),

              // 4. UNIDADE (somente quando aplicável)
              if (isAnalog) ...[
                const Text(
                  'UNIDADE DE ENGENHARIA (ex: °C, PSI, bar, V, mA, RPM)',
                  style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _unitController,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'PSI',
                    hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 12),
                    filled: true,
                    fillColor: AppTokens.panel2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 5. DESCRIÇÃO
              const Text(
                'DESCRIÇÃO / OBSERVAÇÃO (OPCIONAL)',
                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: AppTokens.text, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Descrição da função técnica do ponto no processo...',
                  hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 11),
                  filled: true,
                  fillColor: AppTokens.panel2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                ),
              ),

              // Erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.fault.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.fault.withValues(alpha: 0.5), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTokens.fault, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTokens.fault, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Ações: CANCELAR / CRIAR
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.textDim,
                      side: const BorderSide(color: AppTokens.line, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCELAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.focus,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: _submit,
                    child: const Text('CRIAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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
