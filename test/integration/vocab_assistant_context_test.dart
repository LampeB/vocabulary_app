// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/network/authenticated_edge_session.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocab_assistant_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';

import '../helpers/fake_remote.dart';

Map<String, dynamic> _sessionData(String id, {int version = 1}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'exp': expiry, 'sub': id, 'version': version})}.test',
    'refresh_token': 'test-refresh-$id-$version',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'created_at': '2026-11-27T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  };
}

void main() {
  late List<http.Request> requests;
  late List<String?> sessionUsersAtSend;
  late VocabAssistantDataSource assistant;
  late SupabaseClient client;
  Future<Map<String, dynamic>> Function(http.Request)? refreshSession;

  Future<void> authenticate(String user) async {
    await client.auth.recoverSession(jsonEncode(_sessionData(user)));
  }

  setUp(() async {
    requests = [];
    sessionUsersAtSend = [];
    refreshSession = null;
    client = SupabaseClient(
      'https://assistant.example.test',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        sessionUsersAtSend.add(client.auth.currentUser?.id);
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(await refreshSession!(request)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"translations":[{"text":"고양이"}],"theme":"Chat","suggestions":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.dispose);
    assistant = VocabAssistantDataSource(client);
    await authenticate('a');
  });

  for (final translate in [true, false]) {
    test(
      'an account change during SDK encoding cannot authorize ${translate ? 'translation' : 'suggestions'} with the new session',
      () async {
        final originalToken = client.auth.currentSession!.accessToken;
        final operation = translate
            ? assistant.translate(
                word: 'chat',
                sourceLang: 'fr',
                targetLang: 'ko',
              )
            : assistant.suggest(
                sourceLang: 'fr',
                targetLang: 'ko',
                existingPairs: const [
                  WordPairSuggestion(source: 'chat', target: '고양이'),
                ],
              );
        await authenticate('b');
        final result = await operation;
        expect(result.exceptionOrNull, isA<PermissionException>());
        expect(client.auth.currentUser?.id, 'b');
        final request = requests.single;
        expect(request.url.path, '/functions/v1/vocab-assistant');
        expect(sessionUsersAtSend, ['b']);
        expect(request.headers['authorization'], 'Bearer $originalToken');
        expect(
          jsonDecode(request.body)['mode'],
          translate ? 'translate' : 'suggest',
        );
      },
    );
  }

  test('an expired bearer can refresh within the same session', () async {
    client.auth.currentSession!.expiresAt = 0;
    final renewed = _sessionData('a', version: 2);
    refreshSession = (request) async {
      expect(jsonDecode(request.body)['refresh_token'], 'test-refresh-a-1');
      return renewed;
    };

    final result = await assistant.translate(
      word: 'chat',
      sourceLang: 'fr',
      targetLang: 'ko',
    );
    expect(result.isSuccess, isTrue);
    expect(requests.map((request) => request.url.path), [
      '/auth/v1/token',
      '/functions/v1/vocab-assistant',
    ]);
    expect(
      requests.last.headers['authorization'],
      'Bearer ${renewed['access_token']}',
    );
  });

  test(
    'a session change while a refresh is pending stops the function call',
    () async {
      client.auth.currentSession!.expiresAt = 0;
      final refreshRequested = Completer<void>();
      final releaseRefresh = Completer<Map<String, dynamic>>();
      refreshSession = (_) {
        refreshRequested.complete();
        return releaseRefresh.future;
      };
      final operation = assistant.suggest(
        sourceLang: 'fr',
        targetLang: 'ko',
        existingPairs: const [],
      );
      try {
        await refreshRequested.future.timeout(const Duration(seconds: 2));
        await authenticate('b');
      } finally {
        releaseRefresh.complete(_sessionData('a', version: 2));
      }

      expect((await operation).exceptionOrNull, isA<PermissionException>());
      expect(requests.map((request) => request.url.path), ['/auth/v1/token']);
    },
  );

  test(
    'a benchmark session refuses later samples after an intervening account',
    () async {
      final benchmark = AuthenticatedEdgeSession(client);
      addTearDown(benchmark.close);
      await benchmark.invoke('whisper-proxy', body: {'audio_base64': 'AAAA'});

      final readFile = Completer<String>();
      final pending = readFile.future.then(
        (audio) => benchmark.invoke(
          'elevenlabs-stt-proxy',
          body: {'audio_base64': audio},
        ),
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<PermissionException>()),
      );
      await authenticate('b');
      await authenticate('a');
      readFile.complete('BBBB');
      await rejected;

      expect(client.auth.currentUser?.id, 'a');
      expect(requests.map((request) => request.url.path), [
        '/functions/v1/whisper-proxy',
      ]);
    },
  );

  test(
    'serialized translation omits an absent theme and sends a set theme',
    () async {
      final withoutTheme = await assistant.translate(
        word: 'chat',
        sourceLang: 'fr',
        targetLang: 'ko',
        existingWords: ['animal'],
      );
      final withTheme = await assistant.translate(
        word: 'chat',
        sourceLang: 'fr',
        targetLang: 'ko',
        theme: 'animaux',
      );

      expect(withoutTheme.valueOrNull?.translations.single.text, '고양이');
      expect(withTheme.isSuccess, isTrue);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/functions/v1/vocab-assistant');
      final body = jsonDecode(requests.first.body) as Map;
      expect(body.containsKey('theme'), isFalse);
      expect(body['existingWords'], ['animal']);
      expect(jsonDecode(requests.last.body)['theme'], 'animaux');
    },
  );

  test(
    'a large SQLite list sends at most 80 intact source/target pairs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
      final providers = ProviderContainer(
        overrides: [
          vocabularyRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'u',
              email: '',
              username: 'owner',
              createdAt: DateTime.utc(2026),
            ),
          ),
        ],
      );
      addTearDown(providers.dispose);
      final list = (await repo.createList(
        name: 'Large list',
        langA: 'en',
        langB: 'ja',
      )).valueOrNull!;
      final actions = providers.read(listActionsProvider.notifier);
      final expectedPair = (list.langA, list.langB);
      expect(
        await actions.getSuggestionContext(list.id, expectedPair: expectedPair),
        isEmpty,
      );
      for (var index = 0; index < 95; index++) {
        final created = await repo.addConceptWithVariants(
          listId: list.id,
          wordA: 'word $index',
          wordB: '単語 $index',
          langA: 'en',
          langB: 'ja',
        );
        expect(created.isSuccess, isTrue);
      }
      final sample = (await actions.getSuggestionContext(
        list.id,
        expectedPair: expectedPair,
      ))!;
      expect(sample, hasLength(80));
      expect(
        await actions.getSuggestionContext(list.id, expectedPair: ('fr', 'ko')),
        isNull,
      );
      final result = await assistant.suggest(
        sourceLang: list.langA,
        targetLang: list.langB,
        existingPairs: sample,
      );
      final request = requests.single;
      final body = jsonDecode(request.body) as Map;
      final sent = body['existingPairs'] as List;
      expect(result.isSuccess, isTrue);
      expect(body['sourceLang'], 'en');
      expect(body['targetLang'], 'ja');
      expect(sent, hasLength(80));
      expect(sent.map((pair) => pair['source']).toSet(), hasLength(80));
      for (final pair in sent) {
        final index = (pair['source'] as String).split(' ').last;
        expect(pair['target'], '単語 $index');
      }
      expect(request.bodyBytes.length, lessThanOrEqualTo(32768));
    },
  );

  test(
    'the actual suggestion body fits with multibyte and escaped fields',
    () async {
      final input = [
        WordPairSuggestion(source: 'x' * 257, target: '사용하지 않음'),
        const WordPairSuggestion(source: ' ', target: '사용하지 않음'),
        for (var index = 0; index < 90; index++)
          WordPairSuggestion(
            source: '${'한' * 230} "$index"',
            target: '${'字' * 250}$index',
          ),
        const WordPairSuggestion(source: 'chat', target: '고양이'),
      ];
      final response = await assistant.suggest(
        sourceLang: 'fr',
        targetLang: 'ko',
        existingPairs: input,
      );
      final request = requests.single;
      final sent = jsonDecode(request.body)['existingPairs'] as List;
      expect(response.isSuccess, isTrue);
      expect(request.bodyBytes.length, lessThanOrEqualTo(32768));
      expect(sent.length, inInclusiveRange(2, 79));
      expect(sent.first, {
        'source': input[2].source,
        'target': input[2].target,
      });
      expect(sent.last, {'source': 'chat', 'target': '고양이'});
    },
  );
}
