import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/grammar_language_module.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/seed/starter_seeder.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart' show CardState;
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import '../../helpers/fake_remote.dart';

GrammarRule _rule(
  String id, {
  List<String> prerequisites = const [],
  int minKnownWords = 2,
}) => GrammarRule(
  id: id,
  titles: const {'fr': 'Règle'},
  descriptions: const {'fr': ''},
  explanations: const {'fr': ''},
  workedExamples: const [],
  prerequisiteLists: prerequisites,
  appliesToCategories: const ['nom'],
  minKnownWords: {'nom': minKnownWords},
  mechanics: const ParticleMechanics(
    variants: [
      ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
    ],
  ),
  testVectors: const [],
);

AppUser _user() => AppUser(
  id: 'u',
  email: 'user@example.com',
  username: 'user',
  subscriptionType: SubscriptionType.free,
  createdAt: DateTime(2026),
);

Future<T> _observe<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> future,
) async {
  final subscription = container.listen(future, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

VariantProgressTableCompanion _graduated(String variantId) =>
    VariantProgressTableCompanion.insert(
      id: 'progress-$variantId',
      userId: 'u',
      variantId: variantId,
      direction: 'fr>ko',
      state: const Value('review'),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'loads every shipped grammar curriculum and selects its module',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final lang in kGrammarCurricula) {
        final rules = await container.read(grammarRulesProvider(lang).future);
        final module = await container.read(grammarModuleProvider(lang).future);

        expect(rules, isNotEmpty, reason: '$lang must ship reviewed rules');
        expect(
          rules.map((r) => r.mechanics),
          isNot(contains(isA<UnsupportedMechanics>())),
        );
        expect(module, isNotNull);
        expect(module!.langCode, lang);
      }
    },
  );

  test(
    'languages without a curriculum have neither rules nor a module',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(grammarRulesProvider('ja').future), isEmpty);
      expect(await container.read(grammarModuleProvider('ja').future), isNull);
    },
  );

  test(
    'resolves known target words once per concept for grammar drills',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
      final list = (await repo.createList(
        name: 'Test',
        description: null,
      )).valueOrNull!;
      final usable = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'student',
        wordB: '학생',
        category: 'nom',
      )).valueOrNull!;
      final uncategorized = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'misc',
        wordB: '기타',
      )).valueOrNull!;
      final learnedInFrench = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'friend',
        wordB: '친구',
        category: 'nom',
      )).valueOrNull!;
      final usableVariants = await db.conceptDao.getVariantsByConcept(
        usable.id,
      );
      final uncategorizedVariants = await db.conceptDao.getVariantsByConcept(
        uncategorized.id,
      );
      final learnedInFrenchVariants = await db.conceptDao.getVariantsByConcept(
        learnedInFrench.id,
      );

      // Both variants of one concept can graduate without duplicating the word.
      for (final variant in [...usableVariants, uncategorizedVariants.first]) {
        await db.progressDao.upsert(_graduated(variant.id));
      }
      await db.progressDao.upsert(
        _graduated(
          learnedInFrenchVariants.singleWhere((v) => v.langCode == 'fr').id,
        ),
      );
      await db.progressDao.upsert(_graduated('deleted-remote'));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
        ],
      );
      addTearDown(container.dispose);

      final korean = await _observe(container, drillWordsProvider('ko').future);
      expect(korean.map((word) => word.word), unorderedEquals(['학생', '친구']));
      expect(korean.map((word) => word.category), everyElement('nom'));
      // The same known concepts cannot supply a Spanish drill word.
      expect(
        await _observe(container, drillWordsProvider('es').future),
        isEmpty,
      );
    },
  );

  test('does not query local vocabulary for an anonymous learner', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await _observe(container, drillWordsProvider('ko').future), isEmpty);
  });

  test(
    'real FSRS graduation refreshes cached words and makes the rule playable',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final vocab = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
      final progress = ProgressRepositoryImpl(
        db.progressDao,
        db.conceptDao,
        FakeRemote(),
        'u',
      );
      final list = (await vocab.createList(name: 'Words')).valueOrNull!;
      final ids = <String>[];
      for (final word in ['학생', '선생님']) {
        final concept = (await vocab.addConceptWithVariants(
          listId: list.id,
          wordA: 'person',
          wordB: word,
          category: 'nom',
        )).valueOrNull!;
        ids.add(
          (await db.conceptDao.getVariantsByConcept(
            concept.id,
          )).firstWhere((variant) => variant.langCode == 'ko').id,
        );
      }
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
          grammarRulesProvider.overrideWith(
            (ref, lang) async => [_rule('reactive', minKnownWords: 2)],
          ),
          grammarModuleProvider.overrideWith(
            (ref, lang) async => const KoreanGrammarModule(),
          ),
          grammarProgressProvider.overrideWith((ref) => Stream.value({})),
        ],
      );
      addTearDown(container.dispose);
      final playable = Completer<void>();
      final subscription = container.listen(ruleStatusesProvider('ko'), (
        _,
        next,
      ) {
        if (next.valueOrNull?.single.enoughWords == true &&
            !playable.isCompleted) {
          playable.complete();
        }
      });
      addTearDown(subscription.close);
      expect(
        (await container.read(
          ruleStatusesProvider('ko').future,
        )).single.enoughWords,
        isFalse,
      );
      for (final id in ids) {
        await progress.updateProgress(
          VariantProgress(
            id: 'progress-$id',
            userId: 'u',
            variantId: id,
            direction: QuizDirection.koToFr,
            state: CardState.review,
            reps: 4,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
      }
      await playable.future.timeout(const Duration(seconds: 5));
      expect(
        await container.read(drillWordsProvider('ko').future),
        hasLength(2),
      );
    },
  );

  test(
    'streams persisted grammar progress for the signed-in learner',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.grammarProgressDao.recordAnswer(
        userId: 'u',
        ruleId: 'particles',
        correct: true,
        masteredWhenCorrectReaches: 10,
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
        ],
      );
      addTearDown(container.dispose);

      final progress = await _observe(
        container,
        grammarProgressProvider.future,
      );
      expect(progress['particles'], (shown: 1, correct: 1, mastered: false));
    },
  );

  test(
    'availability and exercises exclude known words outside prerequisites',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
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
          })).valueOrNull!;
      final food = await create('starter-food', '사과');
      final other = await create('starter-daily-life', '학생');
      final variants = await db.conceptDao.getVariantsByConceptIds([
        ...(await db.conceptDao.getConceptsByList(food.id)).map((c) => c.id),
        ...(await db.conceptDao.getConceptsByList(other.id)).map((c) => c.id),
      ], 'ko');
      for (final variant in variants) {
        await db.progressDao.upsert(_graduated(variant.id));
      }
      final rule = _rule('food', prerequisites: ['starter-food']);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
          grammarRulesProvider.overrideWith((ref, lang) async => [rule]),
          grammarModuleProvider.overrideWith(
            (ref, lang) async => const KoreanGrammarModule(),
          ),
          grammarProgressProvider.overrideWith((ref) => Stream.value({})),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await _observe(container, drillWordsProvider('ko').future),
        hasLength(2),
      );
      final pool = await _observe(
        container,
        ruleDrillWordsProvider((ruleId: rule.id, targetLang: 'ko')).future,
      );
      expect(pool.map((word) => word.word), ['사과']);
      expect(
        (await _observe(
          container,
          ruleStatusesProvider('ko').future,
        )).single.enoughWords,
        isFalse,
      );
      final exercises = const GrammarDrillGenerator(
        KoreanGrammarModule(),
      ).generate(rule, pool, count: 10);
      expect(exercises, isNotEmpty);
      expect(
        exercises.every((exercise) => exercise.expected.contains('사과')),
        isTrue,
      );
      expect(
        exercises.any((exercise) => exercise.expected.contains('학생')),
        isFalse,
      );
    },
  );

  test(
    'fully mastered real Korean prerequisites open subject and location drills',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
      await StarterSeeder(
        bundle: rootBundle,
        repo: repo,
        listDao: db.vocabularyListDao,
        conceptDao: db.conceptDao,
        userId: 'u',
      ).ensureSeededForPair('fr', 'ko');
      final lists = (await repo.watchMyLists().first);
      for (final list in lists) {
        final concepts = await db.conceptDao.getConceptsByList(list.id);
        final words = await db.conceptDao.getVariantsByConceptIds(
          concepts.map((c) => c.id).toList(),
          'ko',
        );
        for (final variant in words) {
          await db.progressDao.upsert(_graduated(variant.id));
        }
      }
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
          grammarProgressProvider.overrideWith((ref) => Stream.value({})),
        ],
      );
      addTearDown(container.dispose);
      final statuses = await _observe(
        container,
        ruleStatusesProvider('ko').future,
      );
      final generator = GrammarDrillGenerator(
        (await container.read(grammarModuleProvider('ko').future))!,
      );
      for (final prefix in ['particules-sujet', 'particules-lieu']) {
        final status = statuses.firstWhere((s) => s.rule.id.startsWith(prefix));
        expect(status.availability, RuleAvailability.unlocked);
        expect(status.enoughWords, isTrue, reason: status.rule.id);
        expect(status.prereqProgress.values, everyElement(1.0));
        final pool = await _observe(
          container,
          ruleDrillWordsProvider((
            ruleId: status.rule.id,
            targetLang: 'ko',
          )).future,
        );
        final exercises = generator.generate(status.rule, pool, count: 10);
        expect(exercises, hasLength(10));
        final eligible = generator
            .eligibleWords(status.rule, pool)
            .map((word) => word.word)
            .toSet();
        expect(
          exercises.every((e) => eligible.contains(e.promptParams['word'])),
          isTrue,
        );
      }
    },
  );

  test(
    'derives locked, unlocked and mastered statuses from exact prerequisites',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026);
      Future<void> saveList({
        required String id,
        required String name,
        String? seedId,
        String langA = 'fr',
        String langB = 'ko',
        int known = 4,
        int total = 4,
      }) async {
        await db.vocabularyListDao.upsert(
          VocabularyListsTableCompanion.insert(
            id: id,
            ownerId: 'u',
            name: name,
            seedId: Value(seedId),
            langA: Value(langA),
            langB: Value(langB),
            createdAt: now,
            updatedAt: now,
          ),
        );
        for (var i = 0; i < total; i++) {
          final conceptId = '$id-$i';
          await db.conceptDao.upsert(
            ConceptsTableCompanion.insert(
              id: conceptId,
              listId: id,
              category: const Value('nom'),
              createdAt: now,
              updatedAt: now,
            ),
          );
          final variantId = '$conceptId-$langB';
          await db.conceptDao.upsertVariant(
            WordVariantsTableCompanion.insert(
              id: variantId,
              conceptId: conceptId,
              langCode: langB,
              word: i.isEven ? '학생' : '친구',
              createdAt: now,
              updatedAt: now,
            ),
          );
          if (i < known) await db.progressDao.upsert(_graduated(variantId));
        }
      }

      await saveList(
        id: 'fr-progress',
        name: 'Salutations FR',
        seedId: 'starter-greetings:fr>ko',
        known: 3,
      );
      await saveList(
        id: 'best-progress',
        name: 'Greetings EN',
        seedId: 'starter-greetings:en>ko',
        langA: 'en',
        known: 9,
        total: 10,
      );
      await saveList(id: 'homonym', name: 'starter-greetings');
      await saveList(
        id: 'wrong-pair',
        name: 'starter-greetings',
        seedId: 'starter-greetings:fr>en',
        langB: 'en',
      );
      await saveList(id: 'legacy', name: 'Legacy list');
      final rules = [
        _rule('unlocked', prerequisites: const ['starter-greetings']),
        _rule('locked', prerequisites: const ['Legacy list']),
        _rule('mastered', minKnownWords: 99),
      ];
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
          grammarRulesProvider.overrideWith((ref, lang) async => rules),
          grammarModuleProvider.overrideWith(
            (ref, lang) async => const KoreanGrammarModule(),
          ),
          grammarProgressProvider.overrideWith(
            (ref) => Stream.value({
              'mastered': (shown: 10, correct: 10, mastered: true),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      final statuses = await _observe(
        container,
        ruleStatusesProvider('ko').future,
      );

      final unlocked = statuses[0];
      expect(unlocked.availability, RuleAvailability.unlocked);
      expect(unlocked.enoughWords, isTrue);
      expect(unlocked.missingLists, isEmpty);
      // The furthest copy wins across source languages and keeps its local ID.
      expect(unlocked.prereqProgress['starter-greetings'], 0.9);
      expect(unlocked.prereqNames['starter-greetings'], 'Greetings EN');
      expect(unlocked.prereqListIds['starter-greetings'], 'best-progress');

      final locked = statuses[1];
      expect(locked.availability, RuleAvailability.locked);
      expect(locked.missingLists, const ['Legacy list']);
      expect(locked.unlockFraction, 0);
      expect(locked.enoughWords, isFalse);

      final mastered = statuses[2];
      expect(mastered.availability, RuleAvailability.mastered);
      expect(mastered.correct, 10);
      expect(mastered.enoughWords, isFalse);
    },
  );

  test(
    'an empty prerequisite keeps its name and shows zero progress',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026);
      await db.vocabularyListDao.upsert(
        VocabularyListsTableCompanion.insert(
          id: 'greetings',
          ownerId: 'u',
          name: 'Mes salutations',
          seedId: const Value('starter-greetings:fr>ko'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(_user()),
          grammarRulesProvider.overrideWith(
            (ref, lang) async => [
              _rule('r', prerequisites: ['starter-greetings']),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      final prerequisites = await _observe(
        container,
        grammarPrerequisitesProvider('ko').future,
      );
      expect(prerequisites.names['starter-greetings'], 'Mes salutations');
      expect(prerequisites.progress['starter-greetings']!.fraction, 0);
    },
  );
}
