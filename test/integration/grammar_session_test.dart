// ignore_for_file: invalid_use_of_internal_member
import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/composition_exercise.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/rule_mastery.dart';
import 'package:vocab_kr/data/datasources/remote/grammar_exercise_remote_datasource.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
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

/// Canned AI batch (or failure) — stands in for the Supabase edge function.
class _FakeExerciseRemote implements GrammarExerciseRemoteDataSource {
  _FakeExerciseRemote({this.exercises, this.fail = false});
  final List<CompositionExercise>? exercises;
  final bool fail;
  int calls = 0;

  @override
  Future<Result<List<CompositionExercise>>> generate({
    required Map<String, dynamic> targetRule,
    required List<Map<String, dynamic>> masteredRules,
    required List<DrillWord> words,
    required String promptLanguage,
    required String targetLanguage,
    required int count,
  }) async {
    calls++;
    if (fail) return const Failure(NetworkException('offline'));
    return Success(exercises ?? const []);
  }
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

  ProviderContainer makeContainer(GrammarExerciseRemoteDataSource remote) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
      grammarExerciseRemoteProvider.overrideWithValue(remote),
      drillWordsProvider.overrideWith((ref, lang) async => words),
      currentUserProvider.overrideWithValue(AppUser(
        id: 'u',
        email: 't@t.fr',
        username: 't',
        subscriptionType: SubscriptionType.free,
        createdAt: DateTime(2026),
      )),
      audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      notificationServiceProvider.overrideWithValue(_FakeNotifService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Default: the AI generator is unavailable → the word-level drill
    // generator serves the session (the guaranteed-offline baseline).
    container = makeContainer(_FakeExerciseRemote(fail: true));
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
      'AI composition: a validated remote batch becomes full-sentence cards',
      () async {
    final remote = _FakeExerciseRemote(exercises: const [
      CompositionExercise(
        prompt: "L'étudiant boit de l'eau",
        expected: '학생은 물 마셔요',
        accepted: ['학생은 물 마셔요', '물 마셔요'],
      ),
      CompositionExercise(
        prompt: 'La baleine nage', // hallucinated vocab — must be dropped
        expected: '고래는 헤엄쳐요',
        accepted: ['고래는 헤엄쳐요'],
      ),
    ]);
    final c = makeContainer(remote);
    final sub = c.listen(quizProvider, (_, __) {});

    await c.read(quizProvider.notifier).loadCards(args());

    final state = sub.read();
    expect(remote.calls, 1);
    expect(state.cards, hasLength(1)); // hallucinated item validated away
    expect(state.cards.single.questionWord, "L'étudiant boit de l'eau");
    expect(state.cards.single.answerWords, ['학생은 물 마셔요', '물 마셔요']);
  });

  test('remote failure falls back to word-level drills (and caches nothing)',
      () async {
    final sub = container.listen(quizProvider, (_, __) {});
    await container.read(quizProvider.notifier).loadCards(args());

    final state = sub.read();
    expect(state.cards, hasLength(3));
    // Drill prompts are localized i18n sentences, not AI sentences.
    expect(state.cards.first.questionWord, contains('particule'));
  });

  test('loadCards generates localized drill cards from mastered words',
      () async {
    final sub = container.listen(quizProvider, (_, __) {});
    await container.read(quizProvider.notifier).loadCards(args());

    final state = sub.read();
    expect(state.cards, hasLength(3));
    for (final card in state.cards) {
      expect(card.questionWord, contains('particule')); // localized FR prompt
      expect(card.answerWords.first, anyOf(endsWith('은'), endsWith('는')));
    }
  });

  test('a correct typed answer records rule progress — never FSRS', () async {
    final sub = container.listen(quizProvider, (_, __) {});
    final notifier = container.read(quizProvider.notifier);
    await notifier.loadCards(args());

    final card = sub.read().currentCard!;
    notifier.submitTextAnswer(card.answerWords.first);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final progress =
        await db.grammarProgressDao.get('u', 'particule-theme-eun-neun');
    expect(progress!.shown, 1);
    expect(progress.correct, 1);
    expect(progress.masteredAt, isNull);
    // FSRS untouched:
    expect(await db.progressDao.getUnsyncedProgress(), isEmpty);
  });

  test('a wrong answer counts shown but not correct', () async {
    final sub = container.listen(quizProvider, (_, __) {});
    final notifier = container.read(quizProvider.notifier);
    await notifier.loadCards(args());
    expect(sub.read().cards, isNotEmpty);

    notifier.submitTextAnswer('완전히 틀린 답');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final progress =
        await db.grammarProgressDao.get('u', 'particule-theme-eun-neun');
    expect(progress!.shown, 1);
    expect(progress.correct, 0);
  });

  test('cartes NEVER records grammar progress (practice only)', () async {
    final sub = container.listen(quizProvider, (_, __) {});
    final notifier = container.read(quizProvider.notifier);
    await notifier.loadCards(args(mode: QuizMode.flashcard));
    expect(sub.read().cards, isNotEmpty);

    notifier.gradeFlashcard(FsrsRating.good);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await db.grammarProgressDao.get('u', 'particule-theme-eun-neun'),
        isNull);
  });

  test(
      'skipCurrentCard grades NOTHING and requeues the card once — silence '
      'is never a wrong answer', () async {
    final sub = container.listen(quizProvider, (_, __) {});
    final notifier = container.read(quizProvider.notifier);
    await notifier.loadCards(args());
    final initialTotal = sub.read().total;
    final skipped = sub.read().currentCard!;

    notifier.skipCurrentCard();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // No grammar progress, no FSRS write — the user never answered.
    expect(await db.grammarProgressDao.get('u', 'particule-theme-eun-neun'),
        isNull);
    expect(await db.progressDao.getUnsyncedProgress(), isEmpty);
    // The card went to the back of the queue (internal total grew by one
    // slot so it replays) — but the USER-FACING displayTotal must not grow
    // ("I chose 10 words but ended up with 12", field report 2026-07-09).
    expect(sub.read().total, initialTotal + 1);
    expect(sub.read().displayTotal, initialTotal);
    expect(sub.read().cards.last.progress.variantId,
        skipped.progress.variantId);
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
    expect((await db.grammarProgressDao.get('u', 'r'))!.masteredAt,
        firstMasteredAt);
  });
}
