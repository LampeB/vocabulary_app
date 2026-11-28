import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/utils/streak.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';

class _Reminders implements NotificationService {
  int cancelled = 0;
  int scheduled = 0;

  @override
  Future<void> cancelStreakWarning() async => cancelled++;

  @override
  Future<void> scheduleStreakWarning(int streakDays, {Locale? locale}) async =>
      scheduled++;

  @override
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
    Locale? locale,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QuizSessionsTableCompanion _session(DateTime completedAt) =>
    QuizSessionsTableCompanion.insert(
      id: 'session',
      userId: 'learner',
      listName: 'Salutations',
      mode: 'flashcard',
      direction: 'both',
      cardCount: 2,
      correctCount: 2,
      durationSeconds: 30,
      masteredWordCount: 0,
      completedAt: completedAt,
    );

Future<_Reminders> _restoreReminders(
  AppDatabase db, {
  DateTime? remoteStudyDay,
}) async {
  final reminders = _Reminders();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(reminders),
      currentUserProvider.overrideWithValue(
        AppUser(
          id: 'learner',
          email: 'fixture@example.test',
          username: 'Learner',
          currentStreak: 5,
          lastStudyDate: remoteStudyDay,
          createdAt: DateTime(2026),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  expect(container.read(localStudyDayProvider('learner')), isNull);
  final provider = authenticatedRemindersProvider(const Locale('fr'));
  final listening = container.listen(provider, (_, _) {});
  addTearDown(listening.close);
  await container.read(provider.future);
  return reminders;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final studiedToday in [false, true]) {
    for (final acknowledged in [false, true]) {
      test('restart uses captured day, not shifted timestamp '
          '(today=$studiedToday, acknowledged=$acknowledged)', () async {
        final directory = await Directory.systemTemp.createTemp(
          'ponderin-reminder-civil-',
        );
        final file = File('${directory.path}/history.sqlite');
        addTearDown(() async {
          await file.delete();
          await directory.delete();
        });
        final now = DateTime.now();
        final today = civilDate(now);
        final yesterday = today.subtract(const Duration(days: 1));
        final capturedDay = studiedToday ? today : yesterday;
        final midnightHere = DateTime(now.year, now.month, now.day);
        // The same instant is on the adjacent calendar day after travel.
        final shiftedTimestamp = studiedToday
            ? midnightHere.subtract(const Duration(minutes: 30))
            : midnightHere.add(const Duration(minutes: 30));
        var db = AppDatabase.forTesting(NativeDatabase(file));
        await db.quizSessionDao.insertSession(
          _session(shiftedTimestamp),
          studyDate: capturedDay,
        );
        if (acknowledged) {
          await db.quizSessionDao.acknowledgeStudyDay(
            'learner',
            capturedDay.toIso8601String().split('T').first,
          );
        }
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(db.close);
        final reminders = await _restoreReminders(
          db,
          remoteStudyDay: yesterday,
        );
        expect((
          reminders.cancelled,
          reminders.scheduled,
        ), studiedToday ? (1, 0) : (0, 1));
      });
    }
  }

  test(
    'a different account does not suppress the active account reminder',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final today = civilDate(DateTime.now());
      await db.quizSessionDao.insertSession(
        _session(DateTime.now()).copyWith(userId: const Value('other')),
        studyDate: today,
      );
      final reminders = await _restoreReminders(db);
      expect((reminders.cancelled, reminders.scheduled), (0, 1));
    },
  );

  for (final confirmedByProfile in [false, true]) {
    test(
      'legacy history needs a confirmed civil date (profile=$confirmedByProfile)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final today = civilDate(DateTime.now());
        // Legacy rows have no captured date; do not invent one from completedAt.
        await db.into(db.quizSessionsTable).insert(_session(DateTime.now()));
        final reminders = await _restoreReminders(
          db,
          remoteStudyDay: confirmedByProfile ? today : null,
        );
        expect((
          reminders.cancelled,
          reminders.scheduled,
        ), confirmedByProfile ? (1, 0) : (0, 1));
        expect(await db.quizSessionDao.pendingStudyDays('learner'), isEmpty);
        expect(
          await db.quizSessionDao.getSessionsByUser('learner'),
          hasLength(1),
        );
      },
    );
  }
}
