import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_screen.dart';
import '../../helpers/pump_screen.dart';

/// Grammar hub: every lesson with its unlock/mastery progress — locked rules
/// show HOW to unlock (overall + per-prerequisite-list bars), unlocked rules
/// show mastery and start the session setup, mastered rules show the badge.

GrammarRule _rule(String id, String title, {List<String> prereqs = const []}) =>
    GrammarRule(
      id: id,
      titles: {'fr': title},
      descriptions: const {'fr': ''},
      explanations: const {'fr': 'Une explication.'},
      workedExamples: const [
        WorkedExample(
            target: '저는 학생이에요', translations: {'fr': 'Je suis étudiant'})
      ],
      prerequisiteLists: prereqs,
      appliesToCategories: const ['nom'],
      minKnownWords: const {'nom': 5},
      mechanics: const ParticleMechanics(variants: [
        ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
      ]),
      testVectors: const [],
    );

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  Future<void> pump(WidgetTester tester, List<RuleStatus> statuses) {
    navigatedTo = null;
    return pumpScreen(
      tester,
      screen: const GrammarScreen(),
      overrides: [
        ruleStatusesProvider.overrideWith((ref, lang) async => statuses),
      ],
      routes: [
        GoRoute(
          path: '/start-session-grammar',
          builder: (_, state) {
            navigatedTo = '/start-session-grammar';
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
  }

  testWidgets(
      'a locked rule shows the unlock bar plus one bar per prerequisite '
      'list, and no start button', (tester) async {
    await pump(tester, [
      RuleStatus(
        rule: _rule('r1', 'La particule de thème',
            prereqs: ['Salutations', 'La nourriture']),
        availability: RuleAvailability.locked,
        missingLists: const ['La nourriture'],
        enoughWords: true,
        correct: 0,
        prereqProgress: const {'Salutations': 0.9, 'La nourriture': 0.45},
      ),
    ]);

    expect(
        find.byKey(ValueKey(WidgetKeys.grammarRuleCard('r1'))), findsOneWidget);
    // Both prerequisite lists are named with their own progress bar.
    expect(find.text('Salutations'), findsOneWidget);
    expect(find.text('La nourriture'), findsOneWidget);
    // Overall prerequisite progress: (90% + 45%) / 2 = 67.5%.
    expect(find.text('68%'), findsOneWidget);
    expect(
        find.byKey(ValueKey(WidgetKeys.grammarRuleStart('r1'))), findsNothing);
  });

  testWidgets(
      'an unlocked rule shows mastery progress and starts the grammar '
      'session setup', (tester) async {
    await pump(tester, [
      RuleStatus(
        rule: _rule('r2', 'Le présent poli'),
        availability: RuleAvailability.unlocked,
        missingLists: const [],
        enoughWords: true,
        correct: 3,
      ),
    ]);

    await tester.tap(find.byKey(ValueKey(WidgetKeys.grammarRuleStart('r2'))));
    await tester.pumpAndSettle();
    expect(navigatedTo, '/start-session-grammar');
  });

  testWidgets('a mastered rule shows the badge and no start button',
      (tester) async {
    await pump(tester, [
      RuleStatus(
        rule: _rule('r3', 'La négation'),
        availability: RuleAvailability.mastered,
        missingLists: const [],
        enoughWords: true,
        correct: 10,
      ),
    ]);

    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(
        find.byKey(ValueKey(WidgetKeys.grammarRuleStart('r3'))), findsNothing);
  });

  group('RuleStatus.unlockFraction (unlock math)', () {
    test('no prerequisites → already 1.0', () {
      final s = RuleStatus(
        rule: _rule('r', 't'),
        availability: RuleAvailability.unlocked,
        missingLists: const [],
        enoughWords: true,
        correct: 0,
      );
      expect(s.unlockFraction, 1.0);
    });

    test('uses the raw average across prerequisite lists', () {
      final s = RuleStatus(
        rule: _rule('r', 't', prereqs: ['a', 'b']),
        availability: RuleAvailability.locked,
        missingLists: const ['b'],
        enoughWords: true,
        correct: 0,
        // (90% + 45%) / 2 = 67.5%: still below the 80% unlock threshold.
        prereqProgress: const {'a': 0.9, 'b': 0.45},
      );
      expect(s.unlockFraction, closeTo(0.675, 0.001));
    });

    test('a list the user does not have yet counts as 0', () {
      final s = RuleStatus(
        rule: _rule('r', 't', prereqs: ['a', 'missing']),
        availability: RuleAvailability.locked,
        missingLists: const ['missing'],
        enoughWords: true,
        correct: 0,
        prereqProgress: const {'a': 0.9},
      );
      expect(s.unlockFraction, closeTo(0.45, 0.001));
    });
  });
}
