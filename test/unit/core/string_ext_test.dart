import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/extensions/string_ext.dart';

void main() {
  group('StringExt.normalized', () {
    test('trims leading and trailing whitespace', () {
      expect('  hello  '.normalized, 'hello');
    });

    test('lowercases ASCII letters', () {
      expect('Bonjour'.normalized, 'bonjour');
    });

    test('trims and lowercases together', () {
      expect('  Bonjour  '.normalized, 'bonjour');
    });

    test('empty string stays empty', () {
      expect(''.normalized, '');
    });
  });

  group('StringExt.removeAccents', () {
    test('maps all 28 accented source characters to ASCII equivalents', () {
      const src = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
      const dst = 'aaaaaaceeeeiiiinooooouuuuyy';
      expect(src.removeAccents(), dst);
    });

    test('unaccented characters are unchanged', () {
      expect('hello'.removeAccents(), 'hello');
    });

    test('mixed string: café → cafe', () {
      expect('café'.removeAccents(), 'cafe');
    });

    test('empty string returns empty string', () {
      expect(''.removeAccents(), '');
    });

    test('Korean characters are unchanged', () {
      expect('안녕'.removeAccents(), '안녕');
    });
  });

  group('StringExt.isKorean', () {
    test('true for pure Hangul string', () {
      expect('안녕'.isKorean, isTrue);
    });

    test('true for mixed Hangul and Latin', () {
      expect('hello안'.isKorean, isTrue);
    });

    test('false for Latin-only', () {
      expect('hello'.isKorean, isFalse);
    });

    test('false for empty string', () {
      expect(''.isKorean, isFalse);
    });
  });

  group('StringExt.isFrench', () {
    test('is the logical inverse of isKorean for Hangul string', () {
      expect('안녕'.isFrench, isFalse);
    });

    test('is the logical inverse of isKorean for Latin string', () {
      expect('bonjour'.isFrench, isTrue);
    });

    test('is the logical inverse of isKorean for empty string', () {
      expect(''.isFrench, isTrue);
    });
  });
}
