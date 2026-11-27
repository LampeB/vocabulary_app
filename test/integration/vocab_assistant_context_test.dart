// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocab_assistant_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';

import '../helpers/fake_remote.dart';

void main() {
  late List<http.Request> requests;
  late VocabAssistantDataSource assistant;

  setUp(() {
    requests = [];
    final client = SupabaseClient(
      'https://assistant.example.test',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"translations":[{"text":"고양이"}],"theme":"Chat","suggestions":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.dispose);
    assistant = VocabAssistantDataSource(client);
  });

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
        overrides: [vocabularyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(providers.dispose);
      final list = (await repo.createList(
        name: 'Large list',
        langA: 'en',
        langB: 'ja',
      )).valueOrNull!;
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
      final sample = await providers
          .read(listActionsProvider.notifier)
          .getSuggestionContext(list.id);
      expect(sample, hasLength(80));
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
