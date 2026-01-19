import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_settings.dart';

/// Gestionnaire des préférences audio
class AudioPreferences {
  static const String _keyAudioSettings = 'audio_settings';
  
  /// Sauvegarder les paramètres audio
  static Future<void> saveSettings(AudioSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(settings.toMap());
    await prefs.setString(_keyAudioSettings, json);
  }

  /// Charger les paramètres audio
  static Future<AudioSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyAudioSettings);
    
    if (json == null) {
      return AudioSettings.defaults;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return AudioSettings.fromMap(map);
    } catch (e) {
      print('Erreur lors du chargement des paramètres audio: $e');
      return AudioSettings.defaults;
    }
  }

  /// Réinitialiser aux valeurs par défaut
  static Future<void> resetToDefaults() async {
    await saveSettings(AudioSettings.defaults);
  }
}
