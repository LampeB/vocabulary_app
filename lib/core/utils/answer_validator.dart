import 'package:string_similarity/string_similarity.dart';
import '../constants/app_constants.dart';
import '../extensions/string_ext.dart';
import 'hangul_decomposer.dart';

enum ValidationResultType { exact, acceptable, typo, incorrect }

class ValidationResult {
  const ValidationResult({
    required this.isCorrect,
    required this.score,
    required this.type,
    this.feedback,
    this.matchedWord,
  });

  final bool isCorrect;
  final double score;
  final ValidationResultType type;
  final String? feedback;
  final String? matchedWord;
}

abstract final class AnswerValidator {
  static ValidationResult validate({
    required String userAnswer,
    required List<String> acceptedAnswers,
    bool isDrivingMode = false,
  }) {
    if (userAnswer.trim().isEmpty) {
      return const ValidationResult(
        isCorrect: false,
        score: 0,
        type: ValidationResultType.incorrect,
      );
    }

    final threshold = isDrivingMode
        ? AppConstants.fuzzyThresholdDriving
        : AppConstants.fuzzyThresholdTyping;

    final normalizedUser = _normalize(userAnswer);

    double bestScore = 0;
    String? bestMatch;

    for (final answer in acceptedAnswers) {
      final score = _scoreAgainst(normalizedUser, _normalize(answer));
      if (score > bestScore) {
        bestScore = score;
        bestMatch = answer;
      }
    }

    if (bestScore < threshold && normalizedUser.contains(' ')) {
      for (final word in normalizedUser.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        for (final answer in acceptedAnswers) {
          final score = _scoreAgainst(word, _normalize(answer));
          if (score > bestScore) {
            bestScore = score;
            bestMatch = answer;
          }
        }
      }
    }

    if (bestScore >= 0.98) {
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: ValidationResultType.exact,
        matchedWord: bestMatch,
      );
    }
    if (bestScore >= threshold) {
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: bestScore >= 0.90
            ? ValidationResultType.acceptable
            : ValidationResultType.typo,
        matchedWord: bestMatch,
      );
    }
    return ValidationResult(
      isCorrect: false,
      score: bestScore,
      type: ValidationResultType.incorrect,
      matchedWord: bestMatch,
    );
  }

  static double _scoreAgainst(String a, String b) {
    if (a == b) return 1.0;

    final isKorean = HangulDecomposer.containsHangul(a) ||
        HangulDecomposer.containsHangul(b);

    final directScore = a.similarityTo(b);

    if (!isKorean) return directScore;

    final jamoScore = HangulDecomposer.decompose(a)
        .similarityTo(HangulDecomposer.decompose(b));

    return directScore > jamoScore ? directScore : jamoScore;
  }

  static String _normalize(String text) {
    return text.trim().toLowerCase().removeAccents();
  }
}
