// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/data/sync/vocabulary_write_order.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/services/audio/audio_asset_path.dart';
import '../helpers/fake_remote.dart';

/// Outbound sync: the isSynced flags are the queue. Rows written while the
/// backend is down get pushed by the next drain, marked synced, and never
/// pushed again; per-row failures stay queued for the next drain.

/// Records every push; can fail everything or a specific table.
class _RecordingRemote extends FakeRemote {
  Map<String, dynamic>? publicList;
  bool failAll = false;
  bool failConcepts = false;
  int attempts = 0;
  final pushedLists = <Map<String, dynamic>>[];
  final pushedConcepts = <Map<String, dynamic>>[];
  final pushedVariants = <Map<String, dynamic>>[];
  final pushedProgress = <Map<String, dynamic>>[];
  final pushedEvents = <Map<String, dynamic>>[];
  Future<void> Function(Map<String, dynamic>)? onList;
  Future<ProvisionedAudio?> Function(String)? onAudio;

  @override
  Future<ProvisionedAudio?> provisionAudio(
    String variantId, {
    required String ownerId,
  }) async => await onAudio?.call(variantId);

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async => Success(publicList);

  Result<Map<String, dynamic>> _record(
    List<Map<String, dynamic>> sink,
    Map<String, dynamic> data, {
    bool fail = false,
  }) {
    attempts++;
    if (failAll) return const Failure(NetworkException('down'));
    if (fail) return const Failure(StorageException('row rejected'));
    sink.add(data);
    return Success(data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    await onList?.call(data);
    return _record(pushedLists, data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => _record(pushedConcepts, data, fail: failConcepts);
  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => _record(pushedVariants, data);
  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async => _record(pushedProgress, data);

  @override
  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    final sent = _record(pushedEvents, data);
    return switch (sent) {
      Success() => const Success(null),
      Failure(:final exception) => Failure(exception),
    };
  }
}

class _ShareAuthRepository implements AuthRepository {
  _ShareAuthRepository(this.currentUser);

  final _changes = StreamController<AppUser?>.broadcast(sync: true);

  @override
  AppUser? currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _changes.stream;

  void authenticate(AppUser? user) {
    currentUser = user;
    _changes.add(user);
  }

  @override
  Future<Result<AppUser>> reloadProfile() async => Success(currentUser!);

  Future<void> close() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingExportPath extends PathProviderPlatform {
  final requested = Completer<void>();
  final path = Completer<String>();

  @override
  Future<String?> getTemporaryPath() {
    requested.complete();
    return path.future;
  }
}

enum _ShareOutcome {
  acknowledged,
  switchedAccount,
  signedBackIn,
  signedOutBeforeEvent,
  rejected,
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late _RecordingRemote remote;
  late VocabularyRepositoryImpl repo;
  late PushSync sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _RecordingRemote();
    repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      'u',
      db,
    );
    sync = PushSync(
      db.vocabularyListDao,
      db.conceptDao,
      db.progressDao,
      db.reviewEventDao,
      remote,
    );
  });
  tearDown(() => db.close());

  final owner = AppUser(
    id: 'u',
    email: 'test@example.com',
    username: 'test',
    createdAt: DateTime.utc(2026),
  );
  final otherUser = owner.copyWith(id: 'other');

  Future<ProviderContainer> sessionProviders(_ShareAuthRepository auth) async {
    addTearDown(auth.close);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    return container;
  }

  List<MethodCall> recordNativeShares() {
    final calls = <MethodCall>[];
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  for (final outcome in _ShareOutcome.values) {
    test(
      'native link sharing after the PushSync acknowledgement: ${outcome.name}',
      () async {
        final auth = _ShareAuthRepository(owner);
        final container = await sessionProviders(auth);
        final calls = recordNativeShares();
        final list = (await repo.createList(name: 'Share from A')).valueOrNull!;
        await repo.addConceptWithVariants(
          listId: list.id,
          wordA: 'bonjour',
          wordB: '안녕하세요',
        );
        final submitted = Completer<Map<String, dynamic>>();
        final acknowledge = Completer<void>();
        remote.onList = (row) async {
          submitted.complete(row);
          await acknowledge.future;
        };
        remote.failConcepts = outcome == _ShareOutcome.rejected;

        final sharing = container
            .read(listActionsProvider.notifier)
            .generateAndShareLink(list.id, list.name);
        try {
          final publication = await submitted.future.timeout(
            const Duration(seconds: 2),
          );
          expect(publication['owner_id'], owner.id);
          expect(publication['visibility'], 'public');
          expect(calls, isEmpty);
          switch (outcome) {
            case _ShareOutcome.switchedAccount:
              auth.authenticate(otherUser);
            case _ShareOutcome.signedBackIn:
              auth.authenticate(null);
              auth.authenticate(owner);
            case _ShareOutcome.signedOutBeforeEvent:
              // GoTrue can clear its local session before notifying listeners.
              auth.currentUser = null;
            case _ShareOutcome.acknowledged:
              auth.authenticate(
                owner.copyWith(displayName: 'Refreshed profile'),
              );
              await container.read(authStateProvider.notifier).reloadProfile();
              expect(
                container.read(currentUserProvider)?.displayName,
                'Refreshed profile',
              );
            case _ShareOutcome.rejected:
              break;
          }
        } finally {
          acknowledge.complete();
        }
        final result = await sharing.timeout(const Duration(seconds: 2));
        final row = (await db.vocabularyListDao.getById(list.id))!;
        expect(row.isSynced, isTrue);
        expect(row.shareToken, isNotEmpty);
        expect(
          await db.vocabularyListDao.hasPendingContents(list.id),
          outcome == _ShareOutcome.rejected,
        );
        switch (outcome) {
          case _ShareOutcome.acknowledged:
            expect(result.isSuccess, isTrue);
            final call = calls.single;
            expect(call.method, 'share');
            expect(call.arguments, {
              'text': 'vocabkr://import?token=${row.shareToken}',
              'subject': '${list.name} — Ponderin',
            });
          case _ShareOutcome.switchedAccount:
          case _ShareOutcome.signedBackIn:
          case _ShareOutcome.signedOutBeforeEvent:
            expect(result.exceptionOrNull, isA<PermissionException>());
            expect(calls, isEmpty);
            expect(
              container.read(currentUserProvider)?.id,
              outcome == _ShareOutcome.switchedAccount
                  ? otherUser.id
                  : owner.id,
            );
          case _ShareOutcome.rejected:
            expect(result.exceptionOrNull, isA<NetworkException>());
            expect(calls, isEmpty);
        }
      },
    );
  }

  for (final accountChanges in [false, true]) {
    test(
      'export waits for file preparation in its own session ($accountChanges)',
      () async {
        final auth = _ShareAuthRepository(owner);
        final container = await sessionProviders(auth);
        final calls = recordNativeShares();
        final list = (await repo.createList(
          name: 'Export from A',
        )).valueOrNull!;
        final directory = await Directory.systemTemp.createTemp(
          'ponderin-export-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final originalPathProvider = PathProviderPlatform.instance;
        final pathProvider = _PendingExportPath();
        PathProviderPlatform.instance = pathProvider;
        addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

        final exporting = container
            .read(listActionsProvider.notifier)
            .exportList(list.id, list.name);
        try {
          await pathProvider.requested.future.timeout(
            const Duration(seconds: 2),
          );
          if (accountChanges) auth.authenticate(otherUser);
        } finally {
          pathProvider.path.complete(directory.path);
        }
        final result = await exporting.timeout(const Duration(seconds: 2));
        if (accountChanges) {
          expect(result, const PermissionException().message);
          expect(calls, isEmpty);
          expect(await directory.list().toList(), isEmpty);
        } else {
          expect(result, isNull);
          expect(calls.single.method, 'shareFiles');
          final paths = (calls.single.arguments as Map)['paths'] as List;
          final payload = jsonDecode(
            await File(paths.single as String).readAsString(),
          );
          expect(payload['list']['name'], list.name);
        }
      },
    );
  }

  test('restore reads past the first page of server identities', () async {
    final filters = <String?>[];
    final client = SupabaseClient(
      'https://bootstrap.example.test',
      'anon',
      httpClient: MockClient((request) async {
        expect(request.url.pathSegments.last, 'vocabulary_pull_inventory');
        final parameters = jsonDecode(request.body) as Map<String, dynamic>;
        filters.add(parameters['p_after_id'] as String?);
        expect(parameters['p_owner_id'], 'u');
        final rows = parameters['p_after_id'] == null
            ? List.generate(500, (i) => {'id': i.toString().padLeft(3, '0')})
            : [
                {
                  'id': 'historical-starter',
                  'seed_id': 'starter-greetings:fr>ko',
                },
              ];
        return http.Response(jsonEncode(rows), 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final restored = await VocabularyRemoteDataSource(client).fetchLists('u');
    expect(restored.valueOrNull?.last['id'], 'historical-starter');
    expect(filters, [null, '499']);
  });

  test(
    'audio acknowledgement adopts a canonical path without queuing a write',
    () async {
      final list = (await repo.createList(name: 'Audio')).valueOrNull!;
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'chat',
        wordB: '고양이',
      )).valueOrNull!;
      final word = (await db.conceptDao.getVariantsByConcept(
        concept.id,
      )).firstWhere((v) => v.langCode == 'fr');
      final canonical = AudioAssetPath.seed(
        text: word.word,
        langCode: word.langCode,
      );
      expect(word.audioPath, isNot(canonical));
      remote.onAudio = (id) async => id == word.id
          ? (path: canonical, word: word.word, langCode: word.langCode)
          : null;
      var signals = 0;
      final subscription = db
          .watchOutboundMutations('u')
          .listen((_) => signals++);
      addTearDown(subscription.cancel);
      final updated = db.conceptDao
          .watchVariantsByConcept(concept.id)
          .expand((rows) => rows)
          .firstWhere((row) => row.id == word.id && row.audioPath == canonical);

      expect(await sync.pushAll(), 4);
      final acknowledged = await updated.timeout(const Duration(seconds: 2));
      expect(acknowledged.isSynced, isTrue);
      expect(acknowledged.updatedAt, word.updatedAt);
      expect(signals, 0);
      expect(await sync.pushAll(), 0);
    },
  );

  test(
    'audio rendered for a previous word cannot replace its edited path',
    () async {
      final list = (await repo.createList(name: 'Audio edit')).valueOrNull!;
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'chat',
        wordB: '고양이',
      )).valueOrNull!;
      final word = (await repo.getVariants(
        concept.id,
      )).valueOrNull!.firstWhere((v) => v.langCode == 'fr');
      final started = Completer<void>();
      final ready = Completer<ProvisionedAudio?>();
      final attemptedAfterEdit = Completer<void>();
      remote.onAudio = (id) async {
        if (id != word.id) return null;
        if (started.isCompleted) {
          attemptedAfterEdit.complete();
          return null;
        }
        started.complete();
        return ready.future;
      };

      expect(await sync.pushAll(), 4);
      await started.future.timeout(const Duration(seconds: 2));
      final edited = (await repo.updateVariant(
        word.copyWith(word: 'chaton'),
      )).valueOrNull!;
      expect(await sync.pushAll(), 1);
      ready.complete((
        path: AudioAssetPath.seed(text: 'chat', langCode: 'fr'),
        word: 'chat',
        langCode: 'fr',
      ));
      await attemptedAfterEdit.future.timeout(const Duration(seconds: 2));

      final row = (await db.conceptDao.getVariantById(word.id))!;
      expect(row.word, 'chaton');
      expect(row.audioPath, edited.audioPath);
      expect(row.isSynced, isTrue);
    },
  );

  test(
    'concept deletion removes pending mastery before and after its ordinary ack',
    () async {
      final list = (await repo.createList(name: 'Mastered word')).valueOrNull!;
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'chat',
        wordB: '고양이',
      )).valueOrNull!;
      final variant = (await db.conceptDao.getVariantsByConcept(
        concept.id,
      )).first;
      final progress = ProgressRepositoryImpl(
        db.progressDao,
        db.conceptDao,
        remote,
        'u',
      );
      final base = (await progress.getProgress(
        variantId: variant.id,
        direction: QuizDirection.frToKo,
      )).valueOrNull!;
      final card = base.copyWith(
        state: CardState.review,
        scheduledDays: 40,
        reps: 8,
        timesCorrect: 8,
      );
      await sync.pushAll();
      await progress.updateProgress(card);
      expect(
        (await progress.getMasteredVariants('u')).valueOrNull,
        hasLength(1),
      );
      expect(
        (await progress.getListStats(list.id)).valueOrNull?['mastered'],
        1,
      );

      expect((await repo.deleteConcept(concept.id)).isSuccess, isTrue);
      expect(await db.progressDao.getById(card.id), isNull);
      expect((await progress.getMasteredVariants('u')).valueOrNull, isEmpty);
      expect(
        (await progress.getListStats(list.id)).valueOrNull?['mastered'],
        0,
      );
      expect(await db.conceptDao.getUnsyncedConcepts(), hasLength(1));
      expect((await db.vocabularyListDao.getById(list.id))!.isSynced, isTrue);

      // An older build could leave progress queued beside the authored tombstone.
      await db.progressDao.upsert(card.toLocalCompanion());
      await sync.pushAll();
      expect(remote.pushedConcepts.last['is_deleted'], isTrue);
      expect(remote.pushedProgress, isEmpty);
      expect(await db.progressDao.getById(card.id), isNull);
      expect((await progress.getMasteredVariants('u')).valueOrNull, isEmpty);
    },
  );

  test(
    'remote writes distinguish transport outages from row rejection',
    () async {
      var connected = false;
      final client = SupabaseClient(
        'https://service.example.test',
        'anon',
        httpClient: MockClient((request) async {
          if (!connected) throw http.ClientException('disconnected');
          return http.Response(
            jsonEncode({'code': '23514', 'message': 'row constraint'}),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final datasource = VocabularyRemoteDataSource(client);

      final list = const VocabularyWriteStamp(
        'fixture',
        1,
      ).apply({'id': 'list', 'owner_id': 'u'});
      final outage = await datasource.upsertList(list);
      expect(outage.exceptionOrNull, isA<NetworkException>());
      connected = true;
      final rejected = await datasource.upsertList(list);
      expect(rejected.exceptionOrNull, isA<StorageException>());
    },
  );

  test('the remote import patches only edited fields on a live copy', () async {
    final methods = <String>[];
    final client = SupabaseClient(
      'https://service.example.test',
      'anon',
      httpClient: MockClient((request) async {
        methods.add(request.method);
        switch (request.method) {
          case 'POST':
            expect(
              request.headers['prefer'],
              contains('resolution=ignore-duplicates'),
            );
            return http.Response(
              '[]',
              201,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          case 'PATCH':
            expect(
              request.url.queryParameters,
              containsPair('owner_id', 'eq.u'),
            );
            expect(jsonDecode(request.body), {
              'name': 'Edited on B',
              'sync_write_protocol': 16,
            });
            expect(request.headers['x-ponderin-sync-sequence'], '1');
            return http.Response(
              '{"id":"list","owner_id":"u","name":"Edited on B","visibility":"public"}',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          default:
            fail('Unexpected request ${request.method}');
        }
      }),
    );
    addTearDown(client.dispose);
    final datasource = VocabularyRemoteDataSource(client);

    final result = await datasource.upsertList(
      const VocabularyWriteStamp(
        'fixture',
        1,
      ).apply({'id': 'list', 'owner_id': 'u', 'visibility': 'private'}),
      insertOnly: true,
      changes: {'name': 'Edited on B'},
    );
    expect(result.isSuccess, isTrue, reason: result.exceptionOrNull?.message);
    expect(methods, ['POST', 'PATCH']);
    expect(result.valueOrNull?['visibility'], 'public');
  });

  test('profile data keeps the writer but an account change replaces it', () {
    final user = AppUser(
      id: 'u',
      email: 'test@example.com',
      username: 'test',
      createdAt: DateTime.utc(2026),
    );
    final current = StateProvider<AppUser?>((_) => user);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(remote),
        currentUserProvider.overrideWith((ref) => ref.watch(current)),
      ],
    );
    addTearDown(container.dispose);
    final writer = container.read(pushSyncProvider);
    final repository = container.read(vocabularyRepositoryProvider);

    container.read(current.notifier).state = user.copyWith(
      displayName: 'Late profile',
    );
    expect(container.read(pushSyncProvider), same(writer));
    expect(container.read(vocabularyRepositoryProvider), same(repository));

    container.read(current.notifier).state = user.copyWith(
      id: 'different-account',
    );
    expect(container.read(pushSyncProvider), isNot(same(writer)));
    expect(
      container.read(vocabularyRepositoryProvider),
      isNot(same(repository)),
    );
  });

  test(
    'sharing publishes explicitly; importing a token preserves privacy',
    () async {
      final list = (await repo.createList(name: 'Share me')).valueOrNull!;
      await repo.generateShareLink(list.id);
      expect(
        (await db.vocabularyListDao.getById(list.id))!.visibility,
        'public',
      );

      remote.publicList = {
        'id': 'source',
        'name': 'Imported',
        'lang_a': 'en',
        'lang_b': 'ko',
        'concepts': const [],
      };
      final imported = (await repo.importFromShareToken(
        'original-token',
      )).valueOrNull!;
      final row = (await db.vocabularyListDao.getById(imported.id))!;
      expect(row.shareToken, isNull);
      expect(row.importedFromShareToken, 'original-token');
      expect(row.visibility, 'private');
    },
  );

  test(
    'a user-scoped drain excludes another cached account and its content',
    () async {
      final own = (await repo.createList(name: 'Mine')).valueOrNull!;
      await repo.addConceptWithVariants(
        listId: own.id,
        wordA: 'chat',
        wordB: '고양이',
      );
      final otherRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        remote,
        'other-user',
        db,
      );
      final other = (await otherRepo.createList(name: 'Other')).valueOrNull!;
      await otherRepo.addConceptWithVariants(
        listId: other.id,
        wordA: 'chien',
        wordB: '개',
      );

      final ownSync = PushSync(
        db.vocabularyListDao,
        db.conceptDao,
        db.progressDao,
        db.reviewEventDao,
        remote,
        userId: 'u',
      );
      await ownSync.pushAll();

      expect(remote.pushedLists.map((row) => row['id']), [own.id]);
      expect(remote.pushedConcepts.map((row) => row['list_id']), [own.id]);
      expect(remote.pushedVariants, hasLength(2));
      expect(
        await db.vocabularyListDao.getUnsyncedLists(ownerId: 'other-user'),
        hasLength(1),
      );
      expect(
        await db.conceptDao.getUnsyncedConcepts(ownerId: 'other-user'),
        hasLength(1),
      );
      expect(
        await db.conceptDao.getUnsyncedVariants(ownerId: 'other-user'),
        hasLength(2),
      );
    },
  );

  test(
    'share readiness is list-specific and detects failed child uploads',
    () async {
      final own = (await repo.createList(name: 'Incomplete')).valueOrNull!;
      await repo.addConceptWithVariants(
        listId: own.id,
        wordA: 'chat',
        wordB: '고양이',
      );
      remote.failConcepts = true;
      await sync.pushAll();
      expect(await db.vocabularyListDao.hasPendingContents(own.id), isTrue);

      remote.failConcepts = false;
      await sync.pushAll();
      await repo.createList(name: 'Unrelated pending list');
      expect(await db.vocabularyListDao.hasPendingContents(own.id), isFalse);
    },
  );

  test('a share flush does not wait for a blocked unrelated drain', () async {
    final unrelated = (await repo.createList(name: 'Unrelated')).valueOrNull!;
    final requested = Completer<void>();
    final reply = Completer<void>();
    remote.onList = (row) async {
      if (row['id'] == unrelated.id) {
        requested.complete();
        await reply.future;
      }
    };
    final globalDrain = sync.pushAll();
    try {
      await requested.future;
      final shared = (await repo.createList(name: 'Share me')).valueOrNull!;
      await repo.addConceptWithVariants(
        listId: shared.id,
        wordA: 'chat',
        wordB: '고양이',
      );
      await repo.generateShareLink(shared.id);

      expect(
        await sync.pushList(shared.id).timeout(const Duration(seconds: 2)),
        4,
      );
      expect((await db.vocabularyListDao.getById(shared.id))!.isSynced, isTrue);
      expect(await db.vocabularyListDao.hasPendingContents(shared.id), isFalse);
      expect(
        (await db.vocabularyListDao.getById(unrelated.id))!.isSynced,
        isFalse,
      );
    } finally {
      reply.complete();
      await globalDrain;
    }
  });

  test(
    'blocked audio does not delay share metadata or later global drains',
    () async {
      final shared = (await repo.createList(name: 'Share me')).valueOrNull!;
      await repo.addConceptWithVariants(
        listId: shared.id,
        wordA: 'chat',
        wordB: '고양이',
      );
      await repo.generateShareLink(shared.id);
      final requested = Completer<void>();
      final reply = Completer<void>();
      final requests = <String>[];
      remote.onAudio = (id) async {
        requests.add(id);
        if (!requested.isCompleted) requested.complete();
        await reply.future;
        return null;
      };

      final shareDrain = sync.pushList(shared.id);
      try {
        await requested.future;
        expect(await shareDrain.timeout(const Duration(seconds: 2)), 4);
        expect(
          await db.vocabularyListDao.hasPendingContents(shared.id),
          isFalse,
        );
        final another = (await repo.createList(
          name: 'Work continues',
        )).valueOrNull!;
        await repo.addConceptWithVariants(
          listId: another.id,
          wordA: 'sol',
          wordB: '땅',
        );
        expect(await sync.pushAll().timeout(const Duration(seconds: 2)), 4);
        expect(remote.pushedVariants, hasLength(4));
        expect(requests, hasLength(1));
      } finally {
        reply.complete();
        await shareDrain;
      }
    },
  );

  test('offline writes are drained on the next push: list, concept and both '
      'variants land remotely and are marked synced', () async {
    remote.failAll = true; // backend down while the user works
    final list = (await repo.createList(name: 'Animaux')).valueOrNull!;
    await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'chat',
      wordB: '고양이',
    );
    remote.pushedLists.clear(); // drop the failed fire-and-forget attempts

    remote.failAll = false; // back online
    final pushed = await sync.pushAll();

    expect(pushed, 4); // 1 list + 1 concept + 2 variants
    expect(remote.pushedLists.single['name'], 'Animaux');
    expect(remote.pushedLists.single['lang_a'], 'fr');
    expect(remote.pushedConcepts, hasLength(1));
    expect(
      remote.pushedVariants.map((v) => v['word']),
      containsAll(['chat', '고양이']),
    );
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
    expect(await db.conceptDao.getUnsyncedVariants(), isEmpty);
  });

  test('a second drain pushes nothing (idempotent)', () async {
    await repo.createList(name: 'A');
    await sync.pushAll();
    remote.pushedLists.clear();

    final pushed = await sync.pushAll();

    expect(pushed, 0);
    expect(remote.pushedLists, isEmpty);
  });

  test(
    'a transport outage stops the drain and preserves its pending rows',
    () async {
      for (final name in ['First', 'Second']) {
        final list = (await repo.createList(name: name)).valueOrNull!;
        await repo.addConceptWithVariants(
          listId: list.id,
          wordA: 'chat',
          wordB: '고양이',
        );
      }
      remote.failAll = true;

      expect(await sync.pushAll(), 0);
      expect(remote.attempts, 1);
      expect(await db.vocabularyListDao.getUnsyncedLists(), hasLength(2));
      expect(await db.conceptDao.getUnsyncedConcepts(), hasLength(2));
      expect(await db.conceptDao.getUnsyncedVariants(), hasLength(4));

      remote.failAll = false;
      expect(await sync.pushAll(), 8);
      expect(remote.attempts, 9);
      expect(await db.vocabularyListDao.getPendingListIds(), isEmpty);
    },
  );

  for (final recovered in [true, false]) {
    test('a request during a failed push queues exactly one fresh pass '
        'when transport recovery is $recovered', () async {
      final list = (await repo.createList(name: 'Queued')).valueOrNull!;
      final started = Completer<void>();
      final failedResponse = Completer<void>();
      var requests = 0;
      remote.onList = (_) async {
        requests++;
        if (requests == 1) {
          started.complete();
          await failedResponse.future;
          remote.failAll = true;
        } else {
          remote.failAll = !recovered;
        }
      };

      final originalDrain = sync.pushAll();
      await started.future;
      final reconnectDrain = sync.pushAll();
      expect(reconnectDrain, same(originalDrain));
      expect(sync.pushAll(), same(originalDrain));
      failedResponse.complete();

      expect(await reconnectDrain, recovered ? 1 : 0);
      expect(requests, 2);
      final persisted = await db.vocabularyListDao.getById(list.id);
      expect(persisted?.isSynced, recovered);
      expect(remote.pushedLists, hasLength(recovered ? 1 : 0));
    });
  }

  test('all remote payloads preserve the instant and declare UTC', () async {
    final instant = DateTime.parse('2026-11-27T12:30:00+09:00').toLocal();
    expect(instant.isUtc, isFalse);
    const expected = '2026-11-27T03:30:00.000Z';
    final list = (await repo.createList(name: 'UTC')).valueOrNull!;
    final concept = (await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'chat',
      wordB: '고양이',
    )).valueOrNull!;
    final variant = (await db.conceptDao.getVariantsByConcept(
      concept.id,
    )).first;
    await (db.update(
      db.vocabularyListsTable,
    )..where((t) => t.id.equals(list.id))).write(
      VocabularyListsTableCompanion(
        createdAt: Value(instant),
        updatedAt: Value(instant),
      ),
    );
    await (db.update(
      db.conceptsTable,
    )..where((t) => t.id.equals(concept.id))).write(
      ConceptsTableCompanion(
        createdAt: Value(instant),
        updatedAt: Value(instant),
      ),
    );
    await (db.update(
      db.wordVariantsTable,
    )..where((t) => t.conceptId.equals(concept.id))).write(
      WordVariantsTableCompanion(
        createdAt: Value(instant),
        updatedAt: Value(instant),
      ),
    );
    await db.progressDao.upsert(
      VariantProgressTableCompanion.insert(
        id: 'progress',
        variantId: variant.id,
        userId: 'u',
        direction: 'fr>ko',
        lastReview: Value(instant),
        nextReview: Value(instant),
        createdAt: instant,
        updatedAt: instant,
      ),
    );
    await db.reviewEventDao.insertEvent(
      ReviewEventsTableCompanion.insert(
        id: 'event',
        variantId: variant.id,
        userId: 'u',
        direction: 'fr>ko',
        mode: 'flashcard',
        correct: true,
        rating: 'good',
        createdAt: instant,
      ),
    );

    expect(await sync.pushAll(), 6);
    for (final row in [
      ...remote.pushedLists,
      ...remote.pushedConcepts,
      ...remote.pushedVariants,
      ...remote.pushedProgress,
    ]) {
      expect(row['created_at'], expected);
      expect(row['updated_at'], expected);
    }
    expect(remote.pushedProgress.single['last_review'], expected);
    expect(remote.pushedProgress.single['next_review'], expected);
    expect(remote.pushedEvents.single['created_at'], expected);
  });

  test(
    'an edit during a remote write stays queued until its own acknowledgement',
    () async {
      final list = (await repo.createList(name: 'First')).valueOrNull!;
      remote.onList = (_) async {
        remote.onList = null;
        await repo.updateList(list.copyWith(name: 'Edited'));
      };

      await sync.pushAll();

      expect(remote.pushedLists.map((row) => row['name']), ['First', 'Edited']);
      expect((await db.vocabularyListDao.getById(list.id))!.isSynced, isTrue);
    },
  );

  test(
    'sharing persists public visibility for the single durable writer',
    () async {
      final list = (await repo.createList(name: 'Shared')).valueOrNull!;
      final link = await repo.generateShareLink(list.id);
      expect(link.isSuccess, isTrue);
      expect(remote.pushedLists, isEmpty);
      await sync.pushAll();
      expect(remote.pushedLists.single['visibility'], 'public');
      expect(remote.pushedLists.single['share_token'], isNotEmpty);
    },
  );

  test('a per-table failure keeps ONLY those rows queued; the next drain '
      'retries just them', () async {
    final list = (await repo.createList(name: 'A')).valueOrNull!;
    await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'chat',
      wordB: '고양이',
    );
    remote.failConcepts = true;

    await sync.pushAll();

    // List and variants made it; the concept stayed queued.
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), hasLength(1));

    remote.failConcepts = false;
    final retried = await sync.pushAll();

    expect(retried, 1); // just the concept
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
  });

  test(
    'soft-deleted rows are pushed with is_deleted so the delete syncs',
    () async {
      final list = (await repo.createList(name: 'A')).valueOrNull!;
      final concept = (await repo.addConceptWithVariants(
        listId: list.id,
        wordA: 'chat',
        wordB: '고양이',
      )).valueOrNull!;
      await sync.pushAll();
      remote.pushedConcepts.clear();

      await repo.deleteConcept(
        concept.id,
      ); // soft-delete → isSynced=false again
      // Let the repo's own fire-and-forget push land, then isolate the drain's.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      remote.pushedConcepts.clear();

      await sync.pushAll();

      expect(remote.pushedConcepts.single['is_deleted'], true);
      expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
    },
  );
}
