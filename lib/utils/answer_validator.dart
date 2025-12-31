import 'package:string_similarity/string_similarity.dart';
import '../config/constants.dart';

/// Résultat de la validation d'une réponse
class ValidationResult {
  final bool isCorrect;
  final double similarityScore;
  final String? feedback;
  final ValidationResultType type;

  ValidationResult({
    required this.isCorrect,
    required this.similarityScore,
    this.feedback,
    required this.type,
  });

  @override
  String toString() {
    return 'ValidationResult(correct: $isCorrect, score: ${(similarityScore * 100).toStringAsFixed(1)}%, type: $type)';
  }
}

/// Types de résultats de validation
enum ValidationResultType {
  exact,           // Correspondance exacte
  acceptable,      // Correspondance avec tolérance
  registerMismatch, // Bon mot mais mauvais registre
  synonym,         // Synonyme valide
  incorrect,       // Faux
}

/// Validateur de réponses pour le quiz
class AnswerValidator {
  /// Valide une réponse de l'utilisateur
  /// 
  /// Paramètres:
  /// - [userAnswer]: Réponse de l'utilisateur
  /// - [expectedAnswers]: Liste des réponses acceptables
  /// - [strictRegister]: Vérifier le registre de langue?
  /// - [tolerance]: Niveau de tolérance pour les fautes (0.0 à 1.0)
  /// 
  /// Retourne: ValidationResult
  static ValidationResult validate({
    required String userAnswer,
    required List<Map<String, dynamic>> expectedAnswers,
    bool strictRegister = true,
    double tolerance = AppConstants.similarityThreshold,
  }) {
    if (userAnswer.trim().isEmpty) {
      return ValidationResult(
        isCorrect: false,
        similarityScore: 0.0,
        feedback: 'Aucune réponse fournie',
        type: ValidationResultType.incorrect,
      );
    }

    // Normaliser la réponse utilisateur
    final normalizedUserAnswer = _normalize(userAnswer);

    // Vérifier chaque réponse attendue
    double bestScore = 0.0;
    Map<String, dynamic>? bestMatch;
    ValidationResultType bestType = ValidationResultType.incorrect;

    for (var expected in expectedAnswers) {
      final expectedWord = expected['word'] as String;
      final normalizedExpected = _normalize(expectedWord);

      // Vérification exacte
      if (normalizedUserAnswer == normalizedExpected) {
        // Vérifier le registre si nécessaire
        if (strictRegister) {
          final expectedRegister = expected['register_tag'] as String?;
          final userRegister = expected['user_register'] as String?;
          
          if (expectedRegister != null && userRegister != null && 
              expectedRegister != userRegister) {
            return ValidationResult(
              isCorrect: false,
              similarityScore: 1.0,
              feedback: 'Mot correct mais registre incorrect (attendu: $expectedRegister, fourni: $userRegister)',
              type: ValidationResultType.registerMismatch,
            );
          }
        }

        return ValidationResult(
          isCorrect: true,
          similarityScore: 1.0,
          feedback: 'Parfait !',
          type: ValidationResultType.exact,
        );
      }

      // Calcul de similarité
      final similarity = normalizedUserAnswer.similarityTo(normalizedExpected);
      
      if (similarity > bestScore) {
        bestScore = similarity;
        bestMatch = expected;
        
        if (similarity >= tolerance) {
          bestType = ValidationResultType.acceptable;
        }
      }
    }

    // Si on a trouvé une correspondance acceptable
    if (bestScore >= tolerance && bestMatch != null) {
      return ValidationResult(
        isCorrect: true,
        similarityScore: bestScore,
        feedback: 'Presque ! (Attendu: "${bestMatch['word']}")',
        type: bestType,
      );
    }

    // Réponse incorrecte
    final correctAnswers = expectedAnswers
        .map((e) => e['word'] as String)
        .join(', ');
    
    return ValidationResult(
      isCorrect: false,
      similarityScore: bestScore,
      feedback: 'Incorrect. Réponse(s) attendue(s): $correctAnswers',
      type: ValidationResultType.incorrect,
    );
  }

  /// Normalise une chaîne pour la comparaison
  static String _normalize(String text) {
    String normalized = text.trim().toLowerCase();

    // Retirer les accents si la configuration le permet
    if (!AppConstants.accentSensitive) {
      normalized = _removeAccents(normalized);
    }

    // Respecter la casse si nécessaire
    if (AppConstants.caseSensitive) {
      normalized = text.trim();
    }

    return normalized;
  }

  /// Retire les accents d'une chaîne
  static String _removeAccents(String text) {
    const withAccents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const withoutAccents = 'aaaaaaceeeeiiiinooooouuuuyy';

    String result = text;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result;
  }

  /// Vérifie si deux registres sont compatibles
  static bool areRegistersCompatible(String? register1, String? register2) {
    if (register1 == null || register2 == null) return true;
    
    // Même registre = compatible
    if (register1 == register2) return true;

    // Neutre est compatible avec tout
    if (register1 == AppConstants.registerNeutral || 
        register2 == AppConstants.registerNeutral) {
      return true;
    }

    return false;
  }

  /// Calcule un score de qualité de réponse (pour feedback détaillé)
  static String getQualityFeedback(double similarityScore) {
    if (similarityScore >= 0.95) return 'Excellent !';
    if (similarityScore >= 0.90) return 'Très bien !';
    if (similarityScore >= 0.85) return 'Bien !';
    if (similarityScore >= 0.70) return 'Pas mal';
    if (similarityScore >= 0.50) return 'À revoir';
    return 'Incorrect';
  }

  /// Vérifie si une réponse est acceptable pour plusieurs variantes
  static List<String> findMatchingVariants({
    required String userAnswer,
    required List<Map<String, dynamic>> allVariants,
    double tolerance = AppConstants.similarityThreshold,
  }) {
    final normalizedAnswer = _normalize(userAnswer);
    final matches = <String>[];

    for (var variant in allVariants) {
      final word = variant['word'] as String;
      final normalizedWord = _normalize(word);
      
      if (normalizedAnswer == normalizedWord) {
        matches.add(variant['id'] as String);
      } else {
        final similarity = normalizedAnswer.similarityTo(normalizedWord);
        if (similarity >= tolerance) {
          matches.add(variant['id'] as String);
        }
      }
    }

    return matches;
  }
}
