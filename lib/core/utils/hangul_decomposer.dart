abstract final class HangulDecomposer {
  static const _cho = [
    'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ',
    'ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];
  static const _jung = [
    'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ',
    'ㅙ','ㅚ','㛛','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ'
  ];
  static const _jong = [
    '','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ',
    'ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ',
    'ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];

  static const _base = 0xAC00;
  static const _choCnt = 21 * 28;
  static const _jungCnt = 28;

  static String decompose(String text) {
    final buf = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final offset = rune - _base;
        buf.write(_cho[offset ~/ _choCnt]);
        buf.write(_jung[(offset % _choCnt) ~/ _jungCnt]);
        final jongIdx = offset % _jungCnt;
        if (jongIdx > 0) buf.write(_jong[jongIdx]);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  static bool containsHangul(String text) =>
      text.runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);
}
