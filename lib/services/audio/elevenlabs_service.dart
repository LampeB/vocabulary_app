import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../../config/api_config.dart';
import '../../models/audio_settings.dart';

/// Service pour interagir avec l'API ElevenLabs
class ElevenLabsService {
  static final ElevenLabsService _instance = ElevenLabsService._internal();

  factory ElevenLabsService() {
    return _instance;
  }

  ElevenLabsService._internal();

  /// Générer l'audio pour un texte avec paramètres personnalisés
  ///
  /// Paramètres:
  /// - text: Le texte à convertir en audio
  /// - langCode: Code de la langue (fr, ko, en, etc.)
  /// - settings: Paramètres audio (voix, stabilité, etc.)
  ///
  /// Retourne: Les bytes du fichier MP3 généré
  Future<Uint8List?> generateAudio({
    required String text,
    required String langCode,
    AudioSettings? settings,
  }) async {
    try {
      // Utiliser les paramètres fournis ou les valeurs par défaut
      final audioSettings = settings ?? AudioSettings.defaults;

      // Sélectionner la voix en fonction de la langue et des settings
      final voiceId = audioSettings.getVoiceForLanguage(langCode);

      final url = Uri.parse(
        '${ApiConfig.elevenLabsApiUrl}/text-to-speech/$voiceId',
      );

      print(
          '🎙️ Génération audio avec voix: ${ElevenLabsVoices.getNameFromId(voiceId)} ($voiceId)');
      print(
          '   Stabilité: ${audioSettings.stability}, Similarité: ${audioSettings.similarityBoost}');

      final response = await http
          .post(
            url,
            headers: ApiConfig.getElevenLabsHeaders(),
            body: jsonEncode({
              'text': text,
              'model_id': audioSettings.modelId,
              'voice_settings': {
                'stability': audioSettings.stability,
                'similarity_boost': audioSettings.similarityBoost,
              },
            }),
          )
          .timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        print(
            '✅ Audio généré avec succès (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        print('❌ Erreur ElevenLabs: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur lors de la génération audio: $e');
      return null;
    }
  }

  /// Calculer le hash MD5 d'un texte
  ///
  /// Utilisé pour créer un nom de fichier unique et éviter les doublons
  String calculateHash(String text, String langCode) {
    final combined = '$text-$langCode';
    final bytes = utf8.encode(combined);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Vérifier si l'API est configurée
  bool get isConfigured => ApiConfig.isElevenLabsConfigured;

  /// Obtenir les voix disponibles (pour debug)
  Future<List<dynamic>?> getAvailableVoices() async {
    try {
      final url = Uri.parse('${ApiConfig.elevenLabsApiUrl}/voices');

      final response = await http
          .get(
            url,
            headers: ApiConfig.getElevenLabsHeaders(),
          )
          .timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['voices'] as List<dynamic>;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des voix: $e');
      return null;
    }
  }
}
