import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/home/home_screen.dart';
import '../../helpers/pump_screen.dart';

/// Home screen: greeting/streak/due-count render from providers, list tiles
/// navigate to their detail route, the bell opens notifications, and a
/// positive streak asks the notification notifier to arm the streak warning.

final _now = DateTime(2026, 7, 3);

_FakeNotifSettings? _lastNotif;

/// Real notifier would hit the native notifications plugin from build()'s
/// _load and from maybeScheduleStreakWarning — both stubbed out here.
class _FakeNotifSettings extends NotificationSettingsNotifier {
  _FakeNotifSettings() {
    _lastNotif = this;
  }
  int? scheduledStreak;

  @override
  StudyNotifSettings build() => const StudyNotifSettings();

  @override
  Future<void> maybeScheduleStreakWarning(int streakDays) async {
    scheduledStreak = streakDays;
  }
}

AppUser _user({int streak = 0}) => AppUser(
      id: 'u',
      email: 't@t.fr',
      username: 'thomas',
      currentStreak: streak,
      subscriptionType: SubscriptionType.free,
      createdAt: _now,
    );

VocabularyList _list(String id, String name) => VocabularyList(
      id: id,
      ownerId: 'u',
      name: name,
      wordCount: 7,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;
  QuizArgs? capturedQuizArgs;

  Future<void> pump(
    WidgetTester tester, {
    AppUser? user,
    List<VocabularyList> lists = const [],
    int dueCount = 0,
    bool settle = true,
  }) {
    navigatedTo = null;
    _lastNotif = null;
    GoRoute stub(String path) => GoRoute(
          path: path,
          pageBuilder: (_, state) {
            navigatedTo = state.uri.toString();
            return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
          },
        );
    return pumpScreen(
      tester,
      screen: const HomeScreen(),
      // a streak > 0 animates the waveform forever -> no pumpAndSettle
      overrides: [
        currentUserProvider.overrideWithValue(user ?? _user()),
        syncOnLoginProvider.overrideWith((ref) async {}),
        myListsProvider.overrideWith((ref) => Stream.value(lists)),
        dueCountProvider.overrideWith((ref) => Stream.value(dueCount)),
        notificationSettingsProvider.overrideWith(_FakeNotifSettings.new),
      ],
      routes: [
        stub('/lists'),
        stub('/lists/:id'),
        stub('/notifications'),
        GoRoute(
          path: '/quiz',
          pageBuilder: (_, state) {
            navigatedTo = '/quiz';
            capturedQuizArgs = state.extra as QuizArgs?;
            return const MaterialPage<void>(
                child: Scaffold(body: SizedBox()));
          },
        ),
      ],
      settle: settle,
    );
  }

  testWidgets('renders home with streak and the user lists', (tester) async {
    await pump(tester,
        user: _user(streak: 5),
        lists: [_list('l1', 'Animaux'), _list('l2', 'Cuisine')],
        dueCount: 3,
        settle: false);

    expect(find.byKey(const ValueKey(WidgetKeys.screenHome)), findsOneWidget);
    expect(find.text('Animaux'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('5'), findsWidgets); // streak value appears
  });

  testWidgets('tapping a list tile navigates to its detail route',
      (tester) async {
    await pump(tester, lists: [_list('l1', 'Animaux')]);

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();

    expect(navigatedTo, '/lists/l1');
  });

  testWidgets('the bell opens the notifications screen', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.homeBell)));
    await tester.pumpAndSettle();

    expect(navigatedTo, '/notifications');
  });

  testWidgets('a positive streak arms the streak warning once',
      (tester) async {
    await pump(tester, user: _user(streak: 8), settle: false);
    expect(_lastNotif!.scheduledStreak, 8);
  });

  testWidgets(
      'the À réviser card one-taps into an all-due session (skips the '
      'accordion)', (tester) async {
    await pump(tester, dueCount: 3);

    await tester.tap(find.text('home.review_start'.tr()));
    await tester.pumpAndSettle();

    expect(navigatedTo, '/quiz');
    expect(capturedQuizArgs!.source, QuizSource.allDue);
    expect(capturedQuizArgs!.listId, isNull);
    expect(capturedQuizArgs!.direction, QuizDirectionChoice.both);
  });

  testWidgets('zero streak does not touch the notification scheduler',
      (tester) async {
    await pump(tester, user: _user(streak: 0));
    // The screen never reads the lazy notifier when streak == 0; instantiate
    // it through the container to inspect it.
    final container = ProviderScope.containerOf(tester
        .element(find.byKey(const ValueKey(WidgetKeys.screenHome))));
    container.read(notificationSettingsProvider.notifier);
    expect(_lastNotif!.scheduledStreak, isNull);
  });
}
