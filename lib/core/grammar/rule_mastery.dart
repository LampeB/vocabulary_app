// When a grammar rule counts as mastered — the stage-2 → stage-3 gate
// (mastered rules join the sentence-composition pool). Deliberately
// count-based and simple for the MVP; only mastery-counting answers reach
// the counter (cartes never records).

/// Correct answers needed to master a rule.
const int kRuleMasteryTarget = 10;

bool isRuleMastered({required int correct}) => correct >= kRuleMasteryTarget;
