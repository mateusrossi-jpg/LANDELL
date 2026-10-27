import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/services/network_manager.dart';

/// Simula um controlador acessível pelo AP de gestão (192.168.4.1) que, após
/// conectar no Wi-Fi, passa a responder apenas pelo IP da STA (192.168.5.10).
({MockClient client, void Function(bool) setApDown}) _controllerClient() {
  var apDown = false;
  final mockClient = MockClient((request) async {
    final host = request.url.host;
    final path = request.url.path;

    if (host == '192.168.4.1') {
      if (apDown) {
        throw Exception('AP de gestão desligado');
      }
      if (path == '/api/public/status') {
        return http.Response(
          '{"node_id":123,"transport_name":"wifi","net_wifi_sta_ip_text":"192.168.5.10"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path == '/api/onboarding/status') {
        return http.Response('{"state":"ACTIVE","node_name":"ENDAP-Gateway","profile":0}', 200);
      }
      if (path == '/api/nodes') {
        return http.Response('{"nodes":[]}', 200);
      }
    }

    if (host == '192.168.5.10') {
      if (path == '/api/public/status') {
        return http.Response(
          '{"node_id":123,"transport_name":"wifi","net_wifi_sta_ip_text":"192.168.5.10"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path == '/api/onboarding/status') {
        return http.Response('{"state":"ACTIVE","node_name":"ENDAP-Gateway","profile":0}', 200);
      }
      if (path == '/api/nodes') {
        return http.Response('{"nodes":[]}', 200);
      }
    }

    return http.Response('Not Found', 404);
  });
  return (client: mockClient, setApDown: (down) => apDown = down);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ControllerInfo & NetworkManager Unit Tests', () {
    test('ControllerInfo initial state when offline', () {
      final ctrl = ControllerInfo.offline('192.168.4.1');
      expect(ctrl.isOnline, isFalse);
      expect(ctrl.isReady, isFalse);
      expect(ctrl.isPending, isFalse);
      expect(ctrl.onboardingStateRaw, 'OFFLINE');
      expect(ctrl.ip, '192.168.4.1');
    });

    test('ControllerInfo active/ready state calculation', () {
      final ctrl = ControllerInfo(
        id: 'ENDAP-1694216240',
        ip: '192.168.4.1',
        isOnline: true,
        onboardingState: ControllerOnboardingState.active,
        onboardingStateRaw: 'ACTIVE',
        nodeName: 'ENDAP-Gateway',
        transport: 'wifi-udp',
        profile: 0,
      );

      expect(ctrl.isOnline, isTrue);
      expect(ctrl.isReady, isTrue);
      expect(ctrl.isPending, isFalse);
      expect(ctrl.id, 'ENDAP-1694216240');
    });

    test('ControllerInfo pending/unprovisioned state calculation', () {
      final ctrl = ControllerInfo(
        id: 'ENDAP-1694216240',
        ip: '192.168.4.1',
        isOnline: true,
        onboardingState: ControllerOnboardingState.pending,
        onboardingStateRaw: 'PENDING',
        nodeName: 'ENDAP-Field-Node',
        transport: 'wifi-udp',
        profile: 1,
      );

      expect(ctrl.isOnline, isTrue);
      expect(ctrl.isReady, isFalse);
      expect(ctrl.isPending, isTrue);
    });

    test('NetworkManager parses ACTIVE onboarding state correctly via MockClient', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/public/status') {
          return http.Response(
            '{"node_id":1694216240,"transport_name":"wifi-udp","net_ready":1}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/onboarding/status') {
          return http.Response(
            '{"state":"ACTIVE","profile":0,"gateway_id":1694216240,"timestamp":67,"node_name":"ENDAP-Gateway-Principal"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/nodes') {
          return http.Response('{"nodes":[]}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.onboardingState, ControllerOnboardingState.active);
      expect(manager.controller.onboardingStateRaw, 'ACTIVE');
      expect(manager.controller.isReady, isTrue);
      expect(manager.controller.isPending, isFalse);
      expect(manager.controller.nodeName, 'ENDAP-Gateway-Principal');
      expect(manager.controller.profile, 0);
    });

    test('NetworkManager parses PENDING onboarding state correctly via MockClient', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/public/status') {
          return http.Response('{"node_id":123,"transport_name":"wifi-udp"}', 200);
        }
        if (request.url.path == '/api/onboarding/status') {
          return http.Response(
            '{"state":"PENDING","profile":1,"gateway_id":0,"timestamp":10,"node_name":"ENDAP-Node-1"}',
            200,
          );
        }
        if (request.url.path == '/api/nodes') {
          return http.Response('{"nodes":[]}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.onboardingState, ControllerOnboardingState.pending);
      expect(manager.controller.onboardingStateRaw, 'PENDING');
      expect(manager.controller.isReady, isFalse);
      expect(manager.controller.isPending, isTrue);
    });

    test('NetworkManager handles HTTP 500 on onboarding/status without crashing', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/public/status') {
          return http.Response('{"node_id":123,"transport_name":"wifi-udp"}', 200);
        }
        if (request.url.path == '/api/onboarding/status') {
          return http.Response('Internal Server Error', 500);
        }
        if (request.url.path == '/api/nodes') {
          return http.Response('{"nodes":[]}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.onboardingState, ControllerOnboardingState.unknown);
      expect(manager.controller.onboardingStateRaw, 'HTTP_500');
    });

    test('NetworkManager handles network exception on onboarding/status cleanly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/public/status') {
          return http.Response('{"node_id":123,"transport_name":"wifi-udp"}', 200);
        }
        if (request.url.path == '/api/onboarding/status') {
          throw Exception('Connection timeout');
        }
        if (request.url.path == '/api/nodes') {
          return http.Response('{"nodes":[]}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.onboardingState, ControllerOnboardingState.unknown);
      expect(manager.controller.onboardingStateRaw, 'ERRO_CONEXAO');
    });

    test('NetworkManager stores STA IP from public status', () async {
      final mock = _controllerClient();
      final manager = NetworkManager(client: mock.client);
      await manager.checkControllerAndScan();

      expect(manager.lastStaIp, '192.168.5.10');
      expect(manager.hasAlternativeControllerIp, isTrue);
    });

    test('NetworkManager fails over to STA IP automatically when AP goes down', () {
      final mock = _controllerClient();
      fakeAsync((async) {
        final manager = NetworkManager(client: mock.client);
        async.flushMicrotasks();
        expect(manager.lastStaIp, '192.168.5.10');

        // AP de gestão desligado (controlador agora só na rede STA).
        mock.setApDown(true);
        manager.startPeriodicCheck(interval: const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(manager.gatewayIp, '192.168.5.10');
        expect(manager.controller.isOnline, isTrue);
        expect(manager.controller.ip, '192.168.5.10');
        manager.stopPeriodicCheck();
      });
    });

    test('NetworkManager stays offline when STA IP is unreachable', () {
      fakeAsync((async) {
        // Controlador nem no AP, nem o IP da STA responde.
        final mockClient = MockClient((request) async {
          throw Exception('Sem rede');
        });
        final manager = NetworkManager(client: mockClient);
        async.flushMicrotasks();

        manager.startPeriodicCheck(interval: const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(manager.gatewayIp, '192.168.4.1');
        expect(manager.controller.isOnline, isFalse);
        expect(manager.isHardwareOnline, isFalse);
        manager.stopPeriodicCheck();
      });
    });

    test('discoverControllerAddress prefers mDNS (endap.local) when it responds', () async {
      var gatewayDown = false;
      var mdnsResponds = false;
      final mockClient = MockClient((request) async {
        final host = request.url.host;

        if (host == 'endap.local' && request.url.path == '/api/public/status' && mdnsResponds) {
          return http.Response(
            '{"node_id":123,"transport_name":"wifi","net_wifi_sta_ip_text":"10.0.0.50"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (host == '192.168.4.1') {
          if (gatewayDown) throw Exception('AP off');
          if (request.url.path == '/api/public/status') {
            return http.Response('{"node_id":123,"transport_name":"wifi"}', 200);
          }
          if (request.url.path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","node_name":"N","profile":0}', 200);
          }
          if (request.url.path == '/api/nodes') {
            return http.Response('{"nodes":[]}', 200);
          }
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();
      expect(manager.gatewayIp, '192.168.4.1');

      // mDNS começa a responder (controlador na rede LAN via endap.local).
      mdnsResponds = true;
      gatewayDown = true;

      // Descoberta direta.
      final addr = await manager.discoverControllerAddress();
      expect(addr, 'endap.local');
    });

    test('checkControllerAndScan auto-discovers via endap.local when initial IP fails', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'endap.local' && request.url.path == '/api/public/status') {
          return http.Response(
            '{"node_id":99,"transport_name":"wifi","net_wifi_sta_ip_text":"10.0.0.50"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.host == 'endap.local' && request.url.path == '/api/onboarding/status') {
          return http.Response('{"state":"ACTIVE","node_name":"Mdns-Node","profile":0}', 200);
        }
        if (request.url.host == 'endap.local' && request.url.path == '/api/nodes') {
          return http.Response('{"nodes":[]}', 200);
        }
        // Gateway IP 192.168.4.1 está inacessível.
        throw Exception('Sem rede');
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      // O NetworkManager deveria ter feito failover para endap.local.
      expect(manager.gatewayIp, 'endap.local');
      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.ip, 'endap.local');
      expect(manager.lastStaIp, '10.0.0.50');
    });

    test('discoverControllerAddress returns null when all candidates are unreachable', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Sem rede');
      });
      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      final addr = await manager.discoverControllerAddress();
      expect(addr, isNull);
    });

    test('nodes are repopulated automatically when gateway comes back online', () {
      var gatewayDown = false;
      final mockClient = MockClient((request) async {
        final host = request.url.host;
        final path = request.url.path;

        final isGateway = host == '192.168.4.1' || host == '192.168.0.27';
        if (isGateway) {
          if (gatewayDown) throw Exception('Gateway offline');
          if (path == '/api/public/status') {
            return http.Response(
              '{"node_id":1694216240,"transport_name":"wifi-udp","net_wifi_sta_ip_text":"192.168.0.27"}',
              200,
            );
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":0,"node_name":"ENDAP-Gateway"}', 200);
          }
          if (path == '/api/nodes') {
            return http.Response(
              '{"nodes":[{"id":3639181160,"ip":"192.168.0.12","cluster_state":"online","registry_state":"active","operational_state":"online"}]}',
              200,
            );
          }
        }
        if (host == '192.168.0.12') {
          if (path == '/api/public/status') {
            return http.Response('{"node_id":3639181160,"transport_name":"wifi-udp"}', 200);
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":1,"node_name":"ESP2_Sensor"}', 200);
          }
        }
        return http.Response('Not Found', 404);
      });

      fakeAsync((async) {
        final manager = NetworkManager(client: mockClient);
        async.flushMicrotasks();
        expect(manager.controller.isOnline, isTrue);
        expect(manager.nodes.map((n) => n.id), contains('ENDAP-3639181160'));

        // Gateway cai: nós devem ser limpos e controller offline.
        gatewayDown = true;
        manager.startPeriodicCheck(interval: const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(manager.controller.isOnline, isFalse);
        expect(manager.nodes, isEmpty);

        // Gateway volta: no próximo heartbeat a lista de nós deve reaparecer.
        gatewayDown = false;
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(manager.controller.isOnline, isTrue);
        expect(manager.nodes.map((n) => n.id), contains('ENDAP-3639181160'));

        manager.stopPeriodicCheck();
      });
    });
  });

  group('Multi-controller discovery & remote claim', () {
    test('discoverControllers finds gateway and pending field node', () async {
      final mockClient = MockClient((request) async {
        final host = request.url.host;
        final path = request.url.path;

        // Gateway (endap.local / AP de gestão).
        if (host == '192.168.4.1' || host == 'endap.local') {
          if (path == '/api/public/status') {
            return http.Response(
              '{"node_id":1694216240,"transport_name":"wifi-udp","net_wifi_sta_ip_text":"192.168.0.27"}',
              200,
            );
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":0,"node_name":"ENDAP-Gateway"}', 200);
          }
          if (path == '/api/nodes') {
            return http.Response(
              '{"nodes":[{"id":3639181160,"ip":"192.168.0.12","cluster_state":"online","registry_state":"discovered"}]}',
              200,
            );
          }
        }
        // Nó de campo pendente, descoberto pela STA IP via registro do gateway.
        if (host == '192.168.0.12') {
          if (path == '/api/public/status') {
            return http.Response('{"node_id":3639181160,"transport_name":"wifi-udp","net_wifi_sta_ip_text":"192.168.0.12"}', 200);
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"PENDING","profile":1,"node_name":"ENDAP-Field-Node"}', 200);
          }
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      // Gateway principal ativo.
      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.nodeName, 'ENDAP-Gateway');

      // O gateway aparece como controlador online + o nó de campo como PENDING
      // (candidato a adoção), não como ONLINE.
      expect(manager.nodes, hasLength(2));
      expect(manager.nodes.map((n) => n.id), contains('ENDAP-1694216240'));
      expect(manager.nodes.firstWhere((n) => n.id == 'ENDAP-3639181160').status, NodeStatus.pending);
    });

    test('adoptNode performs remote claim through the gateway', () async {
      final claims = <String>[];
      final mockClient = MockClient((request) async {
        final host = request.url.host;
        final path = request.url.path;

        if (host == '192.168.4.1') {
          if (path == '/api/onboarding/claim' && request.method == 'POST') {
            claims.add(request.body);
            return http.Response('{"ok":true}', 200);
          }
          if (path == '/api/public/status') {
            return http.Response('{"node_id":1694216240,"transport_name":"wifi-udp"}', 200);
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":0,"node_name":"ENDAP-Gateway"}', 200);
          }
          if (path == '/api/nodes') {
            return http.Response('{"nodes":[]}', 200);
          }
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      final ok = await manager.adoptNode('ENDAP-3639181160', 'Field Node');
      expect(ok, isTrue);
      expect(claims, hasLength(1));
      expect(claims.first, contains('target_node_id=3639181160'));
      expect(claims.first, contains('profile=1'));
      expect(claims.first, contains('gateway_id=1694216240'));
      expect(claims.first, contains('node_name='));
    });
  test('CONTROLADORES lista mostra o gateway e o nó ativo juntos', () async {
      // Caso real: gateway 192.168.0.27 (ACTIVE, profile 0) com um nó ativo
      // 192.168.0.12 (ACTIVE) registrado no cluster. A lista deve exibir AMBOS
      // como controladores — não só o que o /api/nodes retorna.
      final mockClient = MockClient((request) async {
        final host = request.url.host;
        final path = request.url.path;

        // Gateway principal.
        if (host == '192.168.4.1' || host == 'endap.local') {
          if (path == '/api/public/status') {
            return http.Response(
              '{"node_id":1694216240,"transport_name":"wifi-udp","net_wifi_sta_ip_text":"192.168.0.27"}',
              200,
            );
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":0,"node_name":"ENDAP-Gateway"}', 200);
          }
          if (path == '/api/nodes') {
            return http.Response(
              '{"nodes":[{"id":3639181160,"ip":"192.168.0.12","cluster_state":"online","registry_state":"active","operational_state":"online"}]}',
              200,
            );
          }
        }
        // Nó de campo já admitido e ativo.
        if (host == '192.168.0.12') {
          if (path == '/api/public/status') {
            return http.Response('{"node_id":3639181160,"transport_name":"wifi-udp","net_wifi_sta_ip_text":"192.168.0.12"}', 200);
          }
          if (path == '/api/onboarding/status') {
            return http.Response('{"state":"ACTIVE","profile":1,"node_name":"ESP2_Sensor_TCC"}', 200);
          }
        }
        return http.Response('Not Found', 404);
      });

      final manager = NetworkManager(client: mockClient);
      await manager.checkControllerAndScan();

      expect(manager.controller.isOnline, isTrue);
      expect(manager.controller.id, 'ENDAP-1694216240');

      final ids = manager.nodes.map((n) => n.id).toList();
      expect(ids, contains('ENDAP-1694216240'), reason: 'gateway deve aparecer na lista');
      expect(ids, contains('ENDAP-3639181160'), reason: 'nó ativo deve aparecer na lista');
      expect(manager.nodes.where((n) => n.status == NodeStatus.online), hasLength(2));
    });

  });
}
