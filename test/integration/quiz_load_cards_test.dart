// ignore_for_file: invalid_use_of_internal_member
import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import '../helpers/fake_remote.dart';

/// QuizNotifier.loadCards, end to end at the provider level: due-card fetching
/// (single + both directions, failure policy), enrichment against a real
/// in-memory drift DB, the drop rule for unresolvable variants, and padding.
/// Harness follows paywall_gate_test.dart (ProviderContainer + overrides).

final _now = DateTime(2026, 7, 3);

class _NoopAudio implements AudioPlayerService {
  @override
  Future<void> warmUp(String langCode) async {}
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

/// Serves canned due-card lists (or failures) per direction, honoring `limit`
/// the way the real repository would.
class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.responses);
  final Map<QuizDirection, Result<List<VariantProgress>>> responses;

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async {
    final r = responses[direction] ?? const Success([]);
    if (r.isFailure) return r;
    return Success(r.valueOrNull!.take(limit).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VariantProgress _due(String variantId, QuizDirection direction) =>
    VariantProgress(
      id: 'p-$variantId',
      userId: 'u',
      variantId: variantId,
      direction: direction,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  late AppDatabase db;
  // fr word → variant ids, seeded in setUp.
  late Map<String, String> frVariantId;
  late Map<String, String> koVariantId;

  const words = [('chat', '고양이'), ('chien', '개'), ('maison', '집')];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
    final list = (await repo.createList(name: 'Quiz List')).valueOrNull!;
    frVariantId = {};
    koVariantId = {};
    for (final (fr, ko) in words) {
      final concept = (await repo.addConceptWithVariants(
              listId: list.id, wordA: fr, wordB: ko))
          .valueOrNull!;
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      frVariantId[fr] = variants.firstWhere((v) => v.langCode == 'fr').id;
      koVariantId[ko] = variants.firstWhere((v) => v.langCode == 'ko').id;
    }
  });
  tearDown(() => db.close());

  /// Container wired for loadCards; keeps the autoDispose notifier alive.
  (ProviderContainer, ProviderSubscription<QuizState>) harness(
      Map<QuizDirection, Result<List<VariantProgress>>> responses) {
    final container = ProviderContainer(overrides: [
      getDueCardsUseCaseProvider
          .overrideWithValue(GetDueCardsUseCase(_FakeProgressRepo(responses))),
      conceptDaoProvider.overrideWithValue(db.conceptDao),
      currentUserProvider.overrideWithValue(null),
      audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(quizProvider, (_, __) {});
    return (container, sub);
  }

  QuizArgs args({
    QuizDirectionChoice direction = QuizDirectionChoice.frToKo,
    int cardLimit = 3,
  }) =>
      QuizArgs(
        listId: 'ignored-by-fake',
        mode: QuizMode.flashcard,
        direction: direction,
        cardLimit: cardLimit,
      );

  test('single direction: cards are enriched with question + answer words',
      () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: Success([
        _due(frVariantId['chat']!, QuizDirection.frToKo),
        _due(frVariantId['chien']!, QuizDirection.frToKo),
        _due(frVariantId['maison']!, QuizDirection.frToKo),
      ]),
    });

    await container.read(quizProvider.notifier).loadCards(args());

    final state = sub.read();
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.cards.length, 3);
    expect(state.cards.map((c) => c.questionWord),
        containsAll(['chat', 'chien', 'maison']));
    final chat = state.cards.firstWhere((c) => c.questionWord == 'chat');
    expect(chat.answerWords, contains('고양이'));
  });

  test(
      'both directions: cards mix WITHOUT the same concept back-to-back '
      '(the old strict alternation dealt "chat" then "고양이" — the same '
      'word with the languages swapped; user report 2026-07-21)', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: Success([
        _due(frVariantId['chat']!, QuizDirection.frToKo),
        _due(frVariantId['chien']!, QuizDirection.frToKo),
      ]),
      QuizDirection.koToFr: Success([
        _due(koVariantId['고양이']!, QuizDirection.koToFr),
        _due(koVariantId['개']!, QuizDirection.koToFr),
      ]),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

    final cards = sub.read().cards;
    // Both directions are present…
    expect(cards.map((c) => c.progress.direction).toSet(),
        {QuizDirection.frToKo, QuizDirection.koToFr});
    // …and the two directions of one concept are spaced as far apart as a
    // 2-concept deck allows (greedy: both FR fronts, then both KO fronts).
    expect(cards.map((c) => c.questionWord).toList(),
        ['chat', 'chien', '고양이', '개']);
  });

  test('both mode: one side failing still builds a session from the other',
      () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Failure(NetworkException('down')),
      QuizDirection.koToFr: Success([
        _due(koVariantId['고양이']!, QuizDirection.koToFr),
        _due(koVariantId['개']!, QuizDirection.koToFr),
      ]),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

    final state = sub.read();
    expect(state.errorMessage, isNull);
    // 2 KO cards padded cyclically to the limit of 4.
    expect(state.cards.length, 4);
    expect(state.cards.every((c) => c.progress.direction == QuizDirection.koToFr),
        isTrue);
  });

  test('both mode: both sides failing → error state, no session', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Failure(NetworkException('down')),
      QuizDirection.koToFr: const Failure(NetworkException('down')),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(direction: QuizDirectionChoice.both, cardLimit: 4));

    final state = sub.read();
    expect(state.errorMessage, isNotNull);
    expect(state.isLoading, isFalse);
    expect(state.cards, isEmpty);
  });

  test('single direction failure → error state', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Failure(NetworkException('down')),
    });

    await container.read(quizProvider.notifier).loadCards(args());

    expect(sub.read().errorMessage, isNotNull);
  });

  test('no due cards → session immediately complete, no error', () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: const Success([]),
    });

    await container.read(quizProvider.notifier).loadCards(args());

    final state = sub.read();
    expect(state.isComplete, isTrue);
    expect(state.errorMessage, isNull);
    expect(state.cards, isEmpty);
  });

  test('a progress row pointing at a missing variant is dropped, not crashed',
      () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: Success([
        _due(frVariantId['chat']!, QuizDirection.frToKo),
        _due('no-such-variant', QuizDirection.frToKo),
      ]),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(cardLimit: 2));

    final state = sub.read();
    expect(state.errorMessage, isNull);
    // The broken row is dropped; the survivor is padded up to the limit.
    expect(state.cards.length, 2);
    expect(state.cards.every((c) => c.questionWord == 'chat'), isTrue);
  });

  test('fewer due cards than the limit → padded cyclically to the limit',
      () async {
    final (container, sub) = harness({
      QuizDirection.frToKo: Success([
        _due(frVariantId['chat']!, QuizDirection.frToKo),
      ]),
    });

    await container
        .read(quizProvider.notifier)
        .loadCards(args(cardLimit: 3));

    final state = sub.read();
    expect(state.cards.length, 3);
    expect(state.cards.every((c) => c.questionWord == 'chat'), isTrue);
    expect(state.isComplete, isFalse);
  });
}
