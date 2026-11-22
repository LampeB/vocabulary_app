// The vocabulary prerequisite rule for curriculum lessons. A lesson may name
// several lists; their combined progress unlocks it. This rule never applies
// to free vocabulary practice.
//
// "Known" for the GATE is the graduated bar: the word's FSRS card left the
// learning phase (a few correct answers over a couple of days). The 21-day
// "mastered" bar stays for stats/mastery display — gating on it would lock
// grammar for everyone's first month, which is not "know the basics first".

/// Weighted fraction of a lesson's prerequisite vocabulary that must be known
/// (graduated from FSRS learning) before the lesson unlocks.
const double kPrerequisiteUnlockThreshold = 0.8;

/// No individual prerequisite list may be too incomplete, even if another
/// list's progress would make the weighted total look sufficient.
const double kPrerequisiteListMinimum = 0.7;

/// Progress of one prerequisite list. Keeping the counts, rather than only a
/// percentage, lets the combined gate weight a 30-word list more than a
/// 10-word list.
class PrerequisiteProgress {
  const PrerequisiteProgress({required this.known, required this.total});

  final int known;
  final int total;

  double get fraction => total <= 0 ? 0 : known / total;
}

/// Mastered fraction of a list; 0 for an empty list.
double listMasteryRatio({required int total, required int mastered}) =>
    total == 0 ? 0 : mastered / total;

/// Whether prerequisite vocabulary unlocks a lesson.
///
/// Every list must reach [minimumPerList], then all words are counted together
/// against [combinedThreshold]. Missing or empty lists fail the per-list
/// check, so they cannot accidentally open a lesson.
bool arePrerequisitesKnown(
  Iterable<PrerequisiteProgress> progress, {
  double combinedThreshold = kPrerequisiteUnlockThreshold,
  double minimumPerList = kPrerequisiteListMinimum,
}) {
  final values = progress.toList(growable: false);
  if (values.isEmpty) return true;
  if (values
      .any((value) => value.total <= 0 || value.fraction < minimumPerList)) {
    return false;
  }
  final known = values.fold<int>(0, (sum, value) => sum + value.known);
  final total = values.fold<int>(0, (sum, value) => sum + value.total);
  return total > 0 && known / total >= combinedThreshold;
}
