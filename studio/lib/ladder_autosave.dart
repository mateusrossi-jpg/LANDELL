import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ladder/models/ladder_project.dart';

const String _kAutosaveKey = 'endap_ladder_autosave';

Future<void> saveCurrentLadder(LadderProject project) async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
    final jsonString = jsonEncode(project.toJson());
    await prefs.setString(_kAutosaveKey, jsonString);
  } catch (e) {
    // Fail silently
  }
}

Future<LadderProject?> loadCurrentLadder() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
    final jsonString = prefs.getString(_kAutosaveKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return LadderProject.fromJson(map);
    }
  } catch (e) {
    // Fail silently
  }
  return null;
}
