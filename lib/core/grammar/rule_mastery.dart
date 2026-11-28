// When a grammar rule counts as mastered. Deliberately count-based and simple
// for the MVP; only mastery-counting answers reach the counter (cartes never
// records).

/// Correct answers needed to master a rule.
const int kRuleMasteryTarget = 10;

bool isRuleMastered({required int correct}) => correct >= kRuleMasteryTarget;
