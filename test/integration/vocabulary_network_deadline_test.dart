import 'dart:async';
import 'dart:convert';

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

http.Response _reply(http.Request request, Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

const _timestamp = {
  'created_at': '2026-11-27T00:00:00Z',
  'updated_at': '2026-11-27T00:00:00Z',
};

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
      pageTimeout: const Duration(seconds: 4),
    );
  }

  VocabularyRepositoryImpl repository(
    VocabularyRemoteDataSource datasource, {
    Duration restoreTimeout = const Duration(seconds: 15),
  }) => VocabularyRepositoryImpl(
    db.vocabularyListDao,
    db.conceptDao,
    datasource,
    'u',
    db,
    restoreTimeout: restoreTimeout,
  );

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

  test(
    'a silent canonical acknowledgement read is a transport failure',
    () async {
      final methods = <String>[];
      final silent = Completer<http.Response>();
      final datasource = remote((request) async {
        methods.add(request.method);
        if (request.method == 'POST') return _reply(request, []);
        return silent.future;
      });
      final result = await datasource
          .upsertList({'id': 'list', 'owner_id': 'u'}, insertOnly: true)
          .timeout(const Duration(seconds: 2));
      expect(result.exceptionOrNull, isA<NetworkException>());
      expect(methods, ['POST', 'GET']);
      expect(silent.isCompleted, isFalse);
    },
  );

  test(
    'one pull deadline preserves received rows and stops after a silent list',
    () async {
      final requests = <String>[];
      final silent = Completer<http.Response>();
      final datasource = remote((request) async {
        final table = request.url.pathSegments.last;
        final list = request.url.queryParameters['list_id'];
        requests.add(list ?? table);
        if (table == 'vocabulary_lists') {
          return _reply(request, [
            for (final id in ['a', 'b', 'c'])
              {..._timestamp, 'id': id, 'owner_id': 'u', 'name': 'Remote $id'},
          ]);
        }
        if (list == 'eq.a') {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return _reply(request, [
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
      expect(requests, ['vocabulary_lists', 'eq.a', 'eq.b']);
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
