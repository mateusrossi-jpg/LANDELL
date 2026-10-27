// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../models/ladder_project.dart';

String generateProjectFilename([DateTime? dt]) {
  final now = dt ?? DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  return 'projeto_endap_$y$m${d}_$h$min.endap';
}

String formatProjectJson(LadderProject project, {int scanPeriodMs = 100, String mode = 'RUN'}) {
  const encoder = JsonEncoder.withIndent('  ');
  final data = {
    'format': 'ENDAP_STUDIO_LADDER_PROJECT_V1',
    'exportedAt': DateTime.now().toIso8601String(),
    'runtimeConfig': {
      'scanPeriodMs': scanPeriodMs,
      'mode': mode,
    },
    'project': project.toJson(),
  };
  return encoder.convert(data);
}

Future<String?> exportProject(LadderProject project, {int scanPeriodMs = 100}) async {
  try {
    final jsonString = formatProjectJson(project, scanPeriodMs: scanPeriodMs);
    final fileName = generateProjectFilename();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    if (kIsWeb) {
      await FilePicker.saveFile(
        dialogTitle: 'Exportar Projeto ENDAP',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json', 'endap'],
      );
    } else {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Exportar Projeto ENDAP',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json', 'endap'],
        bytes: bytes,
      );
      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        debugPrint('Projeto salvo em: $result');
      }
    }
    return jsonString;
  } catch (e) {
    debugPrint('Erro ao exportar projeto: $e');
    return null;
  }
}

Future<LadderProject?> importProject() async {
  try {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Abrir Projeto ENDAP',
      type: FileType.custom,
      allowedExtensions: ['endap', 'json'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final fileData = result.files.first;
      String jsonString;
      if (kIsWeb || fileData.bytes != null) {
        jsonString = utf8.decode(fileData.bytes!);
      } else {
        final file = File(fileData.path!);
        jsonString = await file.readAsString();
      }
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      if (map.containsKey('project') && map['project'] is Map<String, dynamic>) {
        return LadderProject.fromJson(map['project'] as Map<String, dynamic>);
      }
      return LadderProject.fromJson(map);
    }
  } catch (e) {
    debugPrint('Erro ao importar projeto: $e');
  }
  return null;
}
