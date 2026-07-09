/// Rough French grapheme→phoneme encoding for similarity scoring.
///
/// Whisper's errors on short words are PHONETIC: it hears /movi/ and spells
/// "Mauvi" where the answer is "mauvais" /movɛ/ — orthographic bigram
/// similarity sees almost nothing in common while the sounds are nearly
/// identical (field log 2026-07-10). Scoring in a phoneme-ish space is the
/// French counterpart of the Korean jamo-decomposition trick.
///
/// This is NOT a linguistically complete G2P — just enough ordered rewrite
/// rules to make sound-alikes collide and sound-differents stay apart.
abstract final class FrenchPhonetics {
  static final List<(RegExp, String)> _rules = [
    // digraphs/trigraphs first (order matters)
    (RegExp(r'eau|aux|au'), 'o'),
    (RegExp(r'oin'), 'wX'),
    (RegExp(r'oi|oy'), 'wa'),
    (RegExp(r'ou|où|oû'), 'u'),
    (RegExp(r'ain|ein|in|un|ym|im'), 'X'), // nasal /ɛ̃/-ish
    (RegExp(r'an|am|en|em'), 'A'), // nasal /ɑ̃/-ish
    (RegExp(r'on|om'), 'O'), // nasal /ɔ̃/-ish
    (RegExp(r'ai|ei|è|ê|ë|é|et\b'), 'e'),
    (RegExp(r'ch'), 'S'),
    (RegExp(r'ph'), 'f'),
    (RegExp(r'th'), 't'),
    (RegExp(r'gn'), 'N'),
    (RegExp(r'qu|q|k'), 'k'),
    (RegExp(r'gu(?=[ei])'), 'g'),
    (RegExp(r'g(?=[eiy])'), 'Z'), // ge/gi → /ʒ/
    (RegExp(r'j'), 'Z'),
    (RegExp(r'c(?=[eiy])|ç'), 's'),
    (RegExp(r'c'), 'k'),
    (RegExp(r'x'), 'ks'),
    (RegExp(r'h'), ''),
    (RegExp(r'w'), 'v'),
    // silent-ish endings: final consonants & mute e (strip repeatedly)
    (RegExp(r'(?:e|s|t|d|p|z)+$'), ''),
    (RegExp(r'y'), 'i'),
  ];

  /// Encodes [word] (lowercase, accents significant) into the phoneme-ish
  /// space. Multi-word inputs are encoded word by word.
  static String encode(String text) {
    final words = text.toLowerCase().trim().split(RegExp(r'\s+'));
    return words.map(_encodeWord).where((w) => w.isNotEmpty).join(' ');
  }

  static String _encodeWord(String word) {
    var w = word;
    for (final (re, repl) in _rules) {
      w = w.replaceAll(re, repl);
    }
    // collapse doubled letters ("nn" → "n")
    w = w.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
    return w;
  }
}
