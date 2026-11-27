// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<void> speak(String text, String langCode, {String? audioPath}) async {}
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
  Future<Result<void>> updateStreak() async => const Success(null);
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
  setUpAll(initTestLocalization);

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
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        ruleDrillWordsProvider.overrideWith(
          (ref, key) async => switch (key) {
            (ruleId: 'fr-articles-le-la', targetLang: 'fr') => const [
              DrillWord(word: 'eau', category: 'nom', tags: ['f']),
            ],
            (ruleId: 'fr-negation-ne-pas', targetLang: 'fr') => const [
              DrillWord(word: 'travailler', category: 'verbe'),
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

  test(
    'loadCards generates localized drill cards from mastered words',
    () async {
      final sub = container.listen(quizProvider, (_, _) {});
      await container.read(quizProvider.notifier).loadCards(args());

      final state = sub.read();
      expect(state.cards, hasLength(3));
      for (final card in state.cards) {
        expect(card.questionWord, contains('particule')); // localized FR prompt
        expect(card.answerWords.first, anyOf(endsWith('은'), endsWith('는')));
      }
    },
  );

  test('direct voice entry cannot grade an isolated French plural', () async {
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
    for (final mode in [QuizMode.voice, QuizMode.handsFree]) {
      await notifier.loadCards(
        QuizArgs(
          source: QuizSource.grammar,
          ruleId: 'fr-plural-s',
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
    expect(await db.grammarProgressDao.get('u', 'fr-plural-s'), isNull);
  });

  test('the French plural drill requires the written s', () async {
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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
      final sub = session.listen(quizProvider, (_, _) {});
      final quiz = session.read(quizProvider.notifier);
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
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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

  test('a correct typed answer records rule progress — never FSRS', () async {
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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

      final quiz = session.listen(quizProvider, (_, _) {});
      final notifier = session.read(quizProvider.notifier);
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
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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
      final sub = container.listen(quizProvider, (_, _) {});
      final notifier = container.read(quizProvider.notifier);
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
      final sub = container.listen(quizProvider, (_, _) {});
      final notifier = container.read(quizProvider.notifier);
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
      final sub = container.listen(quizProvider, (_, _) {});
      final notifier = container.read(quizProvider.notifier);
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
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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
      final sub = container.listen(quizProvider, (_, _) {});
      final notifier = container.read(quizProvider.notifier);
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
    final sub = container.listen(quizProvider, (_, _) {});
    final notifier = container.read(quizProvider.notifier);
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
