import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/grammar_language_module.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart' show CardState;
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import '../../helpers/fake_remote.dart';

class _StatsProgressRepository implements ProgressRepository {
  _StatsProgressRepository(this.stats, {this.known = const []});

  final Map<String, Map<String, int>> stats;
  final List<VariantProgress> known;

  @override
  Future<Result<Map<String, int>>> getListStats(String listId) async =>
      Success(stats[listId] ?? const {});

  @override
  Future<Result<List<VariantProgress>>> getKnownVariants(String userId) async =>
      Success(known);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GrammarRule _rule(
  String id, {
  List<String> prerequisites = const [],
  int minKnownWords = 2,
}) =>
    GrammarRule(
      id: id,
      titles: const {'fr': 'Règle'},
      descriptions: const {'fr': ''},
      explanations: const {'fr': ''},
      workedExamples: const [],
      prerequisiteLists: prerequisites,
      appliesToCategories: const ['nom'],
      minKnownWords: {'nom': minKnownWords},
      mechanics: const ParticleMechanics(variants: [
        ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
      ]),
      testVectors: const [],
    );

VocabularyList _list({
  required String id,
  required String name,
  String? seedId,
}) =>
    VocabularyList(
      id: id,
      ownerId: 'u',
      name: name,
      seedId: seedId,
      langA: 'fr',
      langB: 'ko',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

AppUser _user() => AppUser(
      id: 'u',
      email: 'user@example.com',
      username: 'user',
      subscriptionType: SubscriptionType.free,
      createdAt: DateTime(2026),
    );

VariantProgress _progress(String id, String variantId) => VariantProgress(
      id: id,
      userId: 'u',
      variantId: variantId,
      direction: QuizDirection.frToKo,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Stream<void> _withInitialProgressChange(Stream<void> changes) async* {
  yield null;
  yield* changes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads every shipped grammar curriculum and selects its module',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final lang in kGrammarCurricula) {
      final rules = await container.read(grammarRulesProvider(lang).future);
      final module = await container.read(grammarModuleProvider(lang).future);

      expect(rules, isNotEmpty, reason: '$lang must ship reviewed rules');
      expect(rules.map((r) => r.mechanics),
          isNot(contains(isA<UnsupportedMechanics>())));
      expect(module, isNotNull);
      expect(module!.langCode, lang);
    }
  });

  test('languages without a curriculum have neither rules nor a module',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(grammarRulesProvider('ja').future), isEmpty);
    expect(await container.read(grammarModuleProvider('ja').future), isNull);
  });

  test('resolves known target words once per concept for grammar drills',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
    final list =
        (await repo.createList(name: 'Test', description: null)).valueOrNull!;
    final usable = (await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'student',
      wordB: '학생',
      category: 'nom',
    ))
        .valueOrNull!;
    final uncategorized = (await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'misc',
      wordB: '기타',
    ))
        .valueOrNull!;
    final usableVariants = await db.conceptDao.getVariantsByConcept(usable.id);
    final uncategorizedVariants =
        await db.conceptDao.getVariantsByConcept(uncategorized.id);

    final progress = _StatsProgressRepository({}, known: [
      _progress(
          'target', usableVariants.singleWhere((v) => v.langCode == 'ko').id),
      // Both variants of one concept can be known; drills must not repeat it.
      _progress('duplicate',
          usableVariants.singleWhere((v) => v.langCode == 'fr').id),
      _progress('deleted-remote', 'does-not-exist'),
      _progress('uncategorized', uncategorizedVariants.first.id),
    ]);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWithValue(_user()),
      progressRepositoryProvider.overrideWithValue(progress),
    ]);
    addTearDown(container.dispose);

    final korean = await container.read(drillWordsProvider('ko').future);
    expect(korean, hasLength(1));
    expect(korean.single.word, '학생');
    expect(korean.single.category, 'nom');
    // The same known concepts cannot supply a Spanish drill word.
    expect(await container.read(drillWordsProvider('es').future), isEmpty);
  });

  test('does not query local vocabulary for an anonymous learner', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(drillWordsProvider('ko').future), isEmpty);
  });

  test(
      'real FSRS graduation refreshes cached words and makes the rule playable',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final vocab = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
    final progress = ProgressRepositoryImpl(
        db.progressDao, db.conceptDao, FakeRemote(), 'u');
    final list = (await vocab.createList(name: 'Words')).valueOrNull!;
    final ids = <String>[];
    for (final word in ['학생', '선생님']) {
      final concept = (await vocab.addConceptWithVariants(
              listId: list.id, wordA: 'person', wordB: word, category: 'nom'))
          .valueOrNull!;
      ids.add((await db.conceptDao.getVariantsByConcept(concept.id))
          .firstWhere((variant) => variant.langCode == 'ko')
          .id);
    }
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWithValue(_user()),
      progressRepositoryProvider.overrideWithValue(progress),
      myListsProvider.overrideWith((ref) => vocab.watchMyLists()),
      grammarRulesProvider.overrideWith(
          (ref, lang) async => [_rule('reactive', minKnownWords: 2)]),
      grammarModuleProvider
          .overrideWith((ref, lang) async => const KoreanGrammarModule()),
      grammarProgressProvider.overrideWith((ref) => Stream.value({})),
    ]);
    addTearDown(container.dispose);
    final playable = Completer<void>();
    final subscription =
        container.listen(ruleStatusesProvider('ko'), (_, next) {
      if (next.valueOrNull?.single.enoughWords == true &&
          !playable.isCompleted) {
        playable.complete();
      }
    });
    addTearDown(subscription.close);
    expect(
        (await container.read(ruleStatusesProvider('ko').future))
            .single
            .enoughWords,
        isFalse);
    for (final id in ids) {
      await progress.updateProgress(VariantProgress(
          id: 'progress-$id',
          userId: 'u',
          variantId: id,
          direction: QuizDirection.koToFr,
          state: CardState.review,
          reps: 4,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026)));
    }
    await playable.future.timeout(const Duration(seconds: 5));
    expect(await container.read(drillWordsProvider('ko').future), hasLength(2));
  });

  test('streams persisted grammar progress for the signed-in learner',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.grammarProgressDao.recordAnswer(
      userId: 'u',
      ruleId: 'particles',
      correct: true,
      masteredWhenCorrectReaches: 10,
    );
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWithValue(_user()),
    ]);
    addTearDown(container.dispose);

    final progress = await container.read(grammarProgressProvider.future);
    expect(progress['particles'], (shown: 1, correct: 1, mastered: false));
  });

  test('availability and exercises exclude known words outside prerequisites',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
    Future<VocabularyList> create(String seedId, String word) async =>
        (await repo.importFromJson({
          'list': {
            'name': seedId,
            'seedId': '$seedId:fr>ko',
            'concepts': [
              {
                'category': 'nom',
                'variants': [
                  {'word': word, 'langCode': 'ko', 'isPrimary': true},
                  {'word': 'mot', 'langCode': 'fr', 'isPrimary': true},
                ],
              },
            ],
          },
        }))
            .valueOrNull!;
    final food = await create('starter-food', '사과');
    final other = await create('starter-daily-life', '학생');
    final variants = await db.conceptDao.getVariantsByConceptIds([
      ...(await db.conceptDao.getConceptsByList(food.id)).map((c) => c.id),
      ...(await db.conceptDao.getConceptsByList(other.id)).map((c) => c.id),
    ], 'ko');
    final rule = _rule('food', prerequisites: ['starter-food']);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWithValue(_user()),
      myListsProvider.overrideWith((ref) => repo.watchMyLists()),
      grammarRulesProvider.overrideWith((ref, lang) async => [rule]),
      grammarModuleProvider
          .overrideWith((ref, lang) async => const KoreanGrammarModule()),
      grammarProgressProvider.overrideWith((ref) => Stream.value({})),
      progressRepositoryProvider.overrideWithValue(_StatsProgressRepository({
        food.id: {'known': 1, 'total': 1},
        other.id: {'known': 1, 'total': 1},
      }, known: [
        for (final v in variants) _progress('p-${v.id}', v.id)
      ])),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(drillWordsProvider('ko').future), hasLength(2));
    final pool = await container.read(
        ruleDrillWordsProvider((ruleId: rule.id, targetLang: 'ko')).future);
    expect(pool.map((word) => word.word), ['사과']);
    expect(
        (await container.read(ruleStatusesProvider('ko').future))
            .single
            .enoughWords,
        isFalse);
    final exercises = const GrammarDrillGenerator(KoreanGrammarModule())
        .generate(rule, pool, count: 10);
    expect(exercises, isNotEmpty);
    expect(exercises.every((exercise) => exercise.expected.contains('사과')),
        isTrue);
    expect(
        exercises.any((exercise) => exercise.expected.contains('학생')), isFalse);
  });

  test(
      'derives locked, unlocked and mastered statuses from exact prerequisites',
      () async {
    final rules = [
      _rule('unlocked', prerequisites: const ['starter-greetings']),
      _rule('locked', prerequisites: const ['Legacy list']),
      _rule('mastered', minKnownWords: 99),
    ];
    final container = ProviderContainer(overrides: [
      grammarRulesProvider.overrideWith((ref, lang) async => rules),
      grammarModuleProvider
          .overrideWith((ref, lang) async => const KoreanGrammarModule()),
      myListsProvider.overrideWith((ref) => Stream.value([
            _list(
              id: 'fr-progress',
              name: 'Salutations FR',
              seedId: 'starter-greetings:fr>ko',
            ),
            _list(
              id: 'best-progress',
              name: 'Greetings EN',
              seedId: 'starter-greetings:en>ko',
            ),
            _list(id: 'legacy', name: 'Legacy list'),
          ])),
      progressRepositoryProvider.overrideWithValue(_StatsProgressRepository({
        'fr-progress': const {'known': 15, 'total': 20},
        'best-progress': const {'known': 18, 'total': 20},
        'legacy': const {'known': 6, 'total': 10},
      })),
      grammarProgressProvider.overrideWith((ref) => Stream.value({
            'mastered': (shown: 10, correct: 10, mastered: true),
          })),
      vocabularyProgressChangesProvider
          .overrideWith((ref) => Stream<void>.value(null)),
      drillWordsProvider.overrideWith((ref, lang) async => const [
            DrillWord(word: '학생', category: 'nom', listId: 'best-progress'),
            DrillWord(word: '친구', category: 'nom', listId: 'best-progress'),
            DrillWord(word: '학생', category: 'nom', listId: 'legacy'),
            DrillWord(word: '친구', category: 'nom', listId: 'legacy'),
          ]),
    ]);
    addTearDown(container.dispose);

    final statuses = await container.read(ruleStatusesProvider('ko').future);

    final unlocked = statuses[0];
    expect(unlocked.availability, RuleAvailability.unlocked);
    expect(unlocked.enoughWords, isTrue);
    expect(unlocked.missingLists, isEmpty);
    // The learner's furthest equivalent curriculum list wins, regardless of
    // source language, and keeps the precise list id for the CTA.
    expect(unlocked.prereqProgress['starter-greetings'], 0.9);
    expect(unlocked.prereqNames['starter-greetings'], 'Greetings EN');
    expect(unlocked.prereqListIds['starter-greetings'], 'best-progress');

    final locked = statuses[1];
    expect(locked.availability, RuleAvailability.locked);
    expect(locked.missingLists, const ['Legacy list']);
    expect(locked.unlockFraction, 0.6);
    expect(locked.enoughWords, isTrue);

    final mastered = statuses[2];
    expect(mastered.availability, RuleAvailability.mastered);
    expect(mastered.correct, 10);
    expect(mastered.enoughWords, isFalse);
  });

  test('refreshes prerequisite availability when FSRS progress changes',
      () async {
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    final stats = <String, Map<String, int>>{
      'starter': {'known': 0, 'total': 10},
    };
    final container = ProviderContainer(overrides: [
      grammarRulesProvider.overrideWith((ref, lang) async => [
            _rule('reactive', prerequisites: const ['a'])
          ]),
      grammarModuleProvider
          .overrideWith((ref, lang) async => const KoreanGrammarModule()),
      myListsProvider.overrideWith((ref) =>
          Stream.value([_list(id: 'starter', name: 'A', seedId: 'a:fr>ko')])),
      progressRepositoryProvider
          .overrideWithValue(_StatsProgressRepository(stats)),
      grammarProgressProvider.overrideWith((ref) => Stream.value({})),
      drillWordsProvider.overrideWith((ref, lang) async => const []),
      vocabularyProgressChangesProvider
          .overrideWith((ref) => _withInitialProgressChange(changes.stream)),
    ]);
    addTearDown(container.dispose);

    final initial = await container.read(ruleStatusesProvider('ko').future);
    expect(initial.single.availability, RuleAvailability.locked);

    final refreshed = Completer<List<RuleStatus>>();
    final subscription =
        container.listen(ruleStatusesProvider('ko'), (_, next) {
      final statuses = next.valueOrNull;
      if (statuses?.single.availability == RuleAvailability.unlocked &&
          !refreshed.isCompleted) {
        refreshed.complete(statuses!);
      }
    });
    addTearDown(subscription.close);

    stats['starter'] = {'known': 10, 'total': 10};
    changes.add(null);

    expect((await refreshed.future).single.availability,
        RuleAvailability.unlocked);
  });
}
