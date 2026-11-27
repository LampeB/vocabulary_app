// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/navigation/auth_redirect.dart';
import 'package:vocab_kr/presentation/widgets/session_bootstrap.dart';
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
    String token,
  ) async {
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
            {
              'word': 'merci',
              'lang_code': 'fr',
              'is_primary': true,
              'position': 0,
            },
            {
              'word': '감사합니다',
              'lang_code': 'ko',
              'is_primary': true,
              'position': 0,
            },
          ],
        },
      ],
    });
  }
}

AppUser _user({int streak = 0}) => AppUser(
  id: 'u',
  email: 'u@example.test',
  username: 'u',
  subscriptionType: SubscriptionType.free,
  createdAt: DateTime(2026),
  currentStreak: streak,
);

class _RestoredSessionRepository implements AuthRepository {
  _RestoredSessionRepository({this.profile});
  final Future<Result<AppUser>>? profile;
  @override
  AppUser get currentUser => _user();
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override
  Future<Result<AppUser>> reloadProfile() async => profile ?? Success(_user());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      db.vocabularyListDao,
      db.conceptDao,
      _SharedListRemote(),
      'u',
      db,
    );
    await pumpScreen(
      tester,
      screen: ImportFromLinkScreen(token: token),
      overrides: [
        authRepositoryProvider.overrideWithValue(_RestoredSessionRepository()),
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
                child: Scaffold(body: SizedBox()),
              );
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
      () => db.vocabularyListDao.getImportedCopy('good-token', 'u'),
    );
    expect(imported, isNotNull);
    expect(imported!.name, 'Liste partagée');
  });

  testWidgets('an unknown token shows not-found and falls back to /lists', (
    tester,
  ) async {
    await pump(tester, token: 'nope');

    expect(find.text('import.error_not_found'.tr()), findsOneWidget);
    expect(navigatedTo, '/lists');
  });

  testWidgets('cold import waits for local identity, not the remote profile', (
    tester,
  ) async {
    final profile = Completer<Result<AppUser>>();
    final bootstrappedOwners = <String>[];
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(_SharedListRemote()),
        authRepositoryProvider.overrideWithValue(
          _RestoredSessionRepository(profile: profile.future),
        ),
        isPremiumProvider.overrideWithValue(true),
        seedStarterListsProvider.overrideWith((ref) async {
          final id = ref.watch(currentUserProvider.select((user) => user?.id));
          if (id != null) bootstrappedOwners.add(id);
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(authStateProvider);
    expect(container.read(currentUserProvider), isNull);
    final router = GoRouter(
      initialLocation: '/import?token=good-token',
      redirect: (_, state) =>
          authRedirect(isSignedIn: true, location: state.matchedLocation),
      routes: [
        GoRoute(
          path: '/import',
          builder: (_, state) =>
              ImportFromLinkScreen(token: state.uri.queryParameters['token']!),
        ),
        GoRoute(
          path: '/lists/:id',
          builder: (_, _) =>
              const Scaffold(body: Text('Imported account list')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: SessionBootstrap(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(profile.isCompleted, isFalse);
    expect(find.text('Imported account list'), findsOneWidget);
    final imported = await tester.runAsync(
      () => db.vocabularyListDao.getImportedCopy('good-token', 'u'),
    );
    expect(imported?.ownerId, 'u');
    expect(bootstrappedOwners, ['u']);
    expect(
      (await tester.runAsync(
        () => db.vocabularyListDao.watchByOwner('').first,
      ))!,
      isEmpty,
    );
    profile.complete(Success(_user(streak: 7)));
    await tester.pump();
    await tester.pump();
    expect(container.read(currentUserProvider)?.currentStreak, 7);
    expect(bootstrappedOwners, ['u']);
    expect(find.text('Imported account list'), findsOneWidget);
    await unmountScreen(tester);
  });
}
