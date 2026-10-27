import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/authenticated_http_client.dart';
import '../../../core/services/studio_event_bus.dart';
import '../../models/ladder_project.dart';
import '../../compiler/bytecode_compiler.dart';
import '../../compiler/bytecode_disassembler.dart';

/// Serviço responsável por sincronizar regras compiladas (Bytecode) com o ESP32.
class FirmwareSyncService {
  static const String _prefGatewayIpKey = 'firmware_gateway_ip';
  static const String _defaultGatewayIp = '192.168.0.229';

  final http.Client _client;

  FirmwareSyncService({http.Client? client})
      : _client = client ?? AuthenticatedHttpClient();

  static Future<String> getSavedGatewayIp() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 500));
      final saved = prefs.getString(_prefGatewayIpKey)?.trim();
      if (saved == null || saved.isEmpty || saved == '192.168.4.1' || saved == '192.168.0.27') {
        await prefs.setString(_prefGatewayIpKey, _defaultGatewayIp);
        return _defaultGatewayIp;
      }
      return saved;
    } catch (e) {
      debugPrint('Erro ao obter IP do Gateway: $e');
      return _defaultGatewayIp;
    }
  }

  static Future<void> saveGatewayIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 500));
      await prefs.setString(_prefGatewayIpKey, ip);
    } catch (e) {
      debugPrint('Erro ao salvar IP do Gateway: $e');
    }
  }

  /// Compila o projeto (ou um controlador específico) em Bytecode binário e envia via POST para o ESP32
  Future<bool> syncRules(String gatewayIp, LadderProject project, {String? targetControllerId}) async {
    try {
      if (project.networks.isEmpty) {
        debugPrint('Nenhum diagrama para sincronizar.');
        return false;
      }

      // 1. Gera o Bytecode Binário usando o Compiler
      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project, targetControllerId: targetControllerId);
      
      final url = Uri.parse('http://$gatewayIp/api/automation/ladder');
      debugPrint('Enviando payload binário (${bytecode.length} bytes) para $url');

      // 2. Envia o Binário Puro (Octet-stream)
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: bytecode,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Lógica binária sincronizada com sucesso no firmware.');
        StudioEventBus.instance.emit(
          type: 'LADDER_DEPLOY',
          source: 'FIRMWARE',
          message: 'Deploy de Bytecode Ladder realizado com sucesso no nó $gatewayIp (${bytecode.length} bytes)',
          severity: EventSeverity.info,
        );
        return true;
      } else {
        debugPrint('ESP32 rejeitou as regras: código ${response.statusCode}, corpo: ${response.body}');
        StudioEventBus.instance.emit(
          type: 'LADDER_DEPLOY_FAIL',
          source: 'FIRMWARE',
          message: 'Falha no Deploy de Bytecode Ladder para $gatewayIp: HTTP ${response.statusCode}',
          severity: EventSeverity.critical,
        );
        return false;
      }
    } catch (e) {
      debugPrint('Erro de conexão/sincronização com o Gateway do ESP32: $e');
      StudioEventBus.instance.emit(
        type: 'LADDER_DEPLOY_FAIL',
        source: 'FIRMWARE',
        message: 'Erro de conexão no Deploy para o nó $gatewayIp: $e',
        severity: EventSeverity.critical,
      );
      return false;
    }
  }

  /// Limpa a lógica binária gravada na Flash/NVS e RAM do ESP32 via POST vazio
  Future<bool> clearRules(String gatewayIp) async {
    final cleanIp = gatewayIp.trim();
    if (cleanIp.isEmpty) return false;
    try {
      final url = Uri.parse('http://$cleanIp/api/automation/ladder');
      debugPrint('Limpando lógica Ladder no ESP32: $url');

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: <int>[],
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('Lógica Ladder limpa com sucesso do CLP.');
        StudioEventBus.instance.emit(
          type: 'LADDER_CLEAR',
          source: 'FIRMWARE',
          message: 'Lógica Ladder removida do nó $gatewayIp (Modo Livre de E/S ativo)',
          severity: EventSeverity.info,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao limpar lógica Ladder no ESP32: $e');
      return false;
    }
  }

  /// Busca o bytecode binário gravado no ESP32 via GET e o desmonta em um LadderProject
  Future<LadderProject?> fetchRules(String gatewayIp) async {
    try {
      final url = Uri.parse('http://$gatewayIp/api/automation/ladder');
      debugPrint('Buscando lógica existente no ESP32 de $url');

      final response = await _client.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.length > 5) {
        final disassembler = BytecodeDisassembler();
        final project = disassembler.disassemble(Uint8List.fromList(response.bodyBytes));
        if (project.networks.isNotEmpty) {
          debugPrint('Lógica recuperada com sucesso do ESP32: ${project.networks.length} rungs.');
          StudioEventBus.instance.emit(
            type: 'LADDER_FETCH',
            source: 'FIRMWARE',
            message: 'Lógica Ladder recuperada do nó $gatewayIp: ${project.networks.length} rungs',
            severity: EventSeverity.info,
          );
          return project;
        }
      }
    } catch (e) {
      debugPrint('Não foi possível obter a lógica existente do ESP32 ($gatewayIp): $e');
    }
    return null;
  }
}
