import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/seed/starter_seeder.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';

import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// These are bundled curriculum identities, deliberately not localized names.
// The rule has two prerequisites, which lets this suite prove that a third,
// unrelated starter list cannot affect its availability.
const _ruleId = 'particules-sujet-objet-i-ga-eul-reul';
const _prerequisites = ['starter-greetings', 'starter-food'];
const _unrelatedList = 'starter-daily-life';

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(MaterialApp)));

/// TEST_MODE correctly skips automatic starter seeding so every E2E can own its
/// data. This fixture intentionally invokes the real seeder, after resetting
/// only its idempotency marker: it creates production-shaped lists, concepts,
/// variants and stable seed ids rather than a test-only shortcut.
Future<void> _seedFrenchKoreanCurriculum(PatrolIntegrationTester $) async {
  await deleteAllLists($);
  final container = _container($);
  final user = container.read(currentUserProvider);
  if (user == null) throw StateError('Lesson E2E needs an authenticated user.');

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(StarterSeeder.flagKeyFor(user.id, 'fr', 'ko'));
  await container.read(starterSeederProvider).ensureSeededForPair('fr', 'ko');

  container.invalidate(myListsProvider);
  final lists = await container.read(myListsProvider.future);
  for (final token in [..._prerequisites, _unrelatedList]) {
    final found = lists.any((list) =>
        list.seedId?.startsWith('$token:fr>ko') == true && list.langB == 'ko');
    if (!found) throw StateError('Starter fixture did not create $token.');
  }
  await $.pump(const Duration(milliseconds: 700));
}

Future<dynamic> _seedList(ProviderContainer container, String token) async {
  container.invalidate(myListsProvider);
  final lists = await container.read(myListsProvider.future);
  return lists.firstWhere((list) =>
      list.seedId?.startsWith('$token:fr>ko') == true && list.langB == 'ko');
}

/// Records real, graduated FSRS progress for every concept in [token]'s list.
/// Rule availability still comes from `getListStats` → `ruleStatusesProvider`;
/// this helper never overrides a provider or writes a RuleStatus directly.
Future<void> _makeStarterListKnown(
    PatrolIntegrationTester $, String token) async {
  final container = _container($);
  final list = await _seedList(container, token);
  final vocabulary = container.read(vocabularyRepositoryProvider);
  final progress = container.read(progressRepositoryProvider);
  final concepts = await vocabulary.watchConcepts(list.id).first;
  if (concepts.isEmpty) {
    throw StateError('Starter list $token has no concepts.');
  }

  for (final concept in concepts) {
    final variants = (await vocabulary.getVariants(concept.id)).valueOrNull;
    final variant = variants?.firstOrNull;
    if (variant == null) {
      throw StateError('Concept ${concept.id} in $token has no word variant.');
    }
    final current = (await progress.getProgress(
      variantId: variant.id,
      direction: QuizDirection.frToKo,
    ))
        .valueOrNull;
    if (current == null) {
      throw StateError('Could not initialise progress for ${variant.word}.');
    }
    final saved = await progress.updateProgress(current.copyWith(
      state: CardState.review,
      scheduledDays: 21,
      reps: 3,
      lastReview: DateTime.now(),
      nextReview: DateTime.now().add(const Duration(days: 21)),
    ));
    if (!saved.isSuccess) {
      throw StateError('Could not persist progress for ${variant.word}.');
    }
  }
}

Future<RuleStatus> _refreshRuleStatus(PatrolIntegrationTester $) async {
  final container = _container($);
  container.invalidate(ruleStatusesProvider('ko'));
  final statuses = await container.read(ruleStatusesProvider('ko').future);
  return statuses.firstWhere((status) => status.rule.id == _ruleId);
}

void main() {
  patrolTest(
      'Lessons — unrelated vocabulary does not unlock a locked prerequisite lesson',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await _seedFrenchKoreanCurriculum($);
    await _makeStarterListKnown($, _unrelatedList);

    // A completed C list must not compensate for missing A and B.
    expect((await _refreshRuleStatus($)).availability, RuleAvailability.locked);

    await app.when.tapsNavTab(NavTab.grammar);
    final card = find.byKey(ValueKey(WidgetKeys.grammarRuleCard(_ruleId)));
    await $(card).scrollTo();
    await $(card).waitUntilVisible(timeout: const Duration(seconds: 30));
    expect(find.byKey(ValueKey(WidgetKeys.grammarRuleOpenLesson(_ruleId))),
        findsNothing);

    // The locked card points specifically to a prerequisite list, not C.
    final prerequisite = find.byKey(
        ValueKey(WidgetKeys.grammarPrerequisiteList(_prerequisites.first)));
    await $(prerequisite).scrollTo();
    await $(prerequisite).tap();
    await app.then.onScreen(Screen.listDetail);
  });

  patrolTest(
      'Lessons — graduated required vocabulary unlocks and opens the real lesson',
      timeout: const Timeout(Duration(minutes: 8)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($));

    await app.given.signedIn();
    await _seedFrenchKoreanCurriculum($);
    for (final token in _prerequisites) {
      await _makeStarterListKnown($, token);
    }

    expect(
        (await _refreshRuleStatus($)).availability, RuleAvailability.unlocked);

    await app.when.tapsNavTab(NavTab.grammar);
    final openLesson =
        find.byKey(ValueKey(WidgetKeys.grammarRuleOpenLesson(_ruleId)));
    await $(openLesson).scrollTo();
    await $(openLesson).tap();
    await $(find.byKey(const ValueKey(WidgetKeys.screenGrammarLesson)))
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  });
}
