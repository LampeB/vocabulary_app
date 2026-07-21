// ignore_for_file: invalid_use_of_internal_member
import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
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
  Future<void> prefetch(String text, String langCode) async {}
  @override
  Future<void> speak(String text, String langCode) async {}
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

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async =>
      Success(due.take(limit).toList());

  @override
  Future<Result<VariantProgress>> updateProgress(
          VariantProgress progress) async =>
      Success(progress);

  @override
  Future<Result<List<VariantProgress>>> getMasteredVariants(
          String userId) async =>
      Success(due); // pretend everything due is mastered → count = due.length

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

void main() {
  test(
      'completing a flashcard session records history and the provider maps it',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a list with one word; the due card points at its FR variant.
    final vocabRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
    final list = (await vocabRepo.createList(name: 'Animaux')).valueOrNull!;
    final concept = (await vocabRepo.addConceptWithVariants(
            listId: list.id, wordA: 'chat', wordB: '고양이'))
        .valueOrNull!;
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

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
      getDueCardsUseCaseProvider
          .overrideWithValue(GetDueCardsUseCase(_FakeProgressRepo([due]))),
      progressRepositoryProvider.overrideWithValue(_FakeProgressRepo([due])),
      audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
      currentUserProvider.overrideWithValue(user),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      notificationServiceProvider.overrideWithValue(_FakeNotifService()),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(quizProvider, (_, __) {});

    // Play the whole (1-card) session.
    final notifier = container.read(quizProvider.notifier);
    await notifier.loadCards(QuizArgs(
      listId: list.id,
      mode: QuizMode.flashcard,
      direction: QuizDirectionChoice.frToKo,
      cardLimit: 1,
    ));
    expect(sub.read().cards.length, 1);
    notifier.gradeFlashcard(FsrsRating.good);
    notifier.advance();
    expect(sub.read().isComplete, isTrue);

    // _onSessionComplete → _recordSession is fire-and-forget; let it land.
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
  });
}
