import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/languages.dart';
import '../../helpers/pump_screen.dart' show initTestLocalization;

/// The content-language registry — the single seam the generic-language-pairs
/// epic routes everything through. Adding a language later must mean: one
/// entry in Languages, one lang.<code> key per locale file, nothing else.
void main() {
  setUpAll(initTestLocalization);

  test('supported content languages are fr and ko (for now)', () {
    expect(Languages.supported, ['fr', 'ko']);
  });

  test('speech locales map to full BCP-47 tags', () {
    expect(Languages.speechLocaleFor('fr'), 'fr-FR');
    expect(Languages.speechLocaleFor('ko'), 'ko-KR');
  });

  test('an unmapped language degrades to its own code, never to French', () {
    expect(Languages.speechLocaleFor('es'), 'es');
  });

  test('display names come from the lang.<code> i18n keys', () {
    // French translations are hydrated by initTestLocalization.
    expect(Languages.displayName('fr'), 'français');
    expect(Languages.displayName('ko'), 'coréen');
  });

  test('an unknown language falls back to the raw code', () {
    expect(Languages.displayName('xx'), 'xx');
  });
}
