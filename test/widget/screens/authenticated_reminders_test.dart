import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vocab_kr/app.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';
import 'package:vocab_kr/presentation/screens/onboarding/welcome_screen.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';

import '../../helpers/pump_screen.dart';

class _BundledTranslations extends AssetLoader {
  const _BundledTranslations(this.translations);

  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      translations[locale.languageCode];
}

class _Profile extends AuthNotifier {
  final ready = Completer<AppUser>();

  @override
  Future<AppUser?> build() => ready.future;

  void studiedToday() {
    state = AsyncData(
      state.requireValue!.copyWith(lastStudyDate: DateTime.now()),
    );
  }
}

class _Reminders implements NotificationService {
  final daily = <(int, int, String?)>[];
  final warnings = <(int, String?)>[];
  int cancelledWarnings = 0;

  @override
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
    Locale? locale,
  }) async {
    daily.add((hour, minute, locale?.languageCode));
  }

  @override
  Future<void> scheduleStreakWarning(int streakDays, {Locale? locale}) async {
    warnings.add((streakDays, locale?.languageCode));
  }

  @override
  Future<void> cancelStreakWarning() async => cancelledWarnings++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _session(String accessToken) => {
  'access_token': accessToken,
  'refresh_token': 'local-refresh-token',
  'token_type': 'bearer',
  'user': {'id': 'learner', 'created_at': '2026-01-01T00:00:00Z'},
};

Future<void> _pumpApp(
  WidgetTester tester, {
  required _Reminders reminders,
  _Profile? profile,
  http.Client? httpClient,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1080, 2340);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'notif_daily_enabled': true,
    'notif_hour': 17,
    'notif_minute': 35,
    'notif_streak_enabled': true,
  });

  final messenger = tester.binding.defaultBinaryMessenger;
  for (final name in [
    'com.llfbandit.app_links/messages',
    'com.llfbandit.app_links/events',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  final translations = <String, Map<String, dynamic>>{};
  await tester.runAsync(() async {
    await EasyLocalization.ensureInitialized();
    for (final code in ['fr', 'ko']) {
      translations[code] =
          jsonDecode(
                await rootBundle.loadString('assets/translations/$code.json'),
              )
              as Map<String, dynamic>;
    }
    await sb.Supabase.initialize(
      url: 'https://invalid.example.test',
      publishableKey: 'widget-test',
      httpClient: httpClient,
      authOptions: const sb.FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: sb.EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
    await sb.Supabase.instance.client.auth.setInitialSession(
      jsonEncode(_session('local-test-session')),
    );
  });
  addTearDown(sb.Supabase.instance.dispose);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('ko')],
      fallbackLocale: const Locale('fr'),
      startLocale: const Locale('fr'),
      path: 'assets/translations',
      assetLoader: _BundledTranslations(translations),
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (profile != null) authStateProvider.overrideWith(() => profile),
          notificationServiceProvider.overrideWithValue(reminders),
          seedStarterListsProvider.overrideWith((ref) async {}),
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
          ruleStatusesProvider.overrideWith((ref, pair) async => []),
          pushOnReconnectProvider.overrideWith((ref) {}),
          connectivityStreamProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.wifi]),
          ),
        ],
        child: const PonderinApp(),
      ),
    ),
  );
  await tester.pump();
}

Future<Finder> _expectHome(WidgetTester tester) async {
  final home = find.byType(V3HomeScreen);
  for (var i = 0; i < 20 && home.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(home, findsOneWidget);
  expect(GoRouterState.of(tester.element(home)).uri.path, '/home');
  return home;
}

void main() {
  testWidgets(
    'signed-in /home restores the daily reminder and streak warning',
    (tester) async {
      final profile = _Profile();
      final reminders = _Reminders();
      await _pumpApp(tester, reminders: reminders, profile: profile);
      expect(reminders.daily, isEmpty);
      expect(reminders.warnings, isEmpty);
      profile.ready.complete(
        AppUser(
          id: 'learner',
          email: 'learner@example.test',
          username: 'Learner',
          currentStreak: 6,
          createdAt: DateTime(2026),
        ),
      );

      await _expectHome(tester);
      expect(reminders.daily, [(17, 35, 'fr')]);
      expect(reminders.warnings, [(6, 'fr')]);

      final app = tester.element(find.byType(PonderinApp));
      final changing = app.setLocale(const Locale('ko'));
      for (var i = 0; i < 20 && reminders.daily.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(reminders.daily, [(17, 35, 'fr'), (17, 35, 'ko')]);
      expect(reminders.warnings, [(6, 'fr'), (6, 'ko')]);
      await changing;

      final cancelledBeforeStudy = reminders.cancelledWarnings;
      profile.studiedToday();
      await tester.pump();
      expect(reminders.warnings, [(6, 'fr'), (6, 'ko')]);
      expect(reminders.cancelledWarnings, cancelledBeforeStudy + 1);
      await unmountScreen(tester);
    },
  );

  testWidgets(
    'a failed token refresh keeps the enriched profile and home route',
    (tester) async {
      var refreshStatus = 503;
      var streak = 6;
      var profileReads = 0;
      final httpClient = MockClient((request) async {
        if (request.url.path == '/rest/v1/profiles') {
          profileReads++;
          expectSync(request.method, 'GET');
          return http.Response(
            jsonEncode([
              {
                'id': 'learner',
                'username': 'chosen',
                'display_name': 'Chosen display name',
                'current_streak': streak,
                'subscription_type': 'premium',
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        expectSync(request.url.path, '/auth/v1/token');
        expectSync(request.url.queryParameters['grant_type'], 'refresh_token');
        final body = switch (refreshStatus) {
          200 => _session('refreshed-test-session'),
          400 => {'code': 'refresh_token_not_found', 'msg': 'Token revoked'},
          _ => {'msg': 'Temporarily unavailable'},
        };
        return http.Response(
          jsonEncode(body),
          refreshStatus,
          request: request,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      });
      await _pumpApp(tester, reminders: _Reminders(), httpClient: httpClient);
      final home = await _expectHome(tester);
      final container = ProviderScope.containerOf(tester.element(home));
      final original = container.read(currentUserProvider)!;
      final auth = sb.Supabase.instance.client.auth;
      final readsBeforeFailure = profileReads;
      expect(original.displayName, 'Chosen display name');
      expect(original.currentStreak, 6);
      expect(original.subscriptionType, SubscriptionType.premium);

      final failedRefresh = expectLater(
        auth.refreshSession(),
        throwsA(
          isA<sb.AuthRetryableFetchException>().having(
            (error) => error.statusCode,
            'HTTP status',
            '503',
          ),
        ),
      );
      // The SDK retries transient refresh errors before emitting a stream error.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      await failedRefresh;
      expect(tester.takeException(), isNull);
      expect(auth.currentUser?.id, 'learner');
      expect(home, findsOneWidget);
      expect(container.read(authStateProvider).hasError, isFalse);
      expect(container.read(currentUserProvider), original);
      expect(profileReads, readsBeforeFailure);

      refreshStatus = 200;
      streak = 7;
      await auth.refreshSession();
      await tester.pump();
      expect(container.read(currentUserProvider)?.currentStreak, 7);

      refreshStatus = 400;
      await expectLater(
        auth.refreshSession(),
        throwsA(isA<sb.AuthException>()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(auth.currentUser, isNull);
      expect(container.read(currentUserProvider), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await unmountScreen(tester);
    },
  );
}
