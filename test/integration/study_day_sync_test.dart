import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/streak.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/sync/study_day_sync.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';

final _first = DateTime.utc(2026, 10, 25);
final _second = DateTime.utc(2026, 10, 26);

QuizSessionsTableCompanion _session(
  String id,
  String userId,
  DateTime completedAt,
) => QuizSessionsTableCompanion.insert(
  id: id,
  userId: userId,
  listName: 'Fixture',
  mode: 'flashcard',
  direction: 'frToKo',
  cardCount: 1,
  correctCount: 1,
  durationSeconds: 10,
  masteredWordCount: 0,
  completedAt: completedAt,
);

Future<void> _complete(
  AppDatabase db,
  String id,
  DateTime completion, {
  String account = 'a',
}) => db.quizSessionDao.insertSession(
  _session(id, account, completion.toUtc()),
  studyDate: civilDate(completion),
);

class _Auth implements AuthRepository {
  _Auth(this.reply);

  final Future<Result<void>> Function(String, DateTime) reply;
  final attempts = <(String, DateTime)>[];

  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) {
    attempts.add((userId, studyDate));
    return reply(userId, studyDate);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test(
    'v13 history is preserved without inventing a civil study day',
    () async {
      final dir = await Directory.systemTemp.createTemp('ponderin-study-v13-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/app.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(file));
      await old
          .into(old.quizSessionsTable)
          .insert(_session('old', 'a', _first));
      await old.customStatement('DROP TABLE quiz_study_days');
      await old.customStatement('PRAGMA user_version = 13');
      await old.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(
        (await upgraded.quizSessionDao.getSessionsByUser('a')).single.id,
        'old',
      );
      expect(await upgraded.quizSessionDao.pendingStudyDays('a'), isEmpty);
      await _complete(upgraded, 'new', _first);
      expect(await upgraded.quizSessionDao.pendingStudyDays('a'), [
        '2026-10-25',
      ]);
      expect(
        await upgraded.quizSessionDao.getSessionsByUser('a'),
        hasLength(2),
      );
    },
  );

  test('a study-day write refusal rolls back the quiz history', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('''
      CREATE TRIGGER deny_study_day BEFORE INSERT ON quiz_study_days
      BEGIN SELECT RAISE(ABORT, 'injected study day write failure'); END
    ''');

    await expectLater(
      _complete(db, 'failed', _first),
      throwsA(isA<Exception>()),
    );
    expect(await db.quizSessionDao.getSessionsByUser('a'), isEmpty);
    expect(await db.quizSessionDao.pendingStudyDays('a'), isEmpty);
  });

  test(
    'overlapping drains send one civil day per account across DST',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final paris = tz.getLocation('Europe/Paris');
      final completion = tz.TZDateTime(paris, 2026, 10, 25, 0, 15);
      final nextCompletion = tz.TZDateTime(paris, 2026, 10, 26, 0, 15);
      expect(completion.toUtc().day, 24);
      expect(nextCompletion.difference(completion), const Duration(hours: 25));
      await _complete(db, 'a1', completion);
      await _complete(db, 'b1', completion, account: 'b');

      final sent = Completer<void>();
      final firstReply = Completer<Result<void>>();
      final auth = _Auth((userId, day) async {
        if (day == _first) {
          sent.complete();
          return firstReply.future;
        }
        return const Success(null);
      });
      final refreshed = <String>[];
      final sync = StudyDaySync(
        db.quizSessionDao,
        () => auth,
        (userId) async => refreshed.add(userId),
        isActiveAccount: (userId) => userId == 'a',
      );
      final draining = sync.pushPending('a');
      await sent.future.timeout(const Duration(seconds: 2));
      await _complete(db, 'a2', completion);
      await _complete(db, 'a3', nextCompletion);
      final joined = sync.pushPending('a');
      expect(joined, same(draining));

      firstReply.complete(const Success(null));
      await joined;
      await _complete(db, 'a4', completion);
      await sync.pushPending('a');
      expect(auth.attempts, [('a', _first), ('a', _second)]);
      expect(refreshed, ['a']);
      expect(await db.quizSessionDao.pendingStudyDays('a'), isEmpty);
      expect(await db.quizSessionDao.pendingStudyDays('b'), ['2026-10-25']);
      expect(await db.quizSessionDao.getSessionsByUser('a'), hasLength(4));
    },
  );

  test(
    'a lost ACK retries the original day before a newer completion',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final accepted = <DateTime>{};
      var dropReply = true;
      final auth = _Auth((_, day) async {
        accepted.add(day);
        return dropReply
            ? const Failure(NetworkException())
            : const Success(null);
      });
      var refreshAttempts = 0;
      final sync = StudyDaySync(db.quizSessionDao, () => auth, (_) async {
        refreshAttempts++;
        throw const NetworkException('profile read failed');
      }, isActiveAccount: (_) => true);

      await _complete(db, 'a1', _first);
      await sync.pushPending('a');
      expect(await db.quizSessionDao.pendingStudyDays('a'), ['2026-10-25']);
      expect(refreshAttempts, 0);

      dropReply = false;
      await _complete(db, 'a2', _second);
      await sync.pushPending('a');
      expect(accepted, {_first, _second});
      expect(auth.attempts, [('a', _first), ('a', _first), ('a', _second)]);
      expect(await db.quizSessionDao.pendingStudyDays('a'), isEmpty);
      expect(refreshAttempts, 1);
    },
  );

  test(
    'switching accounts leaves unsent days scoped to the old account',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _complete(db, 'a1', _first);
      await _complete(db, 'a2', _second);
      await _complete(db, 'b1', _second, account: 'b');
      var activeAccount = 'a';
      final firstRequest = Completer<void>();
      final firstReply = Completer<void>();
      final auth = _Auth((userId, day) async {
        if (!firstRequest.isCompleted) {
          firstRequest.complete();
          await firstReply.future;
        }
        // Production auth refuses a result when the captured account changed.
        return activeAccount == userId
            ? const Success(null)
            : const Failure(AuthException());
      });
      final refreshed = <String>[];
      final sync = StudyDaySync(
        db.quizSessionDao,
        () => auth,
        (userId) async => refreshed.add(userId),
        isActiveAccount: (userId) => activeAccount == userId,
      );
      final drainingA = sync.pushPending('a');
      await firstRequest.future.timeout(const Duration(seconds: 2));
      activeAccount = 'b';
      await sync.pushPending('b');
      firstReply.complete();
      await drainingA;
      expect(auth.attempts, [('a', _first), ('b', _second)]);
      expect(refreshed, ['b']);
      expect(await db.quizSessionDao.pendingStudyDays('a'), [
        '2026-10-25',
        '2026-10-26',
      ]);
      expect(await db.quizSessionDao.pendingStudyDays('b'), isEmpty);

      activeAccount = 'a';
      await sync.pushPending('a');
      expect(auth.attempts, [
        ('a', _first),
        ('b', _second),
        ('a', _first),
        ('a', _second),
      ]);
      expect(refreshed, ['b', 'a']);
      expect(await db.quizSessionDao.pendingStudyDays('a'), isEmpty);
    },
  );
}
