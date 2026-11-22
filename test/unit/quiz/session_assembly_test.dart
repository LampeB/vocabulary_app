import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/providers/quiz/session_assembly.dart';

/// Pure list mechanics behind QuizNotifier.loadCards: the per-direction fetch
/// split, FR/KO interleaving with the cap, and cyclic padding to the limit.
void main() {
  group('halfLimit', () {
    test('even limit splits exactly', () {
      expect(halfLimit(10), 5);
    });

    test('odd limit rounds up so the session can still fill', () {
      expect(halfLimit(5), 3);
      expect(halfLimit(1), 1);
    });
  });

  group('interleaveAndCap', () {
    test('alternates a, b, a, b for equal lengths', () {
      expect(
        interleaveAndCap(['f1', 'f2'], ['k1', 'k2'], 10),
        ['f1', 'k1', 'f2', 'k2'],
      );
    });

    test('unequal lengths: the longer tail runs out consecutively', () {
      expect(
        interleaveAndCap(['f1', 'f2', 'f3'], ['k1'], 10),
        ['f1', 'k1', 'f2', 'f3'],
      );
    });

    test('one empty side degrades to the other list', () {
      expect(interleaveAndCap(<String>[], ['k1', 'k2'], 10), ['k1', 'k2']);
      expect(interleaveAndCap(['f1'], <String>[], 10), ['f1']);
    });

    test('both empty → empty', () {
      expect(interleaveAndCap(<String>[], <String>[], 10), isEmpty);
    });

    test('caps at the limit, keeping the interleaved prefix', () {
      expect(
        interleaveAndCap(['f1', 'f2', 'f3'], ['k1', 'k2', 'k3'], 5),
        ['f1', 'k1', 'f2', 'k2', 'f3'],
      );
    });

    test('odd limit with halfLimit fetches still fills exactly', () {
      // limit 5 → halfLimit 3 per side → 6 interleaved → capped to 5.
      final result = interleaveAndCap(
          ['f1', 'f2', 'f3'], ['k1', 'k2', 'k3'], 5);
      expect(result.length, 5);
    });
  });

  group('padCyclically', () {
    test('repeats cards in order until the limit', () {
      expect(
        padCyclically(['a', 'b', 'c'], 5),
        ['a', 'b', 'c', 'a', 'b'],
      );
    });

    test('a single card fills the whole session', () {
      expect(padCyclically(['a'], 3), ['a', 'a', 'a']);
    });

    test('already at the limit → unchanged', () {
      expect(padCyclically(['a', 'b'], 2), ['a', 'b']);
    });

    test('over the limit → unchanged (padding never truncates)', () {
      expect(padCyclically(['a', 'b', 'c'], 2), ['a', 'b', 'c']);
    });

    test('empty input stays empty (never divides by zero)', () {
      expect(padCyclically(<String>[], 5), isEmpty);
    });

    test('does not mutate the input list', () {
      final input = ['a', 'b'];
      padCyclically(input, 5);
      expect(input, ['a', 'b']);
    });
  });

  group('spaceOutDuplicates (morning→matin echo, user report 2026-07-21)', () {
    // Key = the letter; the digit distinguishes the two directions.
    String keyOf(String s) => s[0];

    int minDistance(List<String> out) {
      var best = out.length;
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          if (keyOf(out[i]) == keyOf(out[j]) && j - i < best) best = j - i;
        }
      }
      return best;
    }

    test('adjacent same-concept pair gets ≥2 cards between its directions',
        () {
      // Interleaved deal: a1, a2 are the same concept back-to-back.
      final out = spaceOutDuplicates(
          ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'], keyOf);
      expect(out.toSet(), {'a1', 'a2', 'b1', 'b2', 'c1', 'c2'});
      expect(minDistance(out), greaterThanOrEqualTo(3));
    });

    test('keeps order stable when nothing conflicts', () {
      expect(spaceOutDuplicates(['a1', 'b1', 'c1', 'a2'], keyOf),
          ['a1', 'b1', 'c1', 'a2']);
    });

    test('degrades gracefully when spacing is impossible (tiny list)', () {
      final out = spaceOutDuplicates(['a1', 'a2'], keyOf);
      expect(out, ['a1', 'a2']); // dealt anyway, never stalls or drops
    });

    test('null keys never conflict', () {
      final out =
          spaceOutDuplicates(['a1', 'a2', 'x', 'y'], (s) => s == 'x' || s == 'y' ? null : 'a');
      expect(out.length, 4);
    });
  });
}
