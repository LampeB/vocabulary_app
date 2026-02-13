import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stt_settings.dart';

/// Gestionnaire des préférences de reconnaissance vocale
class SttPreferences {
  static const String _key = 'stt_settings';

  static Future<void> saveSettings(SttSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toMap()));
  }

  static Future<SttSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);

    if (json == null) {
      return SttSettings.defaults;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return SttSettings.fromMap(map);
    } catch (_) {
      return SttSettings.defaults;
    }
  }

  static Future<void> resetToDefaults() async {
    await saveSettings(SttSettings.defaults);
  }
}
