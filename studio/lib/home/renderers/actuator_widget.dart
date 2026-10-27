import 'package:flutter/material.dart';
import '../models/home_widget_config.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder/runtime/ladder_runtime.dart';

class ActuatorWidget extends StatefulWidget {
  final HomeWidgetConfig config;
  final LadderProject project;
  final LadderRuntime? runtime;
  final VoidCallback? onStateChanged;

  const ActuatorWidget({
    super.key,
    required this.config,
    required this.project,
    this.runtime,
    this.onStateChanged,
  });

  @override
  State<ActuatorWidget> createState() => _ActuatorWidgetState();
}

class _ActuatorWidgetState extends State<ActuatorWidget> {
  bool _isAuto = false;
  bool _pulseActive = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // AUTO / MANUAL Segmented Control
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF222B3D), width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isAuto = true);
                    widget.onStateChanged?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isAuto ? const Color(0xFF1E2638) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'AUTO',
                      style: TextStyle(
                        color: _isAuto ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isAuto = false);
                    widget.onStateChanged?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isAuto ? const Color(0xFF1E2638) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'MANUAL',
                      style: TextStyle(
                        color: !_isAuto ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // PULSE Button
        GestureDetector(
          onTap: () {
            setState(() => _pulseActive = !_pulseActive);
            if (widget.config.tagId != null && widget.runtime != null) {
              final tagId = widget.config.tagId!;
              final currentVal = widget.runtime!.tagStore.getBool(tagId);
              widget.runtime!.tagStore.setBool(tagId, !currentVal);
              widget.runtime!.singleScan(50);
            }
            widget.onStateChanged?.call();
          },
          child: Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _pulseActive ? const Color(0xFF2DD4BF) : const Color(0xFF222B3D),
                width: 1.0,
              ),
              color: _pulseActive ? const Color(0xFF2DD4BF).withValues(alpha: 0.15) : const Color(0xFF1A202E),
            ),
            alignment: Alignment.center,
            child: Text(
              'PULSE',
              style: TextStyle(
                color: _pulseActive ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
