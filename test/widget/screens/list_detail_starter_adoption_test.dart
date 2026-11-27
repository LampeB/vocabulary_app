// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart'
    show VocabularyNetworkBudget;
import 'package:vocab_kr/data/models/concept_dto.dart';
import 'package:vocab_kr/data/models/vocabulary_list_dto.dart';
import 'package:vocab_kr/data/models/word_variant_dto.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';

import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

class _StarterRemote extends FakeRemote {
  late Map<String, dynamic> list;
  late Map<String, dynamic> concept;

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(
    String ownerId, {
    VocabularyNetworkBudget? budget,
  }) async => Success([list]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
    VocabularyNetworkBudget? budget,
  }) async => Success([concept]);
}

void main() {
  setUpAll(initTestLocalization);

  testWidgets('an open starter detail keeps its content and adds to the '
      'canonical list after adoption', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final remote = _StarterRemote();
    final repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      remote,
      'u',
      db,
    );
    const serverListId = 'historical-list';
    const serverConceptId = 'historical-concept';
    const serverVariantId = 'historical-fr';
    late String draftListId;
    late String draftConceptId;
    late String draftVariantId;
    await tester.runAsync(() async {
      final draft = (await repo.importFromJson(const {
        'list': {
          'name': 'Salutations hors ligne',
          'seedId': 'starter-greetings:fr>ko',
          'concepts': [
            {
              'seedId': 'hello',
              'variants': [
                {'word': 'Salut', 'langCode': 'fr'},
                {'word': '안녕하세요', 'langCode': 'ko'},
              ],
            },
          ],
        },
      }, origin: 'starter')).valueOrNull!;
      draftListId = draft.id;
      final concept = (await db.conceptDao.getConceptsByList(draft.id)).single;
      draftConceptId = concept.id;
      final variants = await db.conceptDao.getVariantsByConcept(concept.id);
      final fr = variants.singleWhere((variant) => variant.langCode == 'fr');
      draftVariantId = fr.id;
      remote.list = {
        ...draft.toRemoteMap(),
        'id': serverListId,
        'name': 'Salutations du serveur',
      };
      remote.concept = {
        ...concept.toRemoteMap(),
        'id': serverConceptId,
        'list_id': serverListId,
        'word_variants': [
          for (final variant in variants)
            {
              ...variant.toRemoteMap(),
              'id': variant.langCode == 'fr'
                  ? serverVariantId
                  : 'historical-ko',
              'concept_id': serverConceptId,
              if (variant.langCode == 'fr') ...{
                'word': 'Bonjour',
                'example': 'Bonjour à tous',
              },
            },
        ],
      };
    });

    await pumpScreen(
      tester,
      screen: ListDetailScreen(listId: draftListId),
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
        isPremiumProvider.overrideWithValue(true),
      ],
    );
    expect(find.text('Salutations hors ligne'), findsOneWidget);
    expect(find.text('Salut'), findsOneWidget);

    var restored = false;
    final pull = repo.syncFromRemote().whenComplete(() => restored = true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(restored, isTrue);
    await pull;
    expect(find.text('Salutations du serveur'), findsOneWidget);
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('Salut'), findsNothing);

    Finder byKey(String key) => find.byKey(ValueKey(key));
    await tester.tap(byKey(WidgetKeys.listDetailAddWord));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.addWordFr), 'Bonsoir');
    await tester.enterText(byKey(WidgetKeys.addWordKo), '안녕히 주무세요');
    await tester.tap(byKey(WidgetKeys.addWordConfirm));
    await tester.pumpAndSettle();
    expect(find.text('Bonsoir'), findsOneWidget);
    await unmountScreen(tester);

    await tester.runAsync(() async {
      expect(await db.vocabularyListDao.getById(draftListId), isNull);
      expect(await db.conceptDao.getConceptsByList(draftListId), isEmpty);
      expect(await db.conceptDao.getConceptsByList(serverListId), hasLength(2));
      final exported = (await repo.exportToJson(draftListId)).valueOrNull!;
      expect(exported['list']['name'], 'Salutations du serveur');
      expect(exported['list']['concepts'], hasLength(2));

      final edited = (await repo.updateVariantWord(
        draftVariantId,
        'Bonjour à vous',
      )).valueOrNull!;
      expect(edited.id, serverVariantId);
      expect(edited.example, 'Bonjour à tous');
      final extraVariant = (await repo.createVariant(
        conceptId: draftConceptId,
        word: 'Coucou',
        langCode: 'fr',
      )).valueOrNull!;
      expect(extraVariant.conceptId, serverConceptId);

      await repo.deleteList(draftListId);
      final unavailable = await repo.createConcept(listId: draftListId);
      expect(unavailable.exceptionOrNull, isA<NotFoundException>());
      expect(await db.conceptDao.getConceptsByList(draftListId), isEmpty);
    });
  });
}
