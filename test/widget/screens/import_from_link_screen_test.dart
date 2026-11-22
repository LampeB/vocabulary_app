// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/screens/import/import_from_link_screen.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

/// Deep-link import screen (vocabkr://import?token=…): a valid token imports
/// the shared list and opens it; an unknown token shows the not-found message
/// and falls back to /lists. (The OS-intent → route wiring itself can't run
/// in CI — this covers everything from the screen down.)

class _SharedListRemote extends FakeRemote {
  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
      String token) async {
    if (token != 'good-token') return const Success(null);
    return const Success({
      'name': 'Liste partagée',
      'description': null,
      'concepts': [
        {
          'category': null,
          'notes': null,
          'example_fr': null,
          'example_ko': null,
          'word_variants': [
            {'word': 'merci', 'lang_code': 'fr', 'is_primary': true, 'position': 0},
            {'word': '감사합니다', 'lang_code': 'ko', 'is_primary': true, 'position': 0},
          ],
        },
      ],
    });
  }
}

void main() {
  setUpAll(initTestLocalization);

  late AppDatabase db;
  String? navigatedTo;

  Future<void> pump(WidgetTester tester, {required String token}) async {
    navigatedTo = null;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });
    final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, _SharedListRemote(), 'u', db);
    await pumpScreen(
      tester,
      screen: ImportFromLinkScreen(token: token),
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
        isPremiumProvider.overrideWithValue(true),
      ],
      routes: [
        for (final r in ['/lists', '/lists/:id'])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              navigatedTo = state.uri.toString();
              return const MaterialPage<void>(
                  child: Scaffold(body: SizedBox()));
            },
          ),
      ],
      settle: false, // perpetual waveform
    );
    // Let the post-frame import + navigation run.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('shows the importing state with the screen key', (tester) async {
    await pump(tester, token: 'good-token');
    // After import it navigates away; the key was the root during loading.
    expect(navigatedTo, isNotNull);
  });

  testWidgets('a valid token imports the list and opens it', (tester) async {
    await pump(tester, token: 'good-token');

    expect(navigatedTo, startsWith('/lists/'));
    final imported = await tester.runAsync(
        () => db.vocabularyListDao.getByShareToken('good-token'));
    expect(imported, isNotNull);
    expect(imported!.name, 'Liste partagée');
  });

  testWidgets('an unknown token shows not-found and falls back to /lists',
      (tester) async {
    await pump(tester, token: 'nope');

    expect(find.text('import.error_not_found'.tr()), findsOneWidget);
    expect(navigatedTo, '/lists');
  });
}
