import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_lesson_screen.dart';
import '../../helpers/pump_screen.dart';

final _rule = GrammarRule(
  id: 'ko-topic',
  titles: const {'fr': 'La particule de thème'},
  descriptions: const {'fr': 'Choisis 은 ou 는.'},
  explanations: const {'fr': 'La particule de thème indique ce dont on parle.'},
  workedExamples: const [
    WorkedExample(
      target: '저는 학생이에요.',
      translations: {'fr': 'Je suis étudiant.'},
    ),
  ],
  prerequisiteLists: const [],
  appliesToCategories: const ['nom'],
  minKnownWords: const {'nom': 5},
  mechanics: const ParticleMechanics(variants: [
    ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
  ]),
  testVectors: const [],
);

void main() {
  setUpAll(initTestLocalization);

  testWidgets('opens contextual example details without leaving the lesson',
      (tester) async {
    await pumpScreen(
      tester,
      screen: const GrammarLessonScreen(ruleId: 'ko-topic'),
      overrides: [
        grammarRulesProvider.overrideWith((ref, lang) async => [_rule]),
      ],
      settle: false,
    );

    expect(find.byKey(const ValueKey(WidgetKeys.screenGrammarLesson)),
        findsOneWidget);
    expect(find.text(_rule.explanation('fr')), findsOneWidget);
    await tester.tap(find.text('저는 학생이에요.'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Je suis étudiant.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('common.close'.tr()));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey(WidgetKeys.screenGrammarLesson)),
        findsOneWidget);
  });

  testWidgets('continues from the final lesson page to practice',
      (tester) async {
    String? route;
    await pumpScreen(
      tester,
      screen: const GrammarLessonScreen(ruleId: 'ko-topic'),
      overrides: [
        grammarRulesProvider.overrideWith((ref, lang) async => [_rule]),
      ],
      routes: [
        GoRoute(
          path: '/start-session-grammar',
          builder: (_, state) {
            route = state.uri.toString();
            return const SizedBox();
          },
        ),
      ],
      settle: false,
    );

    await tester
        .tap(find.byKey(const ValueKey(WidgetKeys.grammarLessonPractice)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(route, '/start-session-grammar');
  });
}
