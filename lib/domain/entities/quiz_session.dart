import '../../../presentation/providers/quiz/quiz_provider.dart';

class QuizSession {
  const QuizSession({
    required this.id,
    required this.userId,
    this.listId,
    required this.listName,
    required this.mode,
    required this.direction,
    required this.cardCount,
    required this.correctCount,
    required this.durationSeconds,
    required this.masteredWordCount,
    required this.completedAt,
  });

  final String id;
  final String userId;
  final String? listId;
  final String listName;
  final QuizMode mode;
  final QuizDirectionChoice direction;
  final int cardCount;
  final int correctCount;
  final int durationSeconds;
  final int masteredWordCount;
  final DateTime completedAt;

  double get accuracy => cardCount == 0 ? 0 : correctCount / cardCount;
}
