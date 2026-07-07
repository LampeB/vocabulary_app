// ignore_for_file: invalid_use_of_internal_member
import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/social_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/friendship.dart';
import 'package:vocab_kr/domain/entities/leaderboard_entry.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/repositories/social_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_history_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/social/social_provider.dart';
import 'package:vocab_kr/presentation/screens/home/home_screen.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';
import 'package:vocab_kr/presentation/screens/lists/lists_screen.dart';
import 'package:vocab_kr/presentation/screens/notifications/notification_settings_screen.dart';
import 'package:vocab_kr/presentation/screens/onboarding/auth_screen.dart';
import 'package:vocab_kr/presentation/screens/onboarding/welcome_screen.dart';
import 'package:vocab_kr/presentation/screens/paywall/paywall_screen.dart';
import 'package:vocab_kr/presentation/screens/profile/profile_screen.dart';
import 'package:vocab_kr/presentation/screens/quiz/quiz_screen.dart';
import 'package:vocab_kr/presentation/screens/quiz/start_session_screen.dart';
import 'package:vocab_kr/presentation/screens/settings/settings_screen.dart';
import 'package:vocab_kr/presentation/screens/social/social_screen.dart';
import 'package:vocab_kr/presentation/screens/stats/stats_screen.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../helpers/fake_remote.dart';
import '../helpers/pump_screen.dart';

/// Theme sweep — the app-wide theming task's acceptance check, automated:
/// every screen is pumped in BOTH light and dark mode. A screen fails if it
/// throws (per-theme layout errors) or if its effective scaffold background
/// doesn't follow the theme (hardcoded light-on-dark or vice versa).

final _now = DateTime(2026, 7, 4);

AppUser _user() => AppUser(
      id: 'u',
      email: 't@t.fr',
      username: 'thomas',
      currentStreak: 3,
      subscriptionType: SubscriptionType.free,
      createdAt: _now,
    );

class _NoopAudio implements AudioPlayerService {
  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> speak(String text, String langCode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AppUser?> build() async => null;
  @override
  Future<void> reloadProfile() async {}
}

class _FakeNotifSettings extends NotificationSettingsNotifier {
  @override
  StudyNotifSettings build() => const StudyNotifSettings();
  @override
  Future<void> maybeScheduleStreakWarning(int streakDays) async {}
}

class _FakeNotifService implements NotificationService {
  @override
  Future<void> cancelStreakWarning() async {}
  @override
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {}
  @override
  Future<void> cancelDailyReminder() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<Result<void>> updateStreak() async => const Success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocialRepo implements SocialRepository {
  @override
  Stream<List<Friendship>> watchFriends() => Stream.value(const []);
  @override
  Stream<List<FriendRequest>> watchPendingRequests() => Stream.value(const []);
  @override
  Future<Result<List<LeaderboardEntry>>> getLeaderboard({
    required LeaderboardPeriod period,
    int limit = 100,
    bool friendsOnly = false,
  }) async =>
      const Success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocialRemote implements SocialRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyProgressRepo implements ProgressRepository {
  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async =>
      const Success([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One entry per screen: how to build it and whether pumpAndSettle is safe
/// (screens with perpetual animations need fixed pumps).
class _ScreenSpec {
  const _ScreenSpec(this.name, this.build, {this.settle = true});
  final String name;
  final Widget Function() build;
  final bool settle;
}

void main() {
  setUpAll(initTestLocalization);

  late AppDatabase db;
  late VocabularyRepositoryImpl vocabRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SttSimulator.mode = SttSimulator.correct;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    vocabRepo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
  });
  tearDown(() => SttSimulator.mode = '');

  List<Override> overrides() => [
        currentUserProvider.overrideWithValue(_user()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        isPremiumProvider.overrideWithValue(false),
        customerInfoProvider.overrideWith((ref) => const Stream.empty()),
        offeringsProvider.overrideWith((ref) async => null),
        vocabularyRepositoryProvider.overrideWithValue(vocabRepo),
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        progressRepositoryProvider.overrideWithValue(_EmptyProgressRepo()),
        getDueCardsUseCaseProvider
            .overrideWithValue(GetDueCardsUseCase(_EmptyProgressRepo())),
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        notificationSettingsProvider.overrideWith(_FakeNotifSettings.new),
        notificationServiceProvider.overrideWithValue(_FakeNotifService()),
        socialRepositoryProvider.overrideWithValue(_FakeSocialRepo()),
        socialRemoteDataSourceProvider.overrideWithValue(_FakeSocialRemote()),
        syncOnLoginProvider.overrideWith((ref) async {}),
        myListsProvider.overrideWith((ref) => Stream.value(const [])),
        dueCountProvider.overrideWith((ref) => Stream.value(0)),
        quizHistoryProvider.overrideWith((ref) async => const []),
        masteredOverTimeProvider.overrideWith((ref) async => const []),
        connectivityStreamProvider
            .overrideWith((ref) => Stream.value([ConnectivityResult.wifi])),
      ];

  final specs = <_ScreenSpec>[
    _ScreenSpec('HomeScreen', () => const HomeScreen(), settle: false),
    _ScreenSpec('ListsScreen', () => const ListsScreen()),
    _ScreenSpec('ListDetailScreen',
        () => const ListDetailScreen(listId: 'missing')),
    _ScreenSpec('StartSessionScreen', () => const StartSessionScreen()),
    _ScreenSpec('SettingsScreen', () => const SettingsScreen()),
    _ScreenSpec('NotificationSettingsScreen',
        () => const NotificationSettingsScreen()),
    _ScreenSpec('ProfileScreen', () => const ProfileScreen()),
    _ScreenSpec('StatsScreen', () => const StatsScreen()),
    _ScreenSpec('SocialScreen', () => const SocialScreen()),
    _ScreenSpec('PaywallScreen', () => const PaywallScreen(), settle: false),
    _ScreenSpec('AuthScreen', () => const AuthScreen()),
    _ScreenSpec('WelcomeScreen', () => const WelcomeScreen(), settle: false),
    _ScreenSpec(
        'QuizScreen (summary state)',
        () => const QuizScreen(
              args: QuizArgs(
                listId: 'l',
                mode: QuizMode.flashcard,
                direction: QuizDirectionChoice.frToKo,
                cardLimit: 1,
              ),
            ),
        settle: false),
    _ScreenSpec('AppShell', () => const AppShell(child: SizedBox()),
        settle: false),
  ];

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final isDark = mode == ThemeMode.dark;
    group('${mode.name} mode', () {
      for (final spec in specs) {
        testWidgets('${spec.name} renders and follows the theme',
            (tester) async {
          await pumpScreen(
            tester,
            screen: spec.build(),
            overrides: overrides(),
            settle: spec.settle,
            themeMode: mode,
          );
          if (!spec.settle) {
            await tester.pump(const Duration(milliseconds: 300));
          }

          // Effective background of the first Scaffold must match the theme.
          final scaffoldFinder = find.byType(Scaffold).first;
          final scaffold = tester.widget<Scaffold>(scaffoldFinder);
          final bg = scaffold.backgroundColor ??
              Theme.of(tester.element(scaffoldFinder))
                  .scaffoldBackgroundColor;
          final luminance = bg.computeLuminance();
          expect(
            isDark ? luminance < 0.5 : luminance > 0.5,
            isTrue,
            reason: '${spec.name} in ${mode.name} mode has scaffold '
                'background $bg (luminance ${luminance.toStringAsFixed(2)}) — '
                'not following the theme',
          );
          await unmountScreen(tester);
        });
      }
    });
  }
}
