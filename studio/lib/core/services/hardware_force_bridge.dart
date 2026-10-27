import '../../features/gpio_tags/services/gpio_service.dart';
import '../../ladder/models/plc_tag_contract.dart';
import 'network_manager.dart';
import 'studio_event_bus.dart';

/// Resultado de um forçamento enviado ao firmware.
enum HardwareForceResult {
  /// Firmware aceitou e aplicou o forçamento (GPIO/entrada travados).
  applied,

  /// Sem hardware online: o forçamento ficou apenas no runtime local (simulação).
  localOnly,

  /// Canal sem forçamento físico (analógico, memória, timer...).
  notForceable,

  /// Fail-safe ativo no firmware: forçamento recusado.
  blockedFailsafe,

  /// Erro de rede / resposta inesperada.
  failed,
}

/// Ponte única entre os pontos de forçamento da UI e o force real do firmware
/// (POST /api/io/force). Evita duplicar a lógica em cada tela.
class HardwareForceBridge {
  HardwareForceBridge._();

  /// ID de canal do firmware para E/S digitais físicas (I → 10.., Q → 100..).
  /// Retorna null para canais que não têm forçamento físico.
  static int? channelIdFor(String? address) {
    if (address == null || address.isEmpty) return null;
    final canon = PlcTagContract.normalizeAddress(address);
    if (canon == null) return null;
    if (!(canon.startsWith('I') || canon.startsWith('Q'))) return null;
    try {
      return PlcTagContract.addressToId(canon);
    } catch (_) {
      return null;
    }
  }

  static Future<HardwareForceResult> force(NetworkManager? nm, String? address, bool value) {
    return _send(nm, address, {'action': 'set', 'value': value ? 1 : 0});
  }

  static Future<HardwareForceResult> release(NetworkManager? nm, String? address) {
    return _send(nm, address, {'action': 'release'});
  }

  static Future<HardwareForceResult> releaseAll(NetworkManager? nm) async {
    if (nm == null || !nm.isHardwareOnline) return HardwareForceResult.localOnly;
    final status = await GpioService.instance.postForce(nm.gatewayIp, {'action': 'release_all'});
    return _report(status, 'TODOS');
  }

  static Future<HardwareForceResult> _send(
    NetworkManager? nm,
    String? address,
    Map<String, dynamic> body,
  ) async {
    if (nm == null || !nm.isHardwareOnline) return HardwareForceResult.localOnly;
    final id = channelIdFor(address);
    if (id == null) return HardwareForceResult.notForceable;
    final status = await GpioService.instance.postForce(nm.gatewayIp, {...body, 'id': id});
    return _report(status, address ?? '$id');
  }

  static HardwareForceResult _report(int? status, String label) {
    switch (status) {
      case 200:
        return HardwareForceResult.applied;
      case 404:
        return HardwareForceResult.notForceable;
      case 409:
        StudioEventBus.instance.emit(
          type: 'IO_FORCE_BLOCKED',
          source: 'ESP32 HARDWARE',
          message: 'Forçamento de $label RECUSADO pelo firmware: fail-safe ativo',
          severity: EventSeverity.critical,
        );
        return HardwareForceResult.blockedFailsafe;
      default:
        StudioEventBus.instance.emit(
          type: 'IO_FORCE_FAILED',
          source: 'ESP32 HARDWARE',
          message: 'Falha ao enviar forçamento de $label ao controlador (HTTP ${status ?? "sem resposta"})',
          severity: EventSeverity.warning,
        );
        return HardwareForceResult.failed;
    }
  }
}
