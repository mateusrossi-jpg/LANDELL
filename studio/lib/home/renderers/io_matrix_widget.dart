import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/models/enums.dart';
import '../../ladder/runtime/ladder_runtime.dart';
import '../../core/ui/widgets/io_force_dialog.dart';
import '../../core/services/network_manager.dart';
import '../../ladder/ui/editor/telemetry_sync_service.dart';

class IoMatrixWidget extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;
  final VoidCallback? onStateChanged;
  final NetworkManager? networkManager;

  const IoMatrixWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
    this.onStateChanged,
    this.networkManager,
  });

  @override
  Widget build(BuildContext context) {
    final digitalTags = project.tags.values
        .where((t) => t.type == TagType.bool || t.address?.startsWith('X') == true || t.address?.startsWith('Y') == true)
        .toList();

    // Ordena de forma previsível: Entradas primeiro (I / X), depois Saídas (Q / Y)
    digitalTags.sort((a, b) {
      final addrA = a.address ?? a.id;
      final addrB = b.address ?? b.id;
      final isOutA = addrA.startsWith('Q') || addrA.startsWith('Y');
      final isOutB = addrB.startsWith('Q') || addrB.startsWith('Y');
      if (isOutA != isOutB) {
        return isOutA ? 1 : -1;
      }
      return addrA.compareTo(addrB);
    });

    if (digitalTags.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTokens.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppTokens.textDim, size: 22),
            const SizedBox(height: 8),
            const Text(
              'SEM DADOS • NENHUMA TAG DIGITAL NO PROJETO',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.textDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 2),
            const Text(
              'Nenhuma tag digital configurada no projeto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.muted, fontSize: 9),
            ),
          ],
        ),
      );
    }

    final List<Widget> row1 = [];
    final List<Widget> row2 = [];

    final visibleTags = digitalTags.take(16).toList();
    final splitByDirection = visibleTags.length > 8;

    for (int i = 0; i < visibleTags.length; i++) {
      final tag = visibleTags[i];
      var tagVal = runtime?.tagStore.getBool(tag.id);
      if (tagVal == null && tag.address != null) {
        tagVal = runtime?.tagStore.getBool(tag.address!);
      }
      final bool isFromInitialValue = tagVal == null;
      final bool val = tagVal ?? tag.initialValue?.boolValue ?? false;
      final isForced = (runtime?.tagStore.isForced(tag.id) ?? false) ||
          (tag.address != null && (runtime?.tagStore.isForced(tag.address!) ?? false));
      final label = tag.address ?? tag.name;
      final isOutputTag = label.startsWith('Q') || label.startsWith('Y');

      final dot = _buildIoDot(
        context,
        label,
        val ? const Color(0xFF3FBF5A) : const Color(0xFF8C98A8),
        val ? 'ON' : 'OFF',
        isForced: isForced,
        isFromInitialValue: isFromInitialValue,
        onTap: () {
          IoForceDialog.show(
            context,
            tagId: tag.id,
            address: tag.address ?? tag.name,
            description: tag.description,
            runtime: runtime,
            networkManager: networkManager,
            source: 'HOME_IO_MATRIX',
            onStateChanged: () => onStateChanged?.call(),
          );
        },
      );

      if (splitByDirection ? !isOutputTag : (i < 4)) {
        row1.add(dot);
      } else {
        row2.add(dot);
      }
    }

    final bool isOnline = TelemetrySyncService.instance.isOnline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${visibleTags.length} PONTOS I/O',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.0,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: row1,
        ),
        if (row2.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: row2,
          ),
        ],
      ],
    );
  }

  Widget _buildIoDot(
    BuildContext context,
    String label,
    Color color,
    String stateText, {
    bool isForced = false,
    bool isFromInitialValue = false,
    VoidCallback? onTap,
  }) {
    final bool isActive = color == const Color(0xFF3FBF5A) || color == const Color(0xFF10B981);
    final bool isErr = color == const Color(0xFFD9503F) || color == const Color(0xFFF43F5E);
    final Color effectiveColor = isForced
        ? const Color(0xFFF59E0B)
        : (isActive ? const Color(0xFF10B981) : const Color(0xFF334155));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
                boxShadow: (isActive || isErr || isForced)
                    ? [
                        BoxShadow(
                          color: effectiveColor.withValues(alpha: 0.45),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
            if (isForced)
              const Positioned(
                right: -4,
                top: -4,
                child: Icon(Icons.lock, size: 8, color: Color(0xFFF59E0B)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isForced
                      ? const Color(0xFFF59E0B)
                      : (isErr ? const Color(0xFFF43F5E) : (isActive ? Colors.white : const Color(0xFF94A3B8))),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: isForced ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFF1A202E),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF222B3D),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  isActive ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      );
    }

    return content;
  }
}
