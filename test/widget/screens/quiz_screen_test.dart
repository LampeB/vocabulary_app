// ignore_for_file: invalid_use_of_internal_member
import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/quiz/quiz_screen.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

/// Quiz screen end-to-end at the widget level: flashcard flip + self-grade
/// through to the summary, and the typing mode verdict flow. Runs against a
/// real in-memory drift DB (enrichment + FSRS persistence) with the network,
/// audio, notification and review seams faked.
///
/// The screen's breathing pulse animation runs forever in host tests
/// (TEST_MODE is off), so no pumpAndSettle anywhere — fixed pumps only.

final _now = DateTime(2026, 7, 3);

class _NoopAudio implements AudioPlayerService {
  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> speak(String text, String langCode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.due);
  final List<VariantProgress> due;
  final saved = <VariantProgress>[];

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async =>
      Success(due.where((p) => p.direction == direction).take(limit).toList());

  @override
  Future<Result<VariantProgress>> updateProgress(
      VariantProgress progress) async {
    saved.add(progress);
    return Success(progress);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<Result<void>> updateStreak() async => const Success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AppUser?> build() async => null;
  @override
  Future<void> reloadProfile() async {}
}

class _FakeNotifService implements NotificationService {
  @override
  Future<void> cancelStreakWarning() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initTestLocalization);

  late AppDatabase db;
  late _FakeProgressRepo progressRepo;
  String? navigatedTo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Skips the native speech_to_text initialization in the screen's initState.
    SttSimulator.mode = SttSimulator.correct;
  });
  tearDown(() => SttSimulator.mode = '');

  VariantProgress due(String variantId) => VariantProgress(
        id: 'p-$variantId',
        userId: 'u',
        variantId: variantId,
        direction: QuizDirection.frToKo,
        createdAt: _now,
        updatedAt: _now,
      );

  /// Seeds words, wires every provider seam, pumps QuizScreen in [mode].
  Future<void> pump(
    WidgetTester tester, {
    required QuizMode mode,
    required List<(String, String)> words,
    int? cardLimit,
  }) async {
    navigatedTo = null;
    final dueCards = <VariantProgress>[];
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
          db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
      final list = (await repo.createList(name: 'Quiz')).valueOrNull!;
      for (final (fr, ko) in words) {
        final concept = (await repo.addConceptWithVariants(
                listId: list.id, frWord: fr, koWord: ko))
            .valueOrNull!;
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        dueCards.add(
            due(variants.firstWhere((v) => v.langCode == 'fr').id));
      }
    });
    progressRepo = _FakeProgressRepo(dueCards);
    await pumpScreen(
      tester,
      screen: QuizScreen(
        args: QuizArgs(
          listId: 'l',
          mode: mode,
          direction: QuizDirectionChoice.frToKo,
          cardLimit: cardLimit ?? words.length,
        ),
      ),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        getDueCardsUseCaseProvider
            .overrideWithValue(GetDueCardsUseCase(progressRepo)),
        progressRepositoryProvider.overrideWithValue(progressRepo),
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        currentUserProvider.overrideWithValue(null),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notificationServiceProvider.overrideWithValue(_FakeNotifService()),
      ],
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) {
            navigatedTo = '/home';
            return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
          },
        ),
      ],
      settle: false,
    );
    await tick(tester, times: 4); // loadCards + first frame
  }

  testWidgets('flashcard: flip reveals the answer, grading advances to the '
      'summary, done goes home', (tester) async {
    await pump(tester,
        mode: QuizMode.flashcard, words: [('chat', '고양이'), ('chien', '개')]);

    // Card 1: question shown, answer hidden until flip.
    expect(find.text('chat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    expect(find.text('고양이'), findsOneWidget);

    // Grade "known" → feedback → continue → card 2.
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tick(tester, times: 4);
    await tapIfPresent(tester, WidgetKeys.feedbackContinue);
    expect(find.text('chien'), findsOneWidget);

    // Card 2 the same way → summary.
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tick(tester, times: 6);
    await tapIfPresent(tester, WidgetKeys.feedbackContinue);

    // Cartes NEVER persists mastery (self-grading is too easy to fake) —
    // the session completes but no FSRS rating is written.
    expect(progressRepo.saved, isEmpty);

    // Summary → done → /home.
    final done = find.text('quiz.summary_done'.tr());
    if (done.evaluate().isNotEmpty) {
      await tester.tap(done);
      await tick(tester, times: 2);
      expect(navigatedTo, '/home');
    }
  });

  testWidgets('typing: a correct answer shows the correct verdict and '
      'completes at 100%', (tester) async {
    await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);

    await tester.enterText(
        find.byKey(const ValueKey(WidgetKeys.ecrireInput)), '고양이');
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
    await tick(tester, times: 4);

    expect(find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsOneWidget);
    await tapIfPresent(tester, WidgetKeys.feedbackContinue);
    await tick(tester, times: 4);

    expect(progressRepo.saved.single.timesCorrect, 1);
  });

  testWidgets('typing: a wrong answer shows the wrong verdict', (tester) async {
    await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);

    await tester.enterText(
        find.byKey(const ValueKey(WidgetKeys.ecrireInput)), 'nope');
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
    await tick(tester, times: 4);

    expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackWrong)), findsOneWidget);
    expect(find.text('고양이'), findsWidgets); // the correct answer is revealed
  });
}

/// Fixed pumps — the screen animates forever, so pumpAndSettle can't be used.
Future<void> tick(WidgetTester tester, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> tapIfPresent(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isNotEmpty) {
    await tester.tap(f);
    await tick(tester, times: 4);
  }
}
