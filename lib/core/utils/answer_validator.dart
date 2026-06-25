import 'package:flutter/foundation.dart';
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
    debugPrint('[VAL] validate: transcript="$userAnswer"  accepted=$acceptedAnswers  isDrivingMode=$isDrivingMode');

    if (userAnswer.trim().isEmpty) {
      debugPrint('[VAL] → empty transcript → incorrect');
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
    debugPrint('[VAL] normalized: "$normalizedUser"  threshold=$threshold');

    double bestScore = 0;
    String? bestMatch;

    for (final answer in acceptedAnswers) {
      final score = _scoreAgainst(normalizedUser, _normalize(answer));
      debugPrint('[VAL]   vs "$answer" → score=${score.toStringAsFixed(3)}');
      if (score > bestScore) {
        bestScore = score;
        bestMatch = answer;
      }
    }
    debugPrint('[VAL] After main loop: bestScore=${bestScore.toStringAsFixed(3)}  bestMatch="$bestMatch"');

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

    // Korean STT commonly appends a grammatical particle to the spoken word
    // (e.g. user says "사과" → STT gives "사과를").  Two extra passes:
    //  1. Prefix check: if the expected answer (≥ 2 chars) is a prefix of
    //     the transcript, treat it as exact — the extra chars are a particle.
    //  2. Trailing-strip: try removing 1–2 trailing characters and re-score,
    //     which catches single-character particles that skew the similarity.
    if (bestScore < threshold &&
        HangulDecomposer.containsHangul(normalizedUser)) {
      debugPrint('[VAL] Below threshold — running Korean particle-strip pass');
      outer:
      for (final answer in acceptedAnswers) {
        final normAnswer = _normalize(answer);
        if (normAnswer.length >= 2 && normalizedUser.startsWith(normAnswer)) {
          debugPrint('[VAL]   prefix match: "$normalizedUser" starts with "$normAnswer" → score=1.0');
          bestScore = 1.0;
          bestMatch = answer;
          break outer;
        }
        for (int strip = 1;
            strip <= 2 && strip < normalizedUser.length;
            strip++) {
          final stripped =
              normalizedUser.substring(0, normalizedUser.length - strip);
          final score = _scoreAgainst(stripped, normAnswer);
          debugPrint('[VAL]   strip=$strip → "$stripped" vs "$normAnswer" = ${score.toStringAsFixed(3)}');
          if (score > bestScore) {
            bestScore = score;
            bestMatch = answer;
          }
        }
      }
      debugPrint('[VAL] After particle-strip pass: bestScore=${bestScore.toStringAsFixed(3)}  bestMatch="$bestMatch"');
    }

    if (bestScore >= 0.98) {
      debugPrint('[VAL] ✅ EXACT  score=${bestScore.toStringAsFixed(3)}');
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: ValidationResultType.exact,
        matchedWord: bestMatch,
      );
    }
    if (bestScore >= threshold) {
      debugPrint('[VAL] ✅ ACCEPTABLE  score=${bestScore.toStringAsFixed(3)}');
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: bestScore >= 0.90
            ? ValidationResultType.acceptable
            : ValidationResultType.typo,
        matchedWord: bestMatch,
      );
    }
    debugPrint('[VAL] ❌ INCORRECT  score=${bestScore.toStringAsFixed(3)}  threshold=$threshold');
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
