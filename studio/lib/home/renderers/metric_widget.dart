import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/models/enums.dart';
import '../../ladder/runtime/ladder_runtime.dart';

class MetricWidget extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;

  const MetricWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    String displayValue = '---';
    String unit = config.unit ?? '';
    bool isFromInitialValue = false;

    if (config.tagId != null && project.tags.containsKey(config.tagId)) {
      final tag = project.tags[config.tagId!]!;
      unit = config.unit ?? tag.unit ?? '';
      
      var tagVal = runtime?.tagStore.getValue(tag.id);
      if (tagVal == null && tag.address != null) {
        tagVal = runtime?.tagStore.getValue(tag.address!);
      }

      if (tag.type == TagType.bool) {
        final hasBoolValue = tagVal?.boolValue != null || tag.initialValue?.boolValue != null;
        if (hasBoolValue) {
          final boolVal = tagVal?.boolValue ?? tag.initialValue!.boolValue!;
          displayValue = boolVal ? config.onText : config.offText;
          isFromInitialValue = tagVal?.boolValue == null;
        }
        // Sem valor lógico real: mantém '---' (SEM DADOS).
      } else {
        final realVal = tagVal?.realValue ?? tag.initialValue?.realValue;
        final intVal = tagVal?.intValue ?? tag.initialValue?.intValue;

        if (realVal != null) {
          displayValue = realVal.toStringAsFixed(config.decimalPlaces);
          isFromInitialValue = tagVal?.realValue == null;
        } else if (intVal != null) {
          displayValue = intVal.toString();
          isFromInitialValue = tagVal?.intValue == null;
        }
        // Sem valor real: mantém '---' (SEM DADOS).
      }
    }
    // Sem tag vinculada: sem dados reais; '---' já é o valor exibido.

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTokens.panel2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTokens.focus.withValues(alpha: 0.2), width: 0.8),
            ),
            child: const Icon(Icons.analytics_outlined, color: AppTokens.focus, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              config.title,
              style: const TextStyle(
                color: AppTokens.textDim,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayValue,
                style: const TextStyle(
                  color: AppTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppTokens.textDim,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
