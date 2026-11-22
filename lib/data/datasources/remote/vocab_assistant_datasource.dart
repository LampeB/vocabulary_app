import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';

/// One translation candidate for a word being added to a list.
class TranslationSuggestion {
  const TranslationSuggestion({required this.text, required this.note});
  final String text;

  /// Disambiguation note in the source language ('' when unambiguous).
  final String note;

  /// The form stored in lists: "café (boisson)" — the annotation convention
  /// the validator already strips for spoken/typed matching.
  String get display => note.isEmpty ? text : '$text ($note)';
}

/// A matched source/target pair (voice-friendly form or themed suggestion).
class WordPairSuggestion {
  const WordPairSuggestion({required this.source, required this.target});
  final String source;
  final String target;
}

/// Response of the `translate` mode.
class TranslateAssist {
  const TranslateAssist(
      {required this.translations, required this.voiceFriendly});
  final List<TranslationSuggestion> translations;

  /// Longer natural forms when a side is too short for reliable STT
  /// ("le riz" / "밥을 먹다") — same core word, better acoustics.
  final List<WordPairSuggestion> voiceFriendly;
}

/// Response of the `suggest` mode.
class ThemedSuggestions {
  const ThemedSuggestions({required this.theme, required this.pairs});
  final String theme;
  final List<WordPairSuggestion> pairs;
}

/// Client for the `vocab-assistant` edge function (AI list-creation help,
/// user request 2026-07-11). The Claude key lives server-side; JWT required.
class VocabAssistantDataSource {
  VocabAssistantDataSource(this._client);
  final SupabaseClient _client;

  Future<Result<TranslateAssist>> translate({
    required String word,
    required String sourceLang,
    required String targetLang,
    String? theme,
    List<String> existingWords = const [],
  }) async {
    try {
      final res = await _client.functions.invoke('vocab-assistant', body: {
        'mode': 'translate',
        'word': word,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'theme': theme,
        'existingWords': existingWords,
      });
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownException('réponse invalide'));
      }
      return Success(TranslateAssist(
        translations: [
          if (data['translations'] is List)
            for (final t in data['translations'] as List)
              if (t is Map && (t['text'] as String?)?.trim().isNotEmpty == true)
                TranslationSuggestion(
                  text: (t['text'] as String).trim(),
                  note: (t['note'] as String? ?? '').trim(),
                ),
        ],
        voiceFriendly: _pairs(data['voiceFriendly']),
      ));
    } catch (e) {
      return Failure(UnknownException('$e'));
    }
  }

  Future<Result<ThemedSuggestions>> suggest({
    required String sourceLang,
    required String targetLang,
    required List<WordPairSuggestion> existingPairs,
    int count = 8,
  }) async {
    try {
      final res = await _client.functions.invoke('vocab-assistant', body: {
        'mode': 'suggest',
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'existingPairs': [
          for (final p in existingPairs)
            {'source': p.source, 'target': p.target},
        ],
        'count': count,
      });
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownException('réponse invalide'));
      }
      return Success(ThemedSuggestions(
        theme: (data['theme'] as String? ?? '').trim(),
        pairs: _pairs(data['suggestions']),
      ));
    } catch (e) {
      return Failure(UnknownException('$e'));
    }
  }

  static List<WordPairSuggestion> _pairs(dynamic raw) => [
        if (raw is List)
          for (final p in raw)
            if (p is Map &&
                (p['source'] as String?)?.trim().isNotEmpty == true &&
                (p['target'] as String?)?.trim().isNotEmpty == true)
              WordPairSuggestion(
                source: (p['source'] as String).trim(),
                target: (p['target'] as String).trim(),
              ),
      ];
}
