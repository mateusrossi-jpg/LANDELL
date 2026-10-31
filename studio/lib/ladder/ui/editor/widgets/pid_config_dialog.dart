import 'package:flutter/material.dart';

import '../../../../design_system/tokens.dart';
import '../../../models/enums.dart';
import '../../../models/node_config.dart';
import '../../../models/tag.dart';
import '../../../runtime/evaluators/pid_evaluator.dart';
import 'industrial_tag_browser_dialog.dart';

/// Diálogo de configuração do bloco PID industrial.
///
/// Tudo em % (PV, SP, MV). Organizado em 5 passos para guiar a montagem no Ladder:
/// 1) Sinais (PV / SP / MV)   2) Ação   3) Sintonia   4) Limites e proteções
/// 5) Auto / Manual e saída segura. Mostra um resumo em português do que o bloco fará.
class PidConfigDialog extends StatefulWidget {
  final NodeConfig initial;
  final Map<String, Tag> tags;

  const PidConfigDialog({super.key, required this.initial, required this.tags});

  static Future<NodeConfig?> show(
    BuildContext context, {
    required NodeConfig initial,
    required Map<String, Tag> tags,
  }) {
    return showDialog<NodeConfig>(
      context: context,
      builder: (_) => PidConfigDialog(initial: initial, tags: tags),
    );
  }

  @override
  State<PidConfigDialog> createState() => _PidConfigDialogState();
}

class _PidConfigDialogState extends State<PidConfigDialog> {
  late final TextEditingController _pv;
  late final TextEditingController _sp;
  late final TextEditingController _mv;
  late final TextEditingController _kp;
  late final TextEditingController _ki;
  late final TextEditingController _kd;
  late final TextEditingController _outMin;
  late final TextEditingController _outMax;
  late final TextEditingController _deadband;
  late final TextEditingController _eno;
  late final TextEditingController _enoHys;
  late final TextEditingController _safe;
  late final TextEditingController _manTag;
  late final TextEditingController _manOut;
  late bool _direct;
  late bool _dOnError;
  late bool _useManual;

  static const _mono = TextStyle(color: Color(0xFFE7EBF0), fontFamily: 'JetBrains Mono', fontSize: 13);

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    String n(num? v, num def) {
      final x = v ?? def;
      return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
    }

    _pv = TextEditingController(text: (c.tagId ?? 'AI0.0'));
    _sp = TextEditingController(text: (c.setpointTagId ?? '50').replaceAll('%', ''));
    _mv = TextEditingController(text: (c.outputTagId ?? 'MV_PID'));
    _kp = TextEditingController(text: n(c.kp, 2.5));
    _ki = TextEditingController(text: n(c.ki, 0.5));
    _kd = TextEditingController(text: n(c.kd, 0.1));
    _outMin = TextEditingController(text: n(c.pidOutMin, NodeConfig.defaultPidOutMin));
    _outMax = TextEditingController(text: n(c.pidOutMax, NodeConfig.defaultPidOutMax));
    _deadband = TextEditingController(text: n(c.pidDeadband, NodeConfig.defaultPidDeadband));
    _eno = TextEditingController(text: n(c.pidEnoThreshold, 20));
    _enoHys = TextEditingController(text: n(c.pidEnoHysteresis, 5));
    _safe = TextEditingController(text: n(c.pidSafeOut, NodeConfig.defaultPidSafeOut));
    _manTag = TextEditingController(text: c.pidManualTagId ?? 'M0.0');
    _manOut = TextEditingController(text: (c.pidManualOut ?? '0').replaceAll('%', ''));
    _direct = c.pidDirect ?? NodeConfig.defaultPidDirect;
    _dOnError = c.pidDerivativeOnError ?? NodeConfig.defaultPidDerivativeOnError;
    _useManual = (c.pidManualTagId ?? '').trim().isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in [
      _pv, _sp, _mv, _kp, _ki, _kd, _outMin, _outMax, _deadband, _eno, _enoHys, _safe, _manTag, _manOut
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').replaceAll('%', '').trim());
  int? _i(TextEditingController c) => _d(c)?.round();

  NodeConfig _build() {
    return NodeConfig(
      tagId: _pv.text.trim().toUpperCase().replaceAll(' ', ''),
      setpointTagId: _sp.text.replaceAll('%', '').trim(),
      outputTagId: _mv.text.trim().toUpperCase().replaceAll(' ', ''),
      kp: _d(_kp) ?? 2.5,
      ki: _d(_ki) ?? 0.5,
      kd: _d(_kd) ?? 0.1,
      pidDirect: _direct,
      pidDerivativeOnError: _dOnError,
      pidOutMin: _i(_outMin) ?? 0,
      pidOutMax: _i(_outMax) ?? 100,
      pidDeadband: _d(_deadband) ?? 0,
      pidEnoThreshold: _i(_eno) ?? 0,
      pidEnoHysteresis: _i(_enoHys) ?? 0,
      pidSafeOut: _i(_safe) ?? 0,
      pidManualTagId: _useManual ? _manTag.text.trim().toUpperCase() : null,
      pidManualOut: _useManual ? _manOut.text.replaceAll('%', '').trim() : null,
    );
  }

  List<String> _problems() {
    final out = <String>[];
    final cfg = _build();
    final pv = cfg.tagId ?? '';
    final mv = cfg.outputTagId ?? '';
    if (pv.isEmpty) out.add('Informe a PV (ex.: AI0.0).');
    if (RegExp(r'^[QY]\d').hasMatch(pv)) out.add('A PV não pode ser uma saída (Q).');
    if (mv.isEmpty) out.add('Informe a saída MV (MV_PID, AO0.0, AO0.1 ou Q0.x).');
    if (mv.startsWith('AI') || mv.startsWith('%IW') || RegExp(r'^I\d').hasMatch(mv)) {
      out.add('A MV não pode ser uma entrada ($mv).');
    }
    if (pv.isNotEmpty && pv == mv) out.add('PV e MV não podem ser a mesma variável.');
    final sp = cfg.setpointTagId ?? '';
    final spNum = double.tryParse(sp);
    if (sp.isEmpty) {
      out.add('Informe o Setpoint.');
    } else if (spNum != null && (spNum < 0 || spNum > 100)) {
      out.add('Setpoint deve estar entre 0 e 100 %.');
    } else if (spNum == null && !widget.tags.containsKey(sp)) {
      out.add('Setpoint "$sp" não é número nem tag existente.');
    }
    if ((cfg.pidOutMin ?? 0) >= (cfg.pidOutMax ?? 100)) out.add('Limite mínimo deve ser menor que o máximo.');
    if (!PidEvaluator.paramsFromConfig(cfg).isValid && out.isEmpty) {
      out.add('Parâmetros fora da faixa (limites 0..100 %, banda morta 0..25 %).');
    }
    if (_useManual && !widget.tags.containsKey(cfg.pidManualTagId ?? '')) {
      out.add('Chave Auto/Manual "${cfg.pidManualTagId}" não existe nas tags.');
    }
    return out;
  }

  String _summary() {
    final cfg = _build();
    final mv = cfg.outputTagId ?? 'MV';
    final act = _direct
        ? 'AÇÃO DIRETA: MV sobe quando PV > SP (resfriamento, exaustão).'
        : 'AÇÃO REVERSA: MV sobe quando PV < SP (aquecimento, irrigação).';
    final dest = PidEvaluator.isDigitalOutputTag(mv)
        ? 'Saída digital $mv liga com MV > ${cfg.pidEnoThreshold ?? 0}% e desliga com MV ≤ ${((cfg.pidEnoThreshold ?? 0) - (cfg.pidEnoHysteresis ?? 0)).clamp(0, 100)}%.'
        : '$mv recebe MV de ${cfg.pidOutMin ?? 0}% a ${cfg.pidOutMax ?? 100}%. O pino ENO (para ligar uma bobina em série) conduz com MV > ${cfg.pidEnoThreshold ?? 0}%.';
    final safe = 'Rung desligada: MV = ${cfg.pidSafeOut ?? 0}% (saída segura).';
    return '$act\n$dest\n$safe';
  }

  Widget _num(String label, TextEditingController c, {String? suffix, String? help, bool wide = false}) {
    return SizedBox(
      width: wide ? 260 : 150,
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: _mono,
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          helperMaxLines: 2,
          suffixText: suffix,
          labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11),
          helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
          suffixStyle: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
        ),
      ),
    );
  }

  Widget _tagField(String label, TextEditingController c, {String? help, bool analogOnly = false}) {
    return SizedBox(
      width: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: c,
              onChanged: (_) => setState(() {}),
              style: _mono,
              decoration: InputDecoration(
                labelText: label,
                helperText: help,
                helperMaxLines: 2,
                labelStyle: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11),
                helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTokens.line)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4FD1C5))),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Escolher tag',
            icon: const Icon(Icons.table_chart_outlined, size: 18, color: Color(0xFF38BDF8)),
            onPressed: () async {
              final sel = await IndustrialTagBrowserDialog.show(
                context,
                tags: widget.tags,
                initialSelectedTagId: c.text,
                title: 'Selecione a tag — $label',
                filterAnalogOnly: analogOnly,
              );
              if (sel != null) setState(() => c.text = sel);
            },
          ),
        ],
      ),
    );
  }

  Widget _chips(TextEditingController c, List<String> options, {String Function(String)? label}) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(label?.call(o) ?? o, style: const TextStyle(fontSize: 10.5, fontFamily: 'JetBrains Mono')),
            selected: c.text.trim().toUpperCase() == o,
            onSelected: (_) => setState(() => c.text = o),
          ),
      ],
    );
  }

  Widget _step(int n, String title, String subtitle, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 10, backgroundColor: const Color(0xFF38BDF8), child: Text('$n', style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF8C98A8), fontSize: 11)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  void _preset(double kp, double ki, double kd) {
    setState(() {
      _kp.text = kp.toString();
      _ki.text = ki.toString();
      _kd.text = kd.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final problems = _problems();
    return Dialog(
      backgroundColor: AppTokens.panel,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Icon(Icons.tune, color: Color(0xFF4FD1C5)),
                SizedBox(width: 8),
                Text('Controlador PID Industrial', style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              const Text(
                'PV = medida do sensor · SP = meta desejada · MV = comando enviado ao atuador. Tudo em %.',
                style: TextStyle(color: Color(0xFF8C98A8), fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step(1, 'Sinais', 'Quem mede, qual a meta e onde o comando sai.', [
                        Wrap(spacing: 14, runSpacing: 8, children: [
                          _tagField('PV — Variável de Processo (%)', _pv, help: 'Entrada analógica do sensor: AI0.0 ou AI0.1', analogOnly: true),
                          _num('SP — Setpoint', _sp, suffix: '%', help: 'Número (0..100) ou nome de uma tag', wide: true),
                        ]),
                        const SizedBox(height: 6),
                        _chips(_pv, const ['AI0.0', 'AI0.1'], label: (o) => '$o (0-100%)'),
                        const SizedBox(height: 8),
                        _tagField('MV — Saída de Controle', _mv, help: 'MV_PID (memória), AO0.0/AO0.1 (DAC 0-3,3 V) ou Q0.x (relé)'),
                        const SizedBox(height: 6),
                        _chips(_mv, const ['MV_PID', 'AO0.0', 'AO0.1', 'Q0.0', 'Q0.1']),
                      ]),
                      _step(2, 'Ação do controlador', 'Define o sentido da correção.', [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Reversa (PV<SP → MV↑)'), icon: Icon(Icons.water_drop_outlined, size: 16)),
                            ButtonSegment(value: true, label: Text('Direta (PV>SP → MV↑)'), icon: Icon(Icons.ac_unit, size: 16)),
                          ],
                          selected: {_direct},
                          onSelectionChanged: (s) => setState(() => _direct = s.first),
                        ),
                        const SizedBox(height: 4),
                        const Text('Irrigação/aquecimento = Reversa. Resfriamento/exaustão = Direta.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                      ]),
                      _step(3, 'Sintonia (ganhos)', 'Forma paralela ISA: MV = Kp·erro + Ki·∫erro·dt + Kd·dPV/dt (erro e MV em %, tempo em s).', [
                        Wrap(spacing: 14, runSpacing: 8, children: [
                          _num('Kp — Proporcional', _kp, help: 'Resposta imediata ao erro'),
                          _num('Ki — Integral', _ki, help: '%/(%·s): zera o erro residual'),
                          _num('Kd — Derivativo', _kd, help: '%·s/%: amortece variações rápidas'),
                        ]),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          const Text('Perfis:', style: TextStyle(color: Color(0xFF8C98A8), fontSize: 11)),
                          ActionChip(label: const Text('Suave (1 / 0,1 / 0)', style: TextStyle(fontSize: 10.5)), onPressed: () => _preset(1, 0.1, 0)),
                          ActionChip(label: const Text('Padrão (2,5 / 0,5 / 0,1)', style: TextStyle(fontSize: 10.5)), onPressed: () => _preset(2.5, 0.5, 0.1)),
                          ActionChip(label: const Text('Rápido (4 / 1 / 0,2)', style: TextStyle(fontSize: 10.5)), onPressed: () => _preset(4, 1, 0.2)),
                        ]),
                      ]),
                      _step(4, 'Limites e proteções', 'Evita saturação, ruído e chaveamento excessivo.', [
                        Wrap(spacing: 14, runSpacing: 8, children: [
                          _num('MV mínima', _outMin, suffix: '%', help: 'Piso da saída'),
                          _num('MV máxima', _outMax, suffix: '%', help: 'Teto da saída'),
                          _num('Banda morta', _deadband, suffix: '%', help: 'Erro menor que isso é ignorado (0..25)'),
                          _num('ENO liga acima de', _eno, suffix: '%', help: 'Pino de saída p/ bobina em série (ex.: relé)'),
                          _num('Histerese ENO', _enoHys, suffix: '%', help: 'Desliga em (limiar − histerese)'),
                        ]),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Derivada sobre o erro (padrão: sobre a PV)', style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 12)),
                          subtitle: const Text('Sobre a PV evita "tranco" ao mudar o setpoint — recomendado.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                          value: _dOnError,
                          onChanged: (v) => setState(() => _dOnError = v),
                        ),
                      ]),
                      _step(5, 'Auto / Manual e saída segura', 'Operação manual sem solavanco e comportamento com a rung desligada.', [
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Habilitar chave Auto/Manual', style: TextStyle(color: Color(0xFFE7EBF0), fontSize: 12)),
                          subtitle: const Text('Tag BOOL verdadeira = MANUAL (a MV segue a saída manual).', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                          value: _useManual,
                          onChanged: (v) => setState(() => _useManual = v),
                        ),
                        if (_useManual)
                          Wrap(spacing: 14, runSpacing: 8, children: [
                            _tagField('Chave MANUAL (tag BOOL)', _manTag, help: 'Ex.: M0.0 ou uma entrada I0.x'),
                            _num('Saída manual', _manOut, suffix: '%', help: 'Número 0..100 ou nome de tag', wide: true),
                          ]),
                        const SizedBox(height: 8),
                        _num('Saída segura (EN = 0)', _safe, suffix: '%', help: 'Valor da MV quando a rung está desligada', wide: true),
                      ]),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F291E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
                        ),
                        child: Text(_summary(), style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11.5, height: 1.4)),
                      ),
                      if (problems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final p in problems)
                          Row(children: [
                            const Icon(Icons.error_outline, size: 14, color: Color(0xFFF87171)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(p, style: const TextStyle(color: Color(0xFFF87171), fontSize: 11.5))),
                          ]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTokens.focus, foregroundColor: AppTokens.bg),
                    onPressed: problems.isEmpty ? () => Navigator.pop(context, _build()) : null,
                    child: const Text('Salvar PID', style: TextStyle(fontWeight: FontWeight.bold)),
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

/// Garante que as tags auxiliares do PID existam no projeto (MV_PID, SP_PID) e
/// que a PV/MV/chave manual informadas estejam cadastradas.
void ensurePidTags(Map<String, Tag> tags, NodeConfig cfg) {
  void ensure(String? id, TagType type, {String? unit, String? address}) {
    final key = (id ?? '').trim();
    if (key.isEmpty || double.tryParse(key) != null || tags.containsKey(key)) return;
    tags[key] = Tag(id: key, name: key, type: type, address: address ?? key, unit: unit);
  }

  ensure(cfg.outputTagId, TagType.real, unit: '%');
  final man = cfg.pidManualTagId;
  if (man != null && man.trim().isNotEmpty) ensure(man, TagType.bool);
}
