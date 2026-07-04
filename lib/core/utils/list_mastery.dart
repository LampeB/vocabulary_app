// The "does the user know this list?" rule — the gate for grammar lessons
// (product decision 2026-07-04: grammar lessons declare prerequisite vocab
// lists and stay locked until those lists are known).

/// Fraction of a prerequisite list that must be mastered (FSRS review state,
/// ≥ kMasteryThresholdDays scheduled) for the list to count as known.
const double kListKnownThreshold = 0.8;

/// Mastered fraction of a list; 0 for an empty list.
double listMasteryRatio({required int total, required int mastered}) =>
    total == 0 ? 0 : mastered / total;

/// Whether a prerequisite list counts as known. An empty list is NOT known —
/// it gives no evidence the user learned anything.
bool isListKnown({
  required int total,
  required int mastered,
  double threshold = kListKnownThreshold,
}) =>
    total > 0 && mastered / total >= threshold;
