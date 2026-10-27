import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../models/home_widget_config.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/models/tag.dart';
import '../../../ladder/models/enums.dart';

class WidgetConfigDialog extends StatefulWidget {
  final LadderProject project;
  final WidgetTemplateType templateType;
  final HomeWidgetConfig? existingWidget;
  final String? initialTagId;

  const WidgetConfigDialog({
    super.key,
    required this.project,
    required this.templateType,
    this.existingWidget,
    this.initialTagId,
  });

  static Future<HomeWidgetConfig?> show(
    BuildContext context, {
    required LadderProject project,
    required WidgetTemplateType templateType,
    HomeWidgetConfig? existingWidget,
    String? initialTagId,
  }) {
    return showDialog<HomeWidgetConfig>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WidgetConfigDialog(
        project: project,
        templateType: templateType,
        existingWidget: existingWidget,
        initialTagId: initialTagId,
      ),
    );
  }

  @override
  State<WidgetConfigDialog> createState() => _WidgetConfigDialogState();
}

class _WidgetConfigDialogState extends State<WidgetConfigDialog> {
  late TextEditingController _titleController;
  late TextEditingController _unitController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _warningMaxController;
  late TextEditingController _criticalMaxController;
  late TextEditingController _onTextController;
  late TextEditingController _offTextController;
  late TextEditingController _tagSearchController;

  String? _selectedTagId;
  int _decimalPlaces = 1;
  late WidgetSizePreset _sizePreset;

  bool _isSelectingTag = false;
  String _tagSearchQuery = '';
  String _selectedCategory = 'TODAS';

  @override
  void initState() {
    super.initState();
    final w = widget.existingWidget;
    _selectedTagId = w?.tagId ?? widget.initialTagId;
    _sizePreset = w?.sizePreset ??
        (widget.templateType == WidgetTemplateType.actuator || widget.templateType == WidgetTemplateType.ioMatrix
            ? WidgetSizePreset.wide
            : WidgetSizePreset.standard);
    _decimalPlaces = w?.decimalPlaces ?? 1;

    _titleController = TextEditingController(text: w?.title ?? _suggestTitle());
    _unitController = TextEditingController(text: w?.unit ?? _suggestUnit());
    _minController = TextEditingController(text: w?.minValue?.toString() ?? '0');
    _maxController = TextEditingController(text: w?.maxValue?.toString() ?? '100');
    _warningMaxController = TextEditingController(text: w?.warningMax?.toString() ?? '');
    _criticalMaxController = TextEditingController(text: w?.criticalMax?.toString() ?? '');
    _onTextController = TextEditingController(text: w?.onText ?? 'ON');
    _offTextController = TextEditingController(text: w?.offText ?? 'OFF');
    _tagSearchController = TextEditingController();

    // Auto-select first tag if none selected and not editing
    if (_selectedTagId == null && widget.project.tags.isNotEmpty && widget.templateType != WidgetTemplateType.ioMatrix) {
      _selectedTagId = widget.project.tags.keys.first;
    }
    if (_selectedTagId != null) {
      _onTagChanged(_selectedTagId);
    }
  }

  String _suggestTitle() {
    switch (widget.templateType) {
      case WidgetTemplateType.gauge:
        return 'PRESSÃO AI0.1';
      case WidgetTemplateType.sparkline:
        return 'ENTRADA ANALÓGICA AI0.0';
      case WidgetTemplateType.numeric:
        return 'SAÍDA ANALÓGICA AO0.0';
      case WidgetTemplateType.digital:
        return 'ENTRADA DIGITAL I0.0';
      case WidgetTemplateType.actuator:
        return 'SAÍDA DIGITAL Q0.0';
      case WidgetTemplateType.metric:
        return 'EFICIÊNCIA';
      case WidgetTemplateType.ioMatrix:
        return 'DIGITAL I/O MATRIX';
    }
  }

  String _suggestUnit() {
    switch (widget.templateType) {
      case WidgetTemplateType.gauge:
        return 'PSI';
      case WidgetTemplateType.sparkline:
        return '°C';
      case WidgetTemplateType.numeric:
        return 'RPM';
      case WidgetTemplateType.metric:
        return '%';
      default:
        return '';
    }
  }

  void _onTagChanged(String? tagId) {
    final oldTagId = _selectedTagId;
    setState(() {
      _selectedTagId = tagId;
      if (tagId != null && widget.project.tags.containsKey(tagId)) {
        final tag = widget.project.tags[tagId]!;
        final oldTag = oldTagId != null ? widget.project.tags[oldTagId] : null;

        final isDefaultOrOldTitle = _titleController.text.isEmpty ||
            _titleController.text == _suggestTitle() ||
            (oldTag != null && (_titleController.text == oldTag.name || _titleController.text == (oldTag.description ?? '')));
        if (isDefaultOrOldTitle) {
          _titleController.text = tag.description ?? tag.name;
        }

        final isDefaultOrOldUnit = _unitController.text.isEmpty ||
            _unitController.text == _suggestUnit() ||
            (oldTag != null && _unitController.text == (oldTag.unit ?? ''));
        if (tag.unit != null && tag.unit!.isNotEmpty && isDefaultOrOldUnit) {
          _unitController.text = tag.unit!;
        }

        if (tag.scaledMin != null) {
          _minController.text = tag.scaledMin!.toString();
        }
        if (tag.scaledMax != null) {
          _maxController.text = tag.scaledMax!.toString();
        }
        // Faixas industriais recomendadas para sensores conhecidos
        if (tag.id == 'TEMP_AHT10' || (tag.unit == '°C' && _warningMaxController.text.isEmpty)) {
          _minController.text = '0';
          _maxController.text = '60';
          _warningMaxController.text = '30';
          _criticalMaxController.text = '45';
        } else if (tag.id == 'UMID_AHT10' || (tag.unit == '%' && _warningMaxController.text.isEmpty)) {
          _minController.text = '0';
          _maxController.text = '100';
          _warningMaxController.text = '70';
          _criticalMaxController.text = '85';
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _warningMaxController.dispose();
    _criticalMaxController.dispose();
    _onTextController.dispose();
    _offTextController.dispose();
    _tagSearchController.dispose();
    super.dispose();
  }

  bool _matchesCategory(Tag tag, String category) {
    if (category == 'TODAS') return true;
    final addr = (tag.address ?? '').toUpperCase();
    final name = tag.name.toUpperCase();
    final isBool = tag.type == TagType.bool;
    final isNum = tag.type == TagType.int || tag.type == TagType.dint || tag.type == TagType.real;

    if (category == 'ENTRADAS') {
      return addr.startsWith('I') || addr.startsWith('%I') || addr.startsWith('X') || (isBool && name.contains('IN'));
    }
    if (category == 'SAÍDAS') {
      return addr.startsWith('Q') || addr.startsWith('%Q') || addr.startsWith('Y') || (isBool && (name.contains('OUT') || name.contains('MOTOR') || name.contains('VALV') || name.contains('COIL')));
    }
    if (category == 'ANALÓGICAS') {
      return addr.startsWith('AI') || addr.startsWith('AO') || addr.startsWith('%IW') || addr.startsWith('%QW') || isNum;
    }
    if (category == 'MEMÓRIAS') {
      return addr.startsWith('M') || addr.startsWith('%M') || addr.startsWith('T') || addr.startsWith('C');
    }
    return true;
  }

  List<Tag> _getFilteredTags(List<Tag> allTags) {
    return allTags.where((tag) {
      if (!_matchesCategory(tag, _selectedCategory)) return false;
      if (_tagSearchQuery.trim().isEmpty) return true;
      final q = _tagSearchQuery.trim().toUpperCase();
      final name = tag.name.toUpperCase();
      final addr = (tag.address ?? '').toUpperCase();
      final desc = (tag.description ?? '').toUpperCase();
      return name.contains(q) || addr.contains(q) || desc.contains(q);
    }).toList();
  }

  Color _categoryColor(Tag tag) {
    final addr = (tag.address ?? '').toUpperCase();
    if (addr.startsWith('I') || addr.startsWith('%I') || addr.startsWith('X')) {
      return const Color(0xFF10B981);
    }
    if (addr.startsWith('Q') || addr.startsWith('%Q') || addr.startsWith('Y')) {
      return const Color(0xFFF59E0B);
    }
    if (addr.startsWith('AI') || addr.startsWith('AO') || addr.startsWith('%IW') || addr.startsWith('%QW')) {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFFA78BFA);
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = categoryKey;
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppTokens.focus.withValues(alpha: 0.15) : AppTokens.panel2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? AppTokens.focus : AppTokens.line,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontFamily: 'monospace',
              color: isSelected ? AppTokens.focus : AppTokens.textDim,
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTokens.panel,
          content: Text('Por favor, informe o título do widget.', style: TextStyle(color: AppTokens.fault)),
        ),
      );
      return;
    }

    final unit = _unitController.text.trim();
    final minVal = double.tryParse(_minController.text.trim());
    final maxVal = double.tryParse(_maxController.text.trim());
    final warnMax = double.tryParse(_warningMaxController.text.trim());
    final critMax = double.tryParse(_criticalMaxController.text.trim());

    final id = widget.existingWidget?.id ?? 'widget_${DateTime.now().millisecondsSinceEpoch}';
    final order = widget.existingWidget?.order ?? 0;

    final config = HomeWidgetConfig(
      id: id,
      tagId: _selectedTagId,
      templateType: widget.templateType,
      title: title,
      unit: unit.isNotEmpty ? unit : null,
      minValue: minVal,
      maxValue: maxVal,
      warningMax: warnMax,
      criticalMax: critMax,
      decimalPlaces: _decimalPlaces,
      onText: _onTextController.text.trim().isNotEmpty ? _onTextController.text.trim() : 'ON',
      offText: _offTextController.text.trim().isNotEmpty ? _offTextController.text.trim() : 'OFF',
      order: order,
      sizePreset: _sizePreset,
      visible: true,
      customConfig: widget.existingWidget?.customConfig,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final isAnalog = widget.templateType == WidgetTemplateType.gauge ||
        widget.templateType == WidgetTemplateType.sparkline ||
        widget.templateType == WidgetTemplateType.numeric;
    final isDigital = widget.templateType == WidgetTemplateType.digital;
    final isMatrix = widget.templateType == WidgetTemplateType.ioMatrix;

    final tags = widget.project.tags.values.toList();

    return Dialog(
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
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
                        child: const Icon(Icons.tune, color: AppTokens.focus, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingWidget != null ? 'EDITAR WIDGET' : 'CONFIGURAR WIDGET',
                            style: const TextStyle(
                              color: AppTokens.text,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            widget.templateType.label,
                            style: const TextStyle(color: AppTokens.focus, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ],
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

              // 1. Smart Tag Selector
              if (!isMatrix) ...[
                Builder(
                  builder: (context) {
                    final selectedTag = _selectedTagId != null && widget.project.tags.containsKey(_selectedTagId)
                        ? widget.project.tags[_selectedTagId]
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'VARIÁVEL / TAG DO CLP (IEC 61131-3)',
                          style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 6),
                        if (!_isSelectingTag)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTokens.panel2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.line, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: selectedTag != null
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                if (selectedTag.address != null) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: _categoryColor(selectedTag).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: _categoryColor(selectedTag).withValues(alpha: 0.5)),
                                                    ),
                                                    child: Text(
                                                      selectedTag.address!,
                                                      style: TextStyle(
                                                        color: _categoryColor(selectedTag),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    selectedTag.name,
                                                    style: const TextStyle(
                                                      color: AppTokens.text,
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Tipo: ${selectedTag.type.name.toUpperCase()}${selectedTag.unit != null ? ' • Unidade: ${selectedTag.unit}' : ''}',
                                              style: const TextStyle(color: AppTokens.textDim, fontSize: 10, fontFamily: 'monospace'),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          '(Nenhuma tag vinculada / Modo Didático)',
                                          style: TextStyle(color: AppTokens.textDim, fontSize: 12),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.search, size: 14),
                                  label: Text(
                                    selectedTag != null ? 'ALTERAR' : 'ESCOLHER',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTokens.focus,
                                    side: const BorderSide(color: AppTokens.focus, width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSelectingTag = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTokens.panel2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.focus, width: 1.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _tagSearchController,
                                  style: const TextStyle(color: AppTokens.text, fontSize: 12, fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Buscar tag por nome, %IX, %QX, %IW, %M...',
                                    hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 11),
                                    prefixIcon: const Icon(Icons.search, color: AppTokens.focus, size: 16),
                                    suffixIcon: _tagSearchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 14, color: AppTokens.textDim),
                                            onPressed: () {
                                              _tagSearchController.clear();
                                              setState(() => _tagSearchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: AppTokens.background,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  onChanged: (val) {
                                    setState(() => _tagSearchQuery = val);
                                  },
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildCategoryChip('TODAS', 'TODAS'),
                                      _buildCategoryChip('ENTRADAS', 'ENTRADAS (%IX)'),
                                      _buildCategoryChip('SAÍDAS', 'SAÍDAS (%QX)'),
                                      _buildCategoryChip('ANALÓGICAS', 'ANALÓGICAS (%IW)'),
                                      _buildCategoryChip('MEMÓRIAS', 'MEMÓRIAS (%M)'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 160),
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          _onTagChanged(null);
                                          setState(() => _isSelectingTag = false);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _selectedTagId == null ? AppTokens.panel : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '(Nenhuma tag vinculada / Modo Didático)',
                                            style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ),
                                      const Divider(color: AppTokens.line, height: 8),
                                      ..._getFilteredTags(tags).map((tag) {
                                        final isSelected = tag.id == _selectedTagId;
                                        final catColor = _categoryColor(tag);
                                        return InkWell(
                                          onTap: () {
                                            _onTagChanged(tag.id);
                                            setState(() => _isSelectingTag = false);
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            margin: const EdgeInsets.only(bottom: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppTokens.panel : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              border: isSelected ? Border.all(color: AppTokens.focus, width: 1.0) : null,
                                            ),
                                            child: Row(
                                              children: [
                                                if (tag.address != null) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: catColor.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(3),
                                                      border: Border.all(color: catColor.withValues(alpha: 0.4)),
                                                    ),
                                                    child: Text(
                                                      tag.address!,
                                                      style: TextStyle(color: catColor, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tag.name,
                                                        style: const TextStyle(color: AppTokens.text, fontSize: 11.5, fontWeight: FontWeight.bold),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (tag.description != null && tag.description!.isNotEmpty)
                                                        Text(
                                                          tag.description!,
                                                          style: const TextStyle(color: AppTokens.textDim, fontSize: 9.5),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  tag.type.name.toUpperCase() + (tag.unit != null ? ' (${tag.unit})' : ''),
                                                  style: const TextStyle(color: AppTokens.textDim, fontSize: 9.5, fontFamily: 'monospace'),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.check_circle, size: 14, color: AppTokens.focus),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => setState(() => _isSelectingTag = false),
                                    child: const Text('FECHAR SELETOR', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],

              // 2. Title
              const Text(
                'TÍTULO DE EXIBIÇÃO NO PAINEL',
                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Ex: AI0.0 ENTRADA ANALÓGICA',
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

              // 3. Unit (for analog / metric)
              if (isAnalog || widget.templateType == WidgetTemplateType.metric) ...[
                const Text(
                  'UNIDADE DE ENGENHARIA',
                  style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _unitController,
                  style: const TextStyle(color: AppTokens.text, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ex: °C, PSI, bar, %, RPM',
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

              // 4. Min/Max Scale (for Gauge / Sparkline)
              if (isAnalog) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESCALA MÍN', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTokens.text, fontSize: 12, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTokens.panel2,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESCALA MÁX', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTokens.text, fontSize: 12, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTokens.panel2,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 5. Digital Text (ON / OFF)
              if (isDigital) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TEXTO ESTADO ON', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _onTextController,
                            style: const TextStyle(color: AppTokens.run, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTokens.panel2,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TEXTO ESTADO OFF', style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _offTextController,
                            style: const TextStyle(color: AppTokens.textDim, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTokens.panel2,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.line, width: 1.0)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTokens.focus, width: 1.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 6. Action buttons
              const SizedBox(height: 10),
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
                    child: Text(
                      widget.existingWidget != null ? 'SALVAR' : 'ADICIONAR',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
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
