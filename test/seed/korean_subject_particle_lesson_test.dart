import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/utils/answer_validator.dart';
import 'package:vocab_kr/data/seed/seed_catalog.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Korean FR/EN lessons teach the subject form the drill accepts',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rules = await container.read(grammarRulesProvider('ko').future);
      final lesson = rules.singleWhere(
        (rule) => rule.id == 'particules-sujet-objet-i-ga-eul-reul',
      );
      final topicLesson = rules.singleWhere(
        (rule) => rule.id == 'particule-theme-eun-neun',
      );
      final module = await container.read(grammarModuleProvider('ko').future);
      final generator = GrammarDrillGenerator(module!);

      final catalog = await SeedCatalog.load(rootBundle);
      final korean = await SeedLanguageLayer.load(rootBundle, 'ko');
      final mastered = [
        for (final list in catalog.listsForTarget('ko'))
          if (lesson.prerequisiteLists.contains(list.id))
            for (final id in list.conceptIds)
              DrillWord(
                word: korean.entries[id]!.primary!.word,
                category: catalog.conceptCategories[id]!,
                tags: korean.entries[id]!.primary!.tags,
                listId: list.id,
              ),
      ];
      expect(generator.canGenerate(lesson, mastered), isTrue);

      // Isolate the actual starter word so both particle prompts are generated.
      final humblePronoun = generator
          .eligibleWords(lesson, mastered)
          .singleWhere(
            (word) => word.word == '저' && word.listId == 'starter-greetings',
          );
      final exercises = generator.generate(lesson, [humblePronoun], count: 2);
      final subject = exercises.singleWhere(
        (exercise) => exercise.variantKey == 'subject',
      );
      final object = exercises.singleWhere(
        (exercise) => exercise.variantKey == 'object',
      );
      final topic = generator.generate(topicLesson, [
        humblePronoun,
      ], count: 1).single;

      expect(subject.expected, '제가');
      expect(object.expected, '저를');
      expect(topic.expected, '저는');
      expect(
        AnswerValidator.validate(
          userAnswer: subject.expected,
          acceptedAnswers: subject.accepted,
          langCode: 'ko',
          preserveGrammar: true,
        ).isCorrect,
        isTrue,
      );
      expect(
        AnswerValidator.validate(
          userAnswer: '저가',
          acceptedAnswers: subject.accepted,
          langCode: 'ko',
          preserveGrammar: true,
        ).isCorrect,
        isFalse,
      );

      for (final locale in ['fr', 'en']) {
        expect(
          lesson.explanations[locale],
          allOf(contains(humblePronoun.word), contains(subject.expected)),
          reason: 'the $locale explanation must teach the expected contraction',
        );
      }
      final workedExample = lesson.workedExamples.firstWhere(
        (example) => example.target.startsWith('${subject.expected} '),
      );
      expect(workedExample.translations['fr'], isNotEmpty);
      expect(workedExample.translations['en'], isNotEmpty);
    },
  );
}
