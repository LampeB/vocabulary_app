import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/hangul_decomposer.dart';

void main() {
  group('HangulDecomposer.decompose', () {
    test('single syllable with no final consonant', () {
      expect(HangulDecomposer.decompose('가'), 'ㄱㅏ');
    });

    test('single syllable with final consonant', () {
      expect(HangulDecomposer.decompose('한'), 'ㅎㅏㄴ');
    });

    test('multi-syllable word', () {
      expect(HangulDecomposer.decompose('안녕'), 'ㅇㅏㄴㄴㅕㅇ');
    });

    test('non-Hangul characters pass through unchanged', () {
      expect(HangulDecomposer.decompose('abc123'), 'abc123');
    });

    test('mixed Hangul and Latin', () {
      expect(HangulDecomposer.decompose('A한B'), 'AㅎㅏㄴB');
    });

    test('empty string returns empty string', () {
      expect(HangulDecomposer.decompose(''), '');
    });

    test('first syllable in Unicode block U+AC00 (가)', () {
      // 가 = ㄱ + ㅏ, no final consonant
      expect(HangulDecomposer.decompose('\u{AC00}'), 'ㄱㅏ');
    });

    test('last syllable in Unicode block U+D7A3 (힣)', () {
      // 힣 = ㅎ + ㅣ + ㅎ
      expect(HangulDecomposer.decompose('\u{D7A3}'), 'ㅎㅣㅎ');
    });

    test('space and punctuation pass through', () {
      expect(HangulDecomposer.decompose('안 녕!'), 'ㅇㅏㄴ ㄴㅕㅇ!');
    });
  });

  group('HangulDecomposer.containsHangul', () {
    test('returns true for pure Hangul string', () {
      expect(HangulDecomposer.containsHangul('안녕'), isTrue);
    });

    test('returns true for mixed string with at least one Hangul character', () {
      expect(HangulDecomposer.containsHangul('hello안'), isTrue);
    });

    test('returns false for Latin-only input', () {
      expect(HangulDecomposer.containsHangul('hello'), isFalse);
    });

    test('returns false for empty string', () {
      expect(HangulDecomposer.containsHangul(''), isFalse);
    });

    test('returns false for digits and punctuation', () {
      expect(HangulDecomposer.containsHangul('123!@#'), isFalse);
    });
  });
}
