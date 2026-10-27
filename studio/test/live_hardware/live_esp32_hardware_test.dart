import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/auth/session_manager.dart';
import 'package:endap_studio/ladder/models/enums.dart';
import 'package:endap_studio/ladder/models/ladder_project.dart';
import 'package:endap_studio/ladder/models/ladder_network.dart';
import 'package:endap_studio/ladder/models/ladder_node.dart';
import 'package:endap_studio/ladder/models/node_config.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';

void main() {
  final esp32Ip = '192.168.0.27';
  final url = Uri.parse('http://$esp32Ip/api/automation/ladder');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.login('admin', 'Endap@2026!Secured');
  });

  group('Physical ESP32 Hardware Verification — P2 PLC Tags', () {
    test('1. Deploy Direct Direct Pass-through: I0.0 [ContactNO] -> (Q0.0)', () async {
      final project = LadderProject(id: 'plc_direct_proj', name: 'PLC Direct Test', tags: {});

      final tagI0 = Tag(id: 'I0.0', name: 'START_BUTTON', type: TagType.bool, address: 'I0.0');
      final tagQ0 = Tag(id: 'Q0.0', name: 'MAIN_OUTPUT', type: TagType.bool, address: 'Q0.0');
      project.tags['I0.0'] = tagI0;
      project.tags['Q0.0'] = tagQ0;

      final nodeI0 = LadderNode(id: 'c_i0', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0'));
      final nodeQ0 = LadderNode(id: 'c_q0', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0'));

      final network = LadderNetwork(id: 'net_direct', nodes: [nodeI0, nodeQ0], connections: [])..rebuildConnections();
      project.networks.add(network);

      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);

      // Verify compiler output operands
      final opI0 = (bytecode[6] << 8) | bytecode[7];
      final opQ0 = (bytecode[9] << 8) | bytecode[10];
      expect(opI0, equals(10), reason: 'I0.0 MUST compile to ID 10');
      expect(opQ0, equals(100), reason: 'Q0.0 MUST compile to ID 100');

      print('\n[ESP32 P2 TEST 1] Direct Bytecode I0.0 (10) -> Q0.0 (100) (Len ${bytecode.length}):');
      print(bytecode.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', '));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/octet-stream',
          ...SessionManager.instance.authHeaders,
        },
        body: bytecode,
      );

      print('[ESP32 Deploy Response] Status: ${response.statusCode}, Body: ${response.body}');
      expect(response.statusCode, equals(200));

      final ioMapResp = await http.get(
        Uri.parse('http://$esp32Ip/api/io/map'),
        headers: SessionManager.instance.authHeaders,
      );
      expect(ioMapResp.statusCode, equals(200));
      print('[ESP32 /api/io/map] ${ioMapResp.body}');
    });

    test('2. Deploy Bit Memory Cascade: I0.0 -> (M0.0) and M0.0 -> (Q0.0)', () async {
      final project = LadderProject(id: 'plc_memory_proj', name: 'PLC Memory Cascade Test', tags: {});

      final tagI0 = Tag(id: 'I0.0', name: 'START_BUTTON', type: TagType.bool, address: 'I0.0');
      final tagM0 = Tag(id: 'M0.0', name: 'INTERNAL_FLAG', type: TagType.bool, address: 'M0.0');
      final tagQ0 = Tag(id: 'Q0.0', name: 'MAIN_OUTPUT', type: TagType.bool, address: 'Q0.0');
      project.tags['I0.0'] = tagI0;
      project.tags['M0.0'] = tagM0;
      project.tags['Q0.0'] = tagQ0;

      // Rung 0: I0.0 -> (M0.0)
      final net0 = LadderNetwork(id: 'net0', nodes: [
        LadderNode(id: 'n_i0', type: NodeType.contactNO, config: NodeConfig(tagId: 'I0.0')),
        LadderNode(id: 'n_m0', type: NodeType.coil, config: NodeConfig(tagId: 'M0.0')),
      ], connections: [])..rebuildConnections();

      // Rung 1: M0.0 -> (Q0.0)
      final net1 = LadderNetwork(id: 'net1', nodes: [
        LadderNode(id: 'n_m0_in', type: NodeType.contactNO, config: NodeConfig(tagId: 'M0.0')),
        LadderNode(id: 'n_q0', type: NodeType.coil, config: NodeConfig(tagId: 'Q0.0')),
      ], connections: [])..rebuildConnections();

      project.networks.addAll([net0, net1]);

      final compiler = BytecodeCompiler();
      final bytecode = compiler.compile(project);

      // Verify operands: I0.0=10, M0.0=26, Q0.0=100
      final op1 = (bytecode[6] << 8) | bytecode[7];
      final op2 = (bytecode[9] << 8) | bytecode[10];
      final op3 = (bytecode[12] << 8) | bytecode[13];
      final op4 = (bytecode[15] << 8) | bytecode[16];

      expect(op1, equals(10), reason: 'I0.0 = 10');
      expect(op2, equals(26), reason: 'M0.0 = 26');
      expect(op3, equals(26), reason: 'M0.0 = 26');
      expect(op4, equals(100), reason: 'Q0.0 = 100');

      print('\n[ESP32 P2 TEST 2] Memory Cascade Bytecode I0.0(10)->M0.0(26)->Q0.0(100) (Len ${bytecode.length}):');
      print(bytecode.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', '));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/octet-stream',
          ...SessionManager.instance.authHeaders,
        },
        body: bytecode,
      );

      print('[ESP32 Deploy Response] Status: ${response.statusCode}, Body: ${response.body}');
      expect(response.statusCode, equals(200));

      final getProgramResp = await http.get(
        url,
        headers: SessionManager.instance.authHeaders,
      );
      expect(getProgramResp.statusCode, equals(200));
      print('[ESP32 Stored Bytecode Length] ${getProgramResp.bodyBytes.length} bytes');
    });
  });
}

