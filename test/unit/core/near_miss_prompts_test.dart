import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/stt/near_miss_prompts.dart';

void main() {
  test('Korean session: each target once plus its near misses', () {
    final prompts = nearMissPromptsFor('ko', 'P1');
    final sets = nearMissSets['ko']!;
    final expectedCount =
        sets.values.fold<int>(sets.length, (n, nears) => n + nears.length);
    expect(prompts, hasLength(expectedCount));
    expect(prompts.where((p) => p.isTarget).map((p) => p.spoken).toSet(),
        sets.keys.toSet());
    for (final p in prompts.where((p) => !p.isTarget)) {
      expect(sets[p.expected], contains(p.spoken));
      expect(p.kind, 'near');
      expect(p.langCode, 'ko');
    }
  });

  test('no word is both a target and a near miss, and none repeats', () {
    for (final lang in nearMissSets.keys) {
      final spoken =
          nearMissPromptsFor(lang, 'x').map((p) => p.spoken).toList();
      expect(spoken.toSet(), hasLength(spoken.length), reason: lang);
    }
  });

  test('the order is shuffled, stable per speaker, different across speakers',
      () {
    List<String> order(String s) =>
        nearMissPromptsFor('ko', s).map((p) => p.spoken).toList();
    expect(order('P1'), order('P1'));
    expect(order('P1'), isNot(order('P2')));
    final grouped = [
      for (final e in nearMissSets['ko']!.entries) ...[e.key, ...e.value]
    ];
    expect(order('P1'), isNot(grouped));
  });

  test('an unknown language yields no prompts', () {
    expect(nearMissPromptsFor('xx', 'P1'), isEmpty);
  });

  group('nearMissProgress', () {
    ({String word, String langCode, Map<String, String> meta, DateTime at})
        take(String word, String speaker,
                {String lang = 'ko',
                String condition = 'calme',
                int min = 0}) =>
            (
              word: word,
              langCode: lang,
              meta: {'speaker': speaker, 'condition': condition},
              at: DateTime.utc(2026, 10, 3, 10, min),
            );

    test('counts distinct words per participant, language and condition', () {
      final total = nearMissPromptsFor('ko', '').length;
      final rows = nearMissProgress([
        take('딸기', 'P1', min: 1),
        take('달기', 'P1', min: 2),
        take('달기', 'P1', min: 3), // redone: counts once
        take('밥', 'P1', condition: 'bruit', min: 4),
        take('물', 'P2', min: 5),
      ]);
      expect(rows.map((r) => (r.speaker, r.condition, r.done)).toList(), [
        ('P2', 'calme', 1),
        ('P1', 'bruit', 1),
        ('P1', 'calme', 2),
      ]);
      expect(rows.first.total, total);
      expect(rows.last.lastTakeAt, DateTime.utc(2026, 10, 3, 10, 3));
      expect(rows.last.complete, isFalse);
    });

    test('a full session is complete; unlabelled corpus takes are ignored', () {
      final all = nearMissPromptsFor('fr', 'P9');
      final rows = nearMissProgress([
        for (final p in all) take(p.spoken, 'P9', lang: 'fr'),
        (word: 'eau', langCode: 'fr', meta: const {}, at: DateTime.utc(2026)),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.complete, isTrue);
      expect(rows.single.done, all.length);
    });
  });
}
