// Pure list mechanics for assembling a quiz session, extracted from
// QuizNotifier.loadCards so they're unit-testable without providers or a DB.

/// Per-direction fetch limit when a session mixes both directions: half the
/// requested total, rounded up (so an odd limit still fills, e.g. 5 → 3 + 3
/// fetched, capped back to 5 after interleaving).
int halfLimit(int cardLimit) => (cardLimit + 1) ~/ 2;

/// Interleaves two direction-specific lists (a, b, a, b, …), tolerating
/// unequal lengths — the longer list's tail runs out consecutively — then
/// caps the result at [limit].
List<T> interleaveAndCap<T>(List<T> a, List<T> b, int limit) {
  final out = <T>[];
  final maxLen = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < maxLen; i++) {
    if (i < a.length) out.add(a[i]);
    if (i < b.length) out.add(b[i]);
  }
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// Pads [cards] to [limit] by repeating existing cards cyclically
/// (a, b, c → a, b, c, a, b for limit 5). Returns the input unchanged when
/// it's empty or already at/over the limit.
List<T> padCyclically<T>(List<T> cards, int limit) {
  if (cards.isEmpty || cards.length >= limit) return cards;
  final out = List.of(cards);
  while (out.length < limit) {
    out.add(cards[out.length % cards.length]);
  }
  return out;
}
