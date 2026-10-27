import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design_system/tokens.dart';
import '../../../ladder/models/ladder_project.dart';
import '../../../ladder/ui/editor/file_helper.dart';
import '../../services/studio_event_bus.dart';

class ExportProjectDialog {
  static Future<void> show(
    BuildContext context, {
    required LadderProject project,
    int scanPeriodMs = 100,
    String mode = 'RUN',
  }) async {
    final fileName = generateProjectFilename();
    final jsonString = formatProjectJson(project, scanPeriodMs: scanPeriodMs, mode: mode);

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          backgroundColor: AppTokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTokens.line, width: 1.0),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                ),
                child: const Icon(Icons.download, color: AppTokens.focus, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'EXPORTAR PROJETO',
                  style: TextStyle(
                    color: AppTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nome do arquivo gerado:',
                  style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code, color: AppTokens.focus, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: AppTokens.focus,
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${project.tags.length} Variáveis / Tags I/O', style: const TextStyle(color: AppTokens.textDim, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('• ${project.networks.length} Linhas de Lógica (Rungs)', style: const TextStyle(color: AppTokens.textDim, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('• ${project.dashboardWidgets?.length ?? 0} Widgets de Painel HMI / Home', style: const TextStyle(color: AppTokens.textDim, fontSize: 11)),
                      const SizedBox(height: 2),
                      const Text('• Comentários estruturados e conexões elétricas', style: TextStyle(color: AppTokens.textDim, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('• Configuração do Runtime (Scan: ${scanPeriodMs}ms)', style: const TextStyle(color: AppTokens.textDim, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prévia do JSON gerado:',
                  style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTokens.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line, width: 1.0),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      jsonString,
                      style: const TextStyle(color: AppTokens.textDim, fontFamily: 'monospace', fontSize: 9.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Copiar JSON
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 15, color: AppTokens.focus),
              label: const Text('Copiar JSON', style: TextStyle(color: AppTokens.focus, fontSize: 12)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                StudioEventBus.instance.emit(
                  type: 'PROJECT_EXPORT',
                  source: 'EXPORT_DIALOG',
                  message: 'JSON DO PROJETO COPIADO PARA CLIPBOARD ($fileName)',
                  severity: EventSeverity.info,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTokens.panel2,
                    content: Text(
                      '✓ JSON copiado para a área de transferência!',
                      style: TextStyle(color: AppTokens.focus, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
            ),

            // Salvar Arquivo
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.focus,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.save_alt, size: 16),
              label: const Text(
                'SALVAR ARQUIVO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await exportProject(project, scanPeriodMs: scanPeriodMs);
                StudioEventBus.instance.emit(
                  type: 'PROJECT_EXPORT',
                  source: 'EXPORT_DIALOG',
                  message: 'PROJETO EXPORTADO COM SUCESSO: $fileName',
                  severity: EventSeverity.info,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTokens.panel2,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTokens.run, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✓ Projeto exportado: $fileName',
                              style: const TextStyle(color: AppTokens.run, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
