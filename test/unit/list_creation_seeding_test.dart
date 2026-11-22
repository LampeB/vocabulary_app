import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/seed/starter_seeder.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/repositories/vocabulary_repository.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';

class _Repo implements VocabularyRepository {
  @override
  Future<Result<VocabularyList>> createList(
          {required String name,
          String? description,
          String langA = 'fr',
          String langB = 'ko'}) async =>
      Success(VocabularyList(
          id: 'fixture',
          ownerId: 'learner',
          name: name,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026)));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Seeder implements StarterSeeder {
  final pairs = <(String, String)>[];
  @override
  Future<void> ensureSeededForPair(String source, String target) async {
    pairs.add((source, target));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('list creation seeds automatically only outside TEST_MODE', () async {
    final seeder = _Seeder();
    final container = ProviderContainer(overrides: [
      vocabularyRepositoryProvider.overrideWithValue(_Repo()),
      starterSeederProvider.overrideWithValue(seeder),
      isPremiumProvider.overrideWithValue(true),
    ]);
    addTearDown(container.dispose);
    final result = await container
        .read(listActionsProvider.notifier)
        .createList('Fixture', null, langA: 'en', langB: 'ko');
    expect(result.isSuccess, isTrue);
    // Flush the scheduled automatic seeding task.
    await Future<void>.delayed(Duration.zero);
    expect(
        seeder.pairs,
        const bool.fromEnvironment('TEST_MODE')
            ? isEmpty
            : equals([('en', 'ko')]));
  });
}
