import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';

/// WhisperSpeechService.cleanTranscript: event-tag stripping and the
/// per-language hallucination filter (whisper emits training-data boilerplate
/// on noise/near-silence; a marker match discards the transcript entirely).
void main() {
  String? clean(String raw) => WhisperSpeechService.cleanTranscript(raw);

  group('cleaning', () {
    test('strips bracketed/parenthesized event tags and punctuation', () {
      expect(clean('[Musique] bonjour !'), 'bonjour');
      expect(clean('(rires) chat.'), 'chat');
      expect(clean('*musique d\'outro* chien'), 'chien');
    });

    test('plain answers pass through', () {
      expect(clean(' thé '), 'thé');
      expect(clean('사과'), '사과');
    });

    test('nothing usable → null', () {
      expect(clean('[Musique]'), isNull);
      expect(clean('...'), isNull);
    });
  });

  group('hallucination markers per studied language (2026-07-22)', () {
    const boilerplate = {
      'fr': "Merci d'avoir regardé la vidéo",
      'en': 'Thank you for watching',
      'de': 'Untertitelung des ZDF für funk, 2017',
      'de2': 'Vielen Dank für Ihre Aufmerksamkeit',
      'it': 'Sottotitoli creati dalla comunità Amara.org',
      'it2': 'Grazie per la visione',
      'es': 'Subtítulos realizados por la comunidad de Amara.org',
      'es2': 'Gracias por ver el video',
      'ko': '시청해주셔서 감사합니다',
    };
    for (final entry in boilerplate.entries) {
      test('${entry.key}: "${entry.value}" is discarded', () {
        expect(clean(entry.value), isNull);
      });
    }

    test('real answers containing no markers survive in every language', () {
      for (final w in ['œuf', 'water', 'Wasser', 'acqua', 'agua', '물']) {
        expect(clean(w), isNotNull, reason: w);
      }
    });
  });
}
