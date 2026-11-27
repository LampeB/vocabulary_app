import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';

import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

void main() {
  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets('one concept due in both directions is two cards in $locale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final raw = (await tester.runAsync(
        () => rootBundle.loadString('assets/translations/$locale.json'),
      ))!;
      final copy = jsonDecode(raw) as Map<String, dynamic>;
      final translations = Translations(copy);
      Localization.load(
        Locale(locale),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);
      late AppDatabase db;
      late VocabularyRepositoryImpl repo;
      await tester.runAsync(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        repo = VocabularyRepositoryImpl(
          db.vocabularyListDao,
          db.conceptDao,
          FakeRemote(),
          'u',
          db,
        );
        final list = (await repo.createList(name: 'One concept')).valueOrNull!;
        final concept = (await repo.addConceptWithVariants(
          listId: list.id,
          wordA: 'bonjour',
          wordB: '안녕하세요',
        )).valueOrNull!;
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        for (final direction in [QuizDirection.frToKo, QuizDirection.koToFr]) {
          final variant = variants.singleWhere(
            (v) => v.langCode == direction.questionLang,
          );
          await db.progressDao.upsert(
            VariantProgressTableCompanion.insert(
              id: 'p-${direction.name}',
              userId: 'u',
              variantId: variant.id,
              direction: direction.name,
              state: const Value('review'),
              nextReview: Value(DateTime(2000)),
              createdAt: DateTime(2000),
              updatedAt: DateTime(2000),
            ),
          );
        }
        expect((await db.conceptDao.getConceptsByList(list.id)).length, 1);
      });
      addTearDown(db.close);
      final label = (copy['v3.words_due'] as String).replaceAll('{count}', '2');
      for (final screen in [const DailyPathScreen(), const V3HomeScreen()]) {
        await pumpScreen(
          tester,
          screen: screen,
          settle: false,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vocabularyRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(
              AppUser(
                id: 'u',
                email: 'u@example.test',
                username: 'learner',
                createdAt: DateTime(2026),
              ),
            ),
            ruleStatusesProvider.overrideWith((ref, lang) async => []),
          ],
        );
        for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(label), findsWidgets);
        await unmountScreen(tester);
      }
    });
  }
}
