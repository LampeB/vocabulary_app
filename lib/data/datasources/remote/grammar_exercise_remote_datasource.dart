import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/grammar/composition_exercise.dart';
import '../../../core/grammar/grammar_drill_generator.dart';

/// Client for the `generate-grammar-exercises` edge function: exercises are
/// composed at RUNTIME by the AI from (rules + the user's known words), so
/// any vocabulary works — starter lists and user-made lists alike. The API
/// key never ships in the app; the function holds it server-side.
class GrammarExerciseRemoteDataSource {
  GrammarExerciseRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Result<List<CompositionExercise>>> generate({
    required Map<String, dynamic> targetRule,
    required List<Map<String, dynamic>> masteredRules,
    required List<DrillWord> words,
    required String promptLanguage,
    required String targetLanguage,
    required int count,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'generate-grammar-exercises',
        body: {
          'target_rule': targetRule,
          'mastered_rules': masteredRules,
          'words': [
            for (final w in words) {'word': w.word, 'category': w.category},
          ],
          'prompt_language': promptLanguage,
          'target_language': targetLanguage,
          'count': count,
        },
      );
      final data = res.data;
      final rawList = data is Map<String, dynamic> ? data['exercises'] : null;
      final exercises = [
        if (rawList is List)
          for (final e in rawList)
            if (CompositionExercise.fromJson(e) case final ex?) ex,
      ];
      return Success(exercises);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }
}

/// Last successful batch per rule, kept locally so a session still starts
/// offline (stale exercises beat no exercises; the word-level drill
/// generator remains the final fallback).
class CompositionExerciseCache {
  static String _key(String ruleId) => 'composition_cache_$ruleId';

  Future<void> save(String ruleId, List<CompositionExercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(ruleId),
      jsonEncode([for (final e in exercises) e.toJson()]),
    );
  }

  Future<List<CompositionExercise>> load(String ruleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(ruleId));
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (CompositionExercise.fromJson(e) case final ex?) ex,
      ];
    } catch (_) {
      return const [];
    }
  }
}
