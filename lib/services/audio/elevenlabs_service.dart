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

  Future<Uint8List?> generateAudio({
    required String text,
    required String langCode,
    AudioSettings? settings,
  }) async {
    try {
      final audioSettings = settings ?? AudioSettings.defaults;
      final voiceId = audioSettings.getVoiceForLanguage(langCode);

      final url = Uri.parse(
        '${ApiConfig.elevenLabsApiUrl}/text-to-speech/$voiceId',
      );

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
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String calculateHash(String text, String langCode) {
    final combined = '$text-$langCode';
    final bytes = utf8.encode(combined);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  bool get isConfigured => ApiConfig.isElevenLabsConfigured;

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
      return null;
    }
  }
}
