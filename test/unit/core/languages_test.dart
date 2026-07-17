import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/languages.dart';
import '../../helpers/pump_screen.dart' show initTestLocalization;

/// The content-language registry — the single seam the generic-language-pairs
/// epic routes everything through. Adding a language later must mean: one
/// entry in Languages, one lang.<code> key per locale file, nothing else.
void main() {
  setUpAll(initTestLocalization);

  test('supported content languages are fr, en, it, de, es, ko', () {
    expect(Languages.supported, ['fr', 'en', 'it', 'de', 'es', 'ko']);
  });

  test('speech locales map to full BCP-47 tags', () {
    expect(Languages.speechLocaleFor('fr'), 'fr-FR');
    expect(Languages.speechLocaleFor('en'), 'en-US');
    expect(Languages.speechLocaleFor('it'), 'it-IT');
    expect(Languages.speechLocaleFor('de'), 'de-DE');
    expect(Languages.speechLocaleFor('es'), 'es-ES');
    expect(Languages.speechLocaleFor('ko'), 'ko-KR');
  });

  test('an unmapped language degrades to its own code, never to French', () {
    expect(Languages.speechLocaleFor('pt'), 'pt');
  });

  test('display names come from the lang.<code> i18n keys', () {
    // French translations are hydrated by initTestLocalization.
    expect(Languages.displayName('fr'), 'français');
    expect(Languages.displayName('en'), 'anglais');
    expect(Languages.displayName('it'), 'italien');
    expect(Languages.displayName('de'), 'allemand');
    expect(Languages.displayName('es'), 'espagnol');
    expect(Languages.displayName('ko'), 'coréen');
  });

  test('an unknown language falls back to the raw code', () {
    expect(Languages.displayName('xx'), 'xx');
  });

  group('script resolution (font + answer-scoring branch)', () {
    test('Korean is the only Hangul language today', () {
      expect(Languages.usesHangul('ko'), isTrue);
      expect(Languages.scriptFor('ko'), Script.hangul);
    });

    test('the new European languages are all Latin script', () {
      for (final code in ['fr', 'en', 'it', 'de', 'es']) {
        expect(Languages.usesHangul(code), isFalse, reason: code);
        expect(Languages.scriptFor(code), Script.latin, reason: code);
      }
    });

    test('an unknown language defaults to Latin, not Hangul', () {
      expect(Languages.scriptFor('xx'), Script.latin);
      expect(Languages.usesHangul('xx'), isFalse);
    });
  });
}
