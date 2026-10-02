import 'dart:math';

/// One word a participant reads aloud in a near-miss recording session.
class NearMissPrompt {
  const NearMissPrompt({
    required this.spoken,
    required this.expected,
    required this.langCode,
    required this.isTarget,
  });

  /// What the participant reads out.
  final String spoken;

  /// The card answer this recording stands in for.
  final String expected;
  final String langCode;

  /// True for the correct word itself (control take); false for a near miss
  /// that a recognizer must NOT turn into [expected].
  final bool isTarget;

  String get kind => isTarget ? 'target' : 'near';
}

/// Near-miss sets (2026-10-02): each expected answer with 4–5 words that
/// sound close — tense/aspirated/plain consonants and close vowels in Korean,
/// minimal pairs in French. Non-words are intentional. True homophones are
/// excluded: no recognizer can tell them apart.
const nearMissSets = <String, Map<String, List<String>>>{
  'ko': {
    '딸기': ['달기', '탈기', '딸개', '달걀', '딱지'],
    '밥': ['밤', '반', '법', '빱'],
    '물': ['불', '뭘', '말', '무'],
    '차': ['자', '짜', '사', '초'],
    '빵': ['방', '팡', '병', '뻥'],
    '고기': ['거기', '꼬기', '고개', '오기'],
    '사과': ['사고', '싸과', '자과', '사거'],
    '우유': ['여유', '우비', '오유', '우요'],
    '커피': ['코피', '카피', '거피', '커비'],
    '김치': ['김씨', '김지', '낌치', '김차'],
    '먹다': ['막다', '묵다', '멋다', '넉다'],
    '맛있다': ['맛없다', '멋있다', '마시다', '맛이다'],
  },
  'fr': {
    'pomme': ['bombe', 'homme', 'pompe', 'comme'],
    'pain': ['bain', 'main', 'pont', 'banc'],
    'lait': ['lit', 'loup', 'nez', 'laine'],
    'eau': ['eux', 'ou', 'beau', 'peau'],
    'thé': ['dé', 'thon', 'tu', 'tas'],
    'boire': ['voir', 'poire', 'bois', 'foire'],
    'manger': ['ranger', 'changer', 'mangue', 'nager'],
    'fruit': ['frit', 'bruit', 'fuite', 'froid'],
  },
};

/// Every prompt of [langCode] (each expected word once as a control, plus its
/// near misses), shuffled so a near miss never follows its own target on
/// purpose — reading 딸기 right before 달기 makes people exaggerate the
/// contrast. The order is stable per [speaker], so a session can resume.
List<NearMissPrompt> nearMissPromptsFor(String langCode, String speaker) {
  final sets = nearMissSets[langCode] ?? const {};
  final prompts = <NearMissPrompt>[
    for (final entry in sets.entries) ...[
      NearMissPrompt(
          spoken: entry.key,
          expected: entry.key,
          langCode: langCode,
          isTarget: true),
      for (final near in entry.value)
        NearMissPrompt(
            spoken: near,
            expected: entry.key,
            langCode: langCode,
            isTarget: false),
    ],
  ];
  final seed =
      speaker.codeUnits.fold<int>(17, (h, c) => (h * 31 + c) & 0x7fffffff);
  prompts.shuffle(Random(seed));
  return prompts;
}

/// One participant's progress in one language + room condition.
class NearMissProgress {
  const NearMissProgress({
    required this.speaker,
    required this.langCode,
    required this.condition,
    required this.done,
    required this.total,
    required this.lastTakeAt,
  });

  final String speaker;
  final String langCode;
  final String condition;

  /// Distinct prompts recorded (a redone word counts once).
  final int done;
  final int total;
  final DateTime lastTakeAt;

  bool get complete => done >= total;
}

/// Groups labelled takes into per-participant progress, most recent first.
/// Takes without a speaker label (ordinary corpus captures) are ignored.
List<NearMissProgress> nearMissProgress(
  Iterable<
          ({
            String word,
            String langCode,
            Map<String, String> meta,
            DateTime at
          })>
      takes,
) {
  final groups =
      <(String, String, String), ({Set<String> words, DateTime last})>{};
  for (final t in takes) {
    final speaker = t.meta['speaker'];
    if (speaker == null || speaker.isEmpty) continue;
    final key = (speaker, t.langCode, t.meta['condition'] ?? '');
    final g = groups[key];
    final words = {...?g?.words, t.word};
    final last = g == null || t.at.isAfter(g.last) ? t.at : g.last;
    groups[key] = (words: words, last: last);
  }
  final known = {
    for (final lang in nearMissSets.keys)
      lang: nearMissPromptsFor(lang, '').map((p) => p.spoken).toSet(),
  };
  return [
    for (final e in groups.entries)
      NearMissProgress(
        speaker: e.key.$1,
        langCode: e.key.$2,
        condition: e.key.$3,
        done: e.value.words.intersection(known[e.key.$2] ?? const {}).length,
        total: known[e.key.$2]?.length ?? 0,
        lastTakeAt: e.value.last,
      ),
  ]..sort((a, b) => b.lastTakeAt.compareTo(a.lastTakeAt));
}
