import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ladder/models/ladder_project.dart';

const String _kAutosaveKey = 'endap_ladder_autosave';
const String _kRawMigrationV2Key = 'landell_raw_migration_v2_done';

Future<void> saveCurrentLadder(LadderProject project) async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
    // Se o projeto ainda tiver o ID antigo de mock e o usuário editou, promove para ID de usuário
    final jsonMap = project.toJson();
    final jsonString = jsonEncode(jsonMap);
    await prefs.setString(_kAutosaveKey, jsonString);
    await prefs.setBool(_kRawMigrationV2Key, true);
  } catch (e) {
    // Fail silently in test/offline environments
  }
}

Future<LadderProject?> loadCurrentLadder() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
    final migrated = prefs.getBool(_kRawMigrationV2Key) ?? false;
    final jsonString = prefs.getString(_kAutosaveKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final savedId = map['id']?.toString() ?? '';
      // Na primeira abertura após remover os dados mockados, limpa o projeto mockado legado
      if (!migrated &&
          (savedId == 'proj_bancada_tcc_v5_pid_industrial' ||
           savedId == 'demo_irrigation_v1')) {
        await prefs.setBool(_kRawMigrationV2Key, true);
        final rawProj = LadderProject.raw();
        await prefs.setString(_kAutosaveKey, jsonEncode(rawProj.toJson()));
        return rawProj;
      }
      if (!migrated) {
        await prefs.setBool(_kRawMigrationV2Key, true);
      }
      return LadderProject.fromJson(map);
    } else if (!migrated) {
      await prefs.setBool(_kRawMigrationV2Key, true);
    }
  } catch (e) {
    // Fail silently
  }
  return null;
}

Future<LadderProject> resetToRawProject({String? name}) async {
  final rawProj = LadderProject.raw(
    id: 'proj_user_${DateTime.now().millisecondsSinceEpoch}',
    name: name ?? 'Meu Projeto',
  );
  await saveCurrentLadder(rawProj);
  return rawProj;
}

