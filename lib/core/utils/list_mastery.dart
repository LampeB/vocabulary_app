// The vocabulary prerequisite rule for curriculum lessons. A lesson may name
// several lists; their combined progress unlocks it. This rule never applies
// to free vocabulary practice.
//
// "Known" for the GATE is the graduated bar: the word's FSRS card left the
// learning phase (a few correct answers over a couple of days). The 21-day
// "mastered" bar stays for stats/mastery display — gating on it would lock
// grammar for everyone's first month, which is not "know the basics first".

/// Combined fraction of a lesson's prerequisite vocabulary that must be known
/// (graduated from FSRS learning) before the lesson unlocks.
const double kPrerequisiteUnlockThreshold = 0.8;

/// Mastered fraction of a list; 0 for an empty list.
double listMasteryRatio({required int total, required int mastered}) =>
    total == 0 ? 0 : mastered / total;

/// Whether the combined prerequisite progress unlocks a lesson. Missing or
/// empty lists contribute 0, so they cannot accidentally open a lesson.
bool arePrerequisitesKnown(
  Iterable<double> fractions, {
  double threshold = kPrerequisiteUnlockThreshold,
}) {
  final values = fractions.toList(growable: false);
  if (values.isEmpty) return true;
  final total = values.fold<double>(0, (sum, value) => sum + value);
  return total / values.length >= threshold;
}
