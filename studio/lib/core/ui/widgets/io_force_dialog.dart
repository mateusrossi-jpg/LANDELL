import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../../ladder/runtime/ladder_runtime.dart';
import '../../services/hardware_force_bridge.dart';
import '../../services/network_manager.dart';
import '../../services/studio_event_bus.dart';
import '../../auth/session_manager.dart';

class IoForceDialog {
  static Future<void> show(
    BuildContext context, {
    required String tagId,
    String? address,
    String? description,
    required LadderRuntime? runtime,
    required VoidCallback onStateChanged,
    NetworkManager? networkManager,
    String source = 'IO_MATRIX',
  }) async {
    final currentVal = runtime?.tagStore.getBool(tagId) ?? false;
    final isForced = runtime?.tagStore.isForced(tagId) ?? false;
    final displayAddress = address ?? tagId;
    final operatorName = SessionManager.instance.currentUser ?? 'Operador Técnico';

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTokens.line, width: 1.0),
      ),
      builder: (BuildContext ctx) {
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTokens.focus.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTokens.focus.withValues(alpha: 0.4), width: 1.0),
                                ),
                                child: Text(
                                  displayAddress,
                                  style: const TextStyle(
                                    color: AppTokens.focus,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  tagId,
                                  style: const TextStyle(
                                    color: AppTokens.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (description != null && description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(color: AppTokens.textDim, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isForced)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTokens.warn.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTokens.warn.withValues(alpha: 0.5), width: 1.0),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: AppTokens.warn, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'FORÇADO',
                              style: TextStyle(
                                color: AppTokens.warn,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTokens.run.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTokens.run.withValues(alpha: 0.5), width: 1.0),
                        ),
                        child: const Text(
                          'MODO AUTO',
                          style: TextStyle(
                            color: AppTokens.run,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppTokens.line),
                const SizedBox(height: 12),

                // Status info box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTokens.line, width: 1.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ESTADO LÓGICO (SIMULAÇÃO LOCAL):',
                        style: TextStyle(color: AppTokens.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentVal ? AppTokens.run : AppTokens.textDim,
                              boxShadow: currentVal
                                  ? [BoxShadow(color: AppTokens.run.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentVal ? '1 (ON)' : '0 (OFF)',
                            style: TextStyle(
                              color: currentVal ? AppTokens.run : AppTokens.textDim,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'SELECIONE A AÇÃO DE FORÇAMENTO:',
                  style: TextStyle(
                    color: AppTokens.textDim,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    // Forçar ON
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.run,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          runtime?.tagStore.forceBool(tagId, true);
                          runtime?.singleScan(50);
                          StudioEventBus.instance.emit(
                            type: 'IO_FORCE',
                            source: source,
                            message: 'FORÇAMENTO: Tag $tagId ($displayAddress) FORÇADA PARA ON por $operatorName',
                            severity: EventSeverity.warning,
                          );

                          // Envia forçamento real ao hardware via HardwareForceBridge
                          await HardwareForceBridge.force(
                            networkManager,
                            address,
                            true,
                          );

                          onStateChanged();
                          Navigator.pop(ctx);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'FORÇAR ON',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Forçar OFF
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.panel2,
                          foregroundColor: AppTokens.text,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppTokens.line, width: 1.0),
                          ),
                        ),
                        onPressed: () async {
                          runtime?.tagStore.forceBool(tagId, false);
                          runtime?.singleScan(50);
                          StudioEventBus.instance.emit(
                            type: 'IO_FORCE',
                            source: source,
                            message: 'FORÇAMENTO: Tag $tagId ($displayAddress) FORÇADA PARA OFF por $operatorName',
                            severity: EventSeverity.warning,
                          );

                          // Envia forçamento real ao hardware via HardwareForceBridge
                          await HardwareForceBridge.force(
                            networkManager,
                            address,
                            false,
                          );

                          onStateChanged();
                          Navigator.pop(ctx);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'FORÇAR OFF',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Liberar Forçamento
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.focus,
                    side: const BorderSide(color: AppTokens.focus, width: 1.0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    runtime?.tagStore.releaseForce(tagId);
                    runtime?.singleScan(50);
                    StudioEventBus.instance.emit(
                      type: 'IO_RELEASE',
                      source: source,
                      message: 'LIBERAÇÃO: Tag $tagId ($displayAddress) retornou para MODO AUTO por $operatorName',
                      severity: EventSeverity.info,
                    );

                    // Libera forçamento real no hardware via HardwareForceBridge
                    await HardwareForceBridge.release(
                      networkManager,
                      address,
                    );

                    onStateChanged();
                    Navigator.pop(ctx);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'LIBERAR FORÇAMENTO (MODO AUTO)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
