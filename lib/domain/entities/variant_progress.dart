import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/fsrs_algorithm.dart';

part 'variant_progress.freezed.dart';
part 'variant_progress.g.dart';

// CardState is re-exported from fsrs_algorithm.dart

/// A study direction: which language asks the question and which answers.
/// Generic since the language-pairs epic — was `enum { frToKo, koToFr }`.
/// The legacy constants keep existing call sites (and FR/KR data) working;
/// any pair can be constructed for new languages.
class QuizDirection {
  const QuizDirection({required this.questionLang, required this.answerLang});

  final String questionLang;
  final String answerLang;

  /// Legacy FR/KR directions (most of the app until multi-pair lists exist).
  static const frToKo = QuizDirection(questionLang: 'fr', answerLang: 'ko');
  static const koToFr = QuizDirection(questionLang: 'ko', answerLang: 'fr');

  QuizDirection get reversed =>
      QuizDirection(questionLang: answerLang, answerLang: questionLang);

  /// Storage/query form ('fr>ko'). Named `name` so the enum-era call sites
  /// (`direction.name`) keep working unchanged.
  String get name => '$questionLang>$answerLang';

  /// Parses the storage form AND the legacy enum names (pre-v4 rows, remote
  /// payloads written by old clients).
  factory QuizDirection.fromJson(String raw) => parse(raw);
  String toJson() => name;

  static QuizDirection parse(String raw) => switch (raw) {
        'frToKo' => frToKo,
        'koToFr' => koToFr,
        _ when raw.contains('>') => QuizDirection(
            questionLang: raw.split('>')[0],
            answerLang: raw.split('>')[1],
          ),
        // Defensive default for malformed data — matches the app's historic
        // primary direction rather than crashing a sync.
        _ => frToKo,
      };

  @override
  bool operator ==(Object other) =>
      other is QuizDirection &&
      other.questionLang == questionLang &&
      other.answerLang == answerLang;

  @override
  int get hashCode => Object.hash(questionLang, answerLang);

  @override
  String toString() => 'QuizDirection($name)';
}

@freezed
class VariantProgress with _$VariantProgress {
  const factory VariantProgress({
    required String id,
    required String userId,
    required String variantId,
    required QuizDirection direction,
    @Default(0.0) double stability,
    @Default(5.0) double difficulty,
    @Default(0) int elapsedDays,
    @Default(0) int scheduledDays,
    @Default(0) int reps,
    @Default(0) int lapses,
    @Default(CardState.newCard) CardState state,
    DateTime? lastReview,
    DateTime? nextReview,
    @Default(0) int timesShown,
    @Default(0) int timesCorrect,
    @Default(0.0) double masteryLevel,
    @Default(false) bool isSynced,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _VariantProgress;

  factory VariantProgress.fromJson(Map<String, dynamic> json) =>
      _$VariantProgressFromJson(json);
}

/// Minimum FSRS scheduled-days for a word to count as mastered.
/// Centralised here so every feature (stats, grammar exercises, badges)
/// uses the same definition without re-deriving it.
const int kMasteryThresholdDays = 21;

extension VariantProgressMastery on VariantProgress {
  /// True when FSRS has the card in long-term review and scheduled
  /// at least [kMasteryThresholdDays] days out (~3 weeks retention).
  bool get isMastered =>
      state == CardState.review && scheduledDays >= kMasteryThresholdDays;
}
