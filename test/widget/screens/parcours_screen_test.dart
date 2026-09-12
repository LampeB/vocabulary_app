import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/screens/home/parcours_screen.dart';

import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  final now = DateTime(2026, 9, 12);
  final learner = AppUser(
    id: 'learner',
    email: 'learner@example.test',
    username: 'Thomas',
    subscriptionType: SubscriptionType.free,
    createdAt: now,
  );
  final prerequisite = VocabularyList(
    id: 'starter-food',
    ownerId: learner.id,
    name: 'La nourriture',
    wordCount: 12,
    origin: 'starter',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('connects the path hero to the exact prerequisite list',
      (tester) async {
    String? route;
    GoRoute stub(String path) => GoRoute(
          path: path,
          builder: (_, state) {
            route = state.uri.toString();
            return const SizedBox();
          },
        );

    await pumpScreen(
      tester,
      screen: const ParcoursScreen(),
      overrides: [
        currentUserProvider.overrideWithValue(learner),
        myListsProvider.overrideWith((ref) => Stream.value([prerequisite])),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
        ruleStatusesProvider.overrideWith((ref, language) async => const []),
      ],
      routes: [
        stub('/daily-path'),
        stub('/lists/:id'),
        stub('/grammar'),
        stub('/start-session'),
      ],
    );

    expect(
        find.byKey(const ValueKey(WidgetKeys.homeDailyPath)), findsOneWidget);
    expect(find.text('La nourriture'), findsOneWidget);

    await tester.tap(find.text('La nourriture'));
    await tester.pumpAndSettle();
    expect(route, '/lists/starter-food');
  });
}
