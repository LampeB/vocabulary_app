import '../../domain/entities/grammar_rule.dart';

/// Word-level French spelling drills stay written until an audible exercise
/// can distinguish their silent endings reliably.
bool supportsSpokenGrammar(GrammarRule rule, String targetLang) =>
    !(targetLang == 'fr' &&
        (rule.mechanics is PluralMechanics || rule.id == 'fr-present-er'));
