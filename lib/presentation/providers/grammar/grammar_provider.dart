import 'dart:convert';

import '../../../core/errors/failure.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grammar/grammar_drill_generator.dart';
import '../../../core/grammar/grammar_language_module.dart';
import '../../../core/grammar/rule_mastery.dart';
import '../../../core/utils/list_mastery.dart';
import '../../../data/datasources/remote/grammar_exercise_remote_datasource.dart';
import '../../../domain/entities/grammar_rule.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart';
import '../quiz/quiz_provider.dart' show progressRepositoryProvider;

/// The bundled grammar rules (per-language content; Korean today).
final grammarRulesProvider = FutureProvider<List<GrammarRule>>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/grammar_rules.json');
  return [
    for (final j in jsonDecode(raw) as List)
      GrammarRule.fromJson(j as Map<String, dynamic>),
  ];
});

/// The same rules as raw JSON, keyed by id — the payload sent to the AI
/// exercise generator (test vectors and legacy templates stripped: they're
/// engine/authoring artifacts, not generation context).
final grammarRulesRawProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/grammar_rules.json');
  return {
    // Entries are wrapped as {"rule": {...}} — same shape GrammarRule.fromJson
    // unwraps.
    for (final j in jsonDecode(raw) as List)
      ((j as Map<String, dynamic>)['rule'] as Map<String, dynamic>)['id']
          as String: {
        for (final e in (j['rule'] as Map<String, dynamic>).entries)
          if (e.key != 'test_vectors' && e.key != 'templates') e.key: e.value,
      },
  };
});

/// Remote AI exercise generation (Supabase edge function → Claude) + its
/// offline cache. Overridden in tests.
final grammarExerciseRemoteProvider = Provider<GrammarExerciseRemoteDataSource>(
  (ref) => GrammarExerciseRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final compositionCacheProvider =
    Provider<CompositionExerciseCache>((ref) => CompositionExerciseCache());

/// The language module registry — one entry per studyable grammar language.
/// Adding a language = adding its module here + its rule content (the
/// language-pluggable boundary; see the session-architecture epic).
final grammarModuleProvider =
    FutureProvider<GrammarLanguageModule>((ref) async {
  final rules = await ref.watch(grammarRulesProvider.future);
  final conjugation = rules
      .map((r) => r.mechanics)
      .whereType<ConjugationMechanics>()
      .firstOrNull;
  return KoreanGrammarModule(
      conjugationIrregulars: conjugation?.irregulars ?? const {});
});

/// Known vocabulary resolved for drills: the target-language (KO) word of
/// every concept the user knows (graduated from FSRS learning — the same
/// bar that unlocks the rules), with its category.
final drillWordsProvider = FutureProvider<List<DrillWord>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return const [];
  final progressRepo = ref.watch(progressRepositoryProvider);
  final conceptDao = ref.watch(conceptDaoProvider);

  final mastered =
      (await progressRepo.getKnownVariants(userId)).valueOrNull ?? [];
  final words = <String, DrillWord>{}; // conceptId → word (dedup)
  for (final p in mastered) {
    final variant = await conceptDao.getVariantById(p.variantId);
    if (variant == null) continue;
    if (words.containsKey(variant.conceptId)) continue;
    final concept = await conceptDao.getById(variant.conceptId);
    if (concept == null || concept.category == null) continue;
    final all = await conceptDao.getVariantsByConcept(variant.conceptId);
    final ko = all.where((v) => v.langCode == 'ko').firstOrNull;
    if (ko == null) continue;
    words[variant.conceptId] =
        DrillWord(word: ko.word, category: concept.category!);
  }
  return words.values.toList();
});

/// Per-rule grammar progress, keyed by rule id.
final grammarProgressProvider =
    StreamProvider<Map<String, ({int shown, int correct, bool mastered})>>(
        (ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(const {});
  return ref.watch(appDatabaseProvider).grammarProgressDao.watchByUser(userId).map(
        (rows) => {
          for (final r in rows)
            r.ruleId: (
              shown: r.shown,
              correct: r.correct,
              mastered: r.masteredAt != null,
            ),
        },
      );
});

enum RuleAvailability { locked, unlocked, mastered }

class RuleStatus {
  const RuleStatus({
    required this.rule,
    required this.availability,
    required this.missingLists,
    required this.enoughWords,
    required this.correct,
    this.prereqProgress = const {},
  });

  final GrammarRule rule;
  final RuleAvailability availability;

  /// Prerequisite list names not yet known (isListKnown < 90%).
  final List<String> missingLists;

  /// Whether enough vocabulary is mastered to generate a session.
  final bool enoughWords;
  final int correct;

  /// Known-fraction per prerequisite list name (0–1, `known/total` on the
  /// graduated bar), for the unlock progress bars. Lists the user doesn't
  /// have yet report 0.
  final Map<String, double> prereqProgress;

  /// Overall unlock progress across all prerequisite lists (0–1); 1.0 when
  /// there are no prerequisites.
  double get unlockFraction {
    if (rule.prerequisiteLists.isEmpty) return 1;
    var sum = 0.0;
    for (final name in rule.prerequisiteLists) {
      // A list counts as fully contributing once it crosses the known
      // threshold — the bar reads 100% exactly when the rule unlocks.
      final f = (prereqProgress[name] ?? 0) / kListKnownThreshold;
      sum += f > 1 ? 1 : f;
    }
    return sum / rule.prerequisiteLists.length;
  }
}

/// Availability of every rule: prerequisite lists gate unlocking (≥90%
/// mastered per list — kListKnownThreshold), rule progress gates "mastered".
final ruleStatusesProvider = FutureProvider<List<RuleStatus>>((ref) async {
  final rules = await ref.watch(grammarRulesProvider.future);
  final lists = await ref.watch(myListsProvider.future);
  final progressRepo = ref.watch(progressRepositoryProvider);
  final progress = await ref.watch(grammarProgressProvider.future);
  final drillWords = await ref.watch(drillWordsProvider.future);
  final module = await ref.watch(grammarModuleProvider.future);
  final generator = GrammarDrillGenerator(module);

  // Known-ness per prerequisite list name (lists are matched by name — the
  // starter lists carry the canonical names the rules reference). Gated on
  // the 'known' bar (graduated from learning), not the 21-day mastery bar.
  final knownByName = <String, bool>{};
  final fractionByName = <String, double>{};
  for (final list in lists) {
    final stats = (await progressRepo.getListStats(list.id)).valueOrNull;
    knownByName[list.name] = stats != null &&
        isListKnown(total: stats['total']!, mastered: stats['known']!);
    final total = stats?['total'] ?? 0;
    fractionByName[list.name] =
        total == 0 ? 0 : (stats!['known']! / total).clamp(0.0, 1.0);
  }

  return [
    for (final rule in rules)
      () {
        final missing = [
          for (final name in rule.prerequisiteLists)
            if (!(knownByName[name] ?? false)) name,
        ];
        final p = progress[rule.id];
        final mastered = p?.mastered ?? false;
        return RuleStatus(
          rule: rule,
          availability: mastered
              ? RuleAvailability.mastered
              : missing.isEmpty
                  ? RuleAvailability.unlocked
                  : RuleAvailability.locked,
          missingLists: missing,
          enoughWords: generator.canGenerate(rule, drillWords),
          correct: p?.correct ?? 0,
          prereqProgress: {
            for (final name in rule.prerequisiteLists)
              name: fractionByName[name] ?? 0,
          },
        );
      }(),
  ];
});

/// How many correct answers master a rule — re-exported for UI progress bars.
const ruleMasteryTarget = kRuleMasteryTarget;
