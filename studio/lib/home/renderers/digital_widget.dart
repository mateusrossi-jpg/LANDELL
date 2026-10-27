import 'package:flutter/material.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';
import '../../core/ui/widgets/io_force_dialog.dart';
import '../../core/services/network_manager.dart';

class DigitalWidget extends StatelessWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;
  final VoidCallback? onStateChanged;
  final NetworkManager? networkManager;

  const DigitalWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
    this.onStateChanged,
    this.networkManager,
  });

  @override
  Widget build(BuildContext context) {
    bool isOn = false;
    bool isForced = false;
    bool hasValue = false;
    bool isFromInitialValue = false;
    String? address;
    String? description;

    if (config.tagId != null && project.tags.containsKey(config.tagId)) {
      final tag = project.tags[config.tagId!]!;
      address = tag.address ?? tag.name;
      description = tag.description;
      var tagVal = runtime?.tagStore.getValue(tag.id);
      if (tagVal == null && tag.address != null) {
        tagVal = runtime?.tagStore.getValue(tag.address!);
      }
      isForced = (runtime?.tagStore.isForced(tag.id) ?? false) ||
          (tag.address != null && (runtime?.tagStore.isForced(tag.address!) ?? false));
      hasValue = isForced || tagVal?.boolValue != null || tag.initialValue?.boolValue != null;
      isOn = tagVal?.boolValue ?? tag.initialValue?.boolValue ?? false;
      isFromInitialValue = tagVal?.boolValue == null && !isForced;
    }

    final stateText = !hasValue
        ? 'SEM DADOS'
        : (isOn ? config.onText : config.offText);
    final dotColor = isForced
        ? const Color(0xFFF59E0B)
        : (isOn ? const Color(0xFF10B981) : const Color(0xFF64748B));

    return InkWell(
      onTap: (config.tagId != null && runtime != null)
          ? () {
              IoForceDialog.show(
                context,
                tagId: config.tagId!,
                address: address,
                description: description,
                runtime: runtime,
                networkManager: networkManager,
                source: 'DIGITAL_WIDGET',
                onStateChanged: () => onStateChanged?.call(),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A202E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isForced
                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                : (isOn ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF222B3D)),
            width: 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: (isOn || isForced)
                              ? [
                                  BoxShadow(
                                    color: dotColor.withValues(alpha: 0.45),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (isForced)
                        const Positioned(
                          right: -3,
                          top: -3,
                          child: Icon(Icons.lock, size: 8, color: Color(0xFFF59E0B)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOn
                        ? 'ATIVO (1)'
                        : (hasValue ? 'DESLIGADO (0)' : 'SEM DADOS'),
                    style: TextStyle(
                      color: isOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: dotColor.withValues(alpha: 0.3), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stateText,
                      style: TextStyle(
                        color: dotColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
