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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTokens.panel2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                      ),
                      child: const Icon(Icons.widgets_outlined, color: AppTokens.focus, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'GALERIA DE WIDGETS',
                          style: TextStyle(
                            color: AppTokens.text,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Escolha o modelo visual para sua variável',
                          style: TextStyle(color: AppTokens.textDim, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTokens.textDim, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Seção de Acesso Rápido a Sensores de Processo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.panel2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.sensors, color: AppTokens.focus, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'ATALHO RÁPIDO — SENSORES DE PROCESSO',
                        style: TextStyle(
                          color: AppTokens.focus,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.thermostat, color: AppTokens.warn, size: 16),
                        backgroundColor: AppTokens.background,
                        side: const BorderSide(color: AppTokens.line, width: 1.0),
                        label: const Text(
                          'AHT10 TEMPERATURA (°C)',
                          style: TextStyle(color: AppTokens.text, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.pop(context, WidgetTemplateType.gauge),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.water_drop, color: Color(0xFF38BDF8), size: 16),
                        backgroundColor: AppTokens.background,
                        side: const BorderSide(color: AppTokens.line, width: 1.0),
                        label: const Text(
                          'AHT10 UMIDADE (%)',
                          style: TextStyle(color: AppTokens.text, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.pop(context, WidgetTemplateType.sparkline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppTokens.line, height: 20),
            // Template list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: templates.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return InkWell(
                    onTap: () => Navigator.pop(context, t.type),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTokens.panel2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTokens.line, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTokens.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                            ),
                            child: Icon(t.icon, color: AppTokens.focus, size: 20),
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
                                          letterSpacing: 0.8,
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
                          const Icon(Icons.arrow_forward_ios, color: AppTokens.textDim, size: 14),
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
