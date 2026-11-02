import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/ladder/compiler/bytecode_compiler.dart';
import 'package:endap_studio/ladder/compiler/opcodes.dart';

void main(List<String> args) async {
  final ip = args.isNotEmpty ? args[0] : '192.168.4.1';
  print('Criando projeto limpo da bancada TCC...');
  final project = DemoProject.createCleanTccProject();
  print('Total de rungs: ${project.networks.length}');

  final compiler = BytecodeCompiler();
  var bytecode = compiler.compile(project, targetControllerId: 'GATEWAY');
  print('Bytecode inicial (${bytecode.length} bytes): $bytecode');

  final url = Uri.parse('http://$ip/api/automation/ladder');
  print('Enviando para $url...');

  final client = http.Client();
  try {
    var response = await client.post(
      url,
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytecode,
    ).timeout(const Duration(seconds: 5));

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    // Se rejeitado com invalid_bytecode e contiver PIDX (0x61), tenta fallback legado OP_PID (0x60)
    if (response.statusCode == 400 && response.body.contains('invalid_bytecode') && bytecode.contains(Opcodes.PIDX)) {
      print('ESP32 rejeitou OP_PIDX (0x61). Tentando fallback automático com OP_PID legado (0x60)...');
      bytecode = compiler.compile(project, targetControllerId: 'GATEWAY', useLegacyPid: true);
      print('Bytecode legado (${bytecode.length} bytes): $bytecode');
      response = await client.post(
        url,
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytecode,
      ).timeout(const Duration(seconds: 5));
      print('Response status fallback: ${response.statusCode}');
      print('Response body fallback: ${response.body}');
    }

    if (response.statusCode == 200) {
      print('>>> SUCESSO ABSOLUTO! DEPLOY REALIZADO NO GATEWAY! <<<');
      exit(0);
    } else {
      print('>>> FALHA: ${response.statusCode} <<<');
      exit(1);
    }
  } catch (e) {
    print('Erro na requisição: $e');
    exit(1);
  } finally {
    client.close();
  }
}
