/// Paramètres de reconnaissance vocale (STT)
class SttSettings {
  /// Patience silence — temps d'attente pendant le silence (secondes)
  final int pauseForSeconds;

  /// Durée max d'écoute — durée totale d'enregistrement (secondes)
  final int listenForSeconds;

  /// Tolérance de réponse — seuil de similarité (0.0 - 1.0)
  final double answerTolerance;

  /// Tentatives max en mode mains-libres avant de passer au mot suivant
  final int maxRetryAttempts;

  const SttSettings({
    this.pauseForSeconds = 5,
    this.listenForSeconds = 10,
    this.answerTolerance = 0.85,
    this.maxRetryAttempts = 3,
  });

  static const SttSettings defaults = SttSettings();

  SttSettings copyWith({
    int? pauseForSeconds,
    int? listenForSeconds,
    double? answerTolerance,
    int? maxRetryAttempts,
  }) {
    return SttSettings(
      pauseForSeconds: pauseForSeconds ?? this.pauseForSeconds,
      listenForSeconds: listenForSeconds ?? this.listenForSeconds,
      answerTolerance: answerTolerance ?? this.answerTolerance,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pauseForSeconds': pauseForSeconds,
      'listenForSeconds': listenForSeconds,
      'answerTolerance': answerTolerance,
      'maxRetryAttempts': maxRetryAttempts,
    };
  }

  factory SttSettings.fromMap(Map<String, dynamic> map) {
    return SttSettings(
      pauseForSeconds: map['pauseForSeconds'] ?? defaults.pauseForSeconds,
      listenForSeconds: map['listenForSeconds'] ?? defaults.listenForSeconds,
      answerTolerance: (map['answerTolerance'] ?? defaults.answerTolerance).toDouble(),
      maxRetryAttempts: map['maxRetryAttempts'] ?? defaults.maxRetryAttempts,
    );
  }
}
