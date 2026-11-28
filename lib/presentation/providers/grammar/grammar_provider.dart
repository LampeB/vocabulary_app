import 'dart:async' show StreamController, unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, mapEquals;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grammar/grammar_drill_generator.dart';
import '../../../core/grammar/grammar_language_module.dart';
import '../../../core/grammar/latin/latin_grammar_modules.dart';
import '../../../core/grammar/rule_mastery.dart';
import '../../../core/utils/list_mastery.dart';
import '../../../data/seed/seed_catalog.dart';
import '../../../domain/entities/grammar_rule.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart';
import '../settings/dev_grammar_unlock_provider.dart';

/// The target languages that ship a grammar curriculum
/// (`assets/seed/grammar/<lang>/rules.json`). A studyable language absent here
/// shows the "no curriculum yet" placeholder while its vocabulary lists work
/// normally — curricula are delivered progressively (design decision, see
/// docs/design/map/multi-language.md).
const kGrammarCurricula = {'ko', 'es', 'it', 'fr', 'en', 'de'};

/// Keep catalog keys, rather than translated strings, so a locale change
/// relabels missing prerequisites without reloading progress.
final grammarPrerequisiteNameKeysProvider = FutureProvider<Map<String, String>>(
  (ref) async {
    final catalog = await SeedCatalog.load(rootBundle);
    return {for (final list in catalog.lists) list.id: list.nameKey};
  },
);

/// The bundled grammar rules for one target language; empty when the
/// language has no curriculum yet. Rules whose mechanics this app version
/// cannot parse are skipped (forward compatibility with newer content).
final grammarRulesProvider = FutureProvider.family<List<GrammarRule>, String>((
  ref,
  lang,
) async {
  if (!kGrammarCurricula.contains(lang)) return const [];
  final raw = await rootBundle.loadString(
    'assets/seed/grammar/$lang/rules.json',
  );
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final j in data['rules'] as List)
      GrammarRule.fromJson(j as Map<String, dynamic>),
  ].where((r) => r.mechanics is! UnsupportedMechanics).toList();
});

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
final drillWordsProvider = StreamProvider.autoDispose
    .family<List<DrillWord>, String>((ref, targetLang) {
      final userId = ref.watch(currentUserProvider.select((user) => user?.id));
      if (userId == null || userId.isEmpty) return Stream.value(const []);
      final words = ref
          .watch(progressDaoProvider)
          .watchGrammarDrillWords(userId, targetLang)
          .map(
            (rows) => [
              for (final row in rows)
                DrillWord(
                  word: row.word,
                  category: row.category,
                  listId: row.listId,
                  tags: List<String>.from(jsonDecode(row.contextTags) as List),
                ),
            ],
          );
      return _observeGrammar(ref, words);
    });

// Riverpod can keep listening to finish a previously requested `.future` after
// disposal during loading. Tie the upstream Drift subscription to the scope.
Stream<T> _observeGrammar<T>(Ref ref, Stream<T> source) {
  final controller = StreamController<T>();
  final subscription = source.listen(
    controller.add,
    onError: controller.addError,
    onDone: controller.close,
  );
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
}

/// Per-rule grammar progress, keyed by rule id. (Rule ids are globally unique
/// across languages, so this needs no language dimension.)
final grammarProgressProvider =
    StreamProvider.autoDispose<
      Map<String, ({int shown, int correct, bool mastered})>
    >((ref) {
      final userId = ref.watch(currentUserProvider.select((user) => user?.id));
      if (userId == null || userId.isEmpty) return Stream.value(const {});
      final progress = ref
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
      return _observeGrammar(ref, progress.distinct(mapEquals));
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
    this.prereqTotals = const {},
    this.prereqNames = const {},
    this.prereqListIds = const {},
  });

  final GrammarRule rule;
  final RuleAvailability availability;

  /// Tokens of the least-complete prerequisite lists when their
  /// weighted progress has not reached 80%, or one list is below 70%.
  final List<String> missingLists;

  /// Whether enough vocabulary is mastered to generate a session.
  final bool enoughWords;
  final int correct;

  /// Known-fraction per prerequisite token (0–1, `known/total` on the
  /// graduated bar), for the unlock progress bars. Lists the user doesn't
  /// have yet report 0. Keys are the rule's prerequisite tokens (seed list
  /// ids, or display names for legacy content).
  final Map<String, double> prereqProgress;

  /// Total words per prerequisite token. Used to calculate the weighted
  /// overall progress shown to the learner.
  final Map<String, int> prereqTotals;

  /// Prerequisite token → display name of the matched list, for the bars.
  final Map<String, String> prereqNames;

  /// Prerequisite token → local list id, used to open the exact vocabulary
  /// prerequisite from a locked lesson.
  final Map<String, String> prereqListIds;

  /// Overall unlock progress weighted by prerequisite-list size (0–1); 1.0
  /// when there are no prerequisites. An unknown list reads as 0 instead of
  /// letting the visible percentage imply that the lesson is nearly ready.
  double get unlockFraction {
    if (rule.prerequisiteLists.isEmpty) return 1;
    var known = 0.0;
    var total = 0;
    for (final name in rule.prerequisiteLists) {
      final listTotal = prereqTotals[name] ?? 0;
      if (listTotal <= 0) return 0;
      known += (prereqProgress[name] ?? 0) * listTotal;
      total += listTotal;
    }
    return total == 0 ? 0 : known / total;
  }
}

/// Availability of every rule of one target language: prerequisite lists gate
/// unlocking (≥80% weighted across its prerequisite lists, with ≥70% in each),
/// rule progress
/// gates "mastered". Prerequisites are matched by seed list id
/// (`<id>:<source>><targetLang>`). Legacy starter names are adopted by seeding,
/// never treated as an identity during prerequisite resolution.
typedef GrammarPrerequisites = ({
  Map<String, PrerequisiteProgress> progress,
  Map<String, String> names,
  Map<String, String> listIds,
});

final grammarPrerequisitesProvider = StreamProvider.autoDispose
    .family<GrammarPrerequisites, String>((ref, targetLang) {
      final userId = ref.watch(currentUserProvider.select((user) => user?.id));
      if (userId == null || userId.isEmpty) {
        return Stream.value((
          progress: const {},
          names: const {},
          listIds: const {},
        ));
      }
      final rules = ref.watch(grammarRulesProvider(targetLang).future);
      final dao = ref.watch(progressDaoProvider);
      final prerequisites = Stream.fromFuture(rules).asyncExpand((rules) {
        final tokens = {for (final r in rules) ...r.prerequisiteLists};
        return dao
            .watchGrammarPrerequisites(
              userId: userId,
              targetLang: targetLang,
              tokens: tokens,
            )
            .map((rows) {
              final progress = {
                for (final token in tokens)
                  token: const PrerequisiteProgress(known: 0, total: 0),
              };
              final names = <String, String>{};
              final listIds = <String, String>{};
              for (final row in rows) {
                final candidate = PrerequisiteProgress(
                  known: row.known,
                  total: row.total,
                );
                // A user may study the same curriculum list from several source
                // languages; the furthest one counts.
                if (candidate.fraction >= progress[row.token]!.fraction) {
                  progress[row.token] = candidate;
                  names[row.token] = row.name;
                  listIds[row.token] = row.listId;
                }
              }
              return (progress: progress, names: names, listIds: listIds);
            });
      });
      return _observeGrammar(ref, prerequisites);
    });

/// Availability and exercise generation consume exactly the same vocabulary.
/// Resolve the same prerequisite copies used by the lesson's unlock bars.
final ruleDrillWordsProvider = FutureProvider.autoDispose
    .family<List<DrillWord>, ({String ruleId, String targetLang})>((
      ref,
      key,
    ) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final rules = await ref.watch(
        grammarRulesProvider(key.targetLang).future,
      );
      if (disposed) return const [];
      final rule = rules.where((rule) => rule.id == key.ruleId).firstOrNull;
      if (rule == null) return const [];
      final words = ref.watch(drillWordsProvider(key.targetLang).future);
      if (rule.prerequisiteLists.isEmpty) return words;
      final (pool, prerequisites) = await (
        words,
        ref.watch(grammarPrerequisitesProvider(key.targetLang).future),
      ).wait;
      return _wordsForRule(rule, pool, prerequisites.listIds);
    });

List<DrillWord> _wordsForRule(
  GrammarRule rule,
  List<DrillWord> words,
  Map<String, String> prerequisiteListIds,
) {
  if (rule.prerequisiteLists.isEmpty) return words;
  final listIds = {
    for (final token in rule.prerequisiteLists) ?prerequisiteListIds[token],
  };
  return words.where((word) => listIds.contains(word.listId)).toList();
}

final ruleStatusesProvider = FutureProvider.autoDispose
    .family<List<RuleStatus>, String>((ref, targetLang) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final rules = await ref.watch(grammarRulesProvider(targetLang).future);
      if (disposed || rules.isEmpty) return const [];
      final devUnlock = kDebugMode && ref.watch(devGrammarUnlockProvider);
      final (prerequisites, progress, module, words) = await (
        ref.watch(grammarPrerequisitesProvider(targetLang).future),
        ref.watch(grammarProgressProvider.future),
        ref.watch(grammarModuleProvider(targetLang).future),
        ref.watch(drillWordsProvider(targetLang).future),
      ).wait;
      final prerequisiteProgress = prerequisites.progress;
      final displayName = prerequisites.names;
      final listIds = prerequisites.listIds;
      final generator = module == null ? null : GrammarDrillGenerator(module);

      return [
        for (final rule in rules)
          () {
            final prereqProgress = {
              for (final token in rule.prerequisiteLists)
                token: prerequisiteProgress[token]?.fraction ?? 0,
            };
            final prereqCounts = {
              for (final token in rule.prerequisiteLists)
                token:
                    prerequisiteProgress[token] ??
                    const PrerequisiteProgress(known: 0, total: 0),
            };
            final vocabUnlocked = arePrerequisitesKnown(prereqCounts.values);
            final missing = [
              for (final token in rule.prerequisiteLists)
                if (!vocabUnlocked &&
                    ((prereqCounts[token]?.total ?? 0) <= 0 ||
                        (prereqProgress[token] ?? 0) <
                            kPrerequisiteUnlockThreshold))
                  token,
            ];
            final p = progress[rule.id];
            final mastered = p?.mastered ?? false;
            return RuleStatus(
              rule: rule,
              availability: mastered
                  ? RuleAvailability.mastered
                  : (devUnlock || vocabUnlocked)
                  ? RuleAvailability.unlocked
                  : RuleAvailability.locked,
              missingLists: devUnlock ? const [] : missing,
              enoughWords:
                  devUnlock ||
                  (generator?.canGenerate(
                        rule,
                        _wordsForRule(rule, words, listIds),
                      ) ??
                      false),
              correct: p?.correct ?? 0,
              prereqProgress: prereqProgress,
              prereqTotals: {
                for (final token in rule.prerequisiteLists)
                  token: prerequisiteProgress[token]?.total ?? 0,
              },
              prereqNames: displayName,
              prereqListIds: {
                for (final token in rule.prerequisiteLists)
                  if (listIds[token] != null) token: listIds[token]!,
              },
            );
          }(),
      ];
    });

/// How many correct answers master a rule — re-exported for UI progress bars.
const ruleMasteryTarget = kRuleMasteryTarget;
