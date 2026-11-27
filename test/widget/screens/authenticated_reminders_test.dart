import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vocab_kr/app.dart';
import 'package:vocab_kr/core/ponderin_localization.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';

import '../../helpers/pump_screen.dart';

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
  final daily = <(int, int)>[];
  final warnings = <int>[];
  int cancelledWarnings = 0;

  @override
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    daily.add((hour, minute));
  }

  @override
  Future<void> scheduleStreakWarning(int streakDays) async {
    warnings.add(streakDays);
  }

  @override
  Future<void> cancelStreakWarning() async => cancelledWarnings++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'signed-in /home restores the daily reminder and streak warning',
    (tester) async {
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
      await tester.runAsync(() async {
        await EasyLocalization.ensureInitialized();
        await sb.Supabase.initialize(
          url: 'https://invalid.example.test',
          publishableKey: 'widget-test',
          authOptions: const sb.FlutterAuthClientOptions(
            autoRefreshToken: false,
            localStorage: sb.EmptyLocalStorage(),
            detectSessionInUri: false,
          ),
        );
        await sb.Supabase.instance.client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'local-test-session',
            'token_type': 'bearer',
            'user': {'id': 'learner'},
          }),
        );
      });
      addTearDown(sb.Supabase.instance.dispose);
      final profile = _Profile();
      final reminders = _Reminders();
      await tester.pumpWidget(
        PonderinLocalization(
          startLocale: const Locale('fr'),
          child: ProviderScope(
            overrides: [
              authStateProvider.overrideWith(() => profile),
              notificationServiceProvider.overrideWithValue(reminders),
              seedStarterListsProvider.overrideWith((ref) async {}),
              myListsProvider.overrideWith((ref) => Stream.value([])),
              dueCountForPairProvider.overrideWith(
                (ref, pair) => Stream.value(0),
              ),
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

      final home = find.byType(V3HomeScreen);
      for (var i = 0; i < 20 && home.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(home, findsOneWidget);
      expect(GoRouterState.of(tester.element(home)).uri.path, '/home');
      expect(reminders.daily, [(17, 35)]);
      expect(reminders.warnings, [6]);

      profile.studiedToday();
      await tester.pump();
      expect(reminders.warnings, [6]);
      expect(reminders.cancelledWarnings, 1);
      await unmountScreen(tester);
    },
  );
}
