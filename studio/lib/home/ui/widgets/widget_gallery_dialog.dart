import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../models/home_widget_config.dart';

class WidgetGalleryDialog extends StatelessWidget {
  const WidgetGalleryDialog({super.key});

  static Future<WidgetTemplateType?> show(BuildContext context) {
    return showModalBottomSheet<WidgetTemplateType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTokens.line, width: 1.0),
      ),
      builder: (_) => const WidgetGalleryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = [
      _TemplateItem(
        type: WidgetTemplateType.gauge,
        title: 'MANÔMETRO RADIAL',
        subtitle: 'Medidor circular em arco de 240° (pressão, nível, RPM)',
        icon: Icons.speed,
        badge: 'ANALÓGICO',
      ),
      _TemplateItem(
        type: WidgetTemplateType.sparkline,
        title: 'TENDÊNCIA / SPARKLINE',
        subtitle: 'Valor numérico com histórico gráfico de linha em tempo real',
        icon: Icons.show_chart,
        badge: 'ANALÓGICO',
      ),
      _TemplateItem(
        type: WidgetTemplateType.numeric,
        title: 'VALOR NUMÉRICO',
        subtitle: 'Display numérico de alta precisão com unidade de engenharia',
        icon: Icons.pin_outlined,
        badge: 'ANALÓGICO/INT',
      ),
      _TemplateItem(
        type: WidgetTemplateType.digital,
        title: 'INDICADOR DIGITAL',
        subtitle: 'Status ON/OFF com LED luminoso e comando de forçamento',
        icon: Icons.radio_button_checked,
        badge: 'DIGITAL/BOOL',
      ),
      _TemplateItem(
        type: WidgetTemplateType.actuator,
        title: 'ATUADOR OPERACIONAL',
        subtitle: 'Seletor AUTO/MANUAL com botão de pulso industrial',
        icon: Icons.toggle_on_outlined,
        badge: 'DIGITAL/BOOL',
      ),
      _TemplateItem(
        type: WidgetTemplateType.metric,
        title: 'MÉTRICA COMPACTA',
        subtitle: 'Tile resumido de telemetria para visão geral rápida',
        icon: Icons.analytics_outlined,
        badge: 'GERAL',
      ),
      _TemplateItem(
        type: WidgetTemplateType.ioMatrix,
        title: 'MATRIZ DE I/O DIGITAL',
        subtitle: 'Grade 4x2 com os canais de hardware do controlador',
        icon: Icons.grid_view,
        badge: 'ESTRUTURAL',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTokens.textDim.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'GALERIA DE WIDGETS',
                      style: TextStyle(
                        color: AppTokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Selecione o componente visual para vincular a uma variável',
                      style: TextStyle(color: AppTokens.textDim, fontSize: 11),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'FECHAR',
                    style: TextStyle(color: AppTokens.textDim, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: AppTokens.line, height: 22),
            // Template list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: templates.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return InkWell(
                    onTap: () => Navigator.pop(context, t.type),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTokens.panel2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTokens.line, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppTokens.focus,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
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
                                        t.title,
                                        style: const TextStyle(
                                          color: AppTokens.text,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTokens.background,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTokens.line, width: 1.0),
                                      ),
                                      child: Text(
                                        t.badge,
                                        style: const TextStyle(
                                          color: AppTokens.textDim,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.subtitle,
                                  style: const TextStyle(color: AppTokens.textDim, fontSize: 10.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SELECIONAR',
                            style: TextStyle(
                              color: AppTokens.focus,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
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
}

class _TemplateItem {
  final WidgetTemplateType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;

  _TemplateItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
  });
}
