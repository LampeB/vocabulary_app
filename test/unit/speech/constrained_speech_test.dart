import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/constrained_speech_service.dart';

/// Pure logic of the constrained (Vosk) engine: grammar construction and
/// result-JSON parsing. The engine itself is device-only; these guard the
/// contract the quiz routing relies on — grammar always carries [unk], and
/// parseText never surfaces empty/[unk] junk as an answer.
void main() {
  group('buildGrammar', () {
    test('normalizes, dedupes, and appends [unk]', () {
      final g = ConstrainedSpeechService.buildGrammar(
          ['Thé', 'thé ', ' café', '']);
      expect(g, ['thé', 'café', '[unk]']);
    });

    test('korean answers pass through unchanged', () {
      final g = ConstrainedSpeechService.buildGrammar(['차', '자동차']);
      expect(g, ['차', '자동차', '[unk]']);
    });

    test('empty answers still yield a grammar with [unk] only', () {
      expect(ConstrainedSpeechService.buildGrammar([]), ['[unk]']);
    });
  });

  group('parseText', () {
    test('extracts final text', () {
      expect(
        ConstrainedSpeechService.parseText('{"text": "차"}', partial: false),
        '차',
      );
    });

    test('extracts partial text', () {
      expect(
        ConstrainedSpeechService.parseText('{"partial": "thé"}',
            partial: true),
        'thé',
      );
    });

    test('empty text → null (silence is never an answer)', () {
      expect(
        ConstrainedSpeechService.parseText('{"text": ""}', partial: false),
        isNull,
      );
      expect(
        ConstrainedSpeechService.parseText('{"partial": ""}', partial: true),
        isNull,
      );
    });

    test('[unk] and [unk]-padding are stripped, pure [unk] → null', () {
      expect(
        ConstrainedSpeechService.parseText('{"text": "[unk]"}',
            partial: false),
        isNull,
      );
      expect(
        ConstrainedSpeechService.parseText('{"text": "[unk] 차 [unk]"}',
            partial: false),
        '차',
      );
    });

    test('malformed JSON → null, never a throw', () {
      expect(
        ConstrainedSpeechService.parseText('not json', partial: false),
        isNull,
      );
      expect(
        ConstrainedSpeechService.parseText('{"text": 3}', partial: false),
        isNull,
      );
    });
  });
}
