/// Paramètres de génération audio ElevenLabs
class AudioSettings {
  /// Voix utilisée pour le français
  final String frenchVoiceId;
  
  /// Voix utilisée pour le coréen
  final String koreanVoiceId;
  
  /// Voix utilisée pour l'anglais
  final String englishVoiceId;
  
  /// Stabilité de la voix (0.0 - 1.0)
  /// Plus élevé = plus stable et prévisible
  /// Plus bas = plus expressif et varié
  final double stability;
  
  /// Similarité avec la voix originale (0.0 - 1.0)
  /// Plus élevé = plus proche de la voix originale
  /// Plus bas = plus de liberté créative
  final double similarityBoost;
  
  /// Modèle ElevenLabs à utiliser
  final String modelId;

  const AudioSettings({
    this.frenchVoiceId = 'pNInz6obpgDQGcFmaJgB', // Adam
    this.koreanVoiceId = '21m00Tcm4TlvDq8ikWAM', // Rachel
    this.englishVoiceId = '21m00Tcm4TlvDq8ikWAM', // Rachel
    this.stability = 0.5,
    this.similarityBoost = 0.75,
    this.modelId = 'eleven_multilingual_v2',
  });

  /// Paramètres par défaut
  static const AudioSettings defaults = AudioSettings();

  /// Obtenir la voix pour une langue
  String getVoiceForLanguage(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'fr':
        return frenchVoiceId;
      case 'ko':
        return koreanVoiceId;
      case 'en':
        return englishVoiceId;
      default:
        return englishVoiceId;
    }
  }

  /// Copier avec modifications
  AudioSettings copyWith({
    String? frenchVoiceId,
    String? koreanVoiceId,
    String? englishVoiceId,
    double? stability,
    double? similarityBoost,
    String? modelId,
  }) {
    return AudioSettings(
      frenchVoiceId: frenchVoiceId ?? this.frenchVoiceId,
      koreanVoiceId: koreanVoiceId ?? this.koreanVoiceId,
      englishVoiceId: englishVoiceId ?? this.englishVoiceId,
      stability: stability ?? this.stability,
      similarityBoost: similarityBoost ?? this.similarityBoost,
      modelId: modelId ?? this.modelId,
    );
  }

  /// Convertir en Map pour stockage
  Map<String, dynamic> toMap() {
    return {
      'frenchVoiceId': frenchVoiceId,
      'koreanVoiceId': koreanVoiceId,
      'englishVoiceId': englishVoiceId,
      'stability': stability,
      'similarityBoost': similarityBoost,
      'modelId': modelId,
    };
  }

  /// Créer depuis Map
  factory AudioSettings.fromMap(Map<String, dynamic> map) {
    return AudioSettings(
      frenchVoiceId: map['frenchVoiceId'] ?? defaults.frenchVoiceId,
      koreanVoiceId: map['koreanVoiceId'] ?? defaults.koreanVoiceId,
      englishVoiceId: map['englishVoiceId'] ?? defaults.englishVoiceId,
      stability: (map['stability'] ?? defaults.stability).toDouble(),
      similarityBoost: (map['similarityBoost'] ?? defaults.similarityBoost).toDouble(),
      modelId: map['modelId'] ?? defaults.modelId,
    );
  }

  @override
  String toString() {
    return 'AudioSettings(fr: $frenchVoiceId, ko: $koreanVoiceId, stability: $stability)';
  }
}

/// Voix ElevenLabs disponibles
class ElevenLabsVoices {
  static const Map<String, String> voices = {
    // Voix masculines
    'Adam': 'pNInz6obpgDQGcFmaJgB',
    'Antoni': 'ErXwobaYiN019PkySvjV',
    'Arnold': 'VR6AewLTigWG4xSOukaG',
    'Callum': 'N2lVS1w4EtoT3dr4eOWO',
    'Clyde': '2EiwWnXFnvU5JabPnv8n',
    'Daniel': 'onwK4e9ZLuTAKqWW03F9',
    'Eric': 'cjVigY5qzO86Huf0OWal',
    'George': 'JBFqnCBsd6RMkjVDRZzb',
    'Josh': 'TxGEqnHWrfWFTfGW9XjX',
    'Thomas': 'GBv7mTt0atIp3Br8iCZE',
    
    // Voix féminines
    'Bella': 'EXAVITQu4vr4xnSDxMaL',
    'Charlotte': 'XB0fDUnXU5powFXDhCwa',
    'Domi': 'AZnzlk1XvdvUeBnXmlld',
    'Dorothy': 'ThT5KcBeYPX3keUQqHPh',
    'Emily': 'LcfcDJNUP1GQjkzn1xUU',
    'Elli': 'MF3mGyEYCl7XYWbV9V6O',
    'Freya': 'jsCqWAovK2LkecY7zXl4',
    'Gigi': 'jBpfuIE2acCO8z3wKNLl',
    'Glinda': 'z9fAnlkpzviPz146aGWa',
    'Grace': 'oWAxZDx7w5VEj9dCyTzz',
    'Jessica': 'cgSgspJ2msm6clMCkdW9',
    'Lily': 'pFZP5JQG7iQjIQuC4Bku',
    'Matilda': 'XrExE9yKIg1WjnnlVkGX',
    'Nicole': 'piTKgcLEGmPE4e6mEKli',
    'Rachel': '21m00Tcm4TlvDq8ikWAM',
    'Sarah': 'EXAVITQu4vr4xnSDxMaL',
  };

  /// Obtenir le nom d'une voix depuis son ID
  static String? getNameFromId(String voiceId) {
    return voices.entries
        .firstWhere(
          (entry) => entry.value == voiceId,
          orElse: () => const MapEntry('Unknown', ''),
        )
        .key;
  }

  /// Voix recommandées par langue
  static const Map<String, List<String>> recommendedByLanguage = {
    'fr': ['Adam', 'Charlotte', 'Thomas', 'Bella'],
    'ko': ['Rachel', 'Lily', 'Sarah', 'Nicole'],
    'en': ['Rachel', 'Josh', 'Adam', 'Bella'],
  };
}
