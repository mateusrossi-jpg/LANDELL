import 'dart:io';
import 'package:http/http.dart' as http;
import '../lib/ladder/models/demo_project.dart';
import '../lib/ladder/compiler/bytecode_compiler.dart';

void main() async {
  print('Criando projeto limpo da bancada TCC...');
  final project = DemoProject.createCleanTccProject();
  print('Total de rungs: ${project.networks.length}');

  final compiler = BytecodeCompiler();
  final bytecode = compiler.compile(project, targetControllerId: 'GATEWAY');
  print('Bytecode gerado: ${bytecode.length} bytes: $bytecode');

  final url = Uri.parse('http://192.168.0.229/api/automation/ladder');
  print('Enviando para $url...');

  final client = http.Client();
  try {
    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytecode,
    ).timeout(const Duration(seconds: 5));

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      print('>>> SUCESSO ABSOLUTO! DEPLOY REALIZADO NO GATEWAY! <<<');
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
