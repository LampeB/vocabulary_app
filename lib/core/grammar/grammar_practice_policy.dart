import '../../domain/entities/grammar_rule.dart';

/// The current word-level French plural drill cannot distinguish silent -s
/// through speech. It stays written until an audible exercise is delivered.
bool supportsSpokenGrammar(GrammarRule rule, String targetLang) =>
    !(targetLang == 'fr' && rule.mechanics is PluralMechanics);
