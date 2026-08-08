import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/data/seed/seed_catalog.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart'
    show kGrammarCurricula;

/// CI gate over the SHIPPED seed content (assets/seed/vocab/): every studyable
/// language must fully cover the registry, and the registry must be
/// internally consistent. A failure here means a content edit broke the
/// catalog — fix the content, not the test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SeedCatalog catalog;
  late Map<String, SeedLanguageLayer> layers;

  setUpAll(() async {
    catalog = await SeedCatalog.load(rootBundle);
    layers = {
      for (final lang in Languages.supported)
        lang: await SeedLanguageLayer.load(rootBundle, lang),
    };
  });

  test('registry: list ids unique, concept ids unique and referenced once',
      () {
    final listIds = catalog.lists.map((l) => l.id).toList();
    expect(listIds.toSet().length, listIds.length);

    final conceptIds = catalog.conceptCategories.keys.toList();
    expect(conceptIds.toSet().length, conceptIds.length);

    final referenced = <String>[];
    for (final l in catalog.lists) {
      referenced.addAll(l.conceptIds);
    }
    expect(referenced.toSet().length, referenced.length,
        reason: 'a concept must belong to exactly one list');
    expect(referenced.toSet(), conceptIds.toSet(),
        reason: 'every registry concept must be reachable from a list');
  });

  test('every studyable language fully covers the registry', () {
    for (final MapEntry(key: lang, value: layer) in layers.entries) {
      expect(layer.lang, lang);
      for (final id in catalog.conceptCategories.keys) {
        final entry = layer.entries[id];
        expect(entry, isNotNull, reason: '$lang is missing concept "$id"');
        expect(entry!.words, isNotEmpty,
            reason: '$lang concept "$id" has no words');
        expect(entry.words.where((w) => w.isPrimary).length, 1,
            reason: '$lang concept "$id" must have exactly one primary word');
        for (final w in entry.words) {
          expect(w.word.trim(), isNotEmpty);
        }
        expect(entry.example?.trim(), isNot(equals('')),
            reason: '$lang concept "$id": example present but empty');
      }
      final extra =
          layer.entries.keys.toSet().difference(catalog.conceptCategories.keys.toSet());
      expect(extra, isEmpty, reason: '$lang has entries missing from the registry');
    }
  });

  test('example sentences are aligned across languages', () {
    // If any language ships an example for a concept, all of them must —
    // an example is the same sentence translated, anchored per concept.
    for (final id in catalog.conceptCategories.keys) {
      final withExample = [
        for (final MapEntry(key: lang, value: layer) in layers.entries)
          if (layer.entries[id]?.example != null) lang,
      ];
      expect(withExample.length, anyOf(0, layers.length),
          reason: 'concept "$id" has examples only in $withExample');
    }
  });

  test('notes locales are valid translation locales', () {
    const uiLocales = {'fr', 'en', 'es', 'de', 'it', 'ja', 'ko'};
    for (final MapEntry(key: lang, value: layer) in layers.entries) {
      for (final MapEntry(key: id, value: entry) in layer.entries.entries) {
        expect(uiLocales.containsAll(entry.notes.keys), isTrue,
            reason: '$lang "$id" notes keys ${entry.notes.keys}');
      }
    }
  });

  test('Korean teaching notes carry the English fallback', () {
    // ko is studied from every source language; non-French learners get the
    // en note via SeedEntry.noteFor's fallback.
    final ko = layers['ko']!;
    for (final MapEntry(key: id, value: entry) in ko.entries.entries) {
      if (entry.notes.isEmpty) continue;
      expect(entry.notes['en'], isNotNull,
          reason: 'ko note for "$id" has no en fallback');
    }
  });

  test('list name/desc keys exist in all 7 translation files', () async {
    const locales = ['fr', 'en', 'es', 'de', 'it', 'ja', 'ko'];
    for (final locale in locales) {
      final translations =
          await SeedTranslations.load(rootBundle, [locale]);
      for (final l in catalog.lists) {
        expect(translations.resolve(l.nameKey), isNot(equals(l.nameKey)),
            reason: '$locale is missing ${l.nameKey}');
        expect(translations.resolve(l.descKey), isNot(equals(l.descKey)),
            reason: '$locale is missing ${l.descKey}');
      }
    }
  });

  test('target-scoped lists only reference languages that exist', () {
    for (final l in catalog.lists) {
      for (final lang in l.targetLangs ?? const <String>[]) {
        expect(Languages.supported, contains(lang),
            reason: 'list ${l.id} targets unknown language $lang');
      }
    }
  });

  test(
      'grammar curricula: rules parse, mechanics supported, prerequisites '
      'reference registry lists admitting the target, ids globally unique',
      () async {
    final seenIds = <String>{};
    for (final lang in kGrammarCurricula) {
      final raw = jsonDecode(await rootBundle
          .loadString('assets/seed/grammar/$lang/rules.json'))
          as Map<String, dynamic>;
      expect(raw['lang'], lang);
      for (final j in (raw['rules'] as List).cast<Map<String, dynamic>>()) {
        final rule = GrammarRule.fromJson(j);
        expect(seenIds.add(rule.id), isTrue,
            reason: 'rule id ${rule.id} is not globally unique');
        expect(rule.mechanics, isNot(isA<UnsupportedMechanics>()),
            reason: '${rule.id}: mechanics failed to parse');
        expect(rule.titles['en'], isNotNull,
            reason: '${rule.id}: missing en title (fallback locale)');
        expect(rule.explanations['en'], isNotNull,
            reason: '${rule.id}: missing en explanation');
        for (final e in rule.workedExamples) {
          expect(e.translations['en'], isNotNull,
              reason: '${rule.id}: worked example without en translation');
        }
        for (final prereq in rule.prerequisiteLists) {
          final list =
              catalog.lists.where((l) => l.id == prereq).firstOrNull;
          expect(list, isNotNull,
              reason: '${rule.id}: unknown prerequisite list "$prereq"');
          expect(
              list!.targetLangs == null || list.targetLangs!.contains(lang),
              isTrue,
              reason: '${rule.id}: prerequisite "$prereq" never seeds for '
                  'target $lang');
        }
      }
    }
  });

  test('gender tags are consistent word metadata', () {
    const known = {'m', 'f', 'n'};
    for (final MapEntry(key: lang, value: layer) in layers.entries) {
      for (final MapEntry(key: id, value: entry) in layer.entries.entries) {
        for (final w in entry.words) {
          expect(known.containsAll(w.tags), isTrue,
              reason: '$lang "$id" has unknown tags ${w.tags}');
        }
      }
    }
  });
}
