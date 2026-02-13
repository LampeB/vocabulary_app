import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service de traduction utilisant l'API MyMemory (gratuit, sans clé)
class TranslationService {
  static const _baseUrl = 'https://api.mymemory.translated.net/get';

  /// Returns translation suggestions for [text] from [fromLang] to [toLang].
  /// Language codes: 'fr', 'ko', 'en', etc.
  /// Returns up to 5 unique suggestions, empty list on failure.
  static Future<List<String>> suggest(
    String text,
    String fromLang,
    String toLang,
  ) async {
    if (text.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': text.trim(),
        'langpair': '$fromLang|$toLang',
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = <String>{};

      // Collect translations from matches array (better quality)
      final matches = json['matches'] as List<dynamic>? ?? [];
      // Sort by quality descending
      matches.sort((a, b) {
        final qa = (a['quality'] as num?)?.toDouble() ?? 0;
        final qb = (b['quality'] as num?)?.toDouble() ?? 0;
        return qb.compareTo(qa);
      });

      for (final match in matches) {
        final translation = (match['translation'] as String?)?.trim() ?? '';
        if (translation.isNotEmpty) {
          suggestions.add(translation);
        }
        if (suggestions.length >= 5) break;
      }

      // Add main translation if not already present
      final main = (json['responseData']?['translatedText'] as String?)?.trim() ?? '';
      if (main.isNotEmpty) {
        suggestions.add(main);
      }

      return suggestions.take(5).toList();
    } catch (_) {
      return [];
    }
  }
}
