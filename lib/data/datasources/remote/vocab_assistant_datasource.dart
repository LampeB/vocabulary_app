import 'dart:convert' show jsonEncode, utf8;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/authenticated_edge_session.dart';

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

  Map<String, String> _toJson() => {'source': source, 'target': target};
}

/// Response of the `translate` mode.
class TranslateAssist {
  const TranslateAssist({
    required this.translations,
    required this.voiceFriendly,
  });
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

  // Keep in sync with vocab-assistant/index.ts and _shared/request_limits.ts.
  static const maxContextItems = 80;
  static const _maxFieldLength = 256;
  static const _maxBodyBytes = 32768;

  Future<Result<TranslateAssist>> translate({
    required String word,
    required String sourceLang,
    required String targetLang,
    String? theme,
    List<String> existingWords = const [],
  }) async {
    try {
      final body = <String, Object>{
        'mode': 'translate',
        'word': word,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'theme': ?theme,
        'existingWords': const <String>[],
      };
      body['existingWords'] = _boundedContext(
        body,
        existingWords.where(_validText),
        (word) => word,
      );
      final res = await invokeAuthenticatedEdgeFunction(
        _client,
        'vocab-assistant',
        body: body,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownException('réponse invalide'));
      }
      return Success(
        TranslateAssist(
          translations: [
            if (data['translations'] is List)
              for (final t in data['translations'] as List)
                if (t is Map &&
                    (t['text'] as String?)?.trim().isNotEmpty == true)
                  TranslationSuggestion(
                    text: (t['text'] as String).trim(),
                    note: (t['note'] as String? ?? '').trim(),
                  ),
          ],
          voiceFriendly: _pairs(data['voiceFriendly']),
        ),
      );
    } on PermissionException catch (e) {
      return Failure(e);
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
      final body = _suggestionEnvelope(sourceLang, targetLang, count);
      body['existingPairs'] = _boundPairs(
        body,
        existingPairs,
      ).map((pair) => pair._toJson()).toList();
      final res = await invokeAuthenticatedEdgeFunction(
        _client,
        'vocab-assistant',
        body: body,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownException('réponse invalide'));
      }
      return Success(
        ThemedSuggestions(
          theme: (data['theme'] as String? ?? '').trim(),
          pairs: _pairs(data['suggestions']),
        ),
      );
    } on PermissionException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException('$e'));
    }
  }

  static List<WordPairSuggestion> boundSuggestionContext({
    required String sourceLang,
    required String targetLang,
    required Iterable<WordPairSuggestion> pairs,
  }) => _boundPairs(_suggestionEnvelope(sourceLang, targetLang, 8), pairs);

  static Map<String, Object> _suggestionEnvelope(
    String sourceLang,
    String targetLang,
    int count,
  ) => {
    'mode': 'suggest',
    'sourceLang': sourceLang,
    'targetLang': targetLang,
    'existingPairs': const [],
    'count': count,
  };

  static List<WordPairSuggestion> _boundPairs(
    Map<String, Object> envelope,
    Iterable<WordPairSuggestion> pairs,
  ) => _boundedContext(
    envelope,
    pairs.where((pair) => _validText(pair.source) && _validText(pair.target)),
    (pair) => pair._toJson(),
  );

  static bool _validText(String value) =>
      value.length <= _maxFieldLength && value.trim().isNotEmpty;

  static List<T> _boundedContext<T>(
    Map<String, Object> envelope,
    Iterable<T> items,
    Object Function(T) encodeItem,
  ) {
    var bytes = utf8.encode(jsonEncode(envelope)).length;
    final included = <T>[];
    for (final item in items) {
      if (included.length == maxContextItems) break;
      final itemBytes =
          utf8.encode(jsonEncode(encodeItem(item))).length +
          (included.isEmpty ? 0 : 1);
      if (bytes + itemBytes > _maxBodyBytes) continue;
      bytes += itemBytes;
      included.add(item);
    }
    return included;
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
