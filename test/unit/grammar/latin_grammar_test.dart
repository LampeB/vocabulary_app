import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/grammar/latin/latin_grammar_modules.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';

/// Vector-verifies every Latin-script curriculum: each authored test vector
/// must round-trip through its language module (same guarantee
/// korean_grammar_test gives the ko content).
///
/// Vector `context` convention: the FIRST whitespace token is the variant key
/// when it names a person (p1sg/p2sg/p3sg) and the gender tag when it names
/// one (m/f/n); the rest is free-text authoring notes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final modules = <String, LatinGrammarModule Function(Map<String, String>)>{
    'es': (i) => SpanishGrammarModule(conjugationIrregulars: i),
    'it': (i) => ItalianGrammarModule(conjugationIrregulars: i),
    'fr': (i) => FrenchGrammarModule(conjugationIrregulars: i),
    'en': (i) => EnglishGrammarModule(conjugationIrregulars: i),
    'de': (i) => GermanGrammarModule(conjugationIrregulars: i),
  };

  for (final MapEntry(key: lang, value: makeModule) in modules.entries) {
    group(lang, () {
      late List<GrammarRule> rules;
      late LatinGrammarModule module;

      setUpAll(() async {
        final raw = await rootBundle
            .loadString('assets/seed/grammar/$lang/rules.json');
        rules = [
          for (final j in (jsonDecode(raw) as Map<String, dynamic>)['rules']
              as List)
            GrammarRule.fromJson(j as Map<String, dynamic>),
        ];
        final irregulars = {
          for (final m in rules
              .map((r) => r.mechanics)
              .whereType<ConjugationMechanics>())
            ...m.irregulars,
        };
        module = makeModule(irregulars);
      });

      test('rules parse with supported mechanics and en content', () {
        expect(rules, isNotEmpty);
        for (final r in rules) {
          expect(r.mechanics, isNot(isA<UnsupportedMechanics>()),
              reason: r.id);
          expect(r.title('en'), isNotEmpty, reason: r.id);
          expect(r.explanation('en'), isNotEmpty, reason: r.id);
          expect(r.testVectors.length, greaterThanOrEqualTo(8),
              reason: '${r.id} is under-specified');
        }
      });

      test('every authored test vector passes through the module', () {
        var checked = 0;
        for (final rule in rules) {
          for (final v in rule.testVectors) {
            final first =
                v.context.isEmpty ? '' : v.context.split(' ').first;
            final variantKey =
                RegExp(r'^p[123]sg$').hasMatch(first) ? first : null;
            final tags = ['m', 'f', 'n'].contains(first) ? [first] : <String>[];
            final answer = module.apply(rule, v.input,
                variantKey: variantKey, tags: tags);
            expect(answer.expected, v.expected,
                reason: '$lang/${rule.id}: ${v.input} (${v.context})');
            expect(answer.accepted, contains(v.expected));
            checked++;
          }
        }
        expect(checked, greaterThanOrEqualTo(30),
            reason: '$lang curriculum has too few vectors');
      });
    });
  }
}
