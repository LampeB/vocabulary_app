import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/data/sync/vocabulary_write_order.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';

http.Response _reply(http.Request request, Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

const _conceptEndpoint = 'vocabulary_pull_concepts';

http.Response _conceptReply(
  http.Request request,
  List<Map<String, dynamic>> concepts,
) => _reply(request, [
  for (final concept in concepts) {'id': concept['id'], 'value': concept},
]);

String? _conceptList(http.Request request) =>
    request.url.pathSegments.last == _conceptEndpoint
    ? jsonDecode(request.body)['p_list_id'] as String
    : null;

const _timestamp = {
  'created_at': '2026-11-27T00:00:00Z',
  'updated_at': '2026-11-27T00:00:00Z',
};

Map<String, dynamic> _remoteList(String id, {bool isDeleted = false}) => {
  ..._timestamp,
  'id': id,
  'owner_id': 'u',
  'name': isDeleted ? '' : id,
  'is_deleted': isDeleted,
};

Map<String, dynamic> _remoteConcept(String list) => {
  ..._timestamp,
  'id': 'concept-$list',
  'list_id': list,
  'word_variants': [
    {
      ..._timestamp,
      'id': 'variant-$list',
      'concept_id': 'concept-$list',
      'word': 'bonjour',
      'lang_code': 'fr',
    },
  ],
};

VariantProgress _remoteProgress(String list) => VariantProgress(
  id: 'progress-$list',
  userId: 'u',
  variantId: 'variant-$list',
  direction: QuizDirection.frToKo,
  reps: 4,
  createdAt: DateTime.utc(2026, 11, 27),
  updatedAt: DateTime.utc(2026, 11, 27),
);

Future<Map<String, dynamic>> _pullCheckpoint(AppDatabase db) async {
  final stored = await db
      .customSelect(
        "SELECT snapshot FROM shared_import_bootstrap WHERE id = 'vocabulary-pull:u'",
      )
      .getSingle();
  return jsonDecode(stored.read<String>('snapshot')) as Map<String, dynamic>;
}

Future<void> _useSession(SupabaseClient client, String id) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  await client.auth.recoverSession(
    jsonEncode({
      'access_token':
          '${encode({'alg': 'HS256'})}.${encode({'exp': expiry, 'sub': id})}.test',
      'refresh_token': 'local-fixture',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': _timestamp['created_at'],
      },
    }),
  );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  VocabularyRemoteDataSource remote(
    Future<http.Response> Function(http.Request) send, {
    Duration writeTimeout = const Duration(milliseconds: 250),
    Duration pageTimeout = const Duration(seconds: 4),
    void Function(SupabaseClient)? captureClient,
  }) {
    final client = SupabaseClient(
      'https://sync.example.invalid',
      'anon',
      httpClient: MockClient(send),
    );
    addTearDown(client.dispose);
    captureClient?.call(client);
    return VocabularyRemoteDataSource(
      client,
      writeTimeout: writeTimeout,
      pageTimeout: pageTimeout,
    );
  }

  VocabularyRepositoryImpl repository(
    VocabularyRemoteDataSource datasource, {
    Duration restoreTimeout = const Duration(seconds: 15),
    AppDatabase? device,
  }) {
    final storage = device ?? db;
    return VocabularyRepositoryImpl(
      storage.vocabularyListDao,
      storage.conceptDao,
      datasource,
      'u',
      storage,
      restoreTimeout: restoreTimeout,
    );
  }

  PushSync sender(VocabularyRemoteDataSource datasource) => PushSync(
    db.vocabularyListDao,
    db.conceptDao,
    db.progressDao,
    db.reviewEventDao,
    datasource,
    userId: 'u',
  );

  test('a silent write releases the targeted share wait and queued reconnect '
      'can acknowledge the same durable row', () async {
    final firstPost = Completer<http.Request>();
    final silent = Completer<http.Response>();
    final retryPost = Completer<http.Request>();
    final retryReply = Completer<http.Response>();
    final datasource = remote((request) {
      if (!firstPost.isCompleted) {
        firstPost.complete(request);
        return silent.future;
      }
      retryPost.complete(request);
      return retryReply.future;
    });
    final repo = repository(datasource);
    final list = (await repo.createList(name: 'Shared list')).valueOrNull!;
    final share = (await repo.generateShareLink(list.id)).valueOrNull!;
    final token = Uri.parse(share).queryParameters['token'];
    final sync = sender(datasource);
    final running = sync.pushAll();
    await firstPost.future;
    final waitingToShare = sync.pushList(list.id);
    final reconnect = sync.pushAll();
    expect(reconnect, same(running));
    expect(await waitingToShare.timeout(const Duration(seconds: 2)), 0);
    final retried = await retryPost.future.timeout(const Duration(seconds: 2));
    expect((await db.vocabularyListDao.getById(list.id))!.isSynced, isFalse);
    final body = jsonDecode(retried.body) as Map<String, dynamic>;
    expect(body['share_token'], token);
    retryReply.complete(_reply(retried, body));
    expect(await reconnect, 1);
    expect(silent.isCompleted, isFalse);
    expect(await sync.pushList(list.id), 0);
    final ready = (await db.vocabularyListDao.getById(list.id))!;
    expect(ready.shareToken, token);
    expect(ready.visibility, 'public');
    expect(ready.isSynced, isTrue);
    expect(await db.vocabularyListDao.hasPendingContents(list.id), isFalse);
  });

  test('a purge acknowledgement drains stale list edits and removes the cached '
      'children and progress', () async {
    final requests = <String>[];
    final datasource = remote((request) async {
      final table = request.url.pathSegments.last;
      requests.add(table);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (table == 'vocabulary_lists') {
        expect(body['name'], 'Offline rename');
        expect(body['sync_write_protocol'], 16);
        return http.Response(
          '{"code":"PV001","message":"Vocabulary identity was physically removed"}',
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      expect(table, 'vocabulary_purge_ack');
      expect(body['p_owner_id'], 'u');
      expect(body['p_kind'], 'list');
      expect(body['p_parent_id'], isNull);
      return _reply(
        request,
        _remoteList(body['p_id'] as String, isDeleted: true),
      );
    });
    final repo = repository(datasource);
    final list = (await repo.createList(name: 'Before purge')).valueOrNull!;
    final concept = (await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'chat',
      wordB: '고양이',
    )).valueOrNull!;
    final variant = (await db.conceptDao.getVariantsByConcept(
      concept.id,
    )).first;
    final pending = _remoteProgress(
      list.id,
    ).copyWith(variantId: variant.id, isSynced: false);
    await db.progressDao.upsertLocal(pending.toLocalCompanion());
    await repo.renameList(list.id, 'Offline rename');

    final sync = sender(datasource);
    expect(await sync.pushAll(), 1);
    expect(await sync.pushAll(), 0);
    expect(requests, ['vocabulary_lists', 'vocabulary_purge_ack']);
    final acknowledged = await db.vocabularyListDao.getById(list.id);
    expect(acknowledged?.isDeleted, isTrue);
    expect(acknowledged?.isSynced, isTrue);
    expect((await db.conceptDao.getById(concept.id))?.isDeleted, isTrue);
    expect(await db.progressDao.getById(pending.id), isNull);
  });

  test(
    'a silent canonical acknowledgement write is a transport failure',
    () async {
      final methods = <String>[];
      final silent = Completer<http.Response>();
      final datasource = remote((request) async {
        methods.add(request.method);
        if (request.method == 'POST') return _reply(request, []);
        return silent.future;
      });
      final result = await datasource
          .upsertList(
            const VocabularyWriteStamp(
              'fixture',
              1,
            ).apply({'id': 'list', 'owner_id': 'u'}),
            insertOnly: true,
          )
          .timeout(const Duration(seconds: 2));
      expect(result.exceptionOrNull, isA<NetworkException>());
      expect(methods, ['POST', 'PATCH']);
      expect(silent.isCompleted, isFalse);
    },
  );

  test('a reverted shared import fences the timed-out rename and acknowledges '
      'the canonical copy without touching its metadata', () async {
    final latePatch = Completer<http.Request>();
    final releasePatch = Completer<void>();
    final latePatchRejected = Completer<void>();
    final canonical = <String, dynamic>{
      ..._timestamp,
      'owner_id': 'u',
      'name': 'Baseline',
      'description': 'Edited on another device',
      'imported_from_share_token': 'source-token',
      'visibility': 'public',
      'share_token': 'published-copy',
    };
    var lastSequence = 0;
    var writes = 0;
    final datasource = remote((request) async {
      if (request.method == 'GET') {
        expect(request.url.queryParameters['share_token'], 'eq.source-token');
        return _reply(request, [
          {'name': 'Baseline'},
        ]);
      }
      if (request.method == 'POST') {
        expect(
          request.headers['prefer'],
          contains('resolution=ignore-duplicates'),
        );
        return _reply(request, []);
      }
      expect(request.method, 'PATCH');
      final changes = jsonDecode(request.body) as Map<String, dynamic>;
      final sequence = int.parse(request.headers['x-ponderin-sync-sequence']!);
      if (++writes == 1) {
        expect(changes['name'], 'Transient rename');
        latePatch.complete(request);
        await releasePatch.future;
      } else {
        expect(changes, {'sync_write_protocol': 16});
      }
      if (sequence <= lastSequence) {
        latePatchRejected.complete();
        return http.Response(
          '{"code":"40001","message":"Older than accepted revision"}',
          409,
          request: request,
        );
      }
      lastSequence = sequence;
      canonical.addAll(changes);
      return _reply(request, canonical);
    });
    final repo = repository(datasource);
    final list = (await repo.importFromShareToken('source-token')).valueOrNull!;
    canonical['id'] = list.id;
    await repo.renameList(list.id, 'Transient rename');
    final running = sender(datasource).pushAll();
    final timedOut = await latePatch.future.timeout(const Duration(seconds: 2));
    expect(await running, 0);
    expect((await db.vocabularyListDao.getById(list.id))?.isSynced, isFalse);

    await repo.renameList(list.id, 'Baseline');
    expect(await sender(datasource).pushAll(), 1);
    final acknowledged = (await db.vocabularyListDao.getById(list.id))!;
    expect(acknowledged.isSynced, isTrue);
    expect(acknowledged.description, 'Edited on another device');
    expect(acknowledged.shareToken, 'published-copy');
    expect(
      lastSequence,
      greaterThan(int.parse(timedOut.headers['x-ponderin-sync-sequence']!)),
    );

    releasePatch.complete();
    await latePatchRejected.future.timeout(const Duration(seconds: 2));
    expect(canonical['name'], 'Baseline');
    expect((await db.vocabularyListDao.getById(list.id))?.name, 'Baseline');
  });

  for (final progress in [false, true]) {
    test(
      'later ${progress ? 'FSRS' : 'metadata'} snapshot survives a timed-out HTTP write',
      () async {
        final oldRequest = Completer<http.Request>();
        final letOldCommit = Completer<void>();
        final oldFinished = Completer<void>();
        final requests = <http.Request>[];
        final watchedTable = progress ? 'variant_progress' : 'vocabulary_lists';
        var armed = false;
        var appliedSequence = 0;
        Map<String, dynamic>? stored;
        final datasource = remote((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['sync_write_protocol'], 16);
          if (!armed || request.url.pathSegments.last != watchedTable) {
            return _reply(request, body);
          }
          requests.add(request);
          final isOld = requests.length == 1;
          if (isOld) {
            oldRequest.complete(request);
            await letOldCommit.future;
          }
          final sequence = int.parse(
            request.headers['x-ponderin-sync-sequence']!,
          );
          if (sequence > appliedSequence) {
            appliedSequence = sequence;
            stored = body;
          }
          if (isOld) oldFinished.complete();
          return _reply(request, stored!);
        });
        final repo = repository(datasource);
        final list = (await repo.createList(
          name: 'Before timeout',
        )).valueOrNull!;
        final concept = (await repo.addConceptWithVariants(
          listId: list.id,
          wordA: 'chat',
          wordB: '고양이',
        )).valueOrNull!;
        final variant = (await db.conceptDao.getVariantsByConcept(
          concept.id,
        )).first;
        final now = DateTime.utc(2026, 11, 27);
        final first = VariantProgress(
          id: 'progress',
          userId: 'u',
          variantId: variant.id,
          direction: QuizDirection.frToKo,
          reps: 1,
          createdAt: now,
          updatedAt: now,
        );
        if (progress) {
          await sender(datasource).pushAll();
          await db.progressDao.upsertLocal(first.toLocalCompanion());
        }
        armed = true;
        final firstDrain = sender(datasource).pushAll();
        await oldRequest.future.timeout(const Duration(seconds: 2));
        expect(await firstDrain, 0);
        if (progress) {
          await db.progressDao.upsertLocal(
            first.copyWith(reps: 2).toLocalCompanion(),
          );
        } else {
          await repo.renameList(list.id, 'After timeout');
        }
        // A new sync instance reads the same durable installation sequence.
        expect(await sender(datasource).pushAll(), greaterThan(0));
        expect(requests, hasLength(2));
        expect(
          requests.first.headers['x-ponderin-sync-writer'],
          requests.last.headers['x-ponderin-sync-writer'],
        );
        expect(
          appliedSequence,
          greaterThan(
            int.parse(requests.first.headers['x-ponderin-sync-sequence']!),
          ),
        );
        letOldCommit.complete();
        await oldFinished.future.timeout(const Duration(seconds: 2));
        if (progress) {
          expect(stored!['reps'], 2);
          expect((await db.progressDao.getById(first.id))?.isSynced, isTrue);
        } else {
          expect(stored!['name'], 'After timeout');
          expect(
            (await db.vocabularyListDao.getById(list.id))?.isSynced,
            isTrue,
          );
        }
      },
    );
  }

  test(
    'one pull deadline preserves received rows and stops after a silent list',
    () async {
      final requests = <String>[];
      final silent = Completer<http.Response>();
      final datasource = remote((request) async {
        final table = request.url.pathSegments.last;
        if (table == 'vocabulary_pull_revision') return _reply(request, 0);
        final list = _conceptList(request);
        requests.add(list ?? table);
        if (table == 'vocabulary_pull_inventory') {
          return _reply(request, [
            for (final id in ['a', 'b', 'c'])
              {..._timestamp, 'id': id, 'owner_id': 'u', 'name': 'Remote $id'},
          ]);
        }
        if (list == 'a') {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return _conceptReply(request, [
            {
              ..._timestamp,
              'id': 'first-concept',
              'list_id': 'a',
              'word_variants': [],
            },
          ]);
        }
        return silent.future;
      });
      final repo = repository(
        datasource,
        restoreTimeout: const Duration(milliseconds: 450),
      );
      await expectLater(
        repo.syncFromRemote().timeout(const Duration(seconds: 2)),
        throwsA(isA<NetworkException>()),
      );
      expect(requests, ['vocabulary_pull_inventory', 'a', 'b']);
      expect(
        (await repo.watchMyLists().first).map((list) => list.id),
        unorderedEquals(['a', 'b', 'c']),
      );
      expect((await db.conceptDao.getById('first-concept'))?.listId, 'a');
      expect((await db.vocabularyListDao.getById('a'))?.wordCount, 1);
      final offlineStarter = (await repo.importFromJson({
        'list': {'name': 'Offline starter', 'seed_id': 'starter-offline:fr>ko'},
      }, origin: 'starter')).valueOrNull!;
      expect(
        await db.vocabularyListDao.isStarterDraftHeld(offlineStarter.id),
        isTrue,
      );
      expect(silent.isCompleted, isFalse);
    },
  );

  test(
    'reopening SQLite skips committed list content and retries a timed-out list',
    () async {
      final requests = <String>[];
      final firstIncompletePage = Completer<http.Response>();
      var stallIncompletePage = true;
      final datasource = remote((request) async {
        final table = request.url.pathSegments.last;
        if (table == 'vocabulary_pull_revision') return _reply(request, 0);
        final list = _conceptList(request);
        requests.add(list ?? table);
        if (table == 'vocabulary_pull_inventory') {
          return _reply(request, [
            for (var index = 0; index < 25; index++)
              {
                ..._timestamp,
                'id': 'list-$index',
                'owner_id': 'u',
                'name': 'List $index',
              },
          ]);
        }
        if (table == _conceptEndpoint) {
          if (list == 'list-1' && stallIncompletePage) {
            return firstIncompletePage.future;
          }
          return _conceptReply(request, [
            {
              ..._timestamp,
              'id': 'concept-$list',
              'list_id': list!,
              'word_variants': [],
            },
          ]);
        }
        return _reply(request, []);
      }, pageTimeout: const Duration(milliseconds: 260));

      final directory = await Directory.systemTemp.createTemp(
        'ponderin-pull-test',
      );
      final file = File('${directory.path}/cache.sqlite');
      var device = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() async {
        await device.close();
        await file.delete();
        await directory.delete();
      });
      // Only the first incomplete list stalls its HTTP page. The earlier
      // response can be applied without relying on a wall-clock head start.
      await expectLater(
        repository(
          datasource,
          device: device,
        ).syncFromRemote().timeout(const Duration(seconds: 2)),
        throwsA(isA<NetworkException>()),
      );
      expect(requests, ['vocabulary_pull_inventory', 'list-0', 'list-1']);
      expect(firstIncompletePage.isCompleted, isFalse);
      final checkpoint = await _pullCheckpoint(device);
      expect(checkpoint, containsPair('listsComplete', true));
      expect(checkpoint, containsPair('contentsDone', 1));
      expect(checkpoint, containsPair('progressComplete', false));
      expect(
        (await device.conceptDao.getById('concept-list-0'))?.listId,
        'list-0',
      );
      expect(await device.conceptDao.getById('concept-list-1'), isNull);

      await device.close();
      device = AppDatabase.forTesting(NativeDatabase(file));
      stallIncompletePage = false;
      await repository(
        datasource,
        device: device,
      ).syncFromRemote().timeout(const Duration(seconds: 2));
      expect(
        requests.where((request) => request == 'vocabulary_pull_inventory'),
        hasLength(1),
      );
      expect(requests.where((request) => request == 'list-0'), hasLength(1));
      expect(requests.where((request) => request == 'list-1'), hasLength(2));
      expect(requests[3], 'list-1');
      expect(requests.last, 'variant_progress');
      expect(
        (await device.conceptDao.getById('concept-list-0'))?.listId,
        'list-0',
      );
      expect(
        (await device.conceptDao.getById('concept-list-1'))?.listId,
        'list-1',
      );
      expect(
        (await device.conceptDao.getById('concept-list-24'))?.listId,
        'list-24',
      );
    },
  );

  test(
    'committed list, concept and FSRS pages resume by ID after later timeouts',
    () async {
      final requests = <(String, String?)>[];
      const list = 'list';
      const firstVariant = 'first-variant';
      const finalVariant = 'final-variant';
      const inventoryEndpoint = 'vocabulary_pull_inventory';
      const progressEndpoint = 'variant_progress';
      const inventoryAfter = 'archived-499';
      const conceptsAfter = 'concept-499';
      const progressAfter = 'progress-499';
      (String, String)? blockedPage = (inventoryEndpoint, inventoryAfter);
      final silent = Completer<http.Response>();
      final datasource = remote((request) async {
        final table = request.url.pathSegments.last;
        if (table == 'vocabulary_pull_revision') return _reply(request, 0);
        final cursor = table == inventoryEndpoint || table == _conceptEndpoint
            ? jsonDecode(request.body)['p_after_id'] as String?
            : request.url.queryParameters['id'];
        final page = (table, cursor);
        requests.add(page);
        if (page == blockedPage) return silent.future;
        if (table == inventoryEndpoint) {
          if (cursor == null) {
            return _reply(request, [
              for (var index = 0; index < 500; index++)
                {
                  ..._timestamp,
                  'id': 'archived-$index',
                  'owner_id': 'u',
                  'name': 'Archived $index',
                  'is_deleted': true,
                },
            ]);
          }
          return _reply(request, [
            {
              ..._timestamp,
              'id': list,
              'owner_id': 'u',
              'name': 'Large content',
            },
          ]);
        }
        if (table == _conceptEndpoint) {
          if (cursor == null) {
            return _conceptReply(request, [
              for (var index = 0; index < 500; index++)
                {
                  ..._timestamp,
                  'id': 'concept-$index',
                  'list_id': list,
                  'word_variants': [
                    if (index == 0)
                      {
                        ..._timestamp,
                        'id': firstVariant,
                        'concept_id': 'concept-0',
                        'word': 'salut',
                        'lang_code': 'fr',
                      },
                  ],
                },
            ]);
          }
          return _conceptReply(request, [
            {
              ..._timestamp,
              'id': 'concept-last',
              'list_id': list,
              'word_variants': [
                {
                  ..._timestamp,
                  'id': finalVariant,
                  'concept_id': 'concept-last',
                  'word': 'bonjour',
                  'lang_code': 'fr',
                },
              ],
            },
          ]);
        }
        if (cursor == null) {
          return _reply(request, [
            _remoteProgress(
              list,
            ).copyWith(id: 'progress-0', variantId: firstVariant).toRemoteMap(),
            for (var index = 1; index < 500; index++)
              {'id': 'progress-$index', 'user_id': 'unrelated'},
          ]);
        }
        return _reply(request, [
          _remoteProgress(list)
              .copyWith(id: 'progress-last', variantId: finalVariant)
              .toRemoteMap(),
        ]);
      }, pageTimeout: const Duration(milliseconds: 260));

      Future<void> expectTimeoutWithCheckpoint(String committedAfter) async {
        await expectLater(
          repository(datasource).syncFromRemote(),
          throwsA(isA<NetworkException>()),
        );
        expect(requests.last, blockedPage);
        expect(
          await _pullCheckpoint(db),
          containsPair('afterId', committedAfter),
        );
      }

      await expectTimeoutWithCheckpoint(inventoryAfter);
      expect(
        (await db.vocabularyListDao.getById(inventoryAfter))?.isDeleted,
        isTrue,
      );
      expect(await db.vocabularyListDao.getById(list), isNull);

      blockedPage = (_conceptEndpoint, conceptsAfter);
      await expectTimeoutWithCheckpoint(conceptsAfter);
      expect(await db.conceptDao.getConceptsByList(list), hasLength(500));
      expect(await db.conceptDao.getById('concept-last'), isNull);

      blockedPage = (progressEndpoint, 'gt.$progressAfter');
      await expectTimeoutWithCheckpoint(progressAfter);
      expect(
        (await db.progressDao.getById('progress-0'))?.variantId,
        firstVariant,
      );
      expect(await db.progressDao.getById('progress-last'), isNull);

      blockedPage = null;
      await repository(datasource).syncFromRemote();
      expect(requests, [
        (inventoryEndpoint, null),
        (inventoryEndpoint, inventoryAfter),
        (inventoryEndpoint, inventoryAfter),
        (_conceptEndpoint, null),
        (_conceptEndpoint, conceptsAfter),
        (_conceptEndpoint, conceptsAfter),
        (progressEndpoint, null),
        (progressEndpoint, 'gt.$progressAfter'),
        (progressEndpoint, 'gt.$progressAfter'),
      ]);
      expect(await db.conceptDao.getConceptsByList(list), hasLength(501));
      expect((await db.progressDao.getById('progress-last'))?.reps, 4);
    },
  );

  test('a reopened pull catches up a tombstone and an insertion behind its '
      'list cursor before it reports completion', () async {
    const deleted = 'list-m';
    const tail = 'list-z';
    const inserted = 'list-a';
    const variant = 'variant-list-m';
    final silent = Completer<http.Response>();
    final silentProgress = Completer<http.Response>();
    final requests = <String>[];
    var pauseTail = false;
    var pauseProgress = false;
    var revision = 1;
    final now = DateTime.utc(2026, 11, 27);
    final progress = VariantProgress(
      id: 'old-progress',
      userId: 'u',
      variantId: variant,
      direction: QuizDirection.frToKo,
      reps: 4,
      createdAt: now,
      updatedAt: now,
    );
    Map<String, dynamic> listRow(String id, {bool isDeleted = false}) => {
      ..._timestamp,
      'id': id,
      'owner_id': 'u',
      'name': id,
      'is_deleted': isDeleted,
    };
    final datasource = remote((request) async {
      final table = request.url.pathSegments.last;
      requests.add(table);
      switch (table) {
        case 'vocabulary_pull_revision':
          return _reply(request, revision);
        case 'vocabulary_pull_inventory':
          return _reply(request, [listRow(deleted), listRow(tail)]);
        case 'vocabulary_pull_changed_lists':
          expect(jsonDecode(request.body), {
            'p_owner_id': 'u',
            'p_after': 1,
            'p_through': 3,
          });
          return _reply(request, [
            {'revision': 2, 'value': listRow(deleted, isDeleted: true)},
            {'revision': 3, 'value': listRow(inserted)},
          ]);
        case _conceptEndpoint:
          final list = _conceptList(request)!;
          if (pauseTail && list == tail) return silent.future;
          if (list == tail) return _reply(request, []);
          return _conceptReply(request, [
            {
              ..._timestamp,
              'id': 'concept-$list',
              'list_id': list,
              'word_variants': [
                {
                  ..._timestamp,
                  'id': 'variant-$list',
                  'concept_id': 'concept-$list',
                  'word': 'bonjour',
                  'lang_code': 'fr',
                },
              ],
            },
          ]);
        case 'variant_progress':
          return _reply(request, [progress.toRemoteMap()]);
        case 'vocabulary_pull_changed_progress':
          if (pauseProgress) return silentProgress.future;
          // A stale progress update from before the deletion cannot restore
          // the now-deleted branch's FSRS row.
          return _reply(request, [
            {'revision': 2, 'value': progress.copyWith(reps: 5).toRemoteMap()},
          ]);
        default:
          fail('Unexpected request ${request.url}');
      }
    });
    final directory = await Directory.systemTemp.createTemp(
      'ponderin-catchup-test',
    );
    final file = File('${directory.path}/cache.sqlite');
    var device = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await device.close();
      await file.delete();
      await directory.delete();
    });
    await repository(datasource, device: device).syncFromRemote();
    expect((await device.progressDao.getById(progress.id))?.reps, 4);

    pauseTail = true;
    await expectLater(
      repository(
        datasource,
        device: device,
        restoreTimeout: const Duration(milliseconds: 200),
      ).syncFromRemote(),
      throwsA(isA<NetworkException>()),
    );
    expect(silent.isCompleted, isFalse);
    expect(
      (await device.vocabularyListDao.getById(deleted))?.isDeleted,
      isFalse,
    );
    await device.close();
    device = AppDatabase.forTesting(NativeDatabase(file));
    revision = 3;
    pauseTail = false;
    pauseProgress = true;
    requests.clear();

    await expectLater(
      repository(
        datasource,
        device: device,
        restoreTimeout: const Duration(milliseconds: 200),
      ).syncFromRemote(),
      throwsA(isA<NetworkException>()),
    );
    expect(requests, [
      _conceptEndpoint,
      'variant_progress',
      'vocabulary_pull_revision',
      'vocabulary_pull_changed_lists',
      _conceptEndpoint,
      'vocabulary_pull_changed_progress',
    ]);
    expect(silentProgress.isCompleted, isFalse);
    await device.close();
    device = AppDatabase.forTesting(NativeDatabase(file));
    pauseProgress = false;
    requests.clear();

    await repository(datasource, device: device).syncFromRemote();
    expect(requests, [
      'vocabulary_pull_changed_progress',
      'vocabulary_pull_revision',
    ]);
    expect(
      (await device.vocabularyListDao.getById(deleted))?.isDeleted,
      isTrue,
    );
    expect(
      (await device.conceptDao.getById('concept-$deleted'))?.isDeleted,
      isTrue,
    );
    expect(await device.progressDao.getById(progress.id), isNull);
    expect((await device.vocabularyListDao.getById(inserted))?.wordCount, 1);
    expect(
      (await device.conceptDao.getById('concept-$inserted'))?.listId,
      inserted,
    );
  });

  test('progress before its variant persists across a closed SQLite database '
      'and catch-up windows', () async {
    const earlierList = 'list-a';
    const laterList = 'list-z';
    final progress = _remoteProgress(earlierList);
    final silent = Completer<http.Response>();
    final windows = <(String, int, int)>[];
    var fenceReads = 0;
    var inventoryReads = 0;
    var reopened = false;
    final datasource = remote((request) async {
      final table = request.url.pathSegments.last;
      switch (table) {
        case 'vocabulary_pull_revision':
          if (reopened) return _reply(request, 4);
          return switch (++fenceReads) {
            1 => _reply(request, 1),
            2 => _reply(request, 3),
            _ => silent.future,
          };
        case 'vocabulary_pull_inventory':
          inventoryReads++;
          return _reply(request, [_remoteList(laterList)]);
        case _conceptEndpoint:
          final list = _conceptList(request);
          return _conceptReply(
            request,
            list == earlierList ? [_remoteConcept(earlierList)] : [],
          );
        case 'variant_progress':
          return _reply(request, []);
        case 'vocabulary_pull_changed_lists':
        case 'vocabulary_pull_changed_progress':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final after = body['p_after'] as int;
          final through = body['p_through'] as int;
          windows.add((table, after, through));
          if (table == 'vocabulary_pull_changed_lists') {
            return _reply(request, [
              // The list changed again after the first bound was captured.
              // Its single journal target now belongs to the second window.
              if (through == 4)
                {'revision': 4, 'value': _remoteList(earlierList)},
            ]);
          }
          return _reply(request, [
            if (through == 3) {'revision': 3, 'value': progress.toRemoteMap()},
          ]);
        default:
          fail('Unexpected request ${request.url}');
      }
    });
    final directory = await Directory.systemTemp.createTemp(
      'ponderin-progress-window',
    );
    final file = File('${directory.path}/cache.sqlite');
    var device = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await device.close();
      await file.delete();
      await directory.delete();
    });
    await expectLater(
      repository(
        datasource,
        device: device,
        restoreTimeout: const Duration(milliseconds: 350),
      ).syncFromRemote(),
      throwsA(isA<NetworkException>()),
    );
    expect(fenceReads, 3);
    expect(await device.progressDao.getById(progress.id), isNull);
    expect(await device.vocabularyListDao.getById(earlierList), isNull);
    await device.close();
    device = AppDatabase.forTesting(NativeDatabase(file));
    reopened = true;

    await repository(datasource, device: device).syncFromRemote();
    expect(inventoryReads, 1);
    expect(windows, [
      ('vocabulary_pull_changed_lists', 1, 3),
      ('vocabulary_pull_changed_progress', 1, 3),
      ('vocabulary_pull_changed_lists', 3, 4),
      ('vocabulary_pull_changed_progress', 3, 4),
    ]);
    expect((await device.vocabularyListDao.getById(earlierList))?.wordCount, 1);
    final restored = await device.progressDao.getById(progress.id);
    expect(restored?.variantId, progress.variantId);
    expect(restored?.reps, 4);
    expect(restored?.isSynced, isTrue);
  });

  test('an inventory started after an administrative purge removes the cached '
      'branch and its FSRS, even from an older checkpoint', () async {
    const list = 'list-admin-purged';
    final progress = _remoteProgress(list);
    final requests = <String>[];
    var purged = false;
    final datasource = remote((request) async {
      final table = request.url.pathSegments.last;
      requests.add(table);
      return switch (table) {
        'vocabulary_pull_revision' => _reply(request, purged ? 5 : 4),
        'vocabulary_pull_inventory' => _reply(request, [
          _remoteList(list, isDeleted: purged),
        ]),
        _conceptEndpoint => _conceptReply(request, [_remoteConcept(list)]),
        'variant_progress' => _reply(
          request,
          purged ? [] : [progress.toRemoteMap()],
        ),
        _ => fail('Unexpected request ${request.url}'),
      };
    });
    final directory = await Directory.systemTemp.createTemp(
      'ponderin-purged-list',
    );
    final file = File('${directory.path}/cache.sqlite');
    var device = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await device.close();
      await file.delete();
      await directory.delete();
    });
    await repository(datasource, device: device).syncFromRemote();
    expect((await device.progressDao.getById(progress.id))?.reps, 4);
    await device.customStatement(
      'INSERT INTO shared_import_bootstrap (id, snapshot) VALUES (?, ?)',
      [
        'vocabulary-pull:u',
        jsonEncode({
          'throughRevision': 5,
          'listsComplete': true,
          'progressComplete': true,
        }),
      ],
    );
    await device.close();
    purged = true;
    device = AppDatabase.forTesting(NativeDatabase(file));
    requests.clear();

    await repository(datasource, device: device).syncFromRemote();
    expect(requests, [
      'vocabulary_pull_revision',
      'vocabulary_pull_inventory',
      'variant_progress',
      'vocabulary_pull_revision',
    ]);
    expect((await device.vocabularyListDao.getById(list))?.isDeleted, isTrue);
    expect(
      (await device.conceptDao.getById('concept-$list'))?.isDeleted,
      isTrue,
    );
    expect(await device.progressDao.getById(progress.id), isNull);
    expect(
      await repository(datasource, device: device).watchMyLists().first,
      isEmpty,
    );
  });

  for (final duringPull in [false, true]) {
    test('a ${duringPull ? 'delta' : 'full'} pull removes purged children '
        'and their progress from a reopened cache', () async {
      const list = 'active-list';
      const oldConcept = 'concept-purged';
      const activeConcept = 'concept-retained';
      const oldVariant = 'variant-purged';
      const activeVariant = 'variant-retained';
      const childOfDeleted = 'variant-of-purged-concept';
      final obsoleteProgress = _remoteProgress(
        'purged-word',
      ).copyWith(variantId: oldVariant);
      final cascadeProgress = _remoteProgress(
        'purged-concept',
      ).copyWith(variantId: childOfDeleted);
      final retainedProgress = _remoteProgress(
        'retained',
      ).copyWith(variantId: activeVariant);
      Map<String, dynamic> variant(String id, String concept, bool deleted) => {
        ..._timestamp,
        'id': id,
        'concept_id': concept,
        'is_deleted': deleted,
        if (!deleted) 'word': 'bonjour',
        if (!deleted) 'lang_code': 'fr',
      };
      var reopened = false;
      var fenceReads = 0;
      var catchups = 0;
      bool getShowsPurge() => reopened && (!duringPull || fenceReads >= 2);
      final datasource = remote((request) async {
        switch (request.url.pathSegments.last) {
          case 'vocabulary_pull_revision':
            if (reopened) fenceReads++;
            return _reply(request, getShowsPurge() ? 6 : 4);
          case 'vocabulary_pull_inventory':
            return _reply(request, [_remoteList(list)]);
          case _conceptEndpoint:
            expect(_conceptList(request), list);
            final purged = getShowsPurge();
            return _conceptReply(request, [
              {
                ..._timestamp,
                'id': oldConcept,
                'list_id': list,
                'is_deleted': purged,
                'word_variants': [
                  if (!purged) variant(childOfDeleted, oldConcept, false),
                ],
              },
              {
                ..._timestamp,
                'id': activeConcept,
                'list_id': list,
                'word_variants': [
                  variant(oldVariant, activeConcept, purged),
                  variant(activeVariant, activeConcept, false),
                ],
              },
            ]);
          case 'variant_progress':
            return _reply(request, [
              if (!getShowsPurge()) obsoleteProgress.toRemoteMap(),
              if (!getShowsPurge()) cascadeProgress.toRemoteMap(),
              retainedProgress.toRemoteMap(),
            ]);
          case 'vocabulary_pull_changed_lists':
            catchups++;
            return _reply(request, [
              {'revision': 6, 'value': _remoteList(list)},
            ]);
          case 'vocabulary_pull_changed_progress':
            return _reply(request, []);
          default:
            fail('Unexpected request ${request.url}');
        }
      });

      final directory = await Directory.systemTemp.createTemp(
        'ponderin-child-purge',
      );
      final file = File('${directory.path}/cache.sqlite');
      var device = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() async {
        await device.close();
        await file.delete();
        await directory.delete();
      });
      await repository(datasource, device: device).syncFromRemote();
      expect((await device.vocabularyListDao.getById(list))?.wordCount, 2);
      expect(await device.progressDao.getById(obsoleteProgress.id), isNotNull);
      expect(await device.progressDao.getById(cascadeProgress.id), isNotNull);
      await device.close();
      device = AppDatabase.forTesting(NativeDatabase(file));
      reopened = true;

      await repository(datasource, device: device).syncFromRemote();
      expect(catchups, duringPull ? 1 : 0);
      final parent = await device.vocabularyListDao.getById(list);
      expect(parent?.isDeleted, isFalse);
      expect(parent?.wordCount, 1);
      expect((await device.conceptDao.getById(oldConcept))?.isDeleted, isTrue);
      expect(
        (await device.conceptDao.getVariantById(oldVariant))?.isDeleted,
        isTrue,
      );
      expect(await device.progressDao.getById(obsoleteProgress.id), isNull);
      expect(await device.progressDao.getById(cascadeProgress.id), isNull);
      expect((await device.progressDao.getById(retainedProgress.id))?.reps, 4);
    });
  }

  test('an account change discards the first audio response and stops the '
      'second queued render before it reaches the network', () async {
    late SupabaseClient client;
    final requests = <http.Request>[];
    final firstAudio = Completer<http.Request>();
    final firstReply = Completer<http.Response>();
    final secondReply = Completer<http.Response>();
    final datasource = remote((request) async {
      if (request.url.pathSegments.last != 'audio-provision') {
        return _reply(request, jsonDecode(request.body) as Map);
      }
      requests.add(request);
      if (!firstAudio.isCompleted) {
        firstAudio.complete(request);
        return firstReply.future;
      }
      return secondReply.future;
    }, captureClient: (value) => client = value);
    await _useSession(client, 'u');
    final tokenA = client.auth.currentSession!.accessToken;
    final repo = repository(datasource);
    final list = (await repo.createList(name: 'Audio list')).valueOrNull!;
    final concept = (await repo.addConceptWithVariants(
      listId: list.id,
      wordA: 'chat',
      wordB: '고양이',
    )).valueOrNull!;
    final before = await db.conceptDao.getVariantsByConcept(concept.id);

    expect(await sender(datasource).pushAll(), 4);
    final first = await firstAudio.future.timeout(const Duration(seconds: 2));
    expect(first.headers['authorization'], 'Bearer $tokenA');
    final firstId = jsonDecode(first.body)['variant_id'] as String;
    final firstWord = before.singleWhere((word) => word.id == firstId);
    await _useSession(client, 'b');
    expect(client.auth.currentUser?.id, 'b');
    firstReply.complete(
      _reply(first, {
        'status': 'ready',
        'audio_path': 'users/u/$firstId/new-path.mp3',
        'word': firstWord.word,
        'lang_code': firstWord.langCode,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(requests, [first]);
    expect(secondReply.isCompleted, isFalse);
    final after = await db.conceptDao.getVariantsByConcept(concept.id);
    expect(
      {for (final word in after) word.id: word.audioPath},
      {for (final word in before) word.id: word.audioPath},
    );
  });
}
