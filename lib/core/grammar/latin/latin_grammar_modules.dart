import '../../../domain/entities/grammar_rule.dart';
import '../grammar_language_module.dart';

/// Shared engine for the Latin-script languages (es/it/fr/en/de): mechanics
/// dispatch and the data-driven parts live here; each language subclass
/// supplies its phonology (article elision, 'a'→'an'), its regular
/// conjugation and its regular plural. Lexical exceptions come from the rule
/// data (`irregulars`, `overrides`) — same split as the Korean module
/// (algorithms in code, exceptions in content).
abstract class LatinGrammarModule implements GrammarLanguageModule {
  const LatinGrammarModule({this.conjugationIrregulars = const {}});

  /// Merged 'word|person' → form map mined from the language's conjugation
  /// rules; negation composes on top of conjugation, so it needs the same
  /// map (mirrors KoreanGrammarModule).
  final Map<String, String> conjugationIrregulars;

  @override
  GrammarAnswer apply(GrammarRule rule, String word,
      {String? variantKey, List<String> tags = const []}) {
    switch (rule.mechanics) {
      case ArticleMechanics(:final forms, :final overrides, :final gendered):
        final override = overrides[word];
        if (override != null) {
          return GrammarAnswer(expected: override, accepted: [override]);
        }
        final article = gendered
            ? forms.entries
                .where((e) => tags.contains(e.key))
                .map((e) => e.value)
                .first
            : forms['default']!;
        final phrase = articlePhrase(article, word);
        return GrammarAnswer(expected: phrase, accepted: [phrase]);

      case ConjugationMechanics(:final irregulars, :final persons):
        final person =
            variantKey ?? (persons.isNotEmpty ? persons.first : 'p1sg');
        final form = _irregularOr(
            {...conjugationIrregulars, ...irregulars}, word, person,
            orElse: () => conjugate(word, person));
        return GrammarAnswer(expected: form, accepted: [form]);

      case NegationMechanics(:final irregulars, :final pattern):
        // The negation rule's own irregulars are FULL negated phrases —
        // needed when the pattern's placement breaks down (German separable
        // verbs: 'stehe nicht auf', not 'stehe auf nicht').
        final direct =
            irregulars['$word|$negationPerson'] ?? irregulars[word];
        if (direct != null) {
          return GrammarAnswer(expected: direct, accepted: [direct]);
        }
        final base = _irregularOr(conjugationIrregulars, word, negationPerson,
            orElse: () => negationBase(word));
        final negated =
            negatePhrase((pattern ?? '{verb}').replaceAll('{verb}', base), base);
        return GrammarAnswer(expected: negated, accepted: [negated]);

      case PluralMechanics(:final irregulars):
        final plural = irregulars[word] ?? pluralize(word);
        return GrammarAnswer(expected: plural, accepted: [plural]);

      case ParticleMechanics():
      case UnsupportedMechanics():
        throw StateError(
            'rule ${rule.id}: mechanics not supported by the $langCode module');
    }
  }

  static String _irregularOr(
      Map<String, String> irregulars, String word, String person,
      {required String Function() orElse}) {
    return irregulars['$word|$person'] ?? irregulars[word] ?? orElse();
  }

  /// Article + noun, applying the language's elision ('l\'eau', 'an apple').
  String articlePhrase(String article, String word) => '$article $word';

  /// Regular present-tense form of [infinitive] for [person] (p1sg/p2sg/…).
  String conjugate(String infinitive, String person);

  /// Which person the negation drill wraps (usually p1sg).
  String get negationPerson => 'p1sg';

  /// The verb form the negation pattern wraps — conjugated by default;
  /// English overrides to the bare infinitive ("don't eat").
  String negationBase(String infinitive) =>
      conjugate(infinitive, negationPerson);

  /// Post-processes the filled pattern (French contracts 'ne a…' → 'n\'a…').
  String negatePhrase(String phrase, String base) => phrase;

  /// Regular plural of [noun].
  String pluralize(String noun) => noun;

  static bool startsWithVowel(String word) =>
      word.isNotEmpty && 'aeiouáéíóúàèìòùâêîôûäëïöü'.contains(word[0].toLowerCase());
}

class SpanishGrammarModule extends LatinGrammarModule {
  const SpanishGrammarModule({super.conjugationIrregulars});

  @override
  String get langCode => 'es';

  @override
  String conjugate(String infinitive, String person) {
    final stem = infinitive.substring(0, infinitive.length - 2);
    final isAr = infinitive.endsWith('ar');
    return switch (person) {
      'p1sg' => '${stem}o',
      'p2sg' => isAr ? '${stem}as' : '${stem}es',
      _ => isAr ? '${stem}a' : '${stem}e',
    };
  }

  @override
  String pluralize(String noun) {
    final last = noun[noun.length - 1];
    if ('aeiouáéíóú'.contains(last)) return '${noun}s';
    if (last == 'z') {
      return '${noun.substring(0, noun.length - 1)}ces';
    }
    return '${noun}es';
  }
}

class ItalianGrammarModule extends LatinGrammarModule {
  const ItalianGrammarModule({super.conjugationIrregulars});

  @override
  String get langCode => 'it';

  @override
  String articlePhrase(String article, String word) {
    if (LatinGrammarModule.startsWithVowel(word) &&
        (article == 'il' || article == 'la')) {
      return "l'$word";
    }
    if (article == 'il' && _needsLo(word)) return 'lo $word';
    return '$article $word';
  }

  static bool _needsLo(String word) {
    final w = word.toLowerCase();
    if (w.startsWith('z') || w.startsWith('gn') || w.startsWith('ps')) {
      return true;
    }
    // s + consonant (lo studente, lo sport).
    return w.length > 1 &&
        w.startsWith('s') &&
        !'aeiou'.contains(w[1]);
  }

  @override
  String conjugate(String infinitive, String person) {
    final stem = infinitive.substring(0, infinitive.length - 3);
    final isAre = infinitive.endsWith('are');
    return switch (person) {
      'p1sg' => '${stem}o',
      'p2sg' => '${stem}i',
      _ => isAre ? '${stem}a' : '${stem}e',
    };
  }

  @override
  String pluralize(String noun) {
    // Accented final vowel → invariable (la città → le città).
    final last = noun[noun.length - 1];
    if ('àèìòù'.contains(last)) return noun;
    if (last == 'o' || last == 'e') {
      return '${noun.substring(0, noun.length - 1)}i';
    }
    if (last == 'a') return '${noun.substring(0, noun.length - 1)}e';
    return noun; // consonant-final loanwords are invariable (il bus → i bus)
  }
}

class FrenchGrammarModule extends LatinGrammarModule {
  const FrenchGrammarModule({super.conjugationIrregulars});

  @override
  String get langCode => 'fr';

  @override
  String articlePhrase(String article, String word) =>
      (article == 'le' || article == 'la') &&
              LatinGrammarModule.startsWithVowel(word)
          ? "l'$word"
          : '$article $word';

  @override
  String conjugate(String infinitive, String person) {
    // Regular -er only at A1; stem-changing verbs come from irregulars.
    final stem = infinitive.substring(0, infinitive.length - 2);
    return switch (person) {
      'p2sg' => '${stem}es',
      _ => '${stem}e', // p1sg and p3sg share the -e form
    };
  }

  @override
  String negatePhrase(String phrase, String base) =>
      LatinGrammarModule.startsWithVowel(base)
          ? phrase.replaceFirst('ne $base', "n'$base")
          : phrase;

  @override
  String pluralize(String noun) {
    if (noun.endsWith('s') || noun.endsWith('x') || noun.endsWith('z')) {
      return noun;
    }
    if (noun.endsWith('eau') || noun.endsWith('eu')) return '${noun}x';
    if (noun.endsWith('al')) {
      return '${noun.substring(0, noun.length - 2)}aux';
    }
    return '${noun}s';
  }
}

class EnglishGrammarModule extends LatinGrammarModule {
  const EnglishGrammarModule({super.conjugationIrregulars});

  @override
  String get langCode => 'en';

  @override
  String articlePhrase(String article, String word) =>
      article == 'a' && LatinGrammarModule.startsWithVowel(word)
          ? 'an $word'
          : '$article $word';

  /// 'to eat' → 'eat'; phrasal verbs keep their particle ('to get up' →
  /// 'get up', 3sg 'gets up' — inflection lands on the first token).
  static String _bare(String infinitive) =>
      infinitive.startsWith('to ') ? infinitive.substring(3) : infinitive;

  static String _inflectS(String word) {
    if (RegExp(r'(s|sh|ch|x|z|o)$').hasMatch(word)) return '${word}es';
    if (RegExp(r'[^aeiou]y$').hasMatch(word)) {
      return '${word.substring(0, word.length - 1)}ies';
    }
    return '${word}s';
  }

  @override
  String conjugate(String infinitive, String person) {
    final bare = _bare(infinitive);
    if (person != 'p3sg') return bare;
    final parts = bare.split(' ');
    parts[0] = _inflectS(parts[0]);
    return parts.join(' ');
  }

  @override
  String negationBase(String infinitive) =>
      _bare(infinitive); // don't + bare form

  @override
  String pluralize(String noun) {
    // Compound nouns inflect their LAST token ('cell phone' → 'cell phones').
    final parts = noun.split(' ');
    parts[parts.length - 1] = _inflectS(parts.last);
    return parts.join(' ');
  }
}

class GermanGrammarModule extends LatinGrammarModule {
  const GermanGrammarModule({super.conjugationIrregulars});

  @override
  String get langCode => 'de';

  @override
  String conjugate(String infinitive, String person) {
    var stem = infinitive.endsWith('en')
        ? infinitive.substring(0, infinitive.length - 2)
        : infinitive.substring(0, infinitive.length - 1);
    // -t/-d stems take a linking e (arbeiten → arbeitest, arbeitet).
    final linking = stem.endsWith('t') || stem.endsWith('d') ? 'e' : '';
    return switch (person) {
      'p1sg' => '${stem}e',
      'p2sg' => '$stem${linking}st',
      _ => '$stem${linking}t',
    };
  }
}
