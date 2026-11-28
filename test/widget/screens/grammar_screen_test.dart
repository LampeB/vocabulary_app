import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/data/seed/seed_catalog.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_screen.dart';
import '../../helpers/pump_screen.dart';

/// Grammar hub: every lesson with its unlock/mastery progress — locked rules
/// show HOW to unlock (overall + per-prerequisite-list bars), unlocked rules
/// open their lesson, mastered rules show the badge.

GrammarRule _rule(String id, String title, {List<String> prereqs = const []}) =>
    GrammarRule(
      id: id,
      titles: {'fr': title},
      descriptions: const {'fr': ''},
      explanations: const {'fr': 'Une explication.'},
      workedExamples: const [
        WorkedExample(
          target: '저는 학생이에요',
          translations: {'fr': 'Je suis étudiant'},
        ),
      ],
      prerequisiteLists: prereqs,
      appliesToCategories: const ['nom'],
      minKnownWords: const {'nom': 5},
      mechanics: const ParticleMechanics(
        variants: [
          ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
        ],
      ),
      testVectors: const [],
    );

void main() {
  setUpAll(initTestLocalization);

  String? navigatedTo;

  Future<void> pump(WidgetTester tester, List<RuleStatus> statuses) async {
    navigatedTo = null;
    final catalog = (await tester.runAsync(
      () => SeedCatalog.load(rootBundle),
    ))!;
    await pumpScreen(
      tester,
      screen: const GrammarScreen(),
      overrides: [
        ruleStatusesProvider.overrideWith((ref, lang) async => statuses),
        grammarPrerequisiteNameKeysProvider.overrideWith(
          (ref) async => {
            for (final list in catalog.lists) list.id: list.nameKey,
          },
        ),
      ],
      routes: [
        GoRoute(
          path: '/grammar/:ruleId',
          builder: (_, state) {
            navigatedTo = state.uri.toString();
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
  }

  testWidgets('a tab-root lesson hub has no pop action', (tester) async {
    await pump(tester, []);
    expect(
      find.byKey(const ValueKey(WidgetKeys.screenGrammar)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNull);
  });

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets('missing prerequisite uses catalog labels in $locale', (
      tester,
    ) async {
      final raw = (await tester.runAsync(
        () => rootBundle.loadString('assets/translations/$locale.json'),
      ))!;
      final translations = Translations(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      Localization.load(
        Locale(locale),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);
      await pump(tester, [
        RuleStatus(
          rule: _rule(
            'missing',
            'Articles',
            prereqs: ['starter-greetings', 'starter-food'],
          ),
          availability: RuleAvailability.locked,
          missingLists: const ['starter-greetings', 'starter-food'],
          enoughWords: false,
          correct: 0,
          // A resolved list name wins, even when stats have not arrived.
          prereqNames: const {'starter-food': 'Ma cuisine personnelle'},
        ),
      ]);
      expect(
        find.text('seed.list.starter-greetings.name'.tr()),
        findsOneWidget,
      );
      expect(find.text('Ma cuisine personnelle'), findsOneWidget);
      expect(find.text('starter-greetings'), findsNothing);
      expect(find.text('starter-food'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a locked rule shows the unlock bar plus one bar per prerequisite '
    'list, and no start button',
    (tester) async {
      await pump(tester, [
        RuleStatus(
          rule: _rule(
            'r1',
            'La particule de thème',
            prereqs: ['Salutations', 'La nourriture'],
          ),
          availability: RuleAvailability.locked,
          missingLists: const ['La nourriture'],
          enoughWords: true,
          correct: 0,
          prereqProgress: const {'Salutations': 0.9, 'La nourriture': 0.45},
          prereqTotals: const {'Salutations': 20, 'La nourriture': 20},
          prereqNames: const {
            'Salutations': 'Salutations',
            'La nourriture': 'La nourriture',
          },
        ),
      ]);

      expect(
        find.byKey(ValueKey(WidgetKeys.grammarRuleCard('r1'))),
        findsOneWidget,
      );
      // Both prerequisite lists are named with their own progress bar.
      expect(find.text('Salutations'), findsOneWidget);
      expect(find.text('La nourriture'), findsOneWidget);
      // Equal-sized lists: (18 + 9) / (20 + 20) = 67.5%.
      expect(find.text('68%'), findsOneWidget);
      expect(
        find.byKey(ValueKey(WidgetKeys.grammarRuleStart('r1'))),
        findsNothing,
      );
    },
  );

  testWidgets('an unlocked rule shows mastery progress and opens its lesson', (
    tester,
  ) async {
    await pump(tester, [
      RuleStatus(
        rule: _rule('r2', 'Le présent poli'),
        availability: RuleAvailability.unlocked,
        missingLists: const [],
        enoughWords: true,
        correct: 3,
      ),
    ]);

    await tester.tap(
      find.byKey(ValueKey(WidgetKeys.grammarRuleOpenLesson('r2'))),
    );
    await tester.pumpAndSettle();
    expect(navigatedTo, '/grammar/r2');
  });

  testWidgets('a mastered rule shows the badge and no start button', (
    tester,
  ) async {
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
      find.byKey(ValueKey(WidgetKeys.grammarRuleOpenLesson('r3'))),
      findsNothing,
    );
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

    test('uses the weighted fraction across prerequisite lists', () {
      final s = RuleStatus(
        rule: _rule('r', 't', prereqs: ['a', 'b']),
        availability: RuleAvailability.locked,
        missingLists: const ['b'],
        enoughWords: true,
        correct: 0,
        // (9 + 9) / (10 + 20) = 60%: list sizes influence the total.
        prereqProgress: const {'a': 0.9, 'b': 0.45},
        prereqTotals: const {'a': 10, 'b': 20},
      );
      expect(s.unlockFraction, closeTo(0.6, 0.001));
    });

    test('a list the user does not have yet counts as 0', () {
      final s = RuleStatus(
        rule: _rule('r', 't', prereqs: ['a', 'missing']),
        availability: RuleAvailability.locked,
        missingLists: const ['missing'],
        enoughWords: true,
        correct: 0,
        prereqProgress: const {'a': 0.9},
        prereqTotals: const {'a': 10},
      );
      expect(s.unlockFraction, 0);
    });
  });
}
