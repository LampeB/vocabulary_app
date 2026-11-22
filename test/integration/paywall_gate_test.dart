import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/config/app_config.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/repositories/vocabulary_repository.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';

final _now = DateTime(2026, 7, 2);

VocabularyList _list(
        {String id = 'l',
        String name = 'L',
        int wordCount = 0,
        String origin = 'user'}) =>
    VocabularyList(
      id: id,
      ownerId: 'u',
      name: name,
      wordCount: wordCount,
      origin: origin,
      createdAt: _now,
      updatedAt: _now,
    );

/// Fake repo that records calls and hands back canned successes. Only the three
/// methods the gate touches are implemented; the rest go through noSuchMethod.
class _FakeRepo implements VocabularyRepository {
  _FakeRepo({this.listWordCount = 0});
  final int listWordCount;
  int createListCalls = 0;
  int addConceptCalls = 0;

  @override
  Future<Result<VocabularyList>> createList(
      {required String name,
      String? description,
      String langA = 'fr',
      String langB = 'ko'}) async {
    createListCalls++;
    return Success(_list(name: name));
  }

  @override
  Future<Result<VocabularyList>> getListById(String listId) async =>
      Success(_list(id: listId, wordCount: listWordCount));

  @override
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String wordA,
    required String wordB,
    String langA = 'fr',
    String langB = 'ko',
    String? notes,
    String? category,
  }) async {
    addConceptCalls++;
    return Success(
        Concept(id: 'c', listId: listId, createdAt: _now, updatedAt: _now));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a container wired for the paywall gate. [existingLists] feeds the
/// list-count check; [listWordCount] feeds the words-per-list check.
Future<(ProviderContainer, _FakeRepo)> _harness({
  required bool premium,
  int existingLists = 0,
  int listWordCount = 0,
}) async {
  final repo = _FakeRepo(listWordCount: listWordCount);
  final container = ProviderContainer(overrides: [
    isPremiumProvider.overrideWithValue(premium),
    vocabularyRepositoryProvider.overrideWithValue(repo),
    myListsProvider.overrideWith((ref) => Stream.value(
        List.generate(existingLists, (i) => _list(id: 'l$i')))),
  ]);
  addTearDown(container.dispose);
  await container.read(myListsProvider.future); // ensure the stream emitted
  return (container, repo);
}

void main() {
  group('createList quota', () {
    test('free user at the list limit is blocked with QuotaExceeded', () async {
      final (container, repo) =
          await _harness(premium: false, existingLists: AppConfig.maxFreeVocabLists);

      final result = await container
          .read(listActionsProvider.notifier)
          .createList('Another', null);

      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull, isA<QuotaExceededException>());
      expect(repo.createListCalls, 0); // never reached the repo
    });

    test('free user under the limit can create (delegates to repo)', () async {
      final (container, repo) = await _harness(
          premium: false, existingLists: AppConfig.maxFreeVocabLists - 1);

      final result = await container
          .read(listActionsProvider.notifier)
          .createList('OK', null);

      expect(result.isSuccess, isTrue);
      expect(repo.createListCalls, 1);
    });

    test('seeded starter lists do NOT count against the free quota',
        () async {
      final repo = _FakeRepo();
      final container = ProviderContainer(overrides: [
        isPremiumProvider.overrideWithValue(false),
        vocabularyRepositoryProvider.overrideWithValue(repo),
        myListsProvider.overrideWith((ref) => Stream.value([
              // 6 seeded lists + 2 user lists: still under the 3-user-list cap.
              for (var i = 0; i < 6; i++)
                _list(id: 's$i', origin: 'starter'),
              _list(id: 'u1'),
              _list(id: 'u2'),
            ])),
      ]);
      addTearDown(container.dispose);
      await container.read(myListsProvider.future);

      final result = await container
          .read(listActionsProvider.notifier)
          .createList('Une de plus', null);

      expect(result.isSuccess, isTrue);
      expect(repo.createListCalls, 1);
    });

    test('premium user is never gated, even past the free limit', () async {
      final (container, repo) = await _harness(
          premium: true, existingLists: AppConfig.maxFreeVocabLists + 5);

      final result = await container
          .read(listActionsProvider.notifier)
          .createList('Unlimited', null);

      expect(result.isSuccess, isTrue);
      expect(repo.createListCalls, 1);
    });
  });

  group('addConcept quota', () {
    test('free user at the words-per-list limit is blocked', () async {
      final (container, repo) = await _harness(
          premium: false, listWordCount: AppConfig.maxFreeWordsPerList);

      final result = await container
          .read(listActionsProvider.notifier)
          .addConcept(listId: 'l', wordA: 'bonjour', wordB: '안녕');

      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull, isA<QuotaExceededException>());
      expect(repo.addConceptCalls, 0);
    });

    test('free user under the word limit can add', () async {
      final (container, repo) = await _harness(
          premium: false, listWordCount: AppConfig.maxFreeWordsPerList - 1);

      final result = await container
          .read(listActionsProvider.notifier)
          .addConcept(listId: 'l', wordA: 'bonjour', wordB: '안녕');

      expect(result.isSuccess, isTrue);
      expect(repo.addConceptCalls, 1);
    });

    test('premium user can add past the free word limit', () async {
      final (container, repo) = await _harness(
          premium: true, listWordCount: AppConfig.maxFreeWordsPerList + 100);

      final result = await container
          .read(listActionsProvider.notifier)
          .addConcept(listId: 'l', wordA: 'bonjour', wordB: '안녕');

      expect(result.isSuccess, isTrue);
      expect(repo.addConceptCalls, 1);
    });
  });
}
