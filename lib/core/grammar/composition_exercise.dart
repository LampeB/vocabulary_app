/// A full-sentence exercise generated at runtime by the AI (Supabase edge
/// function → Claude), from the target rule + the user's known words.
/// Language-agnostic: nothing here is FR/KR-specific.
class CompositionExercise {
  const CompositionExercise({
    required this.prompt,
    required this.expected,
    required this.accepted,
  });

  /// Natural sentence in the learner's prompt language.
  final String prompt;

  /// Canonical target-language answer.
  final String expected;

  /// Every acceptable answer (always contains [expected]).
  final List<String> accepted;

  static CompositionExercise? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final prompt = json['prompt'];
    final expected = json['expected'];
    final accepted = json['accepted'];
    if (prompt is! String || prompt.trim().isEmpty) return null;
    if (expected is! String || expected.trim().isEmpty) return null;
    final acceptedList = [
      if (accepted is List)
        for (final a in accepted)
          if (a is String && a.trim().isNotEmpty) a.trim(),
    ];
    if (!acceptedList.contains(expected.trim())) {
      acceptedList.insert(0, expected.trim());
    }
    return CompositionExercise(
      prompt: prompt.trim(),
      expected: expected.trim(),
      accepted: acceptedList,
    );
  }

  Map<String, dynamic> toJson() =>
      {'prompt': prompt, 'expected': expected, 'accepted': accepted};
}
