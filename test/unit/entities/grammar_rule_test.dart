import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';

void main() {
  test('parses authored lesson pages and their contextual example copy', () {
    final rule = GrammarRule.fromJson({
      'rule': {
        'id': 'fr-example',
        'title': {'en': 'Example'},
        'description': {'en': 'Example description'},
        'explanation': {'en': 'Example explanation'},
        'worked_examples': const [],
        'lesson_pages': [
          {
            'type': 'explain',
            'text': {'en': 'Notice the ending.', 'ko': '어미를 살펴보세요.'},
          },
          {
            'type': 'example',
            'text': {'en': 'Here is an example.'},
            'example': {
              'target': 'Je parle français.',
              'translations': {'en': 'I speak French.', 'ko': '저는 프랑스어를 해요.'},
              'detail': {'en': 'parle is the je form.'},
            },
          },
        ],
        'prerequisite_lists': const [],
        'applies_to_categories': const [],
        'min_known_words': <String, dynamic>{},
        'mechanics': <String, dynamic>{
          'type': 'plural',
          'plural': <String, dynamic>{'irregulars': <String, dynamic>{}}
        },
        'test_vectors': const [],
      },
    });

    expect(rule.lessonPages, hasLength(2));
    expect(rule.lessonPages.first.text('ko'), '어미를 살펴보세요.');
    expect(rule.lessonPages.last.example!.translation('ko'), '저는 프랑스어를 해요.');
    expect(
        rule.lessonPages.last.example!.detail('fr'), 'parle is the je form.');
  });

  test('keeps legacy rules lesson-free', () {
    final rule = GrammarRule.fromJson({
      'rule': {
        'id': 'fr-legacy',
        'title': {'en': 'Legacy'},
        'description': {'en': 'Legacy'},
        'explanation': {'en': 'Legacy'},
        'worked_examples': const [],
        'prerequisite_lists': const [],
        'applies_to_categories': const [],
        'min_known_words': <String, dynamic>{},
        'mechanics': <String, dynamic>{
          'type': 'plural',
          'plural': <String, dynamic>{'irregulars': <String, dynamic>{}}
        },
        'test_vectors': const [],
      },
    });

    expect(rule.lessonPages, isEmpty);
  });
}
