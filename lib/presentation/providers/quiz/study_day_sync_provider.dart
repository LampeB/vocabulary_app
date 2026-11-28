import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/study_day_sync.dart';
import '../auth/auth_provider.dart';
import '../lists/vocabulary_provider.dart';

final studyDaySyncProvider = Provider<StudyDaySync>((ref) {
  final dao = ref.watch(appDatabaseProvider).quizSessionDao;
  var active = true;
  ref.onDispose(() => active = false);
  return StudyDaySync(
    dao,
    () => ref.read(authRepositoryProvider),
    (userId) async {
      if (ref.read(authRepositoryProvider).currentUser?.id == userId) {
        await ref.read(authStateProvider.notifier).reloadProfile();
      }
    },
    isActiveAccount: (userId) =>
        active && ref.read(currentUserProvider)?.id == userId,
  );
});
