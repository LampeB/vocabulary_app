/// Interface abstraite pour les services audio
/// Permet de basculer facilement entre implémentations locale et cloud
abstract class AudioService {
  /// Générer ou récupérer l'audio pour un texte
  ///
  /// Paramètres:
  /// - text: Le texte à convertir en audio
  /// - langCode: Code de la langue (fr, ko, en, etc.)
  /// - onProgress: Callback optionnel pour afficher la progression
  /// - forceRegenerate: Si true, régénère l'audio même s'il existe déjà
  ///
  /// Retourne: AudioResult contenant le hash et l'URL de l'audio
  Future<AudioResult> getOrGenerateAudio({
    required String text,
    required String langCode,
    Function(String)? onProgress,
    bool forceRegenerate = false,
  });

  /// Obtenir l'URL/chemin de lecture pour un hash
  ///
  /// Retourne: URL (HTTP) ou chemin local selon l'implémentation
  Future<String?> getAudioUrl(String hash);

  /// Vérifier si un audio existe pour un hash donné
  Future<bool> audioExists(String hash);

  /// Supprimer un audio
  Future<void> deleteAudio(String hash);

  /// Calculer le hash pour un texte et une langue
  String calculateHash(String text, String langCode);
}

/// Résultat d'une opération audio
class AudioResult {
  /// Hash unique de l'audio (MD5)
  final String hash;

  /// URL ou chemin de l'audio
  /// - Local: file:///C:/Users/.../audio/abc123.mp3
  /// - Cloud: https://api.example.com/audio/abc123.mp3
  final String audioUrl;

  /// Indique si l'audio provient du cache (true) ou a été généré (false)
  final bool fromCache;

  AudioResult({
    required this.hash,
    required this.audioUrl,
    required this.fromCache,
  });

  @override
  String toString() {
    return 'AudioResult(hash: $hash, fromCache: $fromCache)';
  }
}
