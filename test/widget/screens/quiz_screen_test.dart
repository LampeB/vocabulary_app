// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/design/v3/v3_tokens.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/elevenlabs_speech_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/shared_pcm_capture_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/whisper_speech_provider.dart';
import 'package:vocab_kr/presentation/screens/quiz/quiz_screen.dart';
import 'package:vocab_kr/presentation/widgets/study/study_feedback_flood.dart';
import 'package:vocab_kr/presentation/widgets/study/word_in_wave.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import 'package:vocab_kr/services/quiz_orchestration/audio_director.dart';
import 'package:vocab_kr/services/speech/elevenlabs_speech_service.dart';
import 'package:vocab_kr/services/speech/shared_pcm_capture.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';
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
  Future<void> prefetch(
    String text,
    String langCode, {
    String? audioPath,
  }) async {}
  @override
  Future<void> speak(String text, String langCode, {String? audioPath}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isSpeaking => false;
  @override
  void dispose() {}
}

class _TestDirector extends AudioDirector {
  _TestDirector() : super(_NoopAudio());

  int cues = 0;
  int stops = 0;
  Completer<void>? pendingStop;

  @override
  Future<void> chainQuiet({
    int cycles = 3,
    Duration firstStartWindow = Duration.zero,
    Duration nextStartWindow = Duration.zero,
    Duration utteranceCap = Duration.zero,
    bool Function()? keepGoing,
  }) async {}

  @override
  Future<void> handOffToMic({Duration focusBeat = Duration.zero}) async {}

  @override
  Future<void> listenCue({Duration clearance = Duration.zero}) async => cues++;

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playIncorrect() async {}

  @override
  Future<void> playListenDone() async {}

  @override
  Future<void> stopAll() async {
    stops++;
    await pendingStop?.future;
  }
}

class _FakeCapture implements SharedPcmCapture {
  int opens = 0;
  bool canOpen = true;
  _FakeCaptureSession? session;

  @override
  Future<PcmCaptureSession?> open({
    required void Function(bool) onSpeechChange,
    required void Function(PcmSegment) onSegment,
  }) async {
    opens++;
    if (!canOpen) return null;
    return session = _FakeCaptureSession(onSegment);
  }

  @override
  Future<void> stop() async {
    await session?.close();
  }

  @override
  void dispose() {}
}

class _FakeCaptureSession implements PcmCaptureSession {
  _FakeCaptureSession(this.onSegment);

  final void Function(PcmSegment) onSegment;
  bool closed = false;

  void answer() => onSegment(PcmSegment(Uint8List(32000), 1000, 5000));

  @override
  bool get inSpeech => false;

  @override
  Future<PcmSegment?> close({bool flush = false}) async {
    closed = true;
    return null;
  }
}

class _FakeWhisper implements WhisperSpeechService {
  int decodes = 0;
  Completer<String?>? pendingDecode;

  @override
  bool get isReady => true;

  @override
  bool get isListening => false;

  @override
  Future<void> stopListening({bool keepPendingTranscripts = false}) async {}

  @override
  Future<String?> transcribeSegment({
    required Uint8List pcm16,
    required String langCode,
    required List<String> promptHints,
  }) async {
    decodes++;
    return pendingDecode == null
        ? promptHints.single
        : await pendingDecode!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScribe implements ElevenLabsSpeechService {
  @override
  bool get isListening => false;

  @override
  Future<void> stopListening() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VoiceHarness {
  _VoiceHarness({Completer<bool>? preparePhone}) {
    SttSimulator.mode = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const speech = MethodChannel('plugin.csdcorp.com/speech_to_text');
    const phone = MethodChannel('vocab_kr/pcm_speech');
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    messenger.setMockMethodCallHandler(speech, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'listen') {
        systemListens++;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(phone, (call) async {
      phonePrepares++;
      return preparePhone == null ? false : await preparePhone.future;
    });
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['none']);
    addTearDown(() {
      messenger.setMockMethodCallHandler(speech, null);
      messenger.setMockMethodCallHandler(phone, null);
      messenger.setMockMethodCallHandler(connectivity, null);
    });
  }

  final capture = _FakeCapture();
  final whisper = _FakeWhisper();
  final director = _TestDirector();
  int systemListens = 0;
  int phonePrepares = 0;
}

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.due);
  final List<VariantProgress> due;
  final saved = <VariantProgress>[];
  int? committedDays;
  Completer<void>? pendingCommit;

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async =>
      Success(due.where((p) => p.direction == direction).take(limit).toList());

  @override
  Future<Result<VariantProgress>> mutateProgress({
    required String variantId,
    required QuizDirection direction,
    required VariantProgress Function(VariantProgress) mutate,
  }) async {
    final latest = [...saved.reversed, ...due].firstWhere(
      (progress) =>
          progress.variantId == variantId && progress.direction == direction,
    );
    await pendingCommit?.future;
    final updated = mutate(latest);
    final days = committedDays;
    final committed = days == null
        ? updated
        : updated.copyWith(scheduledDays: days);
    saved.add(committed);
    return Success(committed);
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
  late List<GrammarRule> koreanRules;
  setUpAll(() async {
    await initTestLocalization();
    // Load the rule assets before individual widgets run in fake time.
    final container = ProviderContainer();
    try {
      koreanRules = await container.read(grammarRulesProvider('ko').future);
    } finally {
      container.dispose();
    }
  });

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
    String? entry,
    _VoiceHarness? voice,
    _TestDirector? director,
    bool grammar = false,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    navigatedTo = null;
    final dueCards = <VariantProgress>[];
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        FakeRemote(),
        'u',
        db,
      );
      final list = (await repo.createList(name: 'Quiz')).valueOrNull!;
      for (final (fr, ko) in words) {
        final concept = (await repo.addConceptWithVariants(
          listId: list.id,
          wordA: fr,
          wordB: ko,
        )).valueOrNull!;
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        dueCards.add(due(variants.firstWhere((v) => v.langCode == 'fr').id));
      }
    });
    progressRepo = _FakeProgressRepo(dueCards);
    final quiz = QuizScreen(
      args: QuizArgs(
        listId: grammar ? null : 'l',
        source: grammar ? QuizSource.grammar : QuizSource.list,
        ruleId: grammar ? 'particule-theme-eun-neun' : null,
        mode: mode,
        direction: QuizDirectionChoice.frToKo,
        cardLimit: cardLimit ?? words.length,
      ),
    );
    await pumpScreen(
      tester,
      screen: entry == null
          ? quiz
          : Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: ValueKey(entry),
                  onPressed: () => context.push(entry),
                  child: const Text('Entry'),
                ),
              ),
            ),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRemoteProvider.overrideWithValue(FakeRemote()),
        getDueCardsUseCaseProvider.overrideWithValue(
          GetDueCardsUseCase(progressRepo),
        ),
        progressRepositoryProvider.overrideWithValue(progressRepo),
        if (grammar) ...[
          grammarRulesProvider.overrideWith((_, _) => koreanRules),
          ruleDrillWordsProvider.overrideWith(
            (_, _) async => const [
              DrillWord(word: '학생', category: 'nom'),
              DrillWord(word: '친구', category: 'nom'),
            ],
          ),
        ],
        audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        if (voice != null) ...[
          sharedPcmCaptureProvider.overrideWithValue(voice.capture),
          whisperSpeechProvider.overrideWithValue(voice.whisper),
          elevenLabsSpeechProvider.overrideWithValue(_FakeScribe()),
        ],
        audioDirectorProvider.overrideWithValue(
          director ?? voice?.director ?? _TestDirector(),
        ),
        currentUserProvider.overrideWithValue(null),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notificationServiceProvider.overrideWithValue(_FakeNotifService()),
      ],
      routes: [
        if (entry != null) ...[
          GoRoute(
            path: entry,
            builder: (context, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-quiz'),
                onPressed: () => context.push('/quiz'),
                child: const Text('Open'),
              ),
            ),
          ),
          GoRoute(path: '/quiz', builder: (_, _) => quiz),
        ],
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) {
            navigatedTo = '/home';
            return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
          },
        ),
      ],
      settle: false,
      themeMode: themeMode,
    );
    if (entry != null) {
      await tester.tap(find.byKey(ValueKey(entry)));
      await tick(tester, times: 2);
      await tester.tap(find.byKey(const ValueKey('open-quiz')));
    }
    await tick(tester, times: 4); // loadCards + first frame
  }

  testWidgets('flashcard: flip reveals the answer, grading advances to the '
      'summary, done goes home', (tester) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [('chat', '고양이'), ('chien', '개')],
    );

    // Card 1: question shown, answer hidden until flip.
    expect(find.text('chat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    expect(find.text('고양이'), findsOneWidget);

    // Swipe right grades "known" and peels the card away without a verdict
    // screen, revealing card 2 in the same physical stack position.
    await tester.fling(
      find.byKey(const ValueKey(WidgetKeys.cartesCard)),
      const Offset(300, 0),
      1000,
    );
    await tick(tester, times: 4);
    expect(find.text('chien'), findsOneWidget);
    expect(find.text('chat'), findsNothing);

    // Card 2 the same way → summary.
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    await tester.fling(
      find.byKey(const ValueKey(WidgetKeys.cartesCard)),
      const Offset(300, 0),
      1000,
    );
    await tick(tester, times: 6);

    expect(progressRepo.saved, hasLength(2));
    expect(progressRepo.saved.map((progress) => progress.timesCorrect), [1, 1]);
    expect(
      progressRepo.saved.every((progress) => progress.nextReview != null),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.summaryDone)));
    await tick(tester, times: 2);
    expect(navigatedTo, '/home');
  });

  testWidgets('flashcard grades are available as focusable buttons', (
    tester,
  ) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [('chat', '고양이'), ('chien', '개')],
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey(WidgetKeys.gradeAgain)),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey(WidgetKeys.gradeKnew)),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeAgain)));
    await tick(tester, times: 4);
    expect(find.text('chien'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tick(tester, times: 6);
    expect(progressRepo.saved, hasLength(2));
    expect(progressRepo.saved.map((progress) => progress.timesCorrect), [0, 1]);
    expect(progressRepo.saved.map((progress) => progress.timesShown), [1, 1]);
    expect(
      progressRepo.saved.first.nextReview!.isBefore(
        progressRepo.saved.last.nextReview!,
      ),
      isTrue,
    );
    expect(find.text('chien'), findsNothing);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('flashcard review grade has readable ${theme.name} contrast', (
      tester,
    ) async {
      await pump(
        tester,
        mode: QuizMode.flashcard,
        words: [('chat', '고양이')],
        themeMode: theme,
      );
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
      await tick(tester, times: 4);

      final button = find.byKey(const ValueKey(WidgetKeys.gradeAgain));
      final label = find.descendant(of: button, matching: find.byType(Text));
      final foreground = DefaultTextStyle.of(
        tester.element(label),
      ).style.color!;
      final material = find.descendant(
        of: button,
        matching: find.byType(Material),
      );
      final background = tester.widget<Material>(material).color!;
      final luminances = [
        foreground.computeLuminance(),
        background.computeLuminance(),
      ]..sort();

      expect(background.a, 1);
      expect(
        (luminances.last + .05) / (luminances.first + .05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('typing: a correct answer shows the correct verdict and '
      'completes at 100%', (tester) async {
    await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);

    await tester.enterText(
      find.byKey(const ValueKey(WidgetKeys.ecrireInput)),
      '고양이',
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
    await tick(tester, times: 4);

    expect(
      find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
      findsOneWidget,
    );
    await tapIfPresent(tester, WidgetKeys.feedbackContinue);
    await tick(tester, times: 4);

    expect(progressRepo.saved.single.timesCorrect, 1);
  });

  testWidgets('typing: a wrong answer shows the wrong verdict', (tester) async {
    await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);

    await tester.enterText(
      find.byKey(const ValueKey(WidgetKeys.ecrireInput)),
      'nope',
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
    await tick(tester, times: 4);

    expect(
      find.byKey(const ValueKey(WidgetKeys.feedbackWrong)),
      findsOneWidget,
    );
    expect(find.text('고양이'), findsWidgets); // the correct answer is revealed
  });

  testWidgets(
    'vocabulary verdict shows the interval returned by the saved rating',
    (tester) async {
      await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);
      final commit = progressRepo.pendingCommit = Completer<void>();
      progressRepo.committedDays = 37;

      await tester.enterText(
        find.byKey(const ValueKey(WidgetKeys.ecrireInput)),
        '고양이',
      );
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
      await tester.pump();
      final verdict = find.byType(StudyFeedbackFlood);
      expect(tester.widget<StudyFeedbackFlood>(verdict).isCorrect, isTrue);
      expect(tester.widget<StudyFeedbackFlood>(verdict).detail, isNull);

      commit.complete();
      await tester.pump();
      expect(
        tester.widget<StudyFeedbackFlood>(verdict).detail,
        'quiz.next_review_in_days'.tr(namedArgs: {'days': '37'}),
      );
      expect(progressRepo.saved.single.scheduledDays, 37);
    },
  );

  for (final mode in [QuizMode.typing, QuizMode.voice]) {
    testWidgets('grammar ${mode.name} feedback has no next-review interval', (
      tester,
    ) async {
      await pump(tester, mode: mode, words: [], grammar: true, cardLimit: 1);
      if (mode == QuizMode.typing) {
        await tester.enterText(
          find.byKey(const ValueKey(WidgetKeys.ecrireInput)),
          '틀림',
        );
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireValidate)));
      } else {
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.micButton)));
        await tester.pump(const Duration(milliseconds: 800));
      }
      await tester.pump();
      expect(
        tester
            .widget<StudyFeedbackFlood>(find.byType(StudyFeedbackFlood))
            .detail,
        isNull,
      );
      expect(progressRepo.saved, isEmpty);
      await unmountScreen(tester);
      // Voice schedules a feedback delay before the next card.
      await tick(tester, times: 5);
    });
  }

  for (final escape in [WidgetKeys.voiceKeyboard, WidgetKeys.voiceReveal]) {
    testWidgets('voice $escape closes PCM and drops a delayed result', (
      tester,
    ) async {
      final voice = _VoiceHarness();
      final recognizing = voice.whisper.pendingDecode = Completer<String?>();
      await pump(
        tester,
        mode: QuizMode.voice,
        words: [('chat', '고양이')],
        voice: voice,
      );
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.micButton)));
      await tester.pump();
      final capture = voice.capture.session!;
      capture.answer();
      await tester.pump();
      expect(voice.whisper.decodes, 1);

      await tester.tap(find.byKey(ValueKey(escape)));
      await tester.pump();
      expect(capture.closed, isTrue);
      recognizing.complete('고양이');
      capture.answer(); // a queued segment after capture closed is stale too
      await tester.pump();
      expect(voice.whisper.decodes, 1);
      expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsNothing,
      );

      if (escape == WidgetKeys.voiceKeyboard) {
        final input = find.byType(TextField);
        expect(input, findsOneWidget);
        expect(progressRepo.saved, isEmpty);
        await tester.enterText(input, '고양이');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(
          find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
          findsOneWidget,
        );
        expect(progressRepo.saved.single.timesCorrect, 1);
      } else {
        expect(
          find.byKey(const ValueKey(WidgetKeys.feedbackWrong)),
          findsOneWidget,
        );
        expect(progressRepo.saved.single.timesCorrect, 0);
        expect(progressRepo.saved.single.timesShown, 1);
      }
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  for (final mode in [QuizMode.typing, QuizMode.handsFree]) {
    testWidgets(
      'long ${mode.name} prompt scrolls on 320×568 at 2× text scale',
      (tester) async {
        final voice = mode == QuizMode.handsFree ? _VoiceHarness() : null;
        final prompt = List.filled(
          14,
          'Une consigne longue avec plusieurs formes',
        ).join(' ');
        await pump(tester, mode: mode, words: [(prompt, '답')], voice: voice);
        tester.view.physicalSize = const Size(960, 1704);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        if (mode == QuizMode.typing) {
          await tester.tap(find.byKey(const ValueKey(WidgetKeys.ecrireInput)));
          tester.view.viewInsets = const FakeViewPadding(bottom: 780);
        }
        await tester.pump();

        final scroll = find.byKey(const ValueKey(WidgetKeys.quizPrompt));
        final scrollable = find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        expect(
          find.ancestor(of: scroll, matching: find.byType(Scrollbar)),
          findsOneWidget,
        );
        await tester.drag(scrollable, const Offset(0, -80));
        await tester.pump();
        expect(position.pixels, greaterThan(0));
        final keys = mode == QuizMode.handsFree
            ? [WidgetKeys.hfRepeat, WidgetKeys.hfSkip]
            : [WidgetKeys.ecrireInput, WidgetKeys.ecrireValidate];
        for (final key in keys) {
          expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'hands-free cues and summary score are readable in ${theme.name}',
      (tester) async {
        final voice = _VoiceHarness();
        await pump(
          tester,
          mode: QuizMode.handsFree,
          words: [('chat', '고양이')],
          voice: voice,
          themeMode: theme,
        );
        final accent = theme == ThemeMode.light
            ? V3Colors.terraInk
            : V3Colors.amber;
        final background = tester
            .widget<Scaffold>(find.byType(Scaffold))
            .backgroundColor!;
        final luminances = [
          accent.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + .05) / (luminances.first + .05),
          greaterThanOrEqualTo(4.5),
        );
        final countdown = tester.widget<Text>(
          find.byKey(const ValueKey('hf_countdown')),
        );
        expect(countdown.style!.color, accent);
        expect(
          tester.widget<WordInWave>(find.byType(WordInWave)).cueColor,
          accent,
        );
        await tick(tester, times: 8);
        expect(
          tester.widget<WordInWave>(find.byType(WordInWave)).cueColor,
          accent,
        );
        voice.capture.session!.answer();
        await tick(tester, times: 6);
        expect(tester.widget<Text>(find.text('100 %')).style!.color, accent);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('summary actions can restart and return to setup by keyboard', (
    tester,
  ) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [('chat', '고양이')],
      entry: '/start-session',
    );
    Future<void> finish() async {
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
      await tick(tester, times: 2);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
      await tick(tester, times: 4);
      expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsOneWidget);
    }

    await finish();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester, times: 4);
    expect(find.byKey(const ValueKey(WidgetKeys.cartesCard)), findsOneWidget);

    await finish();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester, times: 4);
    expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(navigatedTo, isNull);
  });

  testWidgets('an empty session returns to the daily path', (tester) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [],
      entry: '/daily-path',
    );
    expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.summaryDone)));
    await tick(tester, times: 3);
    expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(navigatedTo, isNull);
  });

  testWidgets('a long flashcard scrolls at 320×568 and 2× text scale', (
    tester,
  ) async {
    final question = List.filled(
      6,
      'Une expression particulièrement longue',
    ).join(' ');
    final answer = List.filled(8, '아주 긴 표현을 공부합니다').join(' ');
    await pump(tester, mode: QuizMode.flashcard, words: [(question, answer)]);
    tester.view.physicalSize = const Size(960, 1704);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tick(tester);
    expect(tester.takeException(), isNull);

    final card = find.byKey(const ValueKey(WidgetKeys.cartesCard));
    final scrollable = find.descendant(
      of: card,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(card);
    await tick(tester, times: 3);
    expect(find.text(answer), findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );

    await tester.drag(scrollable, const Offset(0, -110));
    await tick(tester);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(
      find.byKey(const ValueKey(WidgetKeys.gradeAgain)).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tick(tester, times: 4);
    expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in ['/daily-path', '/lists/l']) {
    testWidgets('close stops audio before returning to $entry', (tester) async {
      final director = _TestDirector()..pendingStop = Completer<void>();
      await pump(
        tester,
        mode: QuizMode.flashcard,
        entry: entry,
        words: [('chat', '고양이')],
        director: director,
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tick(tester);
      expect(director.stops, 1);
      expect(find.byType(QuizScreen), findsOneWidget);

      director.pendingStop!.complete();
      await tick(tester, times: 3);
      expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
      expect(navigatedTo, isNull);
    });
  }

  testWidgets('hands-free pause during countdown prevents cue and capture', (
    tester,
  ) async {
    final voice = _VoiceHarness();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    expect(find.byKey(const ValueKey('hf_countdown')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
    await tick(tester, times: 8);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('hands-free pause cancels the scheduled retry', (tester) async {
    final voice = _VoiceHarness();
    voice.capture.canOpen = false;
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    await tick(tester, times: 8);
    expect(voice.capture.opens, 1);
    expect(voice.director.cues, 1);

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
    voice.capture.canOpen = true;
    // VoiceTurnMachine paces retries on the real clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3600)),
    );
    await tick(tester, times: 12);

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 1);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'a hands-free verdict advances once after background and resume',
    (tester) async {
      final voice = _VoiceHarness();
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이'), ('chien', '개')],
        voice: voice,
      );
      await tick(tester, times: 8);
      expect(voice.capture.opens, 1);
      voice.capture.session!.answer();
      await tester.pump();
      expect(voice.whisper.decodes, 1);
      expect(voice.systemListens, 0);
      expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsOneWidget,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tick(tester, times: 6);
      expect(progressRepo.saved, hasLength(1));
      expect(voice.capture.opens, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tick(tester, times: 4);
      expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsNothing,
      );
      expect(find.text('chien'), findsOneWidget);
      expect(progressRepo.saved, hasLength(1));
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('leaving during asynchronous STT preparation never opens a mic', (
    tester,
  ) async {
    final prepared = Completer<bool>();
    final voice = _VoiceHarness(preparePhone: prepared);
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    await tick(tester, times: 8);
    expect(voice.phonePrepares, 1);
    expect(voice.capture.opens, 0);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tick(tester, times: 3);
    expect(navigatedTo, '/home');
    prepared.complete(true);
    await tester.pump(const Duration(seconds: 3));
    expect(voice.capture.opens, 0);
    expect(voice.systemListens, 0);
    expect(tester.takeException(), isNull);
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
