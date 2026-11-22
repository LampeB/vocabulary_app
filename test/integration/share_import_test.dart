// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-share';

/// Fake remote that returns a fixed shared-list payload for any token.
class _SharedListRemote extends FakeRemote {
  _SharedListRemote(this.payload);
  final Map<String, dynamic>? payload;
  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
          String token) async =>
      Success(payload);
}

Map<String, dynamic> _sharedPayload() => {
      'name': 'Shared Greetings',
      'description': 'from a friend',
      'concepts': [
        {
          'category': null,
          'notes': null,
          'example_fr': null,
          'example_ko': null,
          'word_variants': [
            {'word': 'bonjour', 'lang_code': 'fr', 'is_primary': true, 'position': 0},
            {'word': '안녕하세요', 'lang_code': 'ko', 'is_primary': true, 'position': 0},
          ],
        },
      ],
    };

void main() {
  late AppDatabase db;

  VocabularyRepositoryImpl repoWith(dynamic remote) => VocabularyRepositoryImpl(
      db.vocabularyListDao, db.conceptDao, remote, _kUserId, db);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('generateShareLink', () {
    test('creates a token and returns a vocabkr://import link', () async {
      final repo = repoWith(FakeRemote());
      final list = (await repo.importFromJson({
        'list': {'name': 'My List', 'concepts': []}
      })).valueOrNull!;

      final result = await repo.generateShareLink(list.id);

      expect(result.isSuccess, isTrue);
      final link = result.valueOrNull!;
      expect(link, startsWith('vocabkr://import?token='));

      final token = Uri.parse(link).queryParameters['token']!;
      final byToken = await db.vocabularyListDao.getByShareToken(token);
      expect(byToken, isNotNull);
      expect(byToken!.id, list.id);
    });
  });

  group('importFromShareToken', () {
    test('unknown token → NotFoundException', () async {
      final repo = repoWith(_SharedListRemote(null));
      final result = await repo.importFromShareToken('nope');
      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test('valid token → the shared list + concepts are imported locally',
        () async {
      final repo = repoWith(_SharedListRemote(_sharedPayload()));

      final result = await repo.importFromShareToken('abc123');

      expect(result.isSuccess, isTrue);
      final list = result.valueOrNull!;
      expect(list.name, 'Shared Greetings');
      final concepts = await db.conceptDao.getConceptsByList(list.id);
      expect(concepts.length, 1);
      final variants = await db.conceptDao.getVariantsByConcept(concepts.first.id);
      expect(variants.map((v) => v.word), containsAll(['bonjour', '안녕하세요']));
    });

    test('re-importing the same token returns the existing list (dedup)',
        () async {
      final repo = repoWith(_SharedListRemote(_sharedPayload()));

      final first = (await repo.importFromShareToken('abc123')).valueOrNull!;
      // The share token is tagged asynchronously after import; let it settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = (await repo.importFromShareToken('abc123')).valueOrNull!;

      expect(second.id, first.id);
    });
  });
}
