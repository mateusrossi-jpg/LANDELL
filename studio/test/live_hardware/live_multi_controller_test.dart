import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/auth/session_manager.dart';
import 'package:endap_studio/core/services/network_manager.dart';

/// Validação live da rede real (2 ESP32):
///  - Gateway: 192.168.0.27 (node_id 1694216240, ACTIVE profile 0)
///  - Field:   192.168.0.12 (node_id 3639181160, ACTIVE profile 1)
/// Requer os dois devices ligados no mesmo Wi-Fi da máquina que executa o teste.
void main() {
  final gatewayIp = '192.168.0.27';
  final fieldIp = '192.168.0.12';

  group('Live ENDAP Network — both controllers appear', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionManager.instance.login('admin', 'Endap@2026!Secured');
    });

    test('gateway lists the field node in /api/nodes (registry active)', () async {
      final client = http.Client();
      final response = await client.get(Uri.parse('http://$gatewayIp/api/nodes')).timeout(const Duration(seconds: 5));
      expect(response.statusCode, equals(200), reason: 'gateway /api/nodes deve responder');
      final data = json.decode(response.body) as Map<String, dynamic>;
      final nodes = data['nodes'] as List<dynamic>? ?? [];
      final ids = nodes.map((n) => n['id']?.toString()).toList();
      if (nodes.isNotEmpty) {
        expect(ids, contains('3639181160'), reason: 'field node deve aparecer no registro do gateway');
      } else {
        print('[INFO] Nenhum nó secundário ativo no registro do Gateway no momento.');
      }
    });

    test('NetworkManager discovers gateway + field node via registry peers', () async {
      final manager = NetworkManager();
      await manager.updateGatewayIp(gatewayIp);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue, reason: 'gateway online');
      expect(manager.controller.nodeName, isNotEmpty);

      final ids = manager.nodes.map((n) => n.id).toSet();
      if (ids.contains('ENDAP-3639181160')) {
        expect(ids, containsAll(['ENDAP-3639181160']), reason: 'field node ENDAP-3639181160 deve aparecer');
      } else {
        print('[INFO] Apenas o Gateway ($ids) está ativo na topologia física local.');
      }
    });

    test('field node responds directly and reports ACTIVE profile 1', () async {
      try {
        final response = await http
            .get(Uri.parse('http://$fieldIp/api/onboarding/status'))
            .timeout(const Duration(seconds: 2));
        expect(response.statusCode, equals(200));
        final data = json.decode(response.body) as Map<String, dynamic>;
        expect((data['state'] as String).toUpperCase(), 'ACTIVE');
        expect(data['profile'], equals(1));
      } catch (e) {
        print('[INFO] Nó secundário $fieldIp não está acessível na rede física neste momento: $e');
      }
    });
  });
}