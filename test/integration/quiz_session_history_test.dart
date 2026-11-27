// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/models/concept_dto.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/data/models/vocabulary_list_dto.dart';
import 'package:vocab_kr/data/models/word_variant_dto.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_history_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../helpers/fake_remote.dart';

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
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.due);
  final List<VariantProgress> due;
  final masteryRequested = Completer<void>();
  final mastered = Completer<Result<List<VariantProgress>>>();

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async => Success(due.take(limit).toList());

  @override
  Future<Result<VariantProgress>> updateProgress(
    VariantProgress progress,
  ) async => Success(progress);

  @override
  Future<Result<VariantProgress>> mutateProgress({
    required String variantId,
    required QuizDirection direction,
    required VariantProgress Function(VariantProgress) mutate,
  }) async => Success(
    mutate(
      due.firstWhere(
        (row) => row.variantId == variantId && row.direction == direction,
      ),
    ),
  );

  @override
  Future<Result<List<VariantProgress>>> getMasteredVariants(String userId) {
    masteryRequested.complete();
    return mastered.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _StarterRestoreRemote extends FakeRemote {
  late Map<String, dynamic> list;
  late Map<String, dynamic> concept;
  late Map<String, dynamic> progress;

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      Success([list]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId,
  ) async => Success([concept]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId,
  ) async => Success([progress]);
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
    final session = container.listen(quizProvider, (_, _) {});
    final quiz = container.read(quizProvider.notifier);
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

  test(
    'a skipped then correct card records 100% even if a new session loads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Seed a list with one word; the due card points at its FR variant.
      final vocabRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
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
      final due = VariantProgress(
        id: 'p1',
        userId: 'u',
        variantId: variants.firstWhere((v) => v.langCode == 'fr').id,
        direction: QuizDirection.frToKo,
        createdAt: _now,
        updatedAt: _now,
      );

      final user = AppUser(
        id: 'u',
        email: 't@t.fr',
        username: 'thomas',
        subscriptionType: SubscriptionType.free,
        createdAt: _now,
      );

      final progressRepo = _FakeProgressRepo([due]);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
          getDueCardsUseCaseProvider.overrideWithValue(
            GetDueCardsUseCase(progressRepo),
          ),
          progressRepositoryProvider.overrideWithValue(progressRepo),
          audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
          currentUserProvider.overrideWithValue(user),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
          authStateProvider.overrideWith(_FakeAuthNotifier.new),
          notificationServiceProvider.overrideWithValue(_FakeNotifService()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(quizProvider, (_, _) {});

      // Play the whole (1-card) session.
      final notifier = container.read(quizProvider.notifier);
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

      // Start again while the completed session's history query is in flight.
      await progressRepo.masteryRequested.future;
      await notifier.loadCards(args);
      expect(sub.read().correctCount, 0);
      progressRepo.mastered.complete(Success([due]));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The row exists with the right facts…
      final rows = await db.quizSessionDao.getSessionsByUser('u');
      expect(rows.length, 1);
      expect(rows.single.listName, 'Animaux');
      expect(rows.single.mode, 'flashcard');
      expect(rows.single.cardCount, 1);
      expect(rows.single.correctCount, 1);
      expect(rows.single.masteredWordCount, 1);

      // …and quizHistoryProvider maps it back for the stats screen.
      final history = await container.read(quizHistoryProvider.future);
      expect(history.single.listName, 'Animaux');
      expect(history.single.accuracy, 1.0);
    },
  );
}
