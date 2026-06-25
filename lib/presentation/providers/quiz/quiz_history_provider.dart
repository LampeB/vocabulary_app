import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/datasources/local/daos/quiz_session_dao.dart';
import '../../../domain/entities/quiz_session.dart';
import 'quiz_provider.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart' show appDatabaseProvider;

// ── DAO provider ──────────────────────────────────────────────────────────────

final quizSessionDaoProvider = Provider<QuizSessionDao>(
  (ref) => ref.watch(appDatabaseProvider).quizSessionDao,
);

// ── Session list for history screen ──────────────────────────────────────────

final quizHistoryProvider =
    FutureProvider.autoDispose<List<QuizSession>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return [];
  final rows = await ref
      .read(quizSessionDaoProvider)
      .getSessionsByUser(userId);
  return rows.map(_rowToSession).toList();
});

// ── Mastered-over-time data for the line chart ────────────────────────────────

final masteredOverTimeProvider =
    FutureProvider.autoDispose<List<(DateTime, int)>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return [];
  final rows = await ref
      .read(quizSessionDaoProvider)
      .getMasteredOverTime(userId);
  return rows.map((r) => (r.completedAt, r.masteredWordCount)).toList();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

QuizSession _rowToSession(QuizSessionsTableData r) => QuizSession(
      id: r.id,
      userId: r.userId,
      listId: r.listId,
      listName: r.listName,
      mode: QuizMode.values.firstWhere(
        (m) => m.name == r.mode,
        orElse: () => QuizMode.voice,
      ),
      direction: QuizDirectionChoice.values.firstWhere(
        (d) => d.name == r.direction,
        orElse: () => QuizDirectionChoice.frToKo,
      ),
      cardCount: r.cardCount,
      correctCount: r.correctCount,
      durationSeconds: r.durationSeconds,
      masteredWordCount: r.masteredWordCount,
      completedAt: r.completedAt,
    );
