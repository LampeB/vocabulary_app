import 'dart:convert';
import 'package:http/http.dart' as http;
import 'audio_service.dart';
import '../../config/app_config.dart';

/// Implémentation backend du service audio
/// Communique avec l'API backend qui gère ElevenLabs et le stockage
class BackendAudioService implements AudioService {
  final String baseUrl;

  BackendAudioService({String? baseUrl})
      : baseUrl = baseUrl ?? AppConfig.backendUrl;

  @override
  Future<AudioResult> getOrGenerateAudio({
    required String text,
    required String langCode,
    Function(String)? onProgress,
    bool forceRegenerate = false,
  }) async {
    try {
      onProgress?.call('Connexion au serveur...');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/audio/generate'),
            headers: AppConfig.getHeaders(),
            body: jsonEncode({
              'text': text,
              'langCode': langCode,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw BackendException(
          'Erreur serveur: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return AudioResult(
        hash: data['hash'] as String,
        audioUrl: '$baseUrl${data['url']}', // URL HTTP complète
        fromCache: data['fromCache'] as bool? ?? false,
      );
    } on http.ClientException catch (e) {
      throw NetworkException('Erreur réseau: ${e.message}');
    } catch (e) {
      throw BackendException('Erreur inattendue: $e');
    }
  }

  @override
  Future<String?> getAudioUrl(String hash) async {
    // Retourne directement l'URL HTTP du fichier sur le serveur
    return '$baseUrl/api/audio/$hash.mp3';
  }

  @override
  Future<bool> audioExists(String hash) async {
    try {
      final response = await http
          .head(
            Uri.parse('$baseUrl/api/audio/$hash.mp3'),
            headers: AppConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deleteAudio(String hash) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/audio/$hash'),
            headers: AppConfig.getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw BackendException(
          'Échec de la suppression: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Erreur réseau: ${e.message}');
    }
  }

  @override
  String calculateHash(String text, String langCode) {
    // Note: Le calcul du hash est délégué au serveur
    // Le serveur retournera le hash lors de la génération audio
    return '';
  }
}

/// Exception levée lors d'une erreur backend
class BackendException implements Exception {
  final String message;
  final int? statusCode;

  BackendException(this.message, {this.statusCode});

  @override
  String toString() =>
      'BackendException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Exception levée lors d'une erreur réseau
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
