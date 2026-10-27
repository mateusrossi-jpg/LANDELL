import 'package:flutter/material.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';
import '../../core/services/network_manager.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';
import 'numeric_sparkline_widget.dart';
import 'gauge_widget.dart';
import 'digital_widget.dart';
import 'actuator_widget.dart';
import 'metric_widget.dart';
import 'io_matrix_widget.dart';

class HomeWidgetRenderer extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;
  final bool isEditMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStateChanged;
  final NetworkManager? networkManager;

  const HomeWidgetRenderer({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
    this.isEditMode = false,
    this.onEdit,
    this.onDelete,
    this.onStateChanged,
    this.networkManager,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasTag = config.tagId == null || project.tags.containsKey(config.tagId);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditMode
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.6)
              : const Color(0xFF222B3D),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Edit controls
          if (isEditMode)
            _buildEditHeader(context)
          else
            _buildNormalHeader(),

          const SizedBox(height: 10),

          // Body
          if (!hasTag)
            _buildMissingTagFallback()
          else
            _buildTemplateContent(),
        ],
      ),
    );
  }

  Widget _buildNormalHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            config.title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFF1F5F9),
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (config.tagId != null && project.tags.containsKey(config.tagId)) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A202E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF222B3D), width: 1.0),
              ),
              child: Text(
                project.tags[config.tagId!]!.address ?? config.tagId!,
                style: const TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontSize: 9.0,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditHeader(BuildContext context) {
    return Row(
      children: [
        // Reorder Drag Handle (44x44 touch area)
        const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(Icons.drag_indicator, color: Color(0xFF64748B), size: 20),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            config.title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFF1F5F9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // Edit Button (>=44x44 touch target)
        IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.tune, color: Color(0xFF2DD4BF), size: 18),
          tooltip: 'Configurar Widget',
          onPressed: onEdit,
        ),
        // Delete Button (>=44x44 touch target)
        IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 18),
          tooltip: 'Remover Widget',
          onPressed: onDelete,
        ),
      ],
    );
  }

  Widget _buildMissingTagFallback() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'VARIÁVEL NÃO ENCONTRADA (${config.tagId ?? 'N/A'})',
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateContent() {
    switch (config.templateType) {
      case WidgetTemplateType.numeric:
      case WidgetTemplateType.sparkline:
        return NumericSparklineWidget(
          config: config,
          project: project,
          runtime: runtime,
        );
      case WidgetTemplateType.gauge:
        return GaugeWidget(
          config: config,
          project: project,
          runtime: runtime,
        );
      case WidgetTemplateType.digital:
        return DigitalWidget(
          config: config,
          project: project,
          runtime: runtime,
          networkManager: networkManager,
          onStateChanged: onStateChanged,
        );
      case WidgetTemplateType.actuator:
        return ActuatorWidget(
          config: config,
          project: project,
          runtime: runtime,
          onStateChanged: onStateChanged,
        );
      case WidgetTemplateType.metric:
        return MetricWidget(
          config: config,
          project: project,
          runtime: runtime,
        );
      case WidgetTemplateType.ioMatrix:
        return IoMatrixWidget(
          config: config,
          project: project,
          runtime: runtime,
          networkManager: networkManager,
          onStateChanged: onStateChanged,
        );
    }
  }
}
