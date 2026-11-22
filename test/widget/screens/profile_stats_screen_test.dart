import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/quiz_session.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_history_provider.dart';
import 'package:vocab_kr/presentation/screens/profile/profile_screen.dart';
import 'package:vocab_kr/presentation/screens/stats/stats_screen.dart';
import '../../helpers/pump_screen.dart';

/// Profile screen (identity, premium badge, nav tiles) and stats screen
/// (session history + mastered-over-time from canned providers).

final _now = DateTime(2026, 7, 3);

AppUser _user({int streak = 4, SubscriptionType sub = SubscriptionType.free}) =>
    AppUser(
      id: 'u',
      email: 't@t.fr',
      username: 'thomas',
      displayName: 'Thomas',
      currentStreak: streak,
      totalWordsMastered: 42,
      subscriptionType: sub,
      createdAt: _now,
    );

QuizSession _session({int correct = 3, int total = 3}) => QuizSession(
      id: 's1',
      userId: 'u',
      listName: 'Animaux',
      mode: QuizMode.typing,
      direction: QuizDirectionChoice.frToKo,
      cardCount: total,
      correctCount: correct,
      durationSeconds: 61,
      masteredWordCount: 5,
      completedAt: _now,
    );

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  GoRoute stub(String path) => GoRoute(
        path: path,
        pageBuilder: (_, state) {
          navigatedTo = state.uri.toString();
          return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
        },
      );

  group('profile screen', () {
    Future<void> pump(WidgetTester tester, {bool premium = false}) {
      navigatedTo = null;
      return pumpScreen(
        tester,
        screen: const ProfileScreen(),
        overrides: [
          currentUserProvider.overrideWithValue(
              _user(sub: premium ? SubscriptionType.premium : SubscriptionType.free)),
          isPremiumProvider.overrideWithValue(premium),
        ],
        routes: [stub('/stats'), stub('/settings'), stub('/notifications')],
      );
    }

    testWidgets('shows the user identity', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey(WidgetKeys.screenProfile)),
          findsOneWidget);
      expect(find.text('Thomas'), findsWidgets);
    });

    testWidgets('stats tile navigates to /stats', (tester) async {
      await pump(tester);
      await tester.ensureVisible(
          find.byKey(const ValueKey(WidgetKeys.profileTileStats)));
      await tester
          .tap(find.byKey(const ValueKey(WidgetKeys.profileTileStats)));
      await tester.pumpAndSettle();
      expect(navigatedTo, '/stats');
    });

    testWidgets('settings tile navigates to /settings', (tester) async {
      await pump(tester);
      await tester.ensureVisible(
          find.byKey(const ValueKey(WidgetKeys.profileTileSettings)));
      await tester
          .tap(find.byKey(const ValueKey(WidgetKeys.profileTileSettings)));
      await tester.pumpAndSettle();
      expect(navigatedTo, '/settings');
    });
  });

  group('stats screen', () {
    Future<void> pump(WidgetTester tester,
        {List<QuizSession> sessions = const []}) {
      return pumpScreen(
        tester,
        screen: const StatsScreen(),
        overrides: [
          currentUserProvider.overrideWithValue(_user()),
          quizHistoryProvider.overrideWith((ref) async => sessions),
          masteredOverTimeProvider.overrideWith((ref) async => [
                (DateTime(2026, 7, 1), 3),
                (DateTime(2026, 7, 2), 5),
              ]),
        ],
      );
    }

    testWidgets('renders with streak and mastered data', (tester) async {
      await pump(tester, sessions: [_session()]);
      expect(
          find.byKey(const ValueKey(WidgetKeys.screenStats)), findsOneWidget);
      expect(find.text('Animaux'), findsWidgets); // session history entry
    });

    testWidgets('renders the empty-history state without errors',
        (tester) async {
      await pump(tester);
      expect(
          find.byKey(const ValueKey(WidgetKeys.screenStats)), findsOneWidget);
      expect(find.text('Animaux'), findsNothing);
    });
  });
}
