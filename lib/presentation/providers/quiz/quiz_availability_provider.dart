import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/local/daos/progress_dao.dart';
import '../../../domain/entities/variant_progress.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart';
import 'quiz_provider.dart';

typedef QuizAvailabilityQuery = ({
  (String, String) pair,
  QuizSource source,
  QuizDirectionChoice direction,
  String? listId,
});

final quizAvailabilityProvider = StreamProvider.autoDispose
    .family<int, QuizAvailabilityQuery>((ref, query) {
      final userId = ref.watch(currentUserProvider.select((user) => user?.id));
      if (userId == null || userId.isEmpty) return Stream.value(0);
      final (langA, langB) = query.pair;
      final forward = QuizDirection(questionLang: langA, answerLang: langB);
      final directions = switch (query.direction) {
        QuizDirectionChoice.frToKo => [forward],
        QuizDirectionChoice.koToFr => [forward.reversed],
        QuizDirectionChoice.both => [forward, forward.reversed],
      };
      final dao = ref.watch(progressDaoProvider);
      final listId = query.listId;
      return switch (query.source) {
        QuizSource.allDue ||
        QuizSource.inProgress => dao.watchSmartQuizCardCount(
          userId: userId,
          directions: directions,
          pool: query.source == QuizSource.allDue
              ? SmartQuizPool.due
              : SmartQuizPool.inProgress,
          langA: langA,
          langB: langB,
        ),
        QuizSource.list when listId != null => dao.watchListQuizCardCount(
          listId: listId,
          userId: userId,
          directions: directions,
          langA: langA,
          langB: langB,
        ),
        _ => Stream.value(0),
      };
    });
