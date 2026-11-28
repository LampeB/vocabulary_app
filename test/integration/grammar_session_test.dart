// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/rule_mastery.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../helpers/fake_remote.dart';
import '../helpers/pump_screen.dart' show initTestLocalization;

final _quiz = quizProvider(Object());

/// Grammar drill sessions through the REAL quiz flow: cards generated from
/// the rule + mastered words, answers recording rule progress (never FSRS),
/// cartes never counting, mastery reached at the target.

class _NoopAudio implements AudioPlayerService {
  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> prefetch(
    String text,
    String langCode, {
    String? audioPath,
  }) async {}
  @override
  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
  }) async {}
  @override
  Future<void> retryDisposal() => stop();
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

class _FakeAuthRepo implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async => const Success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AppUser?> build() async => null;
  @override
  Future<void> reloadProfile() async {}
}

class _FakeNotifService implements NotificationService {
  @override
  Future<void> cancelStreakWarning() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingPushSync implements PushSync {
  int drains = 0;
  final firstDrain = Completer<void>();

  @override
  Future<int> pushAll() async {
    if (++drains == 1) firstDrain.complete();
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DrillWord catalogKimchi;
  late DrillWord catalogFrenchWater;
  final localeCopies = <String, Map<String, dynamic>>{};
  setUpAll(() async {
    await initTestLocalization();
    final layer =
        jsonDecode(
              await rootBundle.loadString('assets/seed/vocab/lang/en.json'),
            )
            as Map<String, dynamic>;
    final registry =
        jsonDecode(
              await rootBundle.loadString('assets/seed/vocab/registry.json'),
            )
            as Map<String, dynamic>;
    final entry =
        (layer['entries'] as Map<String, dynamic>)['kimchi']
            as Map<String, dynamic>;
    final primary = (entry['words'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((word) => word['is_primary'] == true);
    final concept = (registry['concepts'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((concept) => concept['id'] == 'kimchi');
    final food = (registry['lists'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((list) => list['id'] == 'starter-food');
    expect(food['concepts'] as List, contains('kimchi'));
    catalogKimchi = DrillWord(
      word: primary['word'] as String,
      category: concept['category'] as String,
    );
    final frenchLayer =
        jsonDecode(
              await rootBundle.loadString('assets/seed/vocab/lang/fr.json'),
            )
            as Map<String, dynamic>;
    final water =
        (frenchLayer['entries'] as Map<String, dynamic>)['eau']
            as Map<String, dynamic>;
    final waterPrimary = (water['words'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((word) => word['is_primary'] == true);
    final waterMetadata = (registry['concepts'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((concept) => concept['id'] == 'eau');
    expect(food['concepts'] as List, contains('eau'));
    catalogFrenchWater = DrillWord(
      word: waterPrimary['word'] as String,
      category: waterMetadata['category'] as String,
    );
    for (final locale in ['fr', 'en', 'ko']) {
      localeCopies[locale] =
          jsonDecode(
                await rootBundle.loadString('assets/translations/$locale.json'),
              )
              as Map<String, dynamic>;
    }
  });

  late AppDatabase db;
  late ProviderContainer container;

  const words = [
    DrillWord(word: '학생', category: 'nom'),
    DrillWord(word: '친구', category: 'nom'),
    DrillWord(word: '물', category: 'nom'),
    DrillWord(word: '커피', category: 'nom'),
    DrillWord(word: '밥', category: 'nom'),
  ];

  ProviderContainer makeContainer({
    List<Override> overrides = const [],
    StateProvider<AppUser?>? account,
    bool useCatalog = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        if (!useCatalog)
          ruleDrillWordsProvider.overrideWith(
            (ref, key) async => switch (key) {
              (ruleId: 'fr-articles-le-la', targetLang: 'fr') => const [
                DrillWord(word: 'eau', category: 'nom', tags: ['f']),
              ],
              (ruleId: 'fr-negation-ne-pas', targetLang: 'fr') => const [
                DrillWord(word: 'travailler', category: 'verbe'),
              ],
              (ruleId: 'fr-present-er', targetLang: 'fr') => const [
                DrillWord(word: 'travailler', category: 'verbe'),
              ],
              (ruleId: 'en-negation-dont', targetLang: 'en') => const [
                DrillWord(word: 'to work', category: 'verbe'),
              ],
              (ruleId: 'en-plural-s-es', targetLang: 'en') => [
                const DrillWord(word: 'water', category: 'nom'),
                const DrillWord(word: 'coffee', category: 'nom'),
                const DrillWord(word: 'milk', category: 'nom'),
                const DrillWord(word: 'bread', category: 'nom'),
                catalogKimchi,
              ],
              (ruleId: _, targetLang: 'fr') => const [
                DrillWord(word: 'pomme', category: 'nom'),
              ],
              _ => words,
            },
          ),
        if (account == null)
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'u',
              email: 't@t.fr',
              username: 't',
              subscriptionType: SubscriptionType.free,
              createdAt: DateTime(2026),
            ),
          )
        else
          currentUserProvider.overrideWith((ref) => ref.watch(account)),
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notificationServiceProvider.overrideWithValue(_FakeNotifService()),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = makeContainer();
    addTearDown(db.close);
  });

  QuizArgs args({QuizMode mode = QuizMode.typing, int cardLimit = 3}) =>
      QuizArgs(
        source: QuizSource.grammar,
        ruleId: 'particule-theme-eun-neun',
        ruleTitle: 'La particule de thème 은/는',
        mode: mode,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: cardLimit,
      );

  Future<ProviderContainer> masterCatalog(String langA, String langB) async {
    final session = makeContainer(useCatalog: true);
    await session.read(starterSeederProvider).ensureSeededForPair(langA, langB);
    final lists = await session.read(myListsProvider.future);
    final now = DateTime(2026);
    for (final list in lists) {
      final concepts = await db.conceptDao.getConceptsByList(list.id);
      final variants = await db.conceptDao.getVariantsByConceptIds([
        for (final concept in concepts) concept.id,
      ], langB);
      for (final variant in variants) {
        await db.progressDao.upsert(
          VariantProgressTableCompanion.insert(
            id: 'progress-${variant.id}',
            userId: 'u',
            variantId: variant.id,
            direction: '$langA>$langB',
            state: const Value('review'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    return session;
  }

  Future<void> gradeCatalogAnswers(
    ProviderContainer session, {
    required String ruleId,
    required String targetLang,
    required Map<String, Map<String, bool>> cases,
  }) async {
    final sub = session.listen(_quiz, (_, _) {});
    final notifier = session.read(_quiz.notifier);
    var shown = 0;
    var correct = 0;
    for (final mode in [QuizMode.typing, QuizMode.voice]) {
      for (final MapEntry(key: word, value: answers) in cases.entries) {
        for (final MapEntry(key: answer, value: accepted) in answers.entries) {
          await notifier.loadCards(
            QuizArgs(
              source: QuizSource.grammar,
              ruleId: ruleId,
              mode: mode,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: 40,
              langB: targetLang,
            ),
          );
          final index = sub.read().cards.indexWhere(
            (card) => card.grammarAudioPrompt?.word == word,
          );
          expect(index, isNonNegative, reason: '$ruleId must exercise $word');
          for (var i = 0; i < index; i++) {
            notifier.skipCurrentCard();
          }
          if (mode == QuizMode.voice) {
            notifier.submitVoiceAnswer('$answer.', isDrivingMode: true);
          } else {
            notifier.submitTextAnswer(answer);
          }
          expect(
            sub.read().answerState,
            accepted ? QuizAnswerState.correct : QuizAnswerState.incorrect,
            reason: '$mode, $word: $answer',
          );
          shown++;
          if (accepted) correct++;
        }
      }
    }
    final progress = await db.grammarProgressDao
        .watchByUser('u')
        .expand((rows) => rows)
        .firstWhere((row) => row.ruleId == ruleId && row.shown == shown)
        .timeout(const Duration(seconds: 2));
    expect(progress.correct, correct);
  }

  test('real Korean negation grades lexical exceptions and antonyms', () async {
    final session = await masterCatalog('fr', 'ko');
    await gradeCatalogAnswers(
      session,
      ruleId: 'negation-an',
      targetLang: 'ko',
      cases: const {
        '좋아하다': {'안 좋아해요': true, '좋아 안 해요': false},
        '맛있다': {'맛없어요': true, '안 맛있어요': true},
        '공부하다': {'공부 안 해요': true, '안 공부해요': false},
      },
    );
  });

  test(
    'real Korean particle cards show and speak each selected form',
    () async {
      final session = await masterCatalog('fr', 'ko');
      final sub = session.listen(_quiz, (_, _) {});
      final notifier = session.read(_quiz.notifier);
      addTearDown(initTestLocalization);
      for (final locale in ['fr', 'en', 'ko']) {
        Localization.load(
          Locale(locale),
          translations: Translations(localeCopies[locale]!),
          fallbackTranslations: Translations(localeCopies['fr']!),
        );
        for (final ruleId in [
          'particule-theme-eun-neun',
          'particules-sujet-objet-i-ga-eul-reul',
          'particules-lieu-e-eseo',
        ]) {
          await notifier.loadCards(
            QuizArgs(
              source: QuizSource.grammar,
              ruleId: ruleId,
              mode: QuizMode.handsFree,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: 6,
            ),
            promptLocale: locale,
          );
          final cards = sub.read().cards;
          expect(cards, hasLength(6));
          expect(
            cards
                .map((card) => card.progress.variantId.split('|').last)
                .toSet(),
            switch (ruleId) {
              'particule-theme-eun-neun' => {''},
              'particules-sujet-objet-i-ga-eul-reul' => {'subject', 'object'},
              _ => {'destination_or_time', 'action_location'},
            },
          );
          for (final card in cards) {
            final variant = card.progress.variantId.split('|').last;
            final spoken = card.grammarAudioPrompt!;
            expect(card.direction.answerLang, 'ko');
            expect(spoken.locale, locale);
            if (variant.isNotEmpty) {
              final hint = 'grammar.hint.$variant'.tr();
              expect(card.questionWord, contains(hint));
              expect(spoken.instruction, contains(hint));
            }
            final forms = switch (variant) {
              'subject' => '이/가',
              'object' => '을/를',
              '' => '은/는',
              _ => null,
            };
            if (forms != null) {
              expect(card.questionWord, contains(forms));
              final prefix = '${forms.split('/').join('. ')}. ';
              expect(spoken.word, startsWith(prefix));
              expect(
                card.questionWord,
                contains(spoken.word.substring(prefix.length)),
              );
            } else {
              expect(spoken.word, isNot(contains('. ')));
              expect(card.questionWord, contains(spoken.word));
            }
          }
        }
      }
    },
  );

  test('English catalog drills admit authored forms of to be busy', () async {
    final session = await masterCatalog('fr', 'en');
    final sub = session.listen(_quiz, (_, _) {});
    final notifier = session.read(_quiz.notifier);
    final statuses = await session.read(ruleStatusesProvider('en').future);
    final module = (await session.read(grammarModuleProvider('en').future))!;
    final generator = GrammarDrillGenerator(module);

    for (final ruleId in ['en-present-3sg-s', 'en-negation-dont']) {
      final status = statuses.singleWhere((status) => status.rule.id == ruleId);
      final rule = status.rule;
      expect(status.availability, RuleAvailability.unlocked);
      expect(status.enoughWords, isTrue);
      final pool = await session.read(
        ruleDrillWordsProvider((ruleId: ruleId, targetLang: 'en')).future,
      );
      final busy = pool.singleWhere((word) => word.word == 'to be busy');
      expect(busy.category, 'adjectif');
      final verbs = pool.where((word) => word.category == 'verbe');
      expect(generator.canGenerate(rule, [...verbs.take(4), busy]), isFalse);
      expect(generator.canGenerate(rule, verbs.take(5).toList()), isTrue);
    }

    await notifier.loadCards(
      const QuizArgs(
        source: QuizSource.grammar,
        ruleId: 'en-present-3sg-s',
        mode: QuizMode.typing,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: 40,
        langB: 'en',
      ),
    );
    final busy = sub.read().cards.firstWhere(
      (card) => card.grammarAudioPrompt?.word == 'to be busy',
    );
    expect(busy.answerWords, [
      busy.progress.variantId.endsWith('p1sg') ? 'am busy' : 'is busy',
    ]);

    await gradeCatalogAnswers(
      session,
      ruleId: 'en-negation-dont',
      targetLang: 'en',
      cases: const {
        'to be busy': {
          'am not busy': true,
          'I am not busy': true,
          'I’m not busy': true,
          'I don’t be busy': false,
        },
      },
    );
  });

  test(
    'loadCards generates localized drill cards from mastered words',
    () async {
      final sub = container.listen(_quiz, (_, _) {});
      await container.read(_quiz.notifier).loadCards(args());

      final state = sub.read();
      expect(state.cards, hasLength(3));
      for (final card in state.cards) {
        expect(card.questionWord, contains('particule')); // localized FR prompt
        expect(card.answerWords.first, anyOf(endsWith('은'), endsWith('는')));
      }
    },
  );

  test('a rejected grammar words provider settles the loading state', () async {
    final session = makeContainer(
      overrides: [
        ruleDrillWordsProvider.overrideWith(
          (_, _) async => throw StateError('Could not read grammar words'),
        ),
      ],
    );
    final sub = session.listen(_quiz, (_, _) {});
    await session.read(_quiz.notifier).loadCards(args());

    expect(sub.read().isLoading, isFalse);
    expect(sub.read().isEmpty, isFalse);
    expect(sub.read().cards, isEmpty);
    expect(sub.read().errorMessage, 'quiz.load_failed'.tr());
  });

  for (final ruleId in ['fr-plural-s', 'fr-present-er']) {
    test(
      'direct spoken entry cannot grade ambiguous French spelling in $ruleId',
      () async {
        final sub = container.listen(_quiz, (_, _) {});
        final notifier = container.read(_quiz.notifier);
        for (final mode in [QuizMode.voice, QuizMode.handsFree]) {
          await notifier.loadCards(
            QuizArgs(
              source: QuizSource.grammar,
              ruleId: ruleId,
              mode: mode,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: 3,
              langA: 'ko',
              langB: 'fr',
            ),
          );
          expect(sub.read().cards, isEmpty);
          expect(sub.read().errorMessage, 'grammar.written_only'.tr());
          notifier.submitVoiceAnswer('pommes', isDrivingMode: true);
          expect(sub.read().answerState, QuizAnswerState.idle);
        }
        expect(await db.grammarProgressDao.get('u', ruleId), isNull);
      },
    );
  }

  for (final answer in ['travaille', 'travailles']) {
    test(
      'French present evaluates the written second-person ending in $answer',
      () async {
        const ruleId = 'fr-present-er';
        final sub = container.listen(_quiz, (_, _) {});
        final notifier = container.read(_quiz.notifier);
        await notifier.loadCards(
          const QuizArgs(
            source: QuizSource.grammar,
            ruleId: ruleId,
            mode: QuizMode.typing,
            direction: QuizDirectionChoice.frToKo,
            cardLimit: 2,
            langA: 'ko',
            langB: 'fr',
          ),
        );
        expect(sub.read().currentCard!.answerWords, ['travaille']);
        notifier.submitTextAnswer('travaille');
        expect(sub.read().answerState, QuizAnswerState.correct);
        notifier.advance();
        expect(sub.read().currentCard!.answerWords, ['travailles']);
        notifier.submitTextAnswer(answer);
        expect(
          sub.read().answerState,
          answer == 'travailles'
              ? QuizAnswerState.correct
              : QuizAnswerState.incorrect,
        );
        final progress = await db.grammarProgressDao
            .watchByUser('u')
            .expand((rows) => rows)
            .firstWhere((row) => row.ruleId == ruleId && row.shown == 2)
            .timeout(const Duration(seconds: 2));
        expect(progress.correct, answer == 'travailles' ? 2 : 1);
      },
    );
  }

  test('the French plural drill requires the written s', () async {
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(
      const QuizArgs(
        source: QuizSource.grammar,
        ruleId: 'fr-plural-s',
        mode: QuizMode.typing,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: 2,
        langA: 'ko',
        langB: 'fr',
      ),
    );
    expect(sub.read().currentCard!.answerWords, ['pommes']);
    notifier.submitTextAnswer('pomme');
    expect(sub.read().answerState, QuizAnswerState.incorrect);
    Future<GrammarProgressTableData> afterAnswers(int shown) => db
        .grammarProgressDao
        .watchByUser('u')
        .expand((rows) => rows)
        .firstWhere((row) => row.ruleId == 'fr-plural-s' && row.shown == shown)
        .timeout(const Duration(seconds: 2));
    expect((await afterAnswers(1)).correct, 0);
    notifier.advance();
    notifier.submitTextAnswer('pommes');
    expect(sub.read().answerState, QuizAnswerState.correct);
    expect((await afterAnswers(2)).correct, 1);
  });

  for (final locale in ['fr', 'ko']) {
    test(
      'French catalog water keeps the generic plural instruction in $locale',
      () async {
        final copy = Translations(localeCopies[locale]!);
        Localization.load(
          Locale(locale),
          translations: copy,
          fallbackTranslations: copy,
        );
        addTearDown(initTestLocalization);
        final session = makeContainer(
          overrides: [
            ruleDrillWordsProvider.overrideWith(
              (ref, key) async => [catalogFrenchWater],
            ),
          ],
        );
        final sub = session.listen(_quiz, (_, _) {});
        final notifier = session.read(_quiz.notifier);
        await notifier.loadCards(
          const QuizArgs(
            source: QuizSource.grammar,
            ruleId: 'fr-plural-s',
            mode: QuizMode.typing,
            direction: QuizDirectionChoice.frToKo,
            cardLimit: 1,
            langA: 'ko',
            langB: 'fr',
          ),
          promptLocale: locale,
        );
        final card = sub.read().currentCard!;
        expect(
          card.questionWord,
          (localeCopies[locale]!['grammar.drill.plural'] as String).replaceAll(
            '{word}',
            catalogFrenchWater.word,
          ),
        );
        expect(card.answerWords, ['eaux']);
        notifier.submitTextAnswer('eaux');
        expect(sub.read().answerState, QuizAnswerState.correct);
        final progress = await db.grammarProgressDao
            .watchByUser('u')
            .expand((rows) => rows)
            .firstWhere((row) => row.ruleId == 'fr-plural-s' && row.shown == 1)
            .timeout(const Duration(seconds: 2));
        expect(progress.correct, 1);
      },
    );
  }

  for (final voice in [false, true]) {
    test(
      'English plural accepts catalog kimchi and distinguishes water and coffees, voice=$voice',
      () async {
        final sub = container.listen(_quiz, (_, _) {});
        final notifier = container.read(_quiz.notifier);
        await notifier.loadCards(
          QuizArgs(
            source: QuizSource.grammar,
            ruleId: 'en-plural-s-es',
            mode: voice ? QuizMode.voice : QuizMode.typing,
            direction: QuizDirectionChoice.frToKo,
            cardLimit: 10,
            langA: 'fr',
            langB: 'en',
          ),
          promptLocale: 'fr',
        );
        var rejectedWaterPlural = false;
        var acceptedWater = false;
        var acceptedCoffees = false;
        var acceptedKimchi = false;
        while (!sub.read().isComplete) {
          final card = sub.read().currentCard!;
          expect(card.questionWord, contains('indénombrable inchangé'));
          final expected = card.answerWords.single;
          if (card.questionWord.endsWith(catalogKimchi.word)) {
            expect(expected, catalogKimchi.word);
            expect(card.answerWords, isNot(contains('kimchis')));
            acceptedKimchi = true;
          }
          final reject = expected == 'water' && !rejectedWaterPlural;
          final answer = reject ? 'waters' : expected;
          if (voice) {
            notifier.submitVoiceAnswer(answer);
          } else {
            notifier.submitTextAnswer(answer);
          }
          expect(
            sub.read().answerState,
            reject ? QuizAnswerState.incorrect : QuizAnswerState.correct,
          );
          if (reject) rejectedWaterPlural = true;
          if (!reject && expected == 'water') acceptedWater = true;
          if (expected == 'coffees') acceptedCoffees = true;
          notifier.advance();
        }
        expect(
          rejectedWaterPlural &&
              acceptedWater &&
              acceptedCoffees &&
              acceptedKimchi,
          isTrue,
        );
        final progress = await db.grammarProgressDao
            .watchByUser('u')
            .expand((rows) => rows)
            .firstWhere(
              (row) => row.ruleId == 'en-plural-s-es' && row.shown == 10,
            )
            .timeout(const Duration(seconds: 2));
        expect(progress.correct, 9);
      },
    );
  }

  test(
    'direct account replacement leaves a stale grammar drill ungraded',
    () async {
      AppUser user(String id) => AppUser(
        id: id,
        email: '$id@example.com',
        username: id,
        createdAt: DateTime(2026),
      );
      final accounts = StateProvider<AppUser?>((_) => user('u'));
      final session = makeContainer(account: accounts);
      final sub = session.listen(_quiz, (_, _) {});
      final quiz = session.read(_quiz.notifier);
      await quiz.loadCards(args());
      final oldAnswer = sub.read().currentCard!.answerWords.first;
      session.read(accounts.notifier).state = user('b');
      quiz.submitTextAnswer(oldAnswer);
      quiz.submitVoiceAnswer(oldAnswer, isDrivingMode: true);

      expect(sub.read().cards, isEmpty);
      expect(sub.read().errorMessage, 'quiz.account_changed'.tr());
      for (final id in ['u', 'b']) {
        expect(
          await db.grammarProgressDao.get(id, 'particule-theme-eun-neun'),
          isNull,
        );
        expect(await db.reviewEventDao.getByUser(id), isEmpty);
      }
    },
  );

  test('French negation accepts the full first-person answer', () async {
    const ruleId = 'fr-negation-ne-pas';
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(
      const QuizArgs(
        source: QuizSource.grammar,
        ruleId: ruleId,
        mode: QuizMode.typing,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: 2,
        langA: 'ko',
        langB: 'fr',
      ),
      promptLocale: 'fr',
    );
    final card = sub.read().currentCard!;
    expect(card.questionWord, contains('première personne du singulier'));
    expect(card.questionWord, contains('avec ou sans « je »'));
    expect(card.answerWords, ['ne travaille pas', 'je ne travaille pas']);

    notifier.submitTextAnswer('je travaille pas');
    expect(sub.read().answerState, QuizAnswerState.incorrect);
    notifier.advance();
    notifier.submitTextAnswer('je ne travaille pas');
    expect(sub.read().answerState, QuizAnswerState.correct);
    final progress = await db.grammarProgressDao
        .watchByUser('u')
        .expand((rows) => rows)
        .firstWhere((row) => row.ruleId == ruleId && row.shown == 2)
        .timeout(const Duration(seconds: 2));
    expect(progress.correct, 1);
  });

  for (final voice in [false, true]) {
    for (final answer in [
      "don't work",
      'do not work',
      "I don't work",
      'I do not work',
    ]) {
      test(
        'English negation accepts $answer by ${voice ? 'voice' : 'typing'}',
        () async {
          const ruleId = 'en-negation-dont';
          final sub = container.listen(_quiz, (_, _) {});
          final notifier = container.read(_quiz.notifier);
          await notifier.loadCards(
            QuizArgs(
              source: QuizSource.grammar,
              ruleId: ruleId,
              mode: voice ? QuizMode.voice : QuizMode.typing,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: 1,
              langA: 'fr',
              langB: 'en',
            ),
            promptLocale: 'fr',
          );
          expect(sub.read().currentCard!.answerWords, contains(answer));
          if (voice) {
            notifier.submitVoiceAnswer(answer);
          } else {
            notifier.submitTextAnswer(answer);
          }
          expect(sub.read().answerState, QuizAnswerState.correct);
          final progress = await db.grammarProgressDao
              .watchByUser('u')
              .expand((rows) => rows)
              .firstWhere((row) => row.ruleId == ruleId && row.shown == 1)
              .timeout(const Duration(seconds: 2));
          expect(progress.correct, 1);
          expect(await db.progressDao.getUnsyncedProgress(), isEmpty);
        },
      );
    }
  }

  test('a correct typed answer records rule progress — never FSRS', () async {
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(args());

    final card = sub.read().currentCard!;
    notifier.submitTextAnswer(card.answerWords.first);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final progress = await db.grammarProgressDao.get(
      'u',
      'particule-theme-eun-neun',
    );
    expect(progress!.shown, 1);
    expect(progress.correct, 1);
    expect(progress.masteredAt, isNull);
    // FSRS untouched:
    expect(await db.progressDao.getUnsyncedProgress(), isEmpty);
  });

  test(
    'quiz answers queue offline and the shell drains them once on reconnect',
    () async {
      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);
      final push = _CountingPushSync();
      final session = makeContainer(
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
          pushSyncProvider.overrideWithValue(push),
        ],
      );
      session.read(pushOnReconnectProvider);
      connectivity.add([ConnectivityResult.none]);
      await session.read(connectivityStreamProvider.future);

      final quiz = session.listen(_quiz, (_, _) {});
      final notifier = session.read(_quiz.notifier);
      await notifier.loadCards(args(cardLimit: 3));
      while (!quiz.read().isComplete) {
        notifier.submitTextAnswer(quiz.read().currentCard!.answerWords.first);
        notifier.advance();
      }
      expect(await db.reviewEventDao.getUnsynced(userId: 'u'), hasLength(3));
      const debounce = Duration(milliseconds: 350);
      await Future<void>.delayed(debounce);
      expect(push.drains, 0);

      connectivity.add([ConnectivityResult.wifi]);
      await push.firstDrain.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(debounce);
      expect(push.drains, 1);
    },
  );

  test('a wrong answer counts shown but not correct', () async {
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(args());
    expect(sub.read().cards, isNotEmpty);

    notifier.submitTextAnswer('완전히 틀린 답');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final progress = await db.grammarProgressDao.get(
      'u',
      'particule-theme-eun-neun',
    );
    expect(progress!.shown, 1);
    expect(progress.correct, 0);
  });

  for (final mode in [QuizMode.typing, QuizMode.voice]) {
    test('KO→FR ${mode.name} grading requires the elided article', () async {
      const articleRule = 'fr-articles-le-la';
      final sub = container.listen(_quiz, (_, _) {});
      final notifier = container.read(_quiz.notifier);
      await notifier.loadCards(
        QuizArgs(
          source: QuizSource.grammar,
          ruleId: articleRule,
          mode: mode,
          direction: QuizDirectionChoice.frToKo,
          cardLimit: 2,
          langA: 'ko',
          langB: 'fr',
        ),
      );
      expect(sub.read().currentCard!.answerWords, ["l'eau"]);

      void submit(String answer) {
        if (mode == QuizMode.voice) {
          notifier.submitVoiceAnswer(answer, isDrivingMode: true);
        } else {
          notifier.submitTextAnswer(answer);
        }
      }

      Future<GrammarProgressTableData> afterAnswers(int shown) => db
          .grammarProgressDao
          .watchByUser('u')
          .expand((rows) => rows)
          .firstWhere((row) => row.ruleId == articleRule && row.shown == shown)
          .timeout(const Duration(seconds: 2));

      submit('eau');
      expect(sub.read().answerState, QuizAnswerState.incorrect);
      expect((await afterAnswers(1)).correct, 0);
      notifier.advance();
      submit(mode == QuizMode.voice ? 'L’eau.' : 'l’eau');
      expect(sub.read().answerState, QuizAnswerState.correct);
      expect((await afterAnswers(2)).correct, 1);
    });
  }

  test(
    'a voice answer grades, stops listening, and records grammar progress',
    () async {
      final sub = container.listen(_quiz, (_, _) {});
      final notifier = container.read(_quiz.notifier);
      await notifier.loadCards(args());
      final card = sub.read().currentCard!;

      notifier.setListening(true);
      notifier.submitVoiceAnswer(card.answerWords.first);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sub.read().answerState, QuizAnswerState.correct);
      expect(sub.read().isListening, isFalse);
      expect(sub.read().userAnswer, card.answerWords.first);
      expect(
        (await db.grammarProgressDao.get(
          'u',
          'particule-theme-eun-neun',
        ))!.correct,
        1,
      );
    },
  );

  test(
    'a hands-free correct answer advances only after its audio window',
    () async {
      final sub = container.listen(_quiz, (_, _) {});
      final notifier = container.read(_quiz.notifier);
      await notifier.loadCards(args(cardLimit: 2));
      final answer = sub.read().currentCard!.answerWords.first;

      notifier.submitVoiceAnswer(answer, isDrivingMode: true);
      expect(sub.read().currentIndex, 0);

      await Future<void>.delayed(const Duration(milliseconds: 950));
      expect(sub.read().currentIndex, 1);
      expect(sub.read().answerState, QuizAnswerState.idle);
    },
  );

  test('cartes NEVER records grammar progress (practice only)', () async {
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(args(mode: QuizMode.flashcard));
    expect(sub.read().cards, isNotEmpty);

    notifier.flipCard();
    notifier.gradeFlashcard(FsrsRating.good);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      await db.grammarProgressDao.get('u', 'particule-theme-eun-neun'),
      isNull,
    );
  });

  test(
    'backgrounding feedback holds the graded card until one foreground advance',
    () async {
      final sub = container.listen(_quiz, (_, _) {});
      final notifier = container.read(_quiz.notifier);
      await notifier.loadCards(args(cardLimit: 3));
      notifier.submitVoiceAnswer(
        sub.read().currentCard!.answerWords.first,
        isDrivingMode: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      notifier.setForeground(false);
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(sub.read().currentIndex, 0);
      expect(sub.read().answerState, QuizAnswerState.correct);
      notifier.setForeground(true);
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(sub.read().currentIndex, 1);
      expect(
        (await db.grammarProgressDao.get(
          'u',
          'particule-theme-eun-neun',
        ))!.shown,
        1,
      );
    },
  );

  test('skipCurrentCard grades NOTHING and requeues the card once — silence '
      'is never a wrong answer', () async {
    final sub = container.listen(_quiz, (_, _) {});
    final notifier = container.read(_quiz.notifier);
    await notifier.loadCards(args());
    final initialTotal = sub.read().total;
    final skipped = sub.read().currentCard!;

    notifier.skipCurrentCard();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // No grammar progress, no FSRS write — the user never answered.
    expect(
      await db.grammarProgressDao.get('u', 'particule-theme-eun-neun'),
      isNull,
    );
    expect(await db.progressDao.getUnsyncedProgress(), isEmpty);
    // The card went to the back of the queue (internal total grew by one
    // slot so it replays) — but the USER-FACING displayTotal must not grow
    // ("I chose 10 words but ended up with 12", field report 2026-07-09).
    expect(sub.read().total, initialTotal + 1);
    expect(sub.read().displayTotal, initialTotal);
    expect(
      sub.read().cards.last.progress.variantId,
      skipped.progress.variantId,
    );
    expect(sub.read().cards.last.isRequeue, isTrue);
    expect(sub.read().currentIndex, 1);

    // A second skip of the SAME card does not requeue again (no infinite
    // session in a persistently silent room).
    while (sub.read().currentCard?.progress.variantId !=
        skipped.progress.variantId) {
      notifier.skipCurrentCard();
    }
    final totalBefore = sub.read().total;
    notifier.skipCurrentCard();
    expect(sub.read().total, totalBefore);
  });

  test('the mastery target sets masteredAt exactly once', () async {
    for (var i = 0; i < kRuleMasteryTarget; i++) {
      await db.grammarProgressDao.recordAnswer(
        userId: 'u',
        ruleId: 'r',
        correct: true,
        masteredWhenCorrectReaches: kRuleMasteryTarget,
      );
    }
    final atTarget = await db.grammarProgressDao.get('u', 'r');
    expect(atTarget!.masteredAt, isNotNull);

    final firstMasteredAt = atTarget.masteredAt;
    await db.grammarProgressDao.recordAnswer(
      userId: 'u',
      ruleId: 'r',
      correct: true,
      masteredWhenCorrectReaches: kRuleMasteryTarget,
    );
    expect(
      (await db.grammarProgressDao.get('u', 'r'))!.masteredAt,
      firstMasteredAt,
    );
  });

  test(
    'concurrent correct and wrong answers both count and unlock mastery',
    () async {
      final dao = db.grammarProgressDao;
      Future<GrammarProgressTableData> answer(bool correct) => dao.recordAnswer(
        userId: 'u',
        ruleId: 'concurrent-rule',
        correct: correct,
        masteredWhenCorrectReaches: kRuleMasteryTarget,
      );

      final first = await Future.wait([answer(false), answer(true)]);
      expect(first.map((row) => row.shown), unorderedEquals([1, 2]));
      final firstRow = (await dao.get('u', 'concurrent-rule'))!;
      expect(firstRow.shown, 2);
      expect(firstRow.correct, 1);

      for (
        var correctCount = 1;
        correctCount < kRuleMasteryTarget - 1;
        correctCount++
      ) {
        await answer(true);
      }
      final before = (await dao.get('u', 'concurrent-rule'))!;
      expect(before.masteredAt, isNull);
      final next = await Future.wait([answer(false), answer(true)]);
      expect(
        next.map((row) => row.shown),
        unorderedEquals([before.shown + 1, before.shown + 2]),
      );
      final after = (await dao.get('u', 'concurrent-rule'))!;
      expect(after.correct, kRuleMasteryTarget);
      expect(after.shown, before.shown + 2);
      expect(after.masteredAt, isNotNull);
    },
  );
}
