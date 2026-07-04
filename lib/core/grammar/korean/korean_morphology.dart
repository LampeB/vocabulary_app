/// Pure Korean morphology — the algorithmic heart of the Korean grammar
/// module. Everything here is jamo arithmetic on Hangul syllables; no data
/// files, no plugins. Lexical irregularity (ㄷ/ㅂ-class verbs etc.) is a
/// property of a WORD, not derivable from its written form, so callers pass
/// an [irregulars] override map (from rule content today, from word_variant
/// grammar metadata once the composer lands).
abstract final class KoreanMorphology {
  static const int _base = 0xAC00; // '가'
  static const int _syllableCount = 11172;
  static const int _finalsCount = 28;
  static const int _medialsCount = 21;

  // Medial (vowel) jamo indices used below:
  // ㅏ=0 ㅐ=1 ㅓ=4 ㅔ=5 ㅕ=6 ㅗ=8 ㅘ=9 ㅙ=10 ㅚ=11 ㅜ=13 ㅝ=14 ㅡ=18 ㅣ=20

  static bool isSyllable(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0) - _base;
    return code >= 0 && code < _syllableCount;
  }

  /// Whether the word's final syllable has a final consonant (batchim).
  static bool hasBatchim(String word) {
    final ch = word[word.length - 1];
    if (!isSyllable(ch)) return false;
    return (ch.codeUnitAt(0) - _base) % _finalsCount != 0;
  }

  static (int initial, int medial, int fin) _decompose(String ch) {
    final code = ch.codeUnitAt(0) - _base;
    return (
      code ~/ (_medialsCount * _finalsCount),
      (code ~/ _finalsCount) % _medialsCount,
      code % _finalsCount,
    );
  }

  static String _compose(int initial, int medial, int fin) =>
      String.fromCharCode(
          _base + initial * _medialsCount * _finalsCount + medial * _finalsCount + fin);

  /// Attaches a phonologically alternating particle (은/는, 이/가, 을/를 …).
  /// Invariant particles simply pass the same string for both forms.
  static String attachParticle(
    String word, {
    required String afterConsonant,
    required String afterVowel,
  }) =>
      word + (hasBatchim(word) ? afterConsonant : afterVowel);

  /// Present polite (아요/어요) from the dictionary form (…다).
  ///
  /// Handles algorithmically: 하다 verbs (…해요), vowel-harmony for batchim
  /// stems, and the standard final-vowel contractions (ㅏ, ㅗ→와, ㅜ→워,
  /// ㅣ→여, ㅐ/ㅔ, ㅚ→돼, and the ㅡ-drop with harmony from the previous
  /// syllable). Lexically irregular verbs (ㄷ: 듣다→들어요, ㅂ: 돕다→도와요…)
  /// must be supplied via [irregulars].
  static String presentPolite(
    String dictionaryForm, {
    Map<String, String> irregulars = const {},
  }) {
    final override = irregulars[dictionaryForm];
    if (override != null) return override;

    assert(dictionaryForm.endsWith('다'),
        'expected a dictionary form ending in 다: $dictionaryForm');
    final stem = dictionaryForm.substring(0, dictionaryForm.length - 1);

    // …하다 → …해요 (covers 하다 itself and every compound).
    if (stem.endsWith('하')) {
      return '${stem.substring(0, stem.length - 1)}해요';
    }

    final last = stem[stem.length - 1];
    final head = stem.substring(0, stem.length - 1);
    final (initial, medial, fin) = _decompose(last);

    if (fin != 0) {
      // Batchim stem: plain vowel harmony, no contraction.
      final bright = medial == 0 || medial == 8 || medial == 9; // ㅏ ㅗ ㅘ
      return '$stem${bright ? '아요' : '어요'}';
    }

    // Open (vowel-final) stem: contractions.
    switch (medial) {
      case 0: // ㅏ: 가 + 아요 → 가요
        return '$stem요';
      case 1: // ㅐ: 보내 → 보내요
      case 5: // ㅔ
      case 4: // ㅓ: 서 → 서요
      case 6: // ㅕ
        return '$stem요';
      case 8: // ㅗ → ㅘ: 오 → 와요, 보 → 봐요
        return '$head${_compose(initial, 9, 0)}요';
      case 13: // ㅜ → ㅝ: 배우 → 배워요
        return '$head${_compose(initial, 14, 0)}요';
      case 20: // ㅣ → ㅕ: 마시 → 마셔요
        return '$head${_compose(initial, 6, 0)}요';
      case 11: // ㅚ → ㅙ: 되 → 돼요
        return '$head${_compose(initial, 10, 0)}요';
      case 18: // ㅡ-drop: 바쁘 → 바빠요, 크 → 커요 (harmony from prev syllable)
        var bright = false;
        if (head.isNotEmpty && isSyllable(head[head.length - 1])) {
          final (_, prevMedial, _) = _decompose(head[head.length - 1]);
          bright = prevMedial == 0 || prevMedial == 8 || prevMedial == 9;
        }
        return '$head${_compose(initial, bright ? 0 : 4, 0)}요';
      default:
        return '$stem어요';
    }
  }

  /// Negation with 안 at present polite.
  ///
  /// - [irregulars] wins (incl. pedagogical answers like 맛있다 → 맛없어요).
  /// - noun+하다 compounds split: 공부하다 → 공부 안 해요.
  /// - everything else: 안 + present polite.
  static String negatePresent(
    String dictionaryForm, {
    Map<String, String> irregulars = const {},
    Map<String, String> conjugationIrregulars = const {},
  }) {
    final override = irregulars[dictionaryForm];
    if (override != null) return override;

    if (dictionaryForm.endsWith('하다') && dictionaryForm.length > 2) {
      final noun = dictionaryForm.substring(0, dictionaryForm.length - 2);
      return '$noun 안 해요';
    }
    return '안 ${presentPolite(dictionaryForm, irregulars: conjugationIrregulars)}';
  }

  /// The strictly mechanical negation (안 + conjugated form), ignoring
  /// pedagogical overrides — used as an ACCEPTED alternative when a rule's
  /// irregulars map prefers an antonym (맛있다 → 맛없어요 vs 안 맛있어요).
  static String mechanicalNegation(
    String dictionaryForm, {
    Map<String, String> conjugationIrregulars = const {},
  }) {
    if (dictionaryForm.endsWith('하다') && dictionaryForm.length > 2) {
      final noun = dictionaryForm.substring(0, dictionaryForm.length - 2);
      return '$noun 안 해요';
    }
    return '안 ${presentPolite(dictionaryForm, irregulars: conjugationIrregulars)}';
  }
}
