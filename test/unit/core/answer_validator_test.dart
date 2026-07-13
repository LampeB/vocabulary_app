import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/answer_validator.dart';

/// AnswerValidator drives every typing/voice verdict. Coverage found the
/// STT-oriented passes untested: the multi-word transcript pass and the two
/// Korean particle-strip passes (prefix match, trailing-strip).
void main() {
  ValidationResult validate(String user, List<String> accepted,
          {bool driving = false}) =>
      AnswerValidator.validate(
          userAnswer: user,
          acceptedAnswers: accepted,
          isDrivingMode: driving);

  group('base verdicts', () {
    test('empty transcript → incorrect', () {
      final r = validate('   ', ['chat']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });

    test('exact match → exact, matchedWord set', () {
      final r = validate('chat', ['chat', 'minou']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.matchedWord, 'chat');
      expect(r.score, 1.0);
    });

    test('case, accents and whitespace are normalized away', () {
      final r = validate('  Éléphant ', ['elephant']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
    });

    test('near-miss above 0.90 → acceptable', () {
      // "bibliothequ" vs "bibliotheque": one char short → dice ≈ 0.95.
      final r = validate('bibliothequ', ['bibliothèque']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.acceptable);
    });

    test('near-miss between threshold and 0.90 still accepts', () {
      // "bibliotheqe" vs "bibliotheque": orthographic dice ≈ 0.857. Since
      // the phonetic pass (2026-07-10) it is also SOUND-identical (silent
      // letters), which lifts it into the acceptable tier — the tier
      // matters less than the verdict.
      final r = validate('bibliotheqe', ['bibliothèque']);
      expect(r.isCorrect, isTrue);
      expect(r.type, isNot(ValidationResultType.exact));
    });

    test('unrelated word → incorrect with the best score reported', () {
      final r = validate('voiture', ['chat']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });

    test('best of several accepted answers wins', () {
      final r = validate('minou', ['chat', 'minou']);
      expect(r.isCorrect, isTrue);
      expect(r.matchedWord, 'minou');
    });
  });

  group('multi-word transcript pass (STT gives a sentence)', () {
    test('the answer buried in a longer transcript is found word-by-word', () {
      // Whole-string similarity of "le petit chat" vs "chat" is far below the
      // threshold; the per-word pass matches "chat" exactly.
      final r = validate('le petit chat', ['chat']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.matchedWord, 'chat');
    });

    test('a sentence with no matching word stays incorrect', () {
      final r = validate('une grande maison', ['chat']);
      expect(r.isCorrect, isFalse);
    });
  });

  group('Korean particle passes (STT appends particles)', () {
    test('prefix pass: transcript = answer + particle → exact', () {
      // User said 사과, STT transcribed 사과를 (object particle appended).
      final r = validate('사과를', ['사과']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.score, 1.0);
      expect(r.matchedWord, '사과');
    });

    test(
        'trailing-strip pass: single-char answer + particle → exact '
        '(prefix pass requires ≥ 2 chars, so this exercises the strip loop)',
        () {
      // 물 (water) + 을 → prefix check is skipped (answer < 2 chars), the
      // 1-char strip re-score finds the exact match.
      final r = validate('물을', ['물']);
      expect(r.isCorrect, isTrue);
      expect(r.score, 1.0);
      expect(r.matchedWord, '물');
    });

    test('unrelated Korean word is still rejected after all passes', () {
      final r = validate('바나나', ['사과']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });
  });

  group('phonetic pass (field bug 2026-07-10 — whisper garbles sounds)', () {
    test('"Mauvi" scores close to "mauvais" — same sounds, alien spelling',
        () {
      final r = validate('Mauvi', ['mauvais'], driving: true);
      // /movi/ vs /move/ — sound-space similarity must beat the near-zero
      // bigram score and clear the lenient (Souple 0.55) bar.
      expect(r.score, greaterThanOrEqualTo(0.55));
    });

    test('"Tadung" stays garbage against "mauvais"', () {
      final r = validate('Tadung', ['mauvais'], driving: true);
      expect(r.score, lessThan(0.35));
    });

    test('"Doigre" vs "boire" lands in the borderline band, not a fail', () {
      final r = validate('Doigre', ['boire'], driving: true);
      expect(r.isCorrect, isFalse);
      expect(r.score, greaterThanOrEqualTo(0.35));
    });

    test('phonetic near-match never claims the EXACT tier', () {
      final r = validate('mauvé', ['mauvais'], driving: true);
      expect(r.isCorrect, isTrue);
      expect(r.type, isNot(ValidationResultType.exact));
    });

    test('unrelated French words remain rejected', () {
      expect(validate('bonjour', ['mauvais'], driving: true).isCorrect,
          isFalse);
    });
  });

  group('Korean spoken phonetic leniency (field 2026-07-13)', () {
    // A NATIVE speaker's 밥 was transcribed 팝 — word-initial lenis ㅂ is
    // voiceless, near-homophonous with ㅍ. Spoken mode collapses
    // lenis/aspirated/tense classes; typed mode never does.
    test('팝 accepts for 밥 when SPOKEN', () {
      final r = validate('팝', ['밥'], driving: true);
      expect(r.isCorrect, isTrue);
      expect(r.type, isNot(ValidationResultType.exact));
    });

    test('팝 stays wrong for 밥 when TYPED', () {
      expect(validate('팝', ['밥']).isCorrect, isFalse);
    });

    test('other class pairs: 통 accepts for 동 spoken', () {
      expect(validate('통', ['동'], driving: true).isCorrect, isTrue);
    });

    test('genuinely different Korean words stay rejected spoken', () {
      expect(validate('물', ['밥'], driving: true).isCorrect, isFalse);
    });
  });

  group('annotated answers (field bug 2026-07-09)', () {
    // "café" spoken against stored answer "café (boisson)" was rejected
    // dozens of times in one hands-free session — the parenthetical is a
    // disambiguation note, never part of the spoken/typed answer.
    test('spoken form matches an annotated accepted answer exactly', () {
      final r = validate('café', ['café (boisson)']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
    });

    test('typing the full annotated string still matches', () {
      final r = validate('café (boisson)', ['café (boisson)']);
      expect(r.isCorrect, isTrue);
    });

    test('annotation does not open the door to wrong words', () {
      final r = validate('vin', ['café (boisson)']);
      expect(r.isCorrect, isFalse);
    });

    test('slash-alternatives: either side of "riz / repas" matches', () {
      expect(validate('riz', ['riz / repas']).isCorrect, isTrue);
      expect(validate('repas', ['riz / repas']).isCorrect, isTrue);
      expect(validate('pain', ['riz / repas']).isCorrect, isFalse);
    });

    test('drivingThreshold is tunable: a 0.78 near-miss flips with it', () {
      // "Restourant" vs "restaurant" ≈ 0.78 — accepted at the default
      // (0.75), rejected once the user picks Strict (0.85).
      final prev = AnswerValidator.drivingThreshold;
      try {
        AnswerValidator.drivingThreshold = 0.75;
        expect(validate('Restourant', ['restaurant'], driving: true).isCorrect,
            isTrue);
        AnswerValidator.drivingThreshold = 0.85;
        expect(validate('Restourant', ['restaurant'], driving: true).isCorrect,
            isFalse);
      } finally {
        AnswerValidator.drivingThreshold = prev;
      }
    });

    test('stripAnnotations collapses whitespace', () {
      expect(AnswerValidator.stripAnnotations('café (boisson)'), 'café');
      expect(AnswerValidator.stripAnnotations('avoir (posséder) qqch'),
          'avoir qqch');
    });
  });
}
