// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryInterceptor, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/core/utils/streak.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/local/daos/progress_dao.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart'
    show VocabularyNetworkBudget;
import 'package:vocab_kr/data/models/concept_dto.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/data/models/vocabulary_list_dto.dart';
import 'package:vocab_kr/data/models/word_variant_dto.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_history_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../helpers/fake_remote.dart';

final _quiz = quizProvider(Object());

/// The studying → stats bridge: completing a session records a quiz_sessions
/// row (name, score, mode), and quizHistoryProvider maps it back for the
/// stats screen. This was the top gap in docs/feature-coverage.md — nothing
/// verified that a finished quiz actually produces history.

final _now = DateTime(2026, 7, 3);

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
    bool Function()? keepGoing,
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

class _PausedMasteryDao extends ProgressDao {
  _PausedMasteryDao(super.db);
  final masteryRequested = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<VariantProgressTableData>> getMasteredProgress({
    required String userId,
    int minScheduledDays = 21,
  }) async {
    masteryRequested.complete();
    await release.future;
    return super.getMasteredProgress(
      userId: userId,
      minScheduledDays: minScheduledDays,
    );
  }
}

class _WriteRollback extends QueryInterceptor {
  final done = Completer<void>();

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    await super.rollbackTransaction(inner);
    if (!done.isCompleted) done.complete();
  }
}

class _FakeAuthRepo implements AuthRepository {
  final streakRequested = Completer<(String, DateTime)>();
  final attempts = <(String, DateTime)>[];
  bool online = false;

  @override
  AppUser? currentUser;

  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async {
    attempts.add((userId, studyDate));
    if (!streakRequested.isCompleted) {
      streakRequested.complete((userId, studyDate));
    }
    return online ? const Success(null) : const Failure(NetworkException());
  }

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
  final scheduledStreaks = <int>[];
  int cancelledStreaks = 0;

  @override
  Future<void> cancelStreakWarning() async {
    cancelledStreaks++;
  }

  @override
  Future<void> scheduleStreakWarning(int streakDays, {Locale? locale}) async {
    scheduledStreaks.add(streakDays);
  }

  @override
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
    Locale? locale,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StarterRestoreRemote extends FakeRemote {
  late Map<String, dynamic> list;
  late Map<String, dynamic> concept;
  late Map<String, dynamic> progress;

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(
    String ownerId, {
    VocabularyNetworkBudget? budget,
  }) async => Success([list]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
    VocabularyNetworkBudget? budget,
  }) async => Success([concept]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId, {
    VocabularyNetworkBudget? budget,
  }) async => Success([progress]);
}

void main() {
  test('a quiz loaded before starter adoption records its grade and summary '
      'against the server identities', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final remote = _StarterRestoreRemote();
    final repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      'u',
      db,
    );
    final draft = (await repo.importFromJson({
      'list': {
        'name': 'Starter offline',
        'seed_id': 'starter-greetings:fr>ko',
        'concepts': [
          {
            'seed_id': 'greeting-bonjour',
            'variants': [
              {'word': 'bonjour', 'lang_code': 'fr'},
              {'word': '안녕하세요', 'lang_code': 'ko'},
            ],
          },
        ],
      },
    }, origin: 'starter')).valueOrNull!;
    expect(await db.vocabularyListDao.isStarterDraftHeld(draft.id), isTrue);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(remote),
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        currentUserProvider.overrideWithValue(
          AppUser(
            id: 'u',
            email: 'u@example.com',
            username: 'u',
            createdAt: _now,
          ),
        ),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notificationServiceProvider.overrideWithValue(_FakeNotifService()),
      ],
    );
    addTearDown(container.dispose);
    final session = container.listen(_quiz, (_, _) {});
    final quiz = container.read(_quiz.notifier);
    await quiz.loadCards(
      QuizArgs(
        listId: draft.id,
        mode: QuizMode.flashcard,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: 1,
      ),
    );
    final heldCard = session.read().currentCard!;
    final concept = (await db.conceptDao.getConceptsByList(draft.id)).single;
    final variants = await db.conceptDao.getVariantsByConcept(concept.id);
    final fr = variants.singleWhere((variant) => variant.langCode == 'fr');
    final ko = variants.singleWhere((variant) => variant.langCode == 'ko');
    expect(heldCard.progress.variantId, fr.id);

    const serverList = 'server-list';
    const serverConcept = 'server-concept';
    const serverFr = 'server-fr';
    remote.list = {
      ...draft.toRemoteMap(),
      'id': serverList,
      'name': 'Server list name',
    };
    remote.concept = {
      ...concept.toRemoteMap(),
      'id': serverConcept,
      'list_id': serverList,
      'word_variants': [
        {...fr.toRemoteMap(), 'id': serverFr, 'concept_id': serverConcept},
        {...ko.toRemoteMap(), 'id': 'server-ko', 'concept_id': serverConcept},
      ],
    };
    remote.progress = VariantProgress(
      id: 'server-progress',
      userId: 'u',
      variantId: serverFr,
      direction: QuizDirection.frToKo,
      timesShown: 3,
      timesCorrect: 2,
      createdAt: _now,
      updatedAt: _now,
    ).toRemoteMap();
    await repo.syncFromRemote();
    expect(await db.conceptDao.getVariantById(fr.id), isNull);
    expect(session.read().currentCard, same(heldCard));

    quiz.flipCard();
    quiz.gradeFlashcard(FsrsRating.good);
    quiz.advance();
    expect(session.read().isComplete, isTrue);
    expect(session.read().accuracy, 1);

    final progress = await db
        .select(db.variantProgressTable)
        .watch()
        .expand((rows) => rows)
        .firstWhere((row) => row.id == 'server-progress' && row.timesShown == 4)
        .timeout(const Duration(seconds: 2));
    expect(progress.variantId, serverFr);
    expect(progress.timesCorrect, 3);
    expect(
      (await db.select(db.variantProgressTable).get()).map(
        (row) => row.variantId,
      ),
      [serverFr],
    );
    final event = (await db.reviewEventDao.getByUser('u')).single;
    expect(event.variantId, serverFr);
    expect(event.listId, serverList);
    final history = await db
        .select(db.quizSessionsTable)
        .watch()
        .expand((rows) => rows)
        .first
        .timeout(const Duration(seconds: 2));
    expect(history.listId, serverList);
    expect(history.listName, 'Server list name');
    expect(history.cardCount, 1);
    expect(history.correctCount, 1);
  });

  for (final leaveQuiz in [false, true]) {
    test(
      'completed quiz survives ${leaveQuiz ? 'leaving' : 'replacing the quiz'} and replays on ${leaveQuiz ? 'reconnect' : 'startup'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        final dir = await Directory.systemTemp.createTemp('ponderin-history-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/quiz.sqlite');
        var db = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(() => db.close());

        // A fresh FR→KO card and a mastered KO→FR card share the same concept.
        final remote = FakeRemote();
        final vocabRepo = VocabularyRepositoryImpl(
          db.vocabularyListDao,
          db.conceptDao,
          remote,
          'u',
          db,
        );
        final list = (await vocabRepo.createList(name: 'Animaux')).valueOrNull!;
        final concept = (await vocabRepo.addConceptWithVariants(
          listId: list.id,
          wordA: 'chat',
          wordB: '고양이',
        )).valueOrNull!;
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        await db
            .into(db.variantProgressTable)
            .insert(
              VariantProgress(
                id: 'mastered-ko',
                userId: 'u',
                variantId: variants.singleWhere((v) => v.langCode == 'ko').id,
                direction: QuizDirection.koToFr,
                state: CardState.review,
                scheduledDays: 30,
                createdAt: _now,
                updatedAt: _now,
              ).toLocalCompanion(),
            );

        final user = AppUser(
          id: 'u',
          email: 't@t.fr',
          username: 'thomas',
          subscriptionType: SubscriptionType.free,
          currentStreak: 6,
          lastStudyDate: civilDate(
            DateTime.now(),
          ).subtract(const Duration(days: 1)),
          createdAt: _now,
        );

        final progressDao = _PausedMasteryDao(db);
        final auth = _FakeAuthRepo()..currentUser = user;
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vocabularyRemoteProvider.overrideWithValue(remote),
            progressDaoProvider.overrideWithValue(progressDao),
            audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
            currentUserProvider.overrideWithValue(user),
            authRepositoryProvider.overrideWithValue(auth),
            authStateProvider.overrideWith(_FakeAuthNotifier.new),
            notificationServiceProvider.overrideWithValue(_FakeNotifService()),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(_quiz, (_, _) {});

        // Play the whole (1-card) session.
        final notifier = container.read(_quiz.notifier);
        final args = QuizArgs(
          listId: list.id,
          mode: QuizMode.flashcard,
          direction: QuizDirectionChoice.frToKo,
          cardLimit: 1,
        );
        await notifier.loadCards(args);
        expect(sub.read().cards.length, 1);
        notifier.skipCurrentCard();
        notifier.flipCard();
        notifier.gradeFlashcard(FsrsRating.good);
        notifier.advance();
        expect(sub.read().isComplete, isTrue);
        expect(sub.read().accuracy, 1.0);

        // Keep the real SQLite history lookup suspended during navigation.
        await progressDao.masteryRequested.future.timeout(
          const Duration(seconds: 2),
        );
        if (leaveQuiz) {
          sub.close();
          await container.pump();
          expect(container.exists(_quiz), isFalse);
        } else {
          await notifier.loadCards(
            QuizArgs(
              listId: list.id,
              mode: QuizMode.typing,
              direction: QuizDirectionChoice.frToKo,
              cardLimit: 1,
            ),
          );
          expect(sub.read().correctCount, 0);
        }
        progressDao.release.complete();
        final (account, studyDay) = await auth.streakRequested.future.timeout(
          const Duration(seconds: 2),
        );
        expect(account, user.id);
        final dateKey = studyDay.toIso8601String().split('T').first;
        expect(await db.quizSessionDao.pendingStudyDays(user.id), [dateKey]);
        await db.close();

        db = AppDatabase.forTesting(NativeDatabase(file));
        final reminders = _FakeNotifService();
        final network = StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(network.close);
        final reopened = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserProvider.overrideWithValue(user),
            notificationServiceProvider.overrideWithValue(reminders),
            authRepositoryProvider.overrideWithValue(auth),
            authStateProvider.overrideWith(_FakeAuthNotifier.new),
            vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
            connectivityStreamProvider.overrideWith((_) => network.stream),
          ],
        );
        addTearDown(reopened.dispose);
        expect(reopened.read(localStudyDayProvider(user.id)), isNull);
        expect(await db.quizSessionDao.getSessionsByUser('other'), isEmpty);
        final history = await reopened.read(quizHistoryProvider.future);
        expect(history.single.listName, 'Animaux');
        expect(history.single.listId, list.id);
        expect(history.single.mode, QuizMode.flashcard);
        expect(history.single.cardCount, 1);
        expect(history.single.masteredWordCount, 1);
        expect(history.single.accuracy, 1.0);
        expect(civilDate(history.single.completedAt.toLocal()), studyDay);

        // With a stale profile and no in-memory study date, use SQLite.
        await reopened.read(
          authenticatedRemindersProvider(const Locale('fr')).future,
        );
        expect(reminders.cancelledStreaks, 1);
        expect(reminders.scheduledStreaks, isEmpty);

        final acknowledged = db
            .select(db.quizStudyDaysTable)
            .watch()
            .firstWhere((rows) => rows.any((row) => row.isSynced));
        if (!leaveQuiz) {
          // The connectivity provider may already have a value when login
          // mounts the signed-in shell.
          final initialNetwork = reopened.read(
            connectivityStreamProvider.future,
          );
          network.add([ConnectivityResult.wifi]);
          await initialNetwork;
          auth.online = true;
        }
        reopened.read(pushOnReconnectProvider);
        if (leaveQuiz) {
          network.add([ConnectivityResult.none]);
          await reopened.read(connectivityStreamProvider.future);
          expect(auth.attempts, [(user.id, studyDay)]);
          auth.online = true;
          network.add([ConnectivityResult.wifi]);
        }
        final rows = await acknowledged.timeout(const Duration(seconds: 5));
        expect(rows.single.studyDate, dateKey);
        expect(auth.attempts, [(user.id, studyDay), (user.id, studyDay)]);
        expect(await db.quizSessionDao.pendingStudyDays(user.id), isEmpty);
      },
    );
  }

  test(
    'failed history transaction never reports a completed study day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final rollback = _WriteRollback();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(rollback),
      );
      addTearDown(db.close);
      await db.customStatement('''
      CREATE TRIGGER deny_study_day BEFORE INSERT ON quiz_study_days
      BEGIN SELECT RAISE(ABORT, 'injected local storage error'); END
    ''');
      final remote = FakeRemote();
      final repository = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        remote,
        'u',
        db,
      );
      final list = (await repository.createList(name: 'Animaux')).valueOrNull!;
      await repository.addConceptWithVariants(
        listId: list.id,
        wordA: 'chat',
        wordB: '고양이',
      );
      final user = AppUser(
        id: 'u',
        email: 'u@example.com',
        username: 'learner',
        createdAt: _now,
      );
      final reminders = _FakeNotifService();
      final auth = _FakeAuthRepo()..currentUser = user;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vocabularyRemoteProvider.overrideWithValue(remote),
          currentUserProvider.overrideWithValue(user),
          audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
          authRepositoryProvider.overrideWithValue(auth),
          authStateProvider.overrideWith(_FakeAuthNotifier.new),
          notificationServiceProvider.overrideWithValue(reminders),
        ],
      );
      addTearDown(container.dispose);

      final session = container.listen(_quiz, (_, _) {});
      final quiz = container.read(_quiz.notifier);
      await quiz.loadCards(
        QuizArgs(
          listId: list.id,
          mode: QuizMode.flashcard,
          direction: QuizDirectionChoice.frToKo,
          cardLimit: 1,
        ),
      );
      quiz.flipCard();
      quiz.gradeFlashcard(FsrsRating.good);
      quiz.advance();
      expect(session.read().isComplete, isTrue);
      expect(session.read().accuracy, 1);
      await rollback.done.future.timeout(const Duration(seconds: 2));

      expect(await db.quizSessionDao.getSessionsByUser(user.id), isEmpty);
      expect(await db.quizSessionDao.pendingStudyDays(user.id), isEmpty);
      expect(container.read(localStudyDayProvider(user.id)), isNull);
      expect(reminders.cancelledStreaks, 0);
      expect(auth.attempts, isEmpty);
    },
  );
}
