import 'stt_debug_log.dart';
import 'package:string_similarity/string_similarity.dart';
import '../constants/app_constants.dart';
import '../extensions/string_ext.dart';
import 'french_phonetics.dart';
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
  /// Spoken-answer acceptance threshold. Mutable: user-tunable in settings
  /// ("tolérance vocale") — accents, environments and patience differ.
  /// Typed answers keep the fixed [AppConstants.fuzzyThresholdTyping].
  static double drivingThreshold = AppConstants.fuzzyThresholdDriving;

  /// The first recognizer candidate that validates as correct, or null.
  /// Speech engines frequently rank a near-homophone above the user's
  /// actual word (field log 2026-07-06: primary "병환이" 0.87 with
  /// alternate "병아리" 1.00 — the answer); grading must consider every
  /// candidate, not just the top transcript.
  static String? firstCorrect({
    required List<String> candidates,
    required List<String> acceptedAnswers,
    bool isDrivingMode = false,
  }) {
    for (final candidate in candidates) {
      final v = validate(
        userAnswer: candidate,
        acceptedAnswers: acceptedAnswers,
        isDrivingMode: isDrivingMode,
      );
      if (v.isCorrect) return candidate;
    }
    return null;
  }

  /// Removes disambiguation annotations from an accepted answer:
  /// "café (boisson)" → "café". Spoken/typed answers never contain the
  /// parenthetical, so scoring against the raw string only rejected
  /// correct answers over and over (field log 2026-07-09: "café" vs
  /// "café (boisson)" failed dozens of times in one session).
  static String stripAnnotations(String s) => s
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static ValidationResult validate({
    required String userAnswer,
    required List<String> acceptedAnswers,
    bool isDrivingMode = false,
  }) {
    // Expand the accepted answers before scoring; matching ANY form counts:
    //  - annotation-stripped: "café (boisson)" → "café"
    //  - slash-alternatives:  "riz / repas"    → "riz", "repas"
    acceptedAnswers = <String>{
      ...acceptedAnswers,
      for (final a in acceptedAnswers) stripAnnotations(a),
      for (final a in acceptedAnswers)
        ...a.split('/').map((p) => stripAnnotations(p)),
    }.where((a) => a.trim().isNotEmpty).toList();
    sttLog('[VAL] validate: transcript="$userAnswer"  accepted=$acceptedAnswers  isDrivingMode=$isDrivingMode');

    if (userAnswer.trim().isEmpty) {
      sttLog('[VAL] → empty transcript → incorrect');
      return const ValidationResult(
        isCorrect: false,
        score: 0,
        type: ValidationResultType.incorrect,
      );
    }

    final threshold =
        isDrivingMode ? drivingThreshold : AppConstants.fuzzyThresholdTyping;

    final normalizedUser = _normalize(userAnswer);
    sttLog('[VAL] normalized: "$normalizedUser"  threshold=$threshold');

    double bestScore = 0;
    String? bestMatch;

    for (final answer in acceptedAnswers) {
      final score = _scoreAgainst(normalizedUser, _normalize(answer),
          spoken: isDrivingMode);
      sttLog('[VAL]   vs "$answer" → score=${score.toStringAsFixed(3)}');
      if (score > bestScore) {
        bestScore = score;
        bestMatch = answer;
      }
    }
    sttLog('[VAL] After main loop: bestScore=${bestScore.toStringAsFixed(3)}  bestMatch="$bestMatch"');

    if (bestScore < threshold && normalizedUser.contains(' ')) {
      for (final word in normalizedUser.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        for (final answer in acceptedAnswers) {
          final score =
              _scoreAgainst(word, _normalize(answer), spoken: isDrivingMode);
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
      sttLog('[VAL] Below threshold — running Korean particle-strip pass');
      outer:
      for (final answer in acceptedAnswers) {
        final normAnswer = _normalize(answer);
        if (normAnswer.length >= 2 && normalizedUser.startsWith(normAnswer)) {
          sttLog('[VAL]   prefix match: "$normalizedUser" starts with "$normAnswer" → score=1.0');
          bestScore = 1.0;
          bestMatch = answer;
          break outer;
        }
        for (int strip = 1;
            strip <= 2 && strip < normalizedUser.length;
            strip++) {
          final stripped =
              normalizedUser.substring(0, normalizedUser.length - strip);
          final score =
              _scoreAgainst(stripped, normAnswer, spoken: isDrivingMode);
          sttLog('[VAL]   strip=$strip → "$stripped" vs "$normAnswer" = ${score.toStringAsFixed(3)}');
          if (score > bestScore) {
            bestScore = score;
            bestMatch = answer;
          }
        }
      }
      sttLog('[VAL] After particle-strip pass: bestScore=${bestScore.toStringAsFixed(3)}  bestMatch="$bestMatch"');
    }

    if (bestScore >= 0.98) {
      sttLog('[VAL] ✅ EXACT  score=${bestScore.toStringAsFixed(3)}');
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: ValidationResultType.exact,
        matchedWord: bestMatch,
      );
    }
    if (bestScore >= threshold) {
      sttLog('[VAL] ✅ ACCEPTABLE  score=${bestScore.toStringAsFixed(3)}');
      return ValidationResult(
        isCorrect: true,
        score: bestScore,
        type: bestScore >= 0.90
            ? ValidationResultType.acceptable
            : ValidationResultType.typo,
        matchedWord: bestMatch,
      );
    }
    sttLog('[VAL] ❌ INCORRECT  score=${bestScore.toStringAsFixed(3)}  threshold=$threshold');
    return ValidationResult(
      isCorrect: false,
      score: bestScore,
      type: ValidationResultType.incorrect,
      matchedWord: bestMatch,
    );
  }

  /// Korean initial lenis/aspirated/tense consonants are near-homophonous
  /// word-initially (밥 is pronounced with a voiceless ㅂ ≈ 팝) — NATIVE
  /// speakers produce these; STT picks either spelling (field 2026-07-13:
  /// a native speaker's 밥 transcribed 팝, scored 0.50). Spoken mode
  /// collapses the classes before jamo similarity; typed mode never does —
  /// spelling distinctions are the point when typing.
  static const _laxJamo = {
    'ㅍ': 'ㅂ', 'ㅃ': 'ㅂ',
    'ㅌ': 'ㄷ', 'ㄸ': 'ㄷ',
    'ㅋ': 'ㄱ', 'ㄲ': 'ㄱ',
    'ㅊ': 'ㅈ', 'ㅉ': 'ㅈ',
    'ㅆ': 'ㅅ',
  };

  // Jamo are single BMP code units — split('') is safe here.
  static String _laxKorean(String jamo) =>
      jamo.split('').map((c) => _laxJamo[c] ?? c).join();

  static double _scoreAgainst(String a, String b, {bool spoken = false}) {
    if (a == b) return 1.0;

    final isKorean = HangulDecomposer.containsHangul(a) ||
        HangulDecomposer.containsHangul(b);

    final directScore = a.similarityTo(b);

    if (isKorean) {
      final jamoA = HangulDecomposer.decompose(a);
      final jamoB = HangulDecomposer.decompose(b);
      var best = directScore;
      final jamoScore = jamoA.similarityTo(jamoB);
      if (jamoScore > best) best = jamoScore;
      if (spoken) {
        // Capped below 1.0 so phonetic equivalence can't claim EXACT.
        final laxScore = _laxKorean(jamoA)
            .similarityTo(_laxKorean(jamoB))
            .clamp(0.0, 0.95);
        if (laxScore > best) best = laxScore;
      }
      return best;
    }

    // Latin text: also score in sound-space — STT errors are phonetic
    // ("Mauvi" for "mauvais" shares no bigrams but the same sounds).
    // Capped at 0.97 so only orthographic identity reaches the EXACT tier.
    final phoneticScore = FrenchPhonetics.encode(a)
        .similarityTo(FrenchPhonetics.encode(b))
        .clamp(0.0, 0.97);
    return directScore > phoneticScore ? directScore : phoneticScore;
  }

  static String _normalize(String text) {
    return text.trim().toLowerCase().removeAccents();
  }
}
