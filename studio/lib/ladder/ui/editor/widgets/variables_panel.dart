import '../../../../design_system/tokens.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/network_manager.dart';
import '../../../models/tag.dart';
import '../../../models/tag_value.dart';
import '../../../models/enums.dart';
import '../../../models/plc_tag_contract.dart';
import '../../../../features/gpio_tags/ui/widgets/analog_calibration_dialog.dart';

enum PanelState { collapsed, semi, full }

class VariablesPanel extends StatefulWidget {
  final Map<String, Tag> tags;
  final Map<String, bool> simulationInputs;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<Tag>? onTagCreated;
  final ValueChanged<Tag>? onTagUpdated;
  final ValueChanged<String> onTagRemoved;
  final Function(String, bool) onSimulationInputChanged;

  /// Em modo HARDWARE as tags são monitoradas ao vivo (somente leitura).
  final bool isHardwareMode;
  final Map<String, bool>? liveValues;
  final Map<String, String>? liveAnalogValues;
  final NetworkManager? networkManager;

  const VariablesPanel({
    super.key,
    required this.tags,
    required this.simulationInputs,
    required this.onTagAdded,
    this.onTagCreated,
    this.onTagUpdated,
    required this.onTagRemoved,
    required this.onSimulationInputChanged,
    this.isHardwareMode = false,
    this.liveValues,
    this.liveAnalogValues,
    this.networkManager,
  });

  @override
  State<VariablesPanel> createState() => _VariablesPanelState();
}

class _VariablesPanelState extends State<VariablesPanel> {
  PanelState _panelState = PanelState.collapsed;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.networkManager?.addListener(_onNetworkChanged);
  }

  @override
  void didUpdateWidget(VariablesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkManager != widget.networkManager) {
      oldWidget.networkManager?.removeListener(_onNetworkChanged);
      widget.networkManager?.addListener(_onNetworkChanged);
    }
  }

  @override
  void dispose() {
    widget.networkManager?.removeListener(_onNetworkChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onNetworkChanged() {
    if (mounted) setState(() {});
  }

  void _addVariable(String tagId) {
    widget.onTagAdded(tagId);
  }

  Future<void> _openTagDialog([Tag? existingTag]) async {
    final isEdit = existingTag != null;
    final nameCtrl = TextEditingController(text: existingTag?.name ?? existingTag?.id ?? '');
    final idCtrl = TextEditingController(text: existingTag?.id ?? '');
    final addressCtrl = TextEditingController(text: existingTag?.address ?? '');
    final descCtrl = TextEditingController(text: existingTag?.description ?? '');
    TagType selectedType = existingTag?.type ?? TagType.bool;

    final result = await showDialog<Tag>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTokens.line, width: 1.0),
          ),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_note : Icons.add_circle_outline,
                color: const Color(0xFF4FD1C5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'Editar variável (Tag)' : 'Criar nova variável (Tag)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE7EBF0),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEdit) ...[
                  TextField(
                    controller: idCtrl,
                    style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'ID / Nome da Tag (ex: TEMP_MAX, HEATER_1)',
                      labelStyle: TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Nome Amigável' : 'Descrição / Nome Curto',
                    labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tipo de dado (IEC):',
                  style: TextStyle(color: Color(0xFF8C98A8), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: TagType.values.map((t) {
                    final isSel = selectedType == t;
                    return ChoiceChip(
                      label: Text(
                        t.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSel ? AppTokens.bg : AppTokens.textPrimary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: const Color(0xFF4FD1C5),
                      backgroundColor: AppTokens.panel2,
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedType = t);
                      },
                    );
                  }).toList(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addressCtrl,
                        style: const TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Endereço PLC / Físico (ex: I0.4, Q0.0)',
                          labelStyle: TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.bolt, color: Color(0xFF4FD1C5), size: 20),
                      tooltip: 'Selecionar canal físico ativo',
                      onSelected: (addr) {
                        setDialogState(() {
                          addressCtrl.text = addr;
                        });
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(enabled: false, child: Text('--- NÓ 0 (GATEWAY) ---', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
                        ...['I00', 'I01', 'I02', 'I03', 'I04', 'Q00', 'Q01', 'Q02', 'Q03', 'Q04', 'AI00', 'AO00'].map((a) => PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono')))),
                        const PopupMenuItem(enabled: false, child: Text('--- NÓ 1 (CAMPO) ---', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34D399)))),
                        ...['I10', 'I11', 'I12', 'I13', 'I14', 'Q10', 'Q11', 'Q12', 'Q13', 'Q14', 'AI10', 'AO10'].map((a) => PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono')))),
                        const PopupMenuItem(enabled: false, child: Text('--- NÓ 2 (CAMPO) ---', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)))),
                        ...['I20', 'I21', 'I22', 'I23', 'I24', 'Q20', 'Q21', 'Q22', 'Q23', 'Q24', 'AI20', 'AO20'].map((a) => PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono')))),
                        const PopupMenuItem(enabled: false, child: Text('--- NÓ 3 (CAMPO) ---', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA78BFA)))),
                        ...['I30', 'I31', 'I32', 'I33', 'I34', 'Q30', 'Q31', 'Q32', 'Q33', 'Q34', 'AI30', 'AO30'].map((a) => PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono')))),
                        const PopupMenuItem(enabled: false, child: Text('--- MEMÓRIA / TIMERS ---', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE0A430)))),
                        ...['M0.0', 'T0', 'C0'].map((a) => PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono')))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Descrição / Função no processo',
                    labelStyle: TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8C98A8))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTokens.focus, foregroundColor: AppTokens.bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final rawAddr = addressCtrl.text.trim();
                final canonicalAddr = PlcTagContract.normalizeAddress(rawAddr);
                if (canonicalAddr == null && rawAddr.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Endereço PLC inválido. Use I00..I97, Q00..Q97, I0.0..I9.7, Q0.0..Q9.7, M0.0..M1.5, T0..T15 ou C0..C15')),
                  );
                  return;
                }
                final tagId = isEdit ? existingTag.id : (canonicalAddr ?? idCtrl.text.trim().toUpperCase());
                if (tagId.isEmpty) return;

                final resolvedType = canonicalAddr != null
                    ? (PlcTagContract.getTagTypeForAddress(canonicalAddr) ?? selectedType)
                    : selectedType;

                final tag = Tag(
                  id: tagId,
                  name: nameCtrl.text.trim().isEmpty ? tagId : nameCtrl.text.trim(),
                  type: resolvedType,
                  address: canonicalAddr ?? (rawAddr.isNotEmpty ? rawAddr : null),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  initialValue: resolvedType == TagType.bool
                      ? TagValue.boolean(false)
                      : TagValue.integer(0),
                );
                Navigator.pop(dialogContext, tag);
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (isEdit) {
        widget.onTagUpdated?.call(result);
      } else {
        if (widget.onTagCreated != null) {
          widget.onTagCreated!(result);
        } else {
          widget.onTagAdded(result.id);
        }
      }
    }
  }

  double _calculatePanelHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenHeight < 500;
    switch (_panelState) {
      case PanelState.collapsed:
        return 44.0;
      case PanelState.semi:
        return isLandscape ? (screenHeight * 0.45).clamp(130.0, 180.0) : 220.0;
      case PanelState.full:
        return isLandscape ? (screenHeight * 0.70).clamp(180.0, 260.0) : 380.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFieldNodeIndexes = <int>{};
    final tagsList = widget.tags.values.where((t) {
      final addr = (t.address ?? t.id).toUpperCase();
      final match = RegExp(r'^(I|Q|AI|AO)(\d+)').firstMatch(addr);
      if (match != null) {
        final idx = int.tryParse(match.group(2)!);
        if (idx != null && idx > 0) {
          return activeFieldNodeIndexes.contains(idx);
        }
      }
      return true;
    }).toList();

    final activeCount = widget.isHardwareMode
        ? (widget.liveValues != null
            ? tagsList.where((t) => widget.liveValues![t.id] == true).length
            : 0)
        : tagsList.where((t) => widget.simulationInputs[t.id] == true).length;
    final height = _calculatePanelHeight(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: height,
      clipBehavior: Clip.hardEdge,
      color: AppTokens.panel,
      child: _panelState == PanelState.collapsed
          ? Column(
              children: [
                Container(height: 1.0, color: AppTokens.line),
                Expanded(child: _buildHeaderTab(activeCount, tagsList.length)),
              ],
            )
          : Column(
              children: [
                Container(height: 1.0, color: AppTokens.line),
                SizedBox(
                  height: 43.0,
                  child: _buildHeaderTab(activeCount, tagsList.length),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Input Form to Add Custom Variable
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 34,
                                  child: TextField(
                                    controller: _textController,
                                    style: const TextStyle(color: Color(0xFFE7EBF0), fontSize: 12, fontFamily: 'JetBrains Mono'),
                                    decoration: InputDecoration(
                                      hintText: 'Tag personalizada (ex: SENSOR)',
                                      hintStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11, fontFamily: 'sans-serif'),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      filled: true,
                                      fillColor: AppTokens.panel2,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: AppTokens.line),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: AppTokens.line),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(color: Color(0xFF4FD1C5)),
                                      ),
                                    ),
                                    onSubmitted: (val) {
                                      _addVariable(val);
                                      _textController.clear();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 34,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4FD1C5),
                                    foregroundColor: AppTokens.bg,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    _addVariable(_textController.text);
                                    _textController.clear();
                                  },
                                  child: const Text('Adicionar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 34,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4FD1C5),
                                    side: const BorderSide(color: Color(0xFF4FD1C5), width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Nova', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _openTagDialog(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 12, color: AppTokens.line),

                        // Tag List with Force Switches & Status LEDs
                        if (tagsList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Nenhuma variável cadastrada no projeto.',
                                style: TextStyle(color: Color(0xFF8C98A8), fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            itemCount: tagsList.length,
                            itemBuilder: (context, index) {
                              final tag = tagsList[index];
                              final isValueTrue = widget.isHardwareMode
                                  ? (widget.liveValues?[tag.id] ?? false)
                                  : (widget.simulationInputs[tag.id] ?? false);

                              final isBoolTag = tag.type == TagType.bool;
                              final tagTile = Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isValueTrue
                                      ? const Color(0xFF3FBF5A).withValues(alpha: 0.1)
                                      : AppTokens.panel2,
                                  border: Border.all(
                                    color: isValueTrue
                                        ? const Color(0xFF3FBF5A).withValues(alpha: 0.5)
                                        : AppTokens.line,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: isBoolTag && !widget.isHardwareMode
                                            ? () => widget.onSimulationInputChanged(tag.id, !isValueTrue)
                                            : null,
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isValueTrue
                                                    ? const Color(0xFF3FBF5A)
                                                    : AppTokens.line,
                                                boxShadow: isValueTrue
                                                    ? [
                                                        const BoxShadow(
                                                          color: Color(0xFF3FBF5A),
                                                          blurRadius: 4,
                                                        )
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        tag.id,
                                                        style: const TextStyle(
                                                          color: Color(0xFFE7EBF0),
                                                          fontFamily: 'JetBrains Mono',
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: AppTokens.panel,
                                                          borderRadius: BorderRadius.circular(3),
                                                          border: Border.all(color: AppTokens.line, width: 0.8),
                                                        ),
                                                        child: Text(
                                                          tag.type.name.toUpperCase(),
                                                          style: const TextStyle(
                                                            color: Color(0xFF8C98A8),
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (tag.address != null) ...[
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '· ${tag.address}',
                                                          style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 10, fontFamily: 'JetBrains Mono'),
                                                        ),
                                                      ],
                                                      if (tag.unit != null && tag.unit!.isNotEmpty) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF0F291E),
                                                            borderRadius: BorderRadius.circular(3),
                                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 0.8),
                                                          ),
                                                          child: Text(
                                                            tag.unit == '%' ? 'Unid: % (0-100%)' : 'Unid: ${tag.unit}',
                                                            style: const TextStyle(
                                                              color: Color(0xFF34D399),
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              fontFamily: 'JetBrains Mono',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (widget.liveAnalogValues != null && widget.liveAnalogValues!.containsKey(tag.id)) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF1E293B),
                                                            borderRadius: BorderRadius.circular(3),
                                                            border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                                                          ),
                                                          child: Text(
                                                            'Atual: ${widget.liveAnalogValues![tag.id]}',
                                                            style: const TextStyle(
                                                              color: Color(0xFF38BDF8),
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              fontFamily: 'JetBrains Mono',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (tag.name != tag.id || tag.description != null) ...[
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      tag.description ?? tag.name,
                                                      style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 10),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (tag.type == TagType.real || (tag.address?.startsWith('%IW') ?? false) || (tag.address?.startsWith('AI') ?? false)) ...[
                                      InkWell(
                                        onTap: () {
                                          final gatewayIp = widget.networkManager?.gatewayIp.trim().isNotEmpty == true
                                              ? widget.networkManager!.gatewayIp.trim()
                                              : '192.168.4.1';
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AnalogCalibrationDialog(
                                              tag: tag,
                                              gatewayUrl: 'http://$gatewayIp',
                                              onSaveProject: (newOffset, newGain) {
                                                final updated = Tag(
                                                  id: tag.id,
                                                  name: tag.name,
                                                  type: tag.type,
                                                  address: tag.address,
                                                  unit: tag.unit,
                                                  description: tag.description,
                                                  calOffset: newOffset,
                                                  calGain: newGain,
                                                );
                                                widget.onTagUpdated?.call(updated);
                                              },
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.tune, size: 15, color: Color(0xFFF59E0B)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    InkWell(
                                      onTap: () => _openTagDialog(tag),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.edit_outlined, size: 15, color: Color(0xFF4FD1C5)),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => widget.onTagRemoved(tag.id),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close, size: 14, color: Color(0xFF8C98A8)),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              return LongPressDraggable<Map<String, dynamic>>(
                                delay: const Duration(milliseconds: 180),
                                data: {
                                  'type': 'tag',
                                  'tagId': tag.id,
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: tagTile,
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: tagTile,
                                ),
                                child: tagTile,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderTab(int activeCount, int totalCount) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -6) {
          if (_panelState == PanelState.collapsed) {
            setState(() => _panelState = PanelState.semi);
          } else if (_panelState == PanelState.semi) {
            setState(() => _panelState = PanelState.full);
          }
        } else if (details.primaryDelta! > 6) {
          if (_panelState == PanelState.full) {
            setState(() => _panelState = PanelState.semi);
          } else if (_panelState == PanelState.semi) {
            setState(() => _panelState = PanelState.collapsed);
          }
        }
      },
      onTap: () {
        setState(() {
          if (_panelState == PanelState.collapsed) {
            _panelState = PanelState.semi;
          } else {
            _panelState = PanelState.collapsed;
          }
        });
      },
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 5,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTokens.line,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 10, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: Color(0xFF4FD1C5), size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Monitor I/O',
                    style: TextStyle(
                      color: Color(0xFFE7EBF0),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: activeCount > 0
                          ? const Color(0xFF3FBF5A).withValues(alpha: 0.15)
                          : AppTokens.panel2,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: activeCount > 0 ? const Color(0xFF3FBF5A) : AppTokens.line,
                      ),
                    ),
                    child: Text(
                      '$activeCount/$totalCount',
                      style: TextStyle(
                        color: activeCount > 0 ? const Color(0xFF3FBF5A) : const Color(0xFF8C98A8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      setState(() {
                        if (_panelState == PanelState.collapsed) {
                          _panelState = PanelState.semi;
                        } else if (_panelState == PanelState.semi) {
                          _panelState = PanelState.full;
                        } else {
                          _panelState = PanelState.collapsed;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _panelState == PanelState.collapsed
                            ? Icons.keyboard_arrow_up
                            : _panelState == PanelState.semi
                                ? Icons.open_in_full
                                : Icons.keyboard_arrow_down,
                        color: const Color(0xFF4FD1C5),
                        size: 20,
                      ),
                    ),
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
