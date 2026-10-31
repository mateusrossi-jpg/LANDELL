import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/ladder_node.dart';
import '../../../models/enums.dart';
import '../../../runtime/ladder_runtime.dart';
import '../../../runtime/node_runtime_state.dart';
import '../../../runtime/evaluators/pid_evaluator.dart';
import '../../../runtime/evaluators/timer_evaluator.dart';

class LadderNodeVisual extends StatelessWidget {
  final LadderNode node;
  final bool isSelected;
  final LadderRuntime runtime;

  const LadderNodeVisual({
    super.key,
    required this.node,
    required this.isSelected,
    required this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    final int ms = DateTime.now().millisecondsSinceEpoch;
    final double pulse = (math.sin(ms * 2 * math.pi / 1500) + 1.0) / 2.0;
    final double glowRadius = node.isEnergized ? 3.0 + (pulse * 4.0) : 0.0;
    final double glowOpacity = node.isEnergized ? 0.3 + (pulse * 0.3) : 0.0;

    final wireColor = node.isEnergized ? const Color(0xFF10B981) : const Color(0xFF64748B);

    final tagText = node.config.tagId ?? '';
    final hasTag = tagText.isNotEmpty;
    final displayTag = hasTag ? tagText : '<???>';

    Widget symbolWidget;
    switch (node.type) {
      case NodeType.contactNO:
        symbolWidget = SizedBox(
          width: 80,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header directly above contact (matching base.png / rockwell.png)
              Positioned(
                top: 4,
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (node.isEnergized ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left horizontal wire lead
              Positioned(
                left: 0,
                width: 28,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Left vertical contact bar
              Positioned(
                left: 28,
                top: 19,
                height: 26,
                width: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    borderRadius: BorderRadius.circular(0.5),
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Right vertical contact bar
              Positioned(
                right: 28,
                top: 19,
                height: 26,
                width: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    borderRadius: BorderRadius.circular(0.5),
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Right horizontal wire lead
              Positioned(
                right: 0,
                width: 28,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
        break;

      case NodeType.contactNC:
        symbolWidget = SizedBox(
          width: 80,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header directly above contact
              Positioned(
                top: 4,
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (node.isEnergized ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left horizontal wire lead
              Positioned(
                left: 0,
                width: 28,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Left vertical contact bar
              Positioned(
                left: 28,
                top: 19,
                height: 26,
                width: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    borderRadius: BorderRadius.circular(0.5),
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Right vertical contact bar
              Positioned(
                right: 28,
                top: 19,
                height: 26,
                width: 2.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    borderRadius: BorderRadius.circular(0.5),
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Right horizontal wire lead
              Positioned(
                right: 0,
                width: 28,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Diagonal Slash for NC
              Positioned(
                left: 29,
                right: 29,
                top: 19,
                height: 26,
                child: CustomPaint(painter: _DiagonalLinePainter(color: wireColor)),
              ),
            ],
          ),
        );
        break;

      case NodeType.coil:
      case NodeType.coilSet:
      case NodeType.coilReset:
        final String label = node.type == NodeType.coil
            ? ''
            : (node.type == NodeType.coilSet ? 'S' : 'R');
        final tagStoredValue = hasTag ? runtime.tagStore.getBool(tagText) : false;
        final bool isCoilActive;
        if (node.type == NodeType.coilReset) {
          isCoilActive = node.isEnergized;
        } else if (node.type == NodeType.coilSet) {
          isCoilActive = node.isEnergized || tagStoredValue;
        } else {
          isCoilActive = node.isEnergized || tagStoredValue;
        }

        final coilWireColor = isCoilActive ? const Color(0xFF10B981) : wireColor;

        symbolWidget = SizedBox(
          width: 80,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header directly above coil (matching base.png / rockwell.png)
              Positioned(
                top: 4,
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (isCoilActive ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left horizontal wire lead
              Positioned(
                left: 0,
                width: 25,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Parenthesis-style industrial coil (as seen in base.png `( )` and rockwell.png)
              Positioned(
                top: 17,
                left: 25,
                width: 30,
                height: 30,
                child: CustomPaint(
                  painter: _CoilParenthesisPainter(
                    color: coilWireColor,
                    isEnergized: isCoilActive,
                    badgeText: label,
                  ),
                ),
              ),
              // Right horizontal wire lead
              Positioned(
                right: 0,
                width: 25,
                height: 2.0,
                top: 31,
                child: Container(
                  decoration: BoxDecoration(
                    color: wireColor,
                    boxShadow: node.isEnergized
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 3.0,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
        break;

      case NodeType.timerTON:
      case NodeType.timerTOF:
      case NodeType.counterCTU:
      case NodeType.counterCTD:
        final String prefix;
        final String inPin;
        final String outPin;
        final String pPin;
        final String aPin;

        if (node.type == NodeType.timerTON) {
          prefix = 'TON';
          inPin = 'IN';
          outPin = 'Q';
          pPin = 'PT';
          aPin = 'ET';
        } else if (node.type == NodeType.timerTOF) {
          prefix = 'TOF';
          inPin = 'IN';
          outPin = 'Q';
          pPin = 'PT';
          aPin = 'ET';
        } else if (node.type == NodeType.counterCTU) {
          prefix = 'CTU';
          inPin = 'CU';
          outPin = 'Q';
          pPin = 'PV';
          aPin = 'CV';
        } else {
          prefix = 'CTD';
          inPin = 'CD';
          outPin = 'Q';
          pPin = 'PV';
          aPin = 'CV';
        }

        final isTimer = node.type == NodeType.timerTON || node.type == NodeType.timerTOF;
        NodeRuntimeState? runState = runtime.nodeStates[node.id];
        if (runState == null) {
          for (final s in runtime.nodeStates.values) {
            for (final sub in s.subNodeStates.values) {
              if (sub.nodeId == node.id) {
                runState = sub;
                break;
              }
            }
            if (runState != null) break;
          }
        }
        final tId = node.config.tagId ?? '';
        final int storeAcc = runtime.tagStore.getInt('$tId.ACC') > 0
            ? runtime.tagStore.getInt('$tId.ACC')
            : runtime.tagStore.getInt('$tId.ET');
        final int accValue = isTimer 
            ? ((runState?.accumulatedTimeMs ?? 0) > 0 ? (runState?.accumulatedTimeMs ?? 0) : storeAcc)
            : ((runState?.counterValue ?? 0) > 0 ? (runState?.counterValue ?? 0) : runtime.tagStore.getInt('$tId.CV'));

        final int presetMs = isTimer
            ? TimerEvaluator.resolveNodePreset(node, runtime.tagStore)
            : (node.config.presetValue?.intValue ?? 5);

        final String presetStr;
        if (isTimer) {
          presetStr = presetMs >= 1000 ? '$pPin:${(presetMs / 1000).toStringAsFixed(1)}s' : '$pPin:${presetMs}ms';
        } else {
          presetStr = '$pPin:$presetMs';
        }

        final String accStr;
        if (isTimer) {
          accStr = '$aPin:${(accValue / 1000).toStringAsFixed(1)}s';
        } else {
          accStr = '$aPin:$accValue';
        }

        symbolWidget = SizedBox(
          width: 116,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header above block
              Positioned(
                top: 0,
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (node.isEnergized ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left input lead wire (from 0 to 10, at Y=31)
              Positioned(
                left: 0,
                width: 10,
                height: 2,
                top: 31,
                child: Container(
                  color: node.isEnergized ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
              // Block Box (width: 96, from left: 10 to 106)
              Positioned(
                left: 10,
                width: 96,
                top: 15,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : (node.isEnergized ? const Color(0xFF10B981) : const Color(0xFF334155)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (node.isEnergized)
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: glowOpacity),
                          blurRadius: glowRadius,
                          spreadRadius: glowRadius / 2,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Dark header banner with bold white text
                      Container(
                        width: double.infinity,
                        height: 18,
                        color: const Color(0xFF1E293B),
                        alignment: Alignment.center,
                        child: Text(
                          prefix,
                          style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Pin labels (IN / Q at top row, PT / ET at bottom row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    inPin,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: node.isEnergized ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    outPin,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: node.isConducting ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      presetStr,
                                      style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      accStr,
                                      style: TextStyle(
                                        fontSize: 8.0,
                                        fontWeight: FontWeight.bold,
                                        color: node.isEnergized ? const Color(0xFF047857) : const Color(0xFF334155),
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right output lead wire (from 106 to 116, at Y=31)
              Positioned(
                right: 0,
                width: 10,
                height: 2,
                top: 31,
                child: Container(
                  color: node.isConducting ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
        break;

      case NodeType.compareEqual:
      case NodeType.compareGreater:
      case NodeType.compareLess:
      case NodeType.mathADD:
      case NodeType.mathSUB:
      case NodeType.mathMUL:
      case NodeType.mathDIV:
        final String opName;
        final String in1Label;
        final String in2Label;
        final String outLabel;

        switch (node.type) {
          case NodeType.compareEqual:
            opName = 'EQU';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'ENO';
            break;
          case NodeType.compareGreater:
            opName = 'GRT';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'ENO';
            break;
          case NodeType.compareLess:
            opName = 'LES';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'ENO';
            break;
          case NodeType.mathADD:
            opName = 'ADD';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'OUT';
            break;
          case NodeType.mathSUB:
            opName = 'SUB';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'OUT';
            break;
          case NodeType.mathMUL:
            opName = 'MUL';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'OUT';
            break;
          case NodeType.mathDIV:
            opName = 'DIV';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'OUT';
            break;
          default:
            opName = 'CMP';
            in1Label = 'IN1';
            in2Label = 'IN2';
            outLabel = 'OUT';
        }

        final pVal = node.config.presetValue;
        final rawValStr = pVal?.boolValue?.toString() ??
            pVal?.intValue?.toString() ??
            pVal?.realValue?.toString() ??
            pVal?.stringValue ??
            '';
        final upperTag = tagText.trim().toUpperCase();
        final isPctTag = upperTag == 'AI0.0' ||
            upperTag == 'AI0.1' ||
            upperTag == '%IW0.0' ||
            upperTag == '%IW0.1' ||
            upperTag == 'MV_PID' ||
            upperTag == 'SP_PID' ||
            upperTag == 'AO0.0' ||
            upperTag == 'AO0.1' ||
            upperTag == '%QW0.0' ||
            upperTag == '%QW0.1';
        final int livePctVal = runtime.tagStore.getReal(tagText) != 0.0
            ? runtime.tagStore.getReal(tagText).round()
            : runtime.tagStore.getInt(tagText);
        final String headerTagText = (isPctTag && hasTag)
            ? '$displayTag ($livePctVal%)'
            : displayTag;
        final String valStr = (isPctTag && rawValStr.isNotEmpty && !rawValStr.endsWith('%'))
            ? '$rawValStr%'
            : rawValStr;
        final String in1Display = isPctTag ? '$in1Label:$livePctVal%' : in1Label;

        symbolWidget = SizedBox(
          width: 116,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header above block
              Positioned(
                top: 0,
                child: Text(
                  headerTagText,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (node.isEnergized ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left input lead wire (EN wire at Y=31)
              Positioned(left: 0, width: 14, height: 2, top: 31, child: Container(color: wireColor)),
              // Block Box (width: 88, from left: 14 to 102)
              Positioned(
                left: 14,
                width: 88,
                top: 15,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1), // Industrial gray as in base.png
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : (node.isEnergized ? const Color(0xFF10B981) : const Color(0xFF334155)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (node.isEnergized)
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: glowOpacity),
                          blurRadius: glowRadius,
                          spreadRadius: glowRadius / 2,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Dark header banner with bold white text (e.g. ADD, GRT)
                      Container(
                        width: double.infinity,
                        height: 18,
                        color: const Color(0xFF1E293B),
                        alignment: Alignment.center,
                        child: Text(
                          opName,
                          style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Pin terminals as seen in base.png (EN / ENO, IN1 / OUT, IN2)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('EN', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'monospace')),
                                  Text(outLabel, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: node.isEnergized ? const Color(0xFF047857) : const Color(0xFF1E293B), fontFamily: 'monospace')),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(in1Display, style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace')),
                                  Flexible(
                                    child: Text(
                                      valStr.isNotEmpty ? valStr : in2Label,
                                      style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right output lead wire (ENO wire at Y=31)
              Positioned(right: 0, width: 14, height: 2, top: 31, child: Container(color: wireColor)),
            ],
          ),
        );
        break;

      case NodeType.pid:
        final pvStr = node.config.tagId ?? 'AI0.0';
        final spRaw = (node.config.setpointTagId ?? '50').replaceAll('%', '').trim();
        final mvStr = node.config.outputTagId ?? 'MV_PID';
        final int pvLive = runtime.tagStore.getReal(pvStr) != 0.0
            ? runtime.tagStore.getReal(pvStr).round()
            : runtime.tagStore.getInt(pvStr);
        final bool mvIsDigital = PidEvaluator.isDigitalOutputTag(mvStr);
        final int mvLive = mvIsDigital
            ? (runtime.tagStore.getBool(mvStr) ? 100 : 0)
            : (runtime.tagStore.getReal(mvStr) != 0.0
                ? runtime.tagStore.getReal(mvStr).round()
                : runtime.tagStore.getInt(mvStr));
        final String mvLiveText = mvIsDigital ? (mvLive > 0 ? 'ON' : 'OFF') : '$mvLive%';
        final bool pidManual = runtime.nodeStates[node.id]?.runtimeFlags['MAN'] == true;
        final String pidMode = '${(node.config.pidDirect ?? false) ? 'DIR' : 'REV'}${pidManual ? ' MAN' : ''}';
        final String spDisplay = double.tryParse(spRaw) != null
            ? '$spRaw%'
            : '$spRaw(${runtime.tagStore.getReal(spRaw) != 0.0 ? runtime.tagStore.getReal(spRaw).round() : runtime.tagStore.getInt(spRaw)}%)';

        symbolWidget = SizedBox(
          width: 148,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Tag Address Header above block with live %
              Positioned(
                top: 0,
                child: Text(
                  '$pvStr ($pvLive%)',
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (node.isEnergized ? const Color(0xFF10B981) : (hasTag ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8))),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Left input lead wire (from 0 to 14, at Y=31)
              Positioned(left: 0, width: 14, height: 2, top: 31, child: Container(color: wireColor)),
              // Block Box (width: 120, from left: 14 to 134)
              Positioned(
                left: 14,
                width: 120,
                top: 15,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1), // Industrial silver-gray
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : (node.isEnergized ? const Color(0xFF10B981) : const Color(0xFF334155)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (node.isEnergized)
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: glowOpacity),
                          blurRadius: glowRadius,
                          spreadRadius: glowRadius / 2,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Dark header banner with bold white text
                      Container(
                        width: double.infinity,
                        height: 18,
                        color: const Color(0xFF1E293B),
                        alignment: Alignment.center,
                        child: Text(
                          'PID $pidMode • MV:$mvLiveText',
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'monospace',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // Pin terminals (PV% / SP% and MV%)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('PV:$pvLive%', style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'monospace')),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text('SP:$spDisplay', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: node.isEnergized ? const Color(0xFF047857) : const Color(0xFF1E293B), fontFamily: 'monospace'))),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('EN', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace')),
                                  Flexible(child: Text('MV:$mvStr($mvLiveText)', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: node.isEnergized ? const Color(0xFF047857) : const Color(0xFF334155), fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right output lead wire (from 134 to 148, at Y=31)
              Positioned(right: 0, width: 14, height: 2, top: 31, child: Container(color: wireColor)),
            ],
          ),
        );
        break;

      case NodeType.parallel:
        symbolWidget = const SizedBox();
        break;
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: symbolWidget,
    );
  }
}

/// Industrial Parenthesis Coil Painter matching Rockwell / base.png `( )` style
class _CoilParenthesisPainter extends CustomPainter {
  final Color color;
  final bool isEnergized;
  final String badgeText;

  _CoilParenthesisPainter({
    required this.color,
    required this.isEnergized,
    required this.badgeText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const arcRadius = 13.0;

    // Left parenthesis arc `(`
    final leftCenter = Offset(arcRadius + 1, centerY);
    final leftRect = Rect.fromCircle(center: leftCenter, radius: arcRadius);
    canvas.drawArc(leftRect, 2.5, 1.28, false, arcPaint);

    // Right parenthesis arc `)`
    final rightCenter = Offset(size.width - arcRadius - 1, centerY);
    final rightRect = Rect.fromCircle(center: rightCenter, radius: arcRadius);
    canvas.drawArc(rightRect, -0.64, 1.28, false, arcPaint);

    // If there is a badge (e.g. S for Set, R for Reset), paint it centered
    if (badgeText.isNotEmpty) {
      final textSpan = TextSpan(
        text: badgeText,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoilParenthesisPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isEnergized != isEnergized ||
      oldDelegate.badgeText != badgeText;
}

class _DiagonalLinePainter extends CustomPainter {
  final Color color;

  _DiagonalLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
