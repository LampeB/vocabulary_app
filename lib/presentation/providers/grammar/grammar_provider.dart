import 'dart:convert';

import '../../../core/errors/failure.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grammar/grammar_drill_generator.dart';
import '../../../core/grammar/grammar_language_module.dart';
import '../../../core/grammar/latin/latin_grammar_modules.dart';
import '../../../core/grammar/rule_mastery.dart';
import '../../../core/utils/list_mastery.dart';
import '../../../data/datasources/remote/grammar_exercise_remote_datasource.dart';
import '../../../domain/entities/grammar_rule.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart';
import '../quiz/quiz_provider.dart' show progressRepositoryProvider;
import 'package:flutter/foundation.dart' show kDebugMode;
import '../settings/dev_grammar_unlock_provider.dart';

/// The target languages that ship a grammar curriculum
/// (`assets/seed/grammar/<lang>/rules.json`). A studyable language absent here
/// shows the "no curriculum yet" placeholder while its vocabulary lists work
/// normally — curricula are delivered progressively (design decision, see
/// docs/design/map/multi-language.md).
const kGrammarCurricula = {'ko', 'es', 'it', 'fr', 'en', 'de'};

/// The bundled grammar rules for one target language; empty when the
/// language has no curriculum yet. Rules whose mechanics this app version
/// cannot parse are skipped (forward compatibility with newer content).
final grammarRulesProvider =
    FutureProvider.family<List<GrammarRule>, String>((ref, lang) async {
  if (!kGrammarCurricula.contains(lang)) return const [];
  final raw =
      await rootBundle.loadString('assets/seed/grammar/$lang/rules.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final j in data['rules'] as List)
      GrammarRule.fromJson(j as Map<String, dynamic>),
  ].where((r) => r.mechanics is! UnsupportedMechanics).toList();
});

/// The same rules as raw JSON, keyed by id — the payload sent to the AI
/// exercise generator (test vectors stripped: they're engine/authoring
/// artifacts, not generation context).
final grammarRulesRawProvider =
    FutureProvider.family<Map<String, Map<String, dynamic>>, String>(
        (ref, lang) async {
  if (!kGrammarCurricula.contains(lang)) return const {};
  final raw =
      await rootBundle.loadString('assets/seed/grammar/$lang/rules.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return {
    // Entries are wrapped as {"rule": {...}} — same shape GrammarRule.fromJson
    // unwraps.
    for (final j in (data['rules'] as List).cast<Map<String, dynamic>>())
      (j['rule'] as Map<String, dynamic>)['id'] as String: {
        for (final e in (j['rule'] as Map<String, dynamic>).entries)
          if (e.key != 'test_vectors') e.key: e.value,
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

/// The language-module registry — one entry per language whose grammar can be
/// applied deterministically. Null for languages without a module: callers
/// must treat that as "no grammar drills for this language".
final grammarModuleProvider =
    FutureProvider.family<GrammarLanguageModule?, String>((ref, lang) async {
  final rules = await ref.watch(grammarRulesProvider(lang).future);
  if (rules.isEmpty) return null;
  // Merge every conjugation rule's lexical irregulars — negation composes on
  // top of conjugation, so the module needs the full map.
  final irregulars = {
    for (final m
        in rules.map((r) => r.mechanics).whereType<ConjugationMechanics>())
      ...m.irregulars,
  };
  return switch (lang) {
    'ko' => KoreanGrammarModule(conjugationIrregulars: irregulars),
    'es' => SpanishGrammarModule(conjugationIrregulars: irregulars),
    'it' => ItalianGrammarModule(conjugationIrregulars: irregulars),
    'fr' => FrenchGrammarModule(conjugationIrregulars: irregulars),
    'en' => EnglishGrammarModule(conjugationIrregulars: irregulars),
    'de' => GermanGrammarModule(conjugationIrregulars: irregulars),
    _ => null,
  };
});

/// Known vocabulary resolved for drills: the target-language word of every
/// concept the user knows (graduated from FSRS learning — the same bar that
/// unlocks the rules), with its category.
final drillWordsProvider =
    FutureProvider.family<List<DrillWord>, String>((ref, targetLang) async {
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
    final target = all.where((v) => v.langCode == targetLang).firstOrNull;
    if (target == null) continue;
    words[variant.conceptId] = DrillWord(
      word: target.word,
      category: concept.category!,
      tags: List<String>.from(jsonDecode(target.contextTags) as List),
    );
  }
  return words.values.toList();
});

/// Per-rule grammar progress, keyed by rule id. (Rule ids are globally unique
/// across languages, so this needs no language dimension.)
final grammarProgressProvider =
    StreamProvider<Map<String, ({int shown, int correct, bool mastered})>>(
        (ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return Stream.value(const {});
  return ref
      .watch(appDatabaseProvider)
      .grammarProgressDao
      .watchByUser(userId)
      .map(
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
    this.prereqNames = const {},
  });

  final GrammarRule rule;
  final RuleAvailability availability;

  /// Display names of the least-complete prerequisite lists when their
  /// combined progress has not yet reached the 80% unlock threshold.
  final List<String> missingLists;

  /// Whether enough vocabulary is mastered to generate a session.
  final bool enoughWords;
  final int correct;

  /// Known-fraction per prerequisite token (0–1, `known/total` on the
  /// graduated bar), for the unlock progress bars. Lists the user doesn't
  /// have yet report 0. Keys are the rule's prerequisite tokens (seed list
  /// ids, or display names for legacy content).
  final Map<String, double> prereqProgress;

  /// Prerequisite token → display name of the matched list, for the bars.
  final Map<String, String> prereqNames;

  /// Overall unlock progress across all prerequisite lists (0–1); 1.0 when
  /// there are no prerequisites.
  double get unlockFraction {
    if (rule.prerequisiteLists.isEmpty) return 1;
    var sum = 0.0;
    for (final name in rule.prerequisiteLists) {
      sum += prereqProgress[name] ?? 0;
    }
    return sum / rule.prerequisiteLists.length;
  }
}

/// Availability of every rule of one target language: prerequisite lists gate
/// unlocking (≥80% across its prerequisite lists), rule progress
/// gates "mastered". Prerequisites are matched by seed list id
/// (`<id>:<any-source>><targetLang>`), falling back to display name for
/// not-yet-adopted legacy lists.
final ruleStatusesProvider =
    FutureProvider.family<List<RuleStatus>, String>((ref, targetLang) async {
  final rules = await ref.watch(grammarRulesProvider(targetLang).future);
  if (rules.isEmpty) return const [];
  final lists = await ref.watch(myListsProvider.future);
  final progressRepo = ref.watch(progressRepositoryProvider);
  final progress = await ref.watch(grammarProgressProvider.future);
  final drillWords = await ref.watch(drillWordsProvider(targetLang).future);
  final module = await ref.watch(grammarModuleProvider(targetLang).future);
  final generator = module == null ? null : GrammarDrillGenerator(module);

  // Resolve each prerequisite token to the user's matching list: by seed id
  // for catalog lists (any source language, this target), by name for legacy.
  final tokens = {for (final r in rules) ...r.prerequisiteLists};
  final fraction = <String, double>{};
  final displayName = <String, String>{};
  for (final token in tokens) {
    final matches = [
      for (final l in lists)
        if ((l.seedId != null &&
                l.seedId!.startsWith('$token:') &&
                l.langB == targetLang) ||
            l.name == token)
          l,
    ];
    var tokenFraction = 0.0;
    for (final list in matches) {
      final stats = (await progressRepo.getListStats(list.id)).valueOrNull;
      if (stats == null) continue;
      final total = stats['total'] ?? 0;
      final f = total == 0 ? 0.0 : (stats['known']! / total).clamp(0.0, 1.0);
      // A user may study the same curriculum list from several source
      // languages; the furthest one counts.
      if (f >= tokenFraction) {
        tokenFraction = f;
        displayName[token] = list.name;
      }
    }
    fraction[token] = tokenFraction;
  }

  return [
    for (final rule in rules)
      () {
        final prereqProgress = {
          for (final token in rule.prerequisiteLists)
            token: fraction[token] ?? 0,
        };
        final vocabUnlocked = arePrerequisitesKnown(prereqProgress.values);
        final missing = [
          for (final token in rule.prerequisiteLists)
            if ((prereqProgress[token] ?? 0) < kPrerequisiteUnlockThreshold)
              displayName[token] ?? token,
        ];
        final p = progress[rule.id];
        final mastered = p?.mastered ?? false;
        // DEBUG-ONLY override: unlock everything so the grammar voice path
        // can be exercised without mastering the prerequisite lists first.
        final devUnlock = kDebugMode && ref.watch(devGrammarUnlockProvider);
        return RuleStatus(
          rule: rule,
          availability: mastered
              ? RuleAvailability.mastered
              : (devUnlock || vocabUnlocked)
                  ? RuleAvailability.unlocked
                  : RuleAvailability.locked,
          missingLists: devUnlock ? const [] : missing,
          enoughWords:
              devUnlock || (generator?.canGenerate(rule, drillWords) ?? false),
          correct: p?.correct ?? 0,
          prereqProgress: prereqProgress,
          prereqNames: displayName,
        );
      }(),
  ];
});

/// How many correct answers master a rule — re-exported for UI progress bars.
const ruleMasteryTarget = kRuleMasteryTarget;
