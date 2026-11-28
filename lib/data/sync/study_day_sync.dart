import 'dart:async' show unawaited;
import 'dart:developer' show log;

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/daos/quiz_session_dao.dart';

/// Shares the account's replay between session completion and reconnect.
class StudyDaySync {
  StudyDaySync(
    this._dao,
    this._auth,
    this._refreshProfile, {
    required this.isActiveAccount,
  });

  final QuizSessionDao _dao;
  final AuthRepository Function() _auth;
  final bool Function(String) isActiveAccount;
  final Future<void> Function(String) _refreshProfile;
  final _drains = <String, _StudyDayDrain>{};

  Future<void> pushPending(String userId) {
    if (!isActiveAccount(userId)) return Future.value();
    final running = _drains[userId];
    if (running != null) {
      running.requested = true;
      return running.done;
    }
    final drain = _drains[userId] = _StudyDayDrain();
    return drain.done = _pushUntilIdle(userId, drain);
  }

  Future<void> _pushUntilIdle(String userId, _StudyDayDrain drain) async {
    var acknowledged = false;
    try {
      do {
        drain.requested = false;
        final pending = await _dao.pendingStudyDays(userId);
        for (final day in pending) {
          if (!isActiveAccount(userId)) return;
          final result = await _auth().updateStreak(
            userId: userId,
            studyDate: DateTime.parse('${day}T00:00:00Z'),
          );
          if (result.isSuccess) {
            await _dao.acknowledgeStudyDay(userId, day);
            acknowledged = true;
          } else if (result.exceptionOrNull is NetworkException) {
            break;
          }
        }
      } while (drain.requested && isActiveAccount(userId));
    } catch (error, stackTrace) {
      log('Study day replay failed', error: error, stackTrace: stackTrace);
    } finally {
      _drains.remove(userId);
      if (acknowledged && isActiveAccount(userId)) {
        unawaited(_reloadProfile(userId));
      }
    }
  }

  Future<void> _reloadProfile(String userId) async {
    try {
      await _refreshProfile(userId);
    } catch (error, stackTrace) {
      log('Study profile refresh failed', error: error, stackTrace: stackTrace);
    }
  }
}

class _StudyDayDrain {
  late final Future<void> done;
  bool requested = false;
}
