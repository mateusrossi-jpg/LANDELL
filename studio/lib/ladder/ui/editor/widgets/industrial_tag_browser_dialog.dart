import 'package:flutter/material.dart';
import '../../../../design_system/tokens.dart';
import '../../../models/tag.dart';
import '../../../models/tag_value.dart';
import '../../../models/enums.dart';

/// Diálogo Industrial de Navegação e Seleção de Tags (Estilo TIA Portal / Rockwell RSLogix Tag Browser).
/// Apresenta busca rápida por nome/endereço/descrição e categorização em abas por tipo IEC:
/// - Todas
/// - Entradas Digitais (%I)
/// - Saídas Digitais (%Q)
/// - Memórias / Flags (%M)
/// - Analógicas (%IW / %QW / Real)
/// - Timers & Contadores (T / C)
class IndustrialTagBrowserDialog extends StatefulWidget {
  final Map<String, Tag> tags;
  final String? initialSelectedTagId;
  final String title;
  final bool filterAnalogOnly;
  final bool filterDigitalOnly;

  const IndustrialTagBrowserDialog({
    super.key,
    required this.tags,
    this.initialSelectedTagId,
    this.title = 'Seletor de Tags PLC (Tag Browser)',
    this.filterAnalogOnly = false,
    this.filterDigitalOnly = false,
  });

  static Future<String?> show(
    BuildContext context, {
    required Map<String, Tag> tags,
    String? initialSelectedTagId,
    String title = 'Seletor de Tags PLC (Tag Browser)',
    bool filterAnalogOnly = false,
    bool filterDigitalOnly = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IndustrialTagBrowserDialog(
        tags: tags,
        initialSelectedTagId: initialSelectedTagId,
        title: title,
        filterAnalogOnly: filterAnalogOnly,
        filterDigitalOnly: filterDigitalOnly,
      ),
    );
  }

  @override
  State<IndustrialTagBrowserDialog> createState() => _IndustrialTagBrowserDialogState();
}

class _IndustrialTagBrowserDialogState extends State<IndustrialTagBrowserDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTagId;
  int? _selectedControllerFilter; // null = todos

  final List<String> _categories = [
    'Todas',
    'Entradas (I)',
    'Saídas (Q)',
    'Memórias (M)',
    'Analógicas (AI/AO)',
    'Timers/Contadores',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTagId = widget.initialSelectedTagId;
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesCategory(Tag tag, int categoryIndex) {
    final addr = (tag.address ?? tag.id).trim().toUpperCase();
    final type = tag.type;

    switch (categoryIndex) {
      case 0: // Todas
        return true;
      case 1: // Entradas (I)
        return addr.startsWith('%I') || addr.startsWith('I') || addr.startsWith('X');
      case 2: // Saídas (Q)
        return addr.startsWith('%Q') || addr.startsWith('Q') || addr.startsWith('Y');
      case 3: // Memórias (M)
        return addr.startsWith('%M') || addr.startsWith('M');
      case 4: // Analógicas
        return type == TagType.real ||
            type == TagType.int ||
            type == TagType.dint ||
            addr.startsWith('%IW') ||
            addr.startsWith('AI') ||
            addr.startsWith('%QW') ||
            addr.startsWith('AO');
      case 5: // Timers e Contadores
        return type == TagType.timer ||
            type == TagType.counter ||
            addr.startsWith('T') ||
            addr.startsWith('C');
      default:
        return true;
    }
  }

  Color _getTagBadgeColor(Tag tag) {
    final addr = (tag.address ?? tag.id).trim().toUpperCase();
    if (addr.startsWith('I') || addr.startsWith('%I') || addr.startsWith('X')) {
      return const Color(0xFF3B82F6); // Azul
    }
    if (addr.startsWith('Q') || addr.startsWith('%Q') || addr.startsWith('Y')) {
      return const Color(0xFFEF4444); // Vermelho
    }
    if (addr.startsWith('M') || addr.startsWith('%M')) {
      return const Color(0xFFF59E0B); // Âmbar
    }
    if (addr.startsWith('AI') || addr.startsWith('%IW') || tag.type == TagType.real) {
      return const Color(0xFF10B981); // Verde Esmeralda
    }
    if (addr.startsWith('T') || tag.type == TagType.timer) {
      return const Color(0xFF8B5CF6); // Roxo
    }
    if (addr.startsWith('C') || tag.type == TagType.counter) {
      return const Color(0xFFEC4899); // Rosa
    }
    return const Color(0xFF64748B); // Cinza Ardósia
  }

  String _getTagTypeLabel(Tag tag) {
    switch (tag.type) {
      case TagType.bool:
        return 'BOOL (1-bit)';
      case TagType.real:
        return 'REAL (Float)';
      case TagType.int:
        return 'INT (16-bit)';
      case TagType.dint:
        return 'DINT (32-bit)';
      case TagType.timer:
        return 'TIMER';
      case TagType.counter:
        return 'COUNTER';
      case TagType.string:
        return 'STRING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: AppTokens.line, width: 1.0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.text,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.green,
                      backgroundColor: AppTokens.green.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: AppTokens.green.withValues(alpha: 0.4)),
                      ),
                    ),
                    onPressed: _showQuickCreateTagDialog,
                    child: const Text(
                      '+ Nova Tag',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTokens.textDim, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Barra de Busca Rápida
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: const TextStyle(color: AppTokens.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filtrar por nome, endereço IEC (%IW0.0, Q0.1) ou descrição...',
                  hintStyle: const TextStyle(color: AppTokens.textDim, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: AppTokens.focus, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppTokens.textDim),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTokens.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTokens.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTokens.focus, width: 1.5),
                  ),
                ),
              ),
            ),

            // Barra de Filtro de Controlador (Topologia Distribuída: Nó 0, Nó 1, Nó 2, Nó 3...)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTokens.panel2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('NÓ:', style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildControllerChip(label: 'Todos', index: null),
                    const SizedBox(width: 6),
                    _buildControllerChip(label: 'Nó 0 (Gateway)', index: 0),
                    const SizedBox(width: 6),
                    _buildControllerChip(label: 'Nó 1 (Campo)', index: 1),
                    const SizedBox(width: 6),
                    _buildControllerChip(label: 'Nó 2 (Campo)', index: 2),
                    const SizedBox(width: 6),
                    _buildControllerChip(label: 'Nó 3 (Campo)', index: 3),
                  ],
                ),
              ),
            ),

            // Abas de Categorias Industriais
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTokens.line, width: 1.0)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTokens.focus,
                indicatorWeight: 2.5,
                labelColor: AppTokens.focus,
                unselectedLabelColor: AppTokens.textDim,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: _categories.map((c) => Tab(text: c)).toList(),
              ),
            ),

            // Lista de Tags Filtradas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(_categories.length, (categoryIndex) {
                  final filteredList = widget.tags.values.where((tag) {
                    // Filtro de Controlador Específico
                    if (_selectedControllerFilter != null && tag.controllerIndex != _selectedControllerFilter) {
                      return false;
                    }

                    // Filtro de Categoria
                    if (!_matchesCategory(tag, categoryIndex)) return false;

                    // Filtros opcionais de tipo
                    if (widget.filterAnalogOnly) {
                      final isAnalog = tag.type == TagType.real ||
                          tag.type == TagType.int ||
                          tag.type == TagType.dint;
                      if (!isAnalog) return false;
                    }
                    if (widget.filterDigitalOnly && tag.type != TagType.bool) {
                      return false;
                    }

                    // Filtro de Texto
                    if (_searchQuery.isNotEmpty) {
                      final nameMatch = tag.name.toLowerCase().contains(_searchQuery);
                      final idMatch = tag.id.toLowerCase().contains(_searchQuery);
                      final addrMatch = (tag.address ?? '').toLowerCase().contains(_searchQuery);
                      final descMatch = (tag.description ?? '').toLowerCase().contains(_searchQuery);
                      if (!nameMatch && !idMatch && !addrMatch && !descMatch) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Nenhuma tag cadastrada nesta categoria',
                              style: TextStyle(color: AppTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Crie uma nova tag (Entrada, Saída, Memória, Analógica ou Timer) para vincular ao elemento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTokens.textDim, fontSize: 11.5),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTokens.green,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _showQuickCreateTagDialog,
                              child: const Text(
                                'Nova Tag',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppTokens.line,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final tag = filteredList[index];
                      final isSelected = _selectedTagId == tag.id;
                      final badgeColor = _getTagBadgeColor(tag);

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedTagId = tag.id);
                        },
                        onDoubleTap: () {
                          Navigator.pop(context, tag.id);
                        },
                        child: Container(
                          color: isSelected
                              ? AppTokens.focus.withValues(alpha: 0.14)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Badge de Tipo / Prefixo
                              Container(
                                width: 78,
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1.0),
                                ),
                                child: Text(
                                  tag.address ?? tag.id,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Informações da Tag (Nome, Tipo e Descrição)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            tag.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? AppTokens.focus : AppTokens.text,
                                              fontFamily: 'JetBrains Mono',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTokens.panel2,
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: AppTokens.line),
                                          ),
                                          child: Text(
                                            _getTagTypeLabel(tag),
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppTokens.textDim,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tag.controllerIndex == 0
                                                ? AppTokens.focus.withValues(alpha: 0.12)
                                                : AppTokens.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(
                                              color: tag.controllerIndex == 0
                                                  ? AppTokens.focus.withValues(alpha: 0.5)
                                                  : AppTokens.green.withValues(alpha: 0.5),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            tag.controllerIndex == 0 ? 'Nó 0 (Gateway)' : 'Nó ${tag.controllerIndex}',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: tag.controllerIndex == 0
                                                  ? AppTokens.focus
                                                  : AppTokens.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (tag.description != null && tag.description!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        tag.description!,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppTokens.textDim,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Indicador de Seleção
                              if (isSelected)
                                const Text(
                                  'SELECIONADO',
                                  style: TextStyle(
                                    color: AppTokens.focus,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),

            // Rodapé com Ações
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: AppTokens.line, width: 1.0)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    _selectedTagId != null ? 'Tag selecionada: $_selectedTagId' : 'Nenhuma tag selecionada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedTagId != null ? AppTokens.focus : AppTokens.textDim,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: AppTokens.textDim)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.focus,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _selectedTagId != null
                            ? () => Navigator.pop(context, _selectedTagId)
                            : null,
                        child: const Text('Confirmar Tag', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildControllerChip({required String label, required int? index}) {
    final isSelected = _selectedControllerFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedControllerFilter = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTokens.focus.withValues(alpha: 0.16) : AppTokens.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppTokens.focus : AppTokens.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTokens.focus : AppTokens.textDim,
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickCreateTagDialog() async {
    final presets = widget.filterAnalogOnly
        ? ['AI0.0', 'AI0.1', 'AI0.2', 'AI0.3', 'AO0.0', 'AO0.1']
        : [
            'I0.0',
            'I0.1',
            'I0.2',
            'I0.3',
            'Q0.0',
            'Q0.1',
            'Q0.2',
            'Q0.3',
            'M0.0',
            'M0.1',
            'T0',
            'C0',
            'AI0.0',
            'AO0.0',
          ];

    String selectedAddress = presets.firstWhere(
      (p) => !widget.tags.containsKey(p),
      orElse: () => presets.first,
    );
    final addrCtrl = TextEditingController(text: selectedAddress);
    final nameCtrl = TextEditingController(text: selectedAddress);
    final descCtrl = TextEditingController();
    final unitCtrl = TextEditingController();

    final createdTagId = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final rawAddr = addrCtrl.text.trim().toUpperCase();
          final isAnalog = rawAddr.startsWith('AI') || rawAddr.startsWith('AO') || rawAddr.startsWith('%IW') || rawAddr.startsWith('%QW');

          return AlertDialog(
            backgroundColor: AppTokens.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTokens.line),
            ),
            title: const Text(
              'Criar e Vincular Nova Tag',
              style: TextStyle(color: AppTokens.text, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ENDEREÇO DE HARDWARE / IEC:',
                    style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((p) {
                      final isSelected = addrCtrl.text.trim().toUpperCase() == p;
                      final exists = widget.tags.containsKey(p);
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            final prevAddr = addrCtrl.text.trim().toUpperCase();
                            addrCtrl.text = p;
                            if (nameCtrl.text.trim().isEmpty || nameCtrl.text.trim().toUpperCase() == prevAddr) {
                              nameCtrl.text = p;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTokens.focus.withValues(alpha: 0.18)
                                : (exists ? AppTokens.background : AppTokens.panel2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppTokens.focus
                                  : AppTokens.line,
                            ),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTokens.focus
                                  : (exists ? AppTokens.textDim : AppTokens.text),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    onChanged: (_) => setModalState(() {}),
                    style: const TextStyle(color: AppTokens.text, fontSize: 12.5, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Endereço / ID Técnico (ex: I0.0, Q0.1, M0.0, T0)',
                      labelStyle: TextStyle(color: AppTokens.textDim, fontSize: 11),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppTokens.text, fontSize: 12.5),
                    decoration: const InputDecoration(
                      labelText: 'Apelido Visível no Ladder (ex: BOTAO_LIGA, MOTOR_1)',
                      labelStyle: TextStyle(color: AppTokens.textDim, fontSize: 11),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppTokens.text, fontSize: 12.5),
                    decoration: const InputDecoration(
                      labelText: 'Descrição Funcional (Opcional)',
                      labelStyle: TextStyle(color: AppTokens.textDim, fontSize: 11),
                      isDense: true,
                    ),
                  ),
                  if (isAnalog) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: unitCtrl,
                      style: const TextStyle(color: AppTokens.text, fontSize: 12.5),
                      decoration: const InputDecoration(
                        labelText: 'Unidade de Engenharia (ex: °C, %, bar, RPM)',
                        labelStyle: TextStyle(color: AppTokens.textDim, fontSize: 11),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: AppTokens.textDim)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.green,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                onPressed: () {
                  final cleanAddr = addrCtrl.text.trim().toUpperCase();
                  if (cleanAddr.isEmpty) return;
                  final cleanName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : cleanAddr;
                  final cleanDesc = descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null;
                  final cleanUnit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : null;

                  TagType tagType = TagType.bool;
                  TagValue initVal = TagValue.boolean(false);
                  if (cleanAddr.startsWith('AI') || cleanAddr.startsWith('AO') || cleanAddr.startsWith('%IW') || cleanAddr.startsWith('%QW')) {
                    tagType = TagType.real;
                    initVal = TagValue.real(0.0);
                  } else if (cleanAddr.startsWith('T')) {
                    tagType = TagType.timer;
                    initVal = TagValue.integer(0);
                  } else if (cleanAddr.startsWith('C')) {
                    tagType = TagType.counter;
                    initVal = TagValue.integer(0);
                  }

                  final newTag = Tag(
                    id: cleanAddr,
                    name: cleanName,
                    address: cleanAddr,
                    type: tagType,
                    initialValue: initVal,
                    description: cleanDesc,
                    unit: cleanUnit,
                  );

                  widget.tags[newTag.id] = newTag;
                  Navigator.pop(ctx, newTag.id);
                },
                child: const Text('Criar e Vincular', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (createdTagId != null && mounted) {
      Navigator.pop(context, createdTagId);
    }
  }
}
