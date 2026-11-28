// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/stt_simulator.dart';
import 'package:vocab_kr/core/utils/pcm_segmenter.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/local/daos/concept_dao.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart';
import 'package:vocab_kr/presentation/design/v3/v3_tokens.dart';
import 'package:vocab_kr/presentation/design/v3/v3_card_stack.dart';
import 'package:vocab_kr/presentation/providers/audio/audio_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/notifications/notification_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/audio_settings_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/stt_engine_mode_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/elevenlabs_speech_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/shared_pcm_capture_provider.dart';
import 'package:vocab_kr/presentation/providers/speech/whisper_speech_provider.dart';
import 'package:vocab_kr/presentation/screens/quiz/quiz_screen.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/import/import_from_link_screen.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';
import 'package:vocab_kr/presentation/widgets/study/study_feedback_flood.dart';
import 'package:vocab_kr/presentation/widgets/study/stt_status_strip.dart';
import 'package:vocab_kr/presentation/widgets/study/word_in_wave.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';
import 'package:vocab_kr/services/audio/flutter_tts_service.dart';
import 'package:vocab_kr/services/notifications/notification_service.dart';
import 'package:vocab_kr/services/quiz_orchestration/audio_director.dart';
import 'package:vocab_kr/services/quiz_orchestration/voice_turn_machine.dart';
import 'package:vocab_kr/services/speech/elevenlabs_speech_service.dart';
import 'package:vocab_kr/services/speech/pcm_microphone.dart';
import 'package:vocab_kr/services/speech/shared_pcm_capture.dart';
import 'package:vocab_kr/services/speech/stt_engine.dart';
import 'package:vocab_kr/services/speech/whisper_speech_service.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/rendered_text_contrast.dart';

/// Quiz screen end-to-end at the widget level: flashcard flip + self-grade
/// through to the summary, and the typing mode verdict flow. Runs against a
/// real in-memory drift DB (enrichment + FSRS persistence) with the network,
/// audio, notification and review seams faked.
///
/// The screen's breathing pulse animation runs forever in host tests
/// (TEST_MODE is off), so no pumpAndSettle anywhere — fixed pumps only.

final _now = DateTime(2026, 7, 3);

class _NoopAudio implements AudioPlayerService {
  final spoken = <String>[];

  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> prefetch(
    String text,
    String langCode, {
    String? audioPath,
  }) async {}
  @override
  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
  }) async => spoken.add(text);
  @override
  Future<void> retryDisposal() => stop();
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
  _TestDirector([AudioPlayerService? audio, this.verifyAudioHandoff = false])
    : super(audio ?? _NoopAudio());

  final bool verifyAudioHandoff;
  int cues = 0;
  int endCues = 0;
  int stops = 0;
  Completer<void>? pendingStop;
  Completer<void>? pendingCue;

  @override
  Future<void> chainQuiet({
    int cycles = 3,
    Duration firstStartWindow = Duration.zero,
    Duration nextStartWindow = Duration.zero,
    Duration utteranceCap = Duration.zero,
    bool Function()? keepGoing,
  }) async {}

  @override
  Future<void> handOffToMic({Duration focusBeat = Duration.zero}) async {
    if (verifyAudioHandoff) await super.handOffToMic(focusBeat: focusBeat);
  }

  @override
  Future<void> listenCue({Duration clearance = Duration.zero}) async {
    cues++;
    await pendingCue?.future;
  }

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playIncorrect() async {}

  @override
  Future<void> playListenDone() async => endCues++;

  @override
  Future<void> stopAll() async {
    stops++;
    await pendingStop?.future;
  }
}

class _BlockingPromptAudio extends _NoopAudio {
  final utterances = <(String, String, Completer<void>)>[];
  int stops = 0;

  @override
  Future<void> speak(
    String text,
    String langCode, {
    String? audioPath,
    bool requirePlayback = false,
  }) {
    final done = Completer<void>();
    utterances.add((text, langCode, done));
    return done.future;
  }

  @override
  Future<void> stop() async => stops++;
}

class _AudioAwaitingRelease extends _NoopAudio {
  bool playing = true;
  bool refuseStop = false;
  Future<void>? pendingStop;
  int stops = 0;

  @override
  bool get isSpeaking => playing;

  @override
  Future<void> stop() async {
    stops++;
    if (refuseStop) throw StateError('audio still playing');
    await pendingStop;
    playing = false;
  }
}

class _FakeCapture implements SharedPcmCapture {
  int opens = 0;
  bool canOpen = true;
  _FakeCaptureSession? session;
  Future<bool> Function()? checkPermission;
  void Function(_FakeCaptureSession)? onOpen;

  @override
  Duration get releaseTimeout => sttMicReleaseTimeout;

  @override
  Future<bool> ensurePermission() async {
    final check = checkPermission;
    return check == null || await check();
  }

  @override
  Future<PcmCaptureSession?> open({
    required void Function(bool) onSpeechChange,
    required void Function(PcmSegment) onSegment,
  }) async {
    opens++;
    if (!canOpen) return null;
    final opened = session = _FakeCaptureSession(onSegment);
    onOpen?.call(opened);
    return opened;
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
  Future<void>? pendingClose;
  Object? closeError;
  int closeCalls = 0;

  void answer() => onSegment(PcmSegment(Uint8List(32000), 1000, 5000));

  @override
  bool get inSpeech => false;

  @override
  Future<PcmSegment?> close({bool flush = false}) async {
    closeCalls++;
    await pendingClose;
    if (closeError case final error?) throw error;
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
  void cancelSharedTranscriptions() {}

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
  _VoiceHarness({
    Completer<bool>? preparePhone,
    FutureOr<bool> Function()? probePhone,
    AudioPlayerService? promptAudio,
    bool verifyAudioHandoff = false,
    FutureOr<List<String>> Function()? checkConnectivity,
    bool Function()? acceptSystemStop,
    Future<void>? systemRelease,
  }) : director = _TestDirector(promptAudio, verifyAudioHandoff) {
    SttSimulator.mode = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const phone = MethodChannel('vocab_kr/pcm_speech');
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    messenger.setMockMethodCallHandler(_permissionsChannel, (_) async => true);
    messenger.setMockMethodCallHandler(_speech, (call) async {
      if (call.method == 'supportsOnDeviceRecognition') return false;
      if (call.method == 'listen') {
        systemSession = call.arguments['session'] as int;
        systemListens++;
        return true;
      }
      if (call.method == 'stop') {
        systemStops++;
        if (!(acceptSystemStop?.call() ?? true)) return false;
        final session = call.arguments['session'] as int;
        unawaited(() async {
          await systemRelease;
          await systemEvent('released', const {}, session: session);
        }());
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(phone, (call) async {
      if (call.method != 'isSupported') return null;
      phonePrepares++;
      if (probePhone != null) return await probePhone();
      return preparePhone == null ? false : await preparePhone.future;
    });
    messenger.setMockMethodCallHandler(connectivity, (_) async {
      return checkConnectivity == null ? ['none'] : await checkConnectivity();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_speech, null);
      messenger.setMockMethodCallHandler(_permissionsChannel, null);
      messenger.setMockMethodCallHandler(phone, null);
      messenger.setMockMethodCallHandler(connectivity, null);
    });
  }

  static const _speech = MethodChannel('vocab_kr/system_speech');
  static const _permissionsChannel = MethodChannel(
    'plugin.csdcorp.com/speech_to_text',
  );
  final capture = _FakeCapture();
  final whisper = _FakeWhisper();
  final _TestDirector director;
  int systemListens = 0;
  int systemStops = 0;
  int? systemSession;
  int phonePrepares = 0;

  Future<void> systemFinalResult(String transcript) => systemEvent('result', {
    'isFinal': true,
    'alternates': [
      {'words': transcript, 'confidence': .95},
    ],
  });

  Future<void> systemEvent(
    String method,
    Map<String, Object?> arguments, {
    int? session,
  }) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    return messenger.handlePlatformMessage(
      _speech.name,
      _speech.codec.encodeMethodCall(
        MethodCall(method, {'session': session ?? systemSession, ...arguments}),
      ),
      null,
    );
  }
}

class _SilentFilePlayer implements FileAudioPlayer {
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  Future<void> playFile(String path, {bool waitForCompletion = false}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<PlayerState> get state async => PlayerState.stopped;
  @override
  bool get isPlaying => false;
  @override
  Future<void> release() async {}
  @override
  Future<void> dispose() async {}
}

class _RejectingFilePlayer extends _SilentFilePlayer {
  int starts = 0;
  int releases = 0;
  final released = Completer<void>();

  @override
  Future<void> playFile(String path, {bool waitForCompletion = false}) {
    starts++;
    return Future.error(PlatformException(code: 'AndroidAudioError'));
  }

  @override
  Future<void> release() {
    releases++;
    return released.future;
  }
}

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo(this.due, {this.loadFailure});
  final List<VariantProgress> due;
  final AppException? loadFailure;
  final saved = <VariantProgress>[];
  final _importedCards = <VariantProgress>[];
  int? committedDays;
  Completer<void>? pendingCommit;
  Future<void>? pendingInitialLoad;
  Future<List<VariantProgress>> Function(String, QuizDirection)? importedDue;

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
    bool includeScheduled = false,
  }) async {
    if (loadFailure case final failure?) return Failure(failure);
    if (listId == 'l') await pendingInitialLoad;
    final imported = importedDue;
    final cards = imported != null && listId != 'l'
        ? await imported(listId, direction)
        : due;
    if (!identical(cards, due)) _importedCards.addAll(cards);
    return Success(
      cards.where((p) => p.direction == direction).take(limit).toList(),
    );
  }

  @override
  Future<Result<List<VariantProgress>>> getAllDueCards({
    required String userId,
    required QuizDirection direction,
    String? langA,
    String? langB,
    int limit = 20,
  }) => getDueCards(
    userId: userId,
    listId: '',
    direction: direction,
    limit: limit,
  );

  @override
  Future<Result<List<VariantProgress>>> getMasteredVariants(
    String userId,
  ) async => const Success([]);

  @override
  Future<Result<VariantProgress>> mutateProgress({
    required String variantId,
    required QuizDirection direction,
    required VariantProgress Function(VariantProgress) mutate,
  }) async {
    final latest = [...saved.reversed, ...due, ..._importedCards].firstWhere(
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

class _FailingAnswerVariantDao extends ConceptDao {
  _FailingAnswerVariantDao(super.db);

  final languagesRead = <String>[];

  @override
  Future<List<WordVariantsTableData>> getVariantsByConceptIds(
    List<String> conceptIds,
    String langCode, {
    bool firstPerConcept = false,
  }) async {
    languagesRead.add(langCode);
    if (langCode == 'ko') {
      throw StateError('SQLite answer-variant query failed');
    }
    return super.getVariantsByConceptIds(
      conceptIds,
      langCode,
      firstPerConcept: firstPerConcept,
    );
  }
}

class _DelayedSttMode extends SttEngineModeNotifier {
  final preference = Completer<SttEngineMode>();

  @override
  Future<SttEngineMode> get restored => preference.future;
}

class _FakeAuthRepo implements AuthRepository {
  Future<void>? pendingStreak;
  int streakUpdates = 0;
  @override
  AppUser? get currentUser => null;

  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async {
    streakUpdates++;
    await pendingStreak;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AppUser?> build() async => null;
  @override
  Future<void> reloadProfile() async {}

  @override
  AppUser? useLocalSession() => ref.read(currentUserProvider);
}

class _PendingImportRemote extends FakeRemote {
  final pending = Completer<Result<Map<String, dynamic>?>>();

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(String token) =>
      pending.future;
}

const _sharedImport = Success<Map<String, dynamic>?>({
  'name': 'Liste partagée',
  'description': null,
  'concepts': [
    {
      'word_variants': [
        {'word': 'merci', 'lang_code': 'fr', 'is_primary': true, 'position': 0},
        {'word': '감사합니다', 'lang_code': 'ko', 'is_primary': true, 'position': 0},
      ],
    },
  ],
});

AppUser _importAccount() =>
    AppUser(id: 'u', email: 'u@example.test', username: 'u', createdAt: _now);

class _CachedPrompt implements AudioAssetCache {
  final invalidated = <String>[];

  @override
  Future<String?> downloadAndCache(String audioPath) async =>
      '/cache/prompt.mp3';

  @override
  Future<void> invalidate(String audioPath) async => invalidated.add(audioPath);

  @override
  void scheduleIdleCacheCleanup() {}
}

class _PendingDeviceSpeech implements DeviceSpeech {
  final playback = Completer<void>();
  final released = Completer<void>();
  int speaks = 0;
  int disposals = 0;

  @override
  Future<void> speak(String text, String langCode) {
    speaks++;
    return playback.future;
  }

  @override
  Future<void> warmUp(String langCode) async {}
  @override
  Future<void> stop() async {}
  @override
  bool get isSpeaking => speaks > 0 && !playback.isCompleted;
  @override
  Future<void> dispose() {
    disposals++;
    return released.future;
  }
}

class _RestoringAudioSettings extends AudioSettingsNotifier {
  final restored = Completer<double>();

  @override
  AudioSettings build() {
    unawaited(
      restored.future.then((rate) {
        state = AudioSettings(speechRate: rate);
      }),
    );
    return const AudioSettings();
  }
}

class _FakeNotifService implements NotificationService {
  int cancelledStreaks = 0;
  final scheduledStreaks = <int>[];
  @override
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
    Locale? locale,
  }) async {}
  @override
  Future<void> scheduleStreakWarning(int streakDays, {Locale? locale}) async =>
      scheduledStreaks.add(streakDays);
  @override
  Future<void> cancelStreakWarning() async => cancelledStreaks++;
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
    AudioDirector? director,
    bool grammar = false,
    bool fromDailyReview = false,
    StateProvider<AppUser?>? account,
    _FakeAuthRepo? authRepo,
    _FakeNotifService? reminders,
    _PendingImportRemote? importRemote,
    String? questionAudioPath,
    AudioPlayerService Function(Ref)? audioFactory,
    AudioDirector Function(AudioPlayerService)? directorFactory,
    bool useRealDirector = false,
    AudioSettingsNotifier? audioSettings,
    SttEngineModeNotifier? sttMode,
    VoiceTurnMachine Function()? machineFactory,
    ThemeMode themeMode = ThemeMode.light,
    AppException? loadFailure,
    Future<void>? pendingInitialLoad,
    ConceptDao Function(AppDatabase)? quizConceptDao,
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
        final variant = variants.firstWhere((v) => v.langCode == 'fr');
        dueCards.add(due(variant.id));
        if (questionAudioPath != null) {
          await db.conceptDao.applyProvisionedAudio(
            variantId: variant.id,
            ownerId: 'u',
            word: variant.word,
            langCode: variant.langCode,
            path: questionAudioPath,
          );
        }
      }
    });
    progressRepo = _FakeProgressRepo(dueCards, loadFailure: loadFailure)
      ..pendingInitialLoad = pendingInitialLoad;
    if (importRemote != null) {
      progressRepo.importedDue = (listId, direction) async {
        final concepts = await db.conceptDao.getConceptsByList(listId);
        final cards = <VariantProgress>[];
        for (final concept in concepts) {
          final variants = await db.conceptDao.getVariantsByConcept(concept.id);
          cards.addAll(
            variants
                .where((variant) => variant.langCode == direction.questionLang)
                .map(
                  (variant) => due(variant.id).copyWith(direction: direction),
                ),
          );
        }
        return cards;
      };
    }
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
      screen: fromDailyReview
          ? const DailyPathScreen()
          : importRemote != null
          ? Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const ValueKey('open-quiz'),
                  onPressed: () => context.push('/quiz'),
                  child: const Text('Open'),
                ),
              ),
            )
          : entry == null
          ? reminders == null
                ? quiz
                : Consumer(
                    builder: (context, ref, _) {
                      ref.watch(
                        authenticatedRemindersProvider(const Locale('fr')),
                      );
                      return quiz;
                    },
                  )
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
        if (quizConceptDao != null)
          conceptDaoProvider.overrideWithValue(quizConceptDao(db)),
        vocabularyRemoteProvider.overrideWithValue(
          importRemote ?? FakeRemote(),
        ),
        if (importRemote != null) isPremiumProvider.overrideWithValue(true),
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
        if (audioFactory != null)
          audioPlayerServiceProvider.overrideWith(audioFactory)
        else
          audioPlayerServiceProvider.overrideWithValue(_NoopAudio()),
        if (audioSettings != null)
          audioSettingsProvider.overrideWith(() => audioSettings),
        if (voice != null) ...[
          sharedPcmCaptureProvider.overrideWithValue(voice.capture),
          whisperSpeechProvider.overrideWithValue(voice.whisper),
          elevenLabsSpeechProvider.overrideWithValue(_FakeScribe()),
        ],
        if (directorFactory != null)
          audioDirectorProvider.overrideWith(
            (ref) => directorFactory(ref.watch(audioPlayerServiceProvider)),
          )
        else if (!useRealDirector)
          audioDirectorProvider.overrideWithValue(
            director ?? voice?.director ?? _TestDirector(),
          ),
        if (fromDailyReview) ...[
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(1)),
        ],
        if (sttMode != null) sttEngineModeProvider.overrideWith(() => sttMode),
        if (machineFactory != null)
          voiceTurnMachineFactoryProvider.overrideWithValue(machineFactory),
        if (account == null)
          currentUserProvider.overrideWithValue(null)
        else
          currentUserProvider.overrideWith((ref) => ref.watch(account)),
        authRepositoryProvider.overrideWithValue(authRepo ?? _FakeAuthRepo()),
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notificationServiceProvider.overrideWithValue(
          reminders ?? _FakeNotifService(),
        ),
      ],
      routes: [
        if (importRemote != null) ...[
          ShellRoute(
            builder: (_, _, child) => QuizRouteVisibility(child: child),
            routes: [
              GoRoute(
                path: '/quiz',
                builder: (_, state) => state.extra == null
                    ? quiz
                    : QuizScreen(args: state.extra! as QuizArgs),
              ),
              GoRoute(
                path: '/lists/:id',
                builder: (_, state) =>
                    ListDetailScreen(listId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/import',
            builder: (_, state) => ImportFromLinkScreen(
              token: state.uri.queryParameters['token']!,
            ),
          ),
        ],
        if (fromDailyReview)
          GoRoute(
            path: '/quiz',
            builder: (_, state) => QuizScreen(args: state.extra! as QuizArgs),
          ),
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
    if (importRemote != null) {
      await tester.tap(find.byKey(const ValueKey('open-quiz')));
    }
    if (fromDailyReview) {
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.dailyPathReview)));
      await tick(tester, times: 4);
      await tester.tap(
        find.byKey(ValueKey(WidgetKeys.homeReviewMode(mode.name))),
      );
    }
    await tick(tester, times: 4); // loadCards + first frame
  }

  testWidgets(
    'an emptied pool offers retry and exit without a zero-score summary',
    (tester) async {
      await pump(tester, mode: QuizMode.flashcard, words: [], cardLimit: 3);
      expect(find.text('quiz.no_cards_available'.tr()), findsOneWidget);
      expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsNothing);
      await tester.tap(find.text('common.retry'.tr()));
      await tick(tester, times: 4);
      expect(find.text('quiz.no_cards_available'.tr()), findsOneWidget);
      expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsNothing);
      await tester.tap(find.text('common.back'.tr()));
      await tick(tester, times: 4);
      expect(navigatedTo, '/home');
      await unmountScreen(tester);
    },
  );

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

  testWidgets('next grammar card enters centered after the previous exit', (
    tester,
  ) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [],
      grammar: true,
      cardLimit: 2,
    );
    final stack = find.byType(V3CardStack);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 4);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump();
    expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsNothing);
    final slide = find.descendant(
      of: stack,
      matching: find.byType(SlideTransition),
    );
    expect(tester.widget<SlideTransition>(slide).position.value, Offset.zero);
    expect(progressRepo.saved, isEmpty);
    await unmountScreen(tester);
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

  testWidgets(
    'landscape typing keeps input and validation reachable above keyboard',
    (tester) async {
      await pump(tester, mode: QuizMode.typing, words: [('chat', '고양이')]);
      tester.view.physicalSize = const Size(1704, 960);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      final input = find.byKey(const ValueKey(WidgetKeys.ecrireInput));
      final validate = find.byKey(const ValueKey(WidgetKeys.ecrireValidate));
      final editable = find.descendant(
        of: input,
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, '고양이');
      final focus = tester.widget<EditableText>(editable).focusNode;
      tester.view.viewInsets = const FakeViewPadding(bottom: 540);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<EditableText>(editable).focusNode, same(focus));
      expect(focus.hasFocus, isTrue);
      expect(tester.widget<EditableText>(editable).controller.text, '고양이');
      final scroll = find.byKey(const ValueKey(WidgetKeys.quizPrompt));
      final scrollable = find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
      await tester.ensureVisible(validate);
      await tester.pump();
      expect(input.hitTestable(), findsOneWidget);
      expect(validate.hitTestable(), findsOneWidget);
      expect(tester.getRect(validate).bottom, lessThanOrEqualTo(140));
      await tester.tap(validate);
      tester.view.resetViewInsets();
      await tester.pump();
      expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final mode in [QuizMode.typing, QuizMode.voice]) {
      testWidgets('answer-language contrast in ${mode.name}/${theme.name}', (
        tester,
      ) async {
        useFallbackFontsForContrast();
        await pump(
          tester,
          mode: mode,
          words: [('chat', '고양이')],
          themeMode: theme,
        );
        final key = mode == QuizMode.typing
            ? 'quiz.write_in_lang'
            : 'quiz.say_in_lang';
        final cue = key.tr(namedArgs: {'lang': 'lang.ko'.tr()}).toUpperCase();
        expect(
          await renderedTextContrast(tester, find.text(cue)),
          greaterThanOrEqualTo(4.5),
        );
        await unmountScreen(tester);
      });
    }
  }

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

  testWidgets('typing submits and continues to the next card by keyboard', (
    tester,
  ) async {
    await pump(
      tester,
      mode: QuizMode.typing,
      words: [('chat', '고양이'), ('chien', '개')],
    );
    await tester.enterText(
      find.byKey(const ValueKey(WidgetKeys.ecrireInput)),
      '고양이',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tick(tester, times: 4);
    expect(
      find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester, times: 4);
    expect(
      find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
      findsNothing,
    );
    expect(find.text('chien'), findsOneWidget);
    expect(find.byKey(const ValueKey(WidgetKeys.ecrireInput)), findsOneWidget);
    expect(progressRepo.saved.single.timesCorrect, 1);
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

  for (final action in [WidgetKeys.voiceReveal, WidgetKeys.voiceKeyboard]) {
    testWidgets('voice $action works via Tab and Enter', (tester) async {
      final voice = _VoiceHarness();
      await pump(
        tester,
        mode: QuizMode.voice,
        words: [('chat', '고양이')],
        voice: voice,
      );
      final button = find.byKey(ValueKey(action));
      final label = find.descendant(of: button, matching: find.byType(Text));
      bool hasFocus() =>
          Focus.maybeOf(tester.element(label))?.hasPrimaryFocus ?? false;
      for (var press = 0; press < 8 && !hasFocus(); press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(hasFocus(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      if (action == WidgetKeys.voiceReveal) {
        expect(
          find.byKey(const ValueKey(WidgetKeys.feedbackWrong)),
          findsOneWidget,
        );
      } else {
        tester.view.physicalSize = const Size(1704, 960);
        tester.view.viewInsets = const FakeViewPadding(bottom: 540);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        final input = find.byKey(const ValueKey(WidgetKeys.voiceInput));
        final validate = find.byKey(const ValueKey(WidgetKeys.voiceValidate));
        await tester.ensureVisible(validate);
        await tester.pump();
        expect(input.hitTestable(), findsOneWidget);
        expect(validate.hitTestable(), findsOneWidget);
        expect(tester.getRect(validate).bottom, lessThanOrEqualTo(140));
        await tester.enterText(input, '고양이');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        tester.view.resetViewInsets();
        await tester.pump();
        expect(
          find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
          findsOneWidget,
        );
      }
      expect(voice.capture.opens, 0);
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
    });
  }

  testWidgets('voice microphone has a localized name and opens with Enter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final voice = _VoiceHarness();
    await pump(
      tester,
      mode: QuizMode.voice,
      words: [('chat', '고양이')],
      voice: voice,
    );
    final mic = find.byKey(const ValueKey(WidgetKeys.micButton));
    final icon = find.descendant(
      of: mic,
      matching: find.byIcon(Icons.mic_none),
    );
    expect(
      tester.getSemantics(icon),
      matchesSemantics(
        tooltip: 'quiz.voice_start_microphone'.tr(),
        isButton: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    bool focused() =>
        Focus.maybeOf(tester.element(icon))?.hasPrimaryFocus ?? false;
    for (var attempt = 0; attempt < 8 && !focused(); attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), isTrue);
    expect(voice.capture.opens, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(voice.capture.opens, 1);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets(
    'compact voice scrolls status, transcript and both alternatives',
    (tester) async {
      final voice = _VoiceHarness();
      final mode = _DelayedSttMode()..preference.complete(SttEngineMode.system);
      await pump(
        tester,
        mode: QuizMode.voice,
        words: [('chat', '고양이')],
        voice: voice,
        sttMode: mode,
      );
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.micButton)));
      await tick(tester);
      expect(voice.systemListens, 1);
      tester.view.physicalSize = const Size(1704, 960);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final transcript = List.filled(
        18,
        'Un exemple de transcription',
      ).join(' ');
      await voice.systemEvent('result', {
        'isFinal': false,
        'alternates': [
          {'words': transcript, 'confidence': .95},
        ],
      });
      await tester.pump();
      await tester.pump();
      final surface = find.byKey(const ValueKey(WidgetKeys.quizPrompt));
      final scrollable = find.descendant(
        of: surface,
        matching: find.byType(Scrollable),
      );
      final scrollPosition = tester.state<ScrollableState>(scrollable).position;
      expect(scrollPosition.maxScrollExtent, greaterThan(0));
      expect(find.byType(SttStatusStrip), findsOneWidget);
      expect(find.text(transcript), findsOneWidget);
      expect(find.text('v3.scroll_hint'.tr()), findsOneWidget);
      for (final key in [WidgetKeys.voiceReveal, WidgetKeys.voiceKeyboard]) {
        final alternative = find.byKey(ValueKey(key));
        await tester.ensureVisible(alternative);
        await tester.pump();
        expect(alternative.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
  );

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
          find.ancestor(of: scrollable, matching: find.byType(Scrollbar)),
          findsOneWidget,
        );
        await tester.drag(scrollable, const Offset(0, -80));
        await tester.pump();
        expect(position.pixels, greaterThan(0));
        final keys = mode == QuizMode.handsFree
            ? [WidgetKeys.hfRepeat, WidgetKeys.hfPause, WidgetKeys.hfSkip]
            : [WidgetKeys.ecrireInput, WidgetKeys.ecrireValidate];
        for (final key in keys) {
          final control = find.byKey(ValueKey(key));
          if (mode == QuizMode.handsFree) await tester.ensureVisible(control);
          expect(control.hitTestable(), findsOneWidget);
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

  testWidgets('compact summary announces scroll and exposes both actions', (
    tester,
  ) async {
    await pump(tester, mode: QuizMode.flashcard, words: [('chat', '고양이')]);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 2);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeAgain)));
    await tick(tester, times: 4);
    tester.view.physicalSize = const Size(1704, 960);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tick(tester, times: 4);
    final summary = find.byKey(const ValueKey(WidgetKeys.summary));
    expect(summary, findsOneWidget);
    final cue = find.descendant(
      of: summary,
      matching: find.text('v3.scroll_hint'.tr()),
    );
    expect(cue, findsOneWidget);
    final opacity = find
        .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
        .first;
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
    for (final key in [WidgetKeys.summaryRestart, WidgetKeys.summaryDone]) {
      final action = find.byKey(ValueKey(key));
      await tester.ensureVisible(action);
      await tick(tester);
      expect(action.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
  });

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

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets(
      'a failed card read is localized and returns by keyboard ($locale)',
      (tester) async {
        final raw = (await tester.runAsync(
          () => rootBundle.loadString('assets/translations/$locale.json'),
        ))!;
        final strings = jsonDecode(raw) as Map<String, dynamic>;
        final translations = Translations(strings);
        Localization.load(
          Locale(locale),
          translations: translations,
          fallbackTranslations: translations,
        );
        addTearDown(initTestLocalization);
        const details = 'SQLite SELECT variant_progress: missing table';
        await pump(
          tester,
          mode: QuizMode.flashcard,
          words: [('chat', '고양이')],
          entry: '/start-session',
          loadFailure: const StorageException(details),
        );

        expect(
          find.text(strings['quiz.load_failed'] as String),
          findsOneWidget,
        );
        expect(find.textContaining(details), findsNothing);
        expect(find.textContaining('Failed to load cards'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, strings['common.back'] as String),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('open-quiz')), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester, times: 4);
        expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
        expect(find.byType(QuizScreen), findsNothing);
        expect(navigatedTo, isNull);
        await unmountScreen(tester);
      },
    );
  }

  testWidgets('an exception enriching selected cards returns to the setup '
      'by keyboard', (tester) async {
    late _FailingAnswerVariantDao dao;
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [('chat', '고양이')],
      entry: '/start-session',
      quizConceptDao: (db) => dao = _FailingAnswerVariantDao(db),
    );

    expect(progressRepo.due, isNotEmpty);
    expect(dao.languagesRead, ['fr', 'ko']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('quiz.load_failed'.tr()), findsOneWidget);
    expect(
      find.textContaining('SQLite answer-variant query failed'),
      findsNothing,
    );
    expect(
      find.widgetWithText(FilledButton, 'common.back'.tr()),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-quiz')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester, times: 4);
    expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(navigatedTo, isNull);
    await unmountScreen(tester);
  });

  testWidgets('an empty session returns to the daily path', (tester) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [],
      entry: '/daily-path',
    );
    expect(find.text('quiz.no_cards_available'.tr()), findsOneWidget);
    expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsNothing);
    await tester.tap(find.text('common.back'.tr()));
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

  for (final hangs in [false, true]) {
    testWidgets('system back handles PCM cleanup failure (hangs: $hangs)', (
      tester,
    ) async {
      final voice = _VoiceHarness();
      await pump(
        tester,
        mode: QuizMode.handsFree,
        entry: '/daily-path',
        words: [('chat', '고양이')],
        voice: voice,
      );
      await tick(tester, times: 8);
      final capture = voice.capture.session!;
      final closing = Completer<void>();
      if (hangs) {
        capture.pendingClose = closing.future;
      } else {
        capture.closeError = StateError('recorder still active');
      }
      final providers = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      await providers
          .read(sttEngineModeProvider.notifier)
          .set(SttEngineMode.system);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tick(tester, times: 12);
      expect(find.byType(QuizScreen), findsNothing);
      expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
      expect(capture.closeCalls, greaterThan(0));
      expect(capture.closed, isFalse);
      expect(tester.takeException(), isNull);

      // A new route cannot switch to the exclusive recognizer while the app's
      // earlier shared microphone has not confirmed release.
      await tester.tap(find.byKey(const ValueKey('open-quiz')));
      await tick(tester, times: 16);
      expect(find.text('quiz.mic_release_failed_hf'.tr()), findsOneWidget);
      expect(voice.systemListens, 0);
      expect(voice.director.cues, 1);
      expect(voice.director.endCues, 0);
      if (hangs) closing.complete();
      capture.closeError = null;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await tick(tester, times: 10);
      expect(voice.systemListens, 1);
      expect(voice.director.cues, 2);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a rejected connectivity channel lets Course continue locally', (
    tester,
  ) async {
    final network = Completer<List<String>>();
    var checks = 0;
    final voice = _VoiceHarness(
      checkConnectivity: () {
        checks++;
        return network.future;
      },
    );
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    expect(checks, 1);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);

    network.completeError(PlatformException(code: 'ConnectivityUnavailable'));
    await tick(tester, times: 8);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 1);
    expect(voice.systemListens, 0);
    voice.capture.session!.answer();
    await tick(tester, times: 3);
    expect(voice.whisper.decodes, 1);
    expect(progressRepo.saved, hasLength(1));
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('System starts without consulting the connectivity channel', (
    tester,
  ) async {
    var checks = 0;
    final voice = _VoiceHarness(
      checkConnectivity: () async {
        checks++;
        throw PlatformException(code: 'ConnectivityUnavailable');
      },
    );
    final mode = _DelayedSttMode()..preference.complete(SttEngineMode.system);
    await pump(
      tester,
      mode: QuizMode.voice,
      words: [('chat', '고양이')],
      voice: voice,
      sttMode: mode,
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.micButton)));
    await tick(tester, times: 4);
    expect(checks, 0);
    expect(voice.systemListens, 1);
    expect(voice.capture.opens, 0);
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
  });

  for (final cancel in [false, true]) {
    testWidgets('a rejected native recorder permission allows a safe retry '
        '(cancelled first: $cancel)', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('com.llfbandit.record/messages');
      final permission = Completer<bool>();
      final retryPermission = Completer<bool>();
      var permissionChecks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'hasPermission') return null;
        return ++permissionChecks == 1
            ? await permission.future
            : await retryPermission.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final recorder = RecordPcmMicrophone();
      final voice = _VoiceHarness();
      voice.capture.checkPermission = recorder.hasPermission;
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이')],
        voice: voice,
      );
      expect(permissionChecks, 1);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);
      if (cancel) {
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
        await tester.pump();
      }

      permission.completeError(
        PlatformException(code: 'PermissionQueryFailed'),
      );
      await tick(tester, times: 2);
      final message = find.text('quiz.voice_prepare_failed'.tr());
      expect(message, cancel ? findsNothing : findsOneWidget);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);
      await tester.tap(
        find.byKey(
          ValueKey(cancel ? WidgetKeys.hfResume : WidgetKeys.hfRepeat),
        ),
      );
      await tick(tester, times: 5);
      expect(permissionChecks, 2);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);

      retryPermission.complete(true);
      await tick(tester, times: 8);
      expect(message, findsNothing);
      expect(voice.director.cues, 1);
      expect(voice.capture.opens, 1);
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
      recorder.dispose();
      await tester.pump();
    });
  }

  testWidgets('a failed partial mic start releases before a newer retry', (
    tester,
  ) async {
    final release = Completer<void>();
    final voice = _VoiceHarness();
    voice.capture.onOpen = (session) {
      if (voice.capture.opens == 1) {
        session.pendingClose = release.future;
        throw PlatformException(code: 'RecorderStartFailed');
      }
    };
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    await tick(tester, times: 8);
    final partial = voice.capture.session!;
    expect(partial.closeCalls, greaterThan(0));
    expect(partial.closed, isFalse);
    expect(find.text('quiz.voice_prepare_failed'.tr()), findsNothing);

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
    await tick(tester, times: 2);
    expect(voice.capture.opens, 1);
    expect(voice.director.cues, 1);
    release.complete();
    await tick(tester, times: 10);
    expect(partial.closed, isTrue);
    expect(voice.capture.opens, 2);
    expect(voice.director.cues, 2);
    expect(find.text('quiz.voice_prepare_failed'.tr()), findsNothing);
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
  });

  for (final staleBy in ['current', 'pause', 'account']) {
    testWidgets('native phone preparation failure is contained ($staleBy)', (
      tester,
    ) async {
      final firstProbe = Completer<bool>();
      final nextProbe = Completer<bool>();
      var probes = 0;
      final voice = _VoiceHarness(
        probePhone: () => ++probes == 1 ? firstProbe.future : nextProbe.future,
      );
      final account = StateProvider<AppUser?>((_) => _importAccount());
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이')],
        voice: voice,
        account: account,
      );
      await tick(tester, times: 5);
      expect(voice.phonePrepares, 1);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);

      if (staleBy == 'pause') {
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      } else if (staleBy == 'account') {
        final providers = ProviderScope.containerOf(
          tester.element(find.byType(QuizScreen)),
        );
        providers.read(account.notifier).state = null;
      }
      await tester.pump();
      firstProbe.completeError(PlatformException(code: 'PhoneProbeFailed'));
      await tick(tester, times: 3);
      final message = find.text('quiz.voice_prepare_failed'.tr());
      expect(message, staleBy == 'current' ? findsOneWidget : findsNothing);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);
      expect(tester.takeException(), isNull);

      if (staleBy != 'account') {
        final cue = voice.director.pendingCue = Completer<void>();
        await tester.tap(
          find.byKey(
            ValueKey(
              staleBy == 'current' ? WidgetKeys.hfRepeat : WidgetKeys.hfResume,
            ),
          ),
        );
        await tick(tester, times: 8);
        expect(voice.phonePrepares, 2);
        expect(voice.director.cues, 0);
        expect(voice.capture.opens, 0);
        nextProbe.complete(false);
        await tick(tester, times: 8);
        expect(message, findsNothing);
        expect(voice.director.cues, 1);
        expect(voice.capture.opens, 0);
        cue.complete();
        await tick(tester, times: 2);
        expect(voice.capture.opens, 1);
      }
      await unmountScreen(tester);
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
    'hands-free awaits the grammar instruction and word on both cards',
    (tester) async {
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'fr';
      addTearDown(() => Intl.defaultLocale = previousLocale);
      final audio = _BlockingPromptAudio();
      final voice = _VoiceHarness(promptAudio: audio);
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [],
        cardLimit: 2,
        grammar: true,
        voice: voice,
      );

      for (var index = 0; index < 2; index++) {
        await tick(tester, times: 8);
        expect(audio.utterances, hasLength(index * 2 + 1));
        final (instruction, instructionLang, instructionDone) =
            audio.utterances.last;
        expect(instruction, contains('les formes de la particule'));
        expect(instructionLang, 'fr');
        expect(voice.director.cues, index);
        expect(voice.capture.opens, index);

        instructionDone.complete();
        await tick(tester, times: 8);
        expect(audio.utterances, hasLength(index * 2 + 2));
        final (word, wordLang, wordDone) = audio.utterances.last;
        expect(word, anyOf('은. 는. 학생', '은. 는. 친구'));
        expect(wordLang, 'ko');
        expect(voice.director.cues, index);
        expect(voice.capture.opens, index);

        wordDone.complete();
        await tick(tester, times: 8);
        expect(voice.director.cues, index + 1);
        expect(voice.capture.opens, index + 1);
        voice.capture.session!.answer();
        await tick(tester, times: 5);
      }

      expect(audio.utterances[1].$1, isNot(audio.utterances[3].$1));
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'hands-free vocabulary awaits native configuration and both prompts',
    (tester) async {
      const channel = MethodChannel('flutter_tts');
      final messenger = tester.binding.defaultBinaryMessenger;
      final configuration = Completer<int>();
      final utterances = <(String, Completer<int>)>[];
      int configurationCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getEngines':
            return <Object>[];
          case 'setLanguage':
            if (++configurationCalls == 1) return configuration.future;
          case 'speak':
            final done = Completer<int>();
            utterances.add((call.arguments as String, done));
            return done.future;
        }
        return 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final tts = FlutterTtsService();
      final voice = _VoiceHarness(
        promptAudio: AudioPlayerService(
          usePremium: false,
          filePlayer: _SilentFilePlayer(),
          tts: tts,
        ),
      );
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이'), ('félin', '고양이')],
        voice: voice,
      );
      expect(configurationCalls, 1);
      await tick(tester, times: 16);
      expect(tts.isSpeaking, isFalse);
      expect(utterances, isEmpty);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);
      configuration.complete(1);
      for (var index = 0; index < 2; index++) {
        await tick(tester, times: 12);
        expect(utterances, hasLength(index + 1));
        expect(voice.director.cues, index);
        expect(voice.capture.opens, index);
        utterances.last.$2.complete(1);
        await tick(tester, times: 8);
        expect(voice.director.cues, index + 1);
        expect(voice.capture.opens, index + 1);
        voice.capture.session!.answer();
        await tick(tester, times: 6);
      }
      expect(utterances.map((utterance) => utterance.$1), ['chat', 'félin']);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
  );

  for (final timesOut in [false, true]) {
    testWidgets(
      'vocabulary prompt can be repeated after failure (timeout: $timesOut)',
      (tester) async {
        final audio = _BlockingPromptAudio();
        final voice = _VoiceHarness(promptAudio: audio);
        await pump(
          tester,
          mode: QuizMode.handsFree,
          words: [('chat', '고양이')],
          voice: voice,
        );
        if (timesOut) {
          await tester.pump(const Duration(seconds: 16));
        } else {
          audio.utterances.single.$3.completeError(
            StateError('Prompt rejected'),
          );
          await tester.pump();
        }
        await tester.pump();
        expect(find.text('quiz.grammar_prompt_failed'.tr()), findsOneWidget);
        expect(voice.director.cues, 0);
        expect(voice.capture.opens, 0);
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
        await tester.pump();
        expect(audio.utterances, hasLength(2));
        audio.utterances.last.$3.complete();
        await tick(tester, times: 8);
        expect(voice.director.cues, 1);
        expect(voice.capture.opens, 1);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 8));
      },
    );
  }

  testWidgets('file error releases before device fallback and listening', (
    tester,
  ) async {
    final file = _RejectingFilePlayer();
    final cache = _CachedPrompt();
    final speech = _PendingDeviceSpeech();
    final audio = AudioPlayerService(
      usePremium: true,
      assetCache: cache,
      filePlayer: file,
      tts: speech,
    );
    final voice = _VoiceHarness(promptAudio: audio, verifyAudioHandoff: true);
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      questionAudioPath: 'seed/v1/fr/chat.mp3',
    );
    expect(file.starts, 1);
    expect(file.releases, 1);
    expect(speech.speaks, 0);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);
    expect(tester.takeException(), isNull);

    file.released.complete();
    await tick(tester, times: 8);
    expect(cache.invalidated, ['seed/v1/fr/chat.mp3']);
    expect(speech.speaks, 1);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);
    speech.playback.complete();
    await tick(tester, times: 8);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 1);
    speech.released.complete();
    await unmountScreen(tester);
    audio.dispose();
    await audio.stop();
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets(
    'restored speech rate replaces a held prompt and waits for replay',
    (tester) async {
      final voice = _VoiceHarness();
      final settings = _RestoringAudioSettings();
      final voices = <_PendingDeviceSpeech>[];
      final directors = <_TestDirector>[];
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이')],
        voice: voice,
        audioSettings: settings,
        audioFactory: (ref) {
          final rate = ref.watch(
            audioSettingsProvider.select((state) => state.speechRate),
          );
          final tts = _PendingDeviceSpeech();
          voices.add(tts);
          final audio = AudioPlayerService(
            usePremium: false,
            speechRate: rate,
            tts: tts,
            filePlayer: _SilentFilePlayer(),
          );
          ref.onDispose(audio.dispose);
          return audio;
        },
        directorFactory: (audio) {
          final director = _TestDirector(audio);
          directors.add(director);
          return director;
        },
      );
      final oldVoice = voices.single;
      expect(oldVoice.speaks, 1);
      settings.restored.complete(.7);
      await tester.pump();
      expect(oldVoice.disposals, 1);
      expect(voices, hasLength(2));
      expect(voices.last.speaks, 0);
      oldVoice.playback.complete();
      await tester.pump();
      expect(voice.capture.opens, 0);
      expect(directors.every((director) => director.cues == 0), isTrue);

      oldVoice.released.complete();
      await tick(tester, times: 10);
      expect(voices.last.speaks, 1);
      expect(voice.capture.opens, 0);
      expect(directors.every((director) => director.cues == 0), isTrue);
      voices.last.playback.complete();
      await tick(tester, times: 8);
      expect(voice.capture.opens, 1);
      expect(directors.map((director) => director.cues), [0, 1]);
      voices.last.released.complete();
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
  );

  testWidgets(
    'native opening cue requires completion across failures and director changes',
    (tester) async {
      const codec = StandardMethodCodec();
      const global = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const player = MethodChannel('xyz.luan/audioplayers');
      final messenger = tester.binding.defaultBinaryMessenger;
      final events = <String, MethodChannel>{};
      var preparationCalls = 0;
      var playbackCalls = 0;
      var successfulCues = 0;
      String? lastCuePlayer;
      String? preparingPlayer;
      Completer<void>? preparing;
      String? loadingBytesPlayer;
      Completer<void>? loadingBytes;
      String? stoppingPlayer;
      Completer<void>? stopping;
      final stopRequests = <String>[];
      Future<void> until(bool Function() ready) async {
        for (var attempt = 0; attempt < 300 && !ready(); attempt++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(ready(), isTrue);
      }

      Future<void> finishCue(String id) => messenger.handlePlatformMessage(
        events[id]!.name,
        codec.encodeSuccessEnvelope({'event': 'audio.onComplete'}),
        null,
      );
      messenger.setMockMethodCallHandler(global, (_) async => null);
      messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
      messenger.setMockMethodCallHandler(player, (call) async {
        final id = call.arguments['playerId'] as String;
        switch (call.method) {
          case 'setAudioContext':
            if (++preparationCalls == 1) {
              throw PlatformException(code: 'NativeCuePreparationRefused');
            }
            final initializing = preparing;
            if (initializing != null) {
              preparingPlayer = id;
              preparing = null;
              await initializing.future;
            }
          case 'create':
            final channel = events[id] = MethodChannel(
              'xyz.luan/audioplayers/events/$id',
            );
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          case 'setSourceBytes':
            final loading = loadingBytes;
            if (loading != null) {
              loadingBytesPlayer = id;
              loadingBytes = null;
              await loading.future;
            }
            await messenger.handlePlatformMessage(
              events[id]!.name,
              codec.encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
              null,
            );
          case 'getCurrentPosition':
            return 0;
          case 'resume':
            if (++playbackCalls == 1) {
              throw PlatformException(code: 'NativeCuePlaybackRefused');
            }
            successfulCues++;
            lastCuePlayer = id;
          case 'stop':
            stopRequests.add(id);
            if (id == stoppingPlayer) await stopping?.future;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(global, null);
        messenger.setMockMethodCallHandler(globalEvents, null);
        messenger.setMockMethodCallHandler(player, null);
        for (final channel in events.values) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      final voice = _VoiceHarness();
      final audioPlayers = <_NoopAudio>[];
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이')],
        voice: voice,
        useRealDirector: true,
        audioFactory: (ref) {
          ref.watch(
            audioSettingsProvider.select((s) => (s.speechRate, s.pitch)),
          );
          final audio = _NoopAudio();
          audioPlayers.add(audio);
          return audio;
        },
      );
      final providers = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      final director = providers.read(audioDirectorProvider);
      await tick(tester, times: 12);
      expect(preparationCalls, 1);
      expect(playbackCalls, 0);
      expect(successfulCues, 0);
      expect(voice.capture.opens, 0);
      expect(find.text('quiz.listen_cue_failed'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await tick(tester, times: 12);
      expect(preparationCalls, 2);
      expect(playbackCalls, 1);
      expect(successfulCues, 0);
      expect(voice.capture.opens, 0);
      expect(find.text('quiz.listen_cue_failed'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await tick(tester, times: 12);
      expect(preparationCalls, 3);
      expect(playbackCalls, 2);
      expect(successfulCues, 1);
      expect(voice.capture.opens, 0);
      final timedOut = lastCuePlayer!;
      await tick(tester, times: 10);
      expect(find.text('quiz.listen_cue_failed'.tr()), findsOneWidget);
      expect(voice.capture.opens, 0);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await tick(tester, times: 12);
      expect(successfulCues, 2);
      final paused = lastCuePlayer!;
      expect(paused, isNot(timedOut));
      await finishCue(timedOut);
      await tester.pump();
      expect(voice.capture.opens, 0);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      await tester.pump();
      await finishCue(paused);
      await tester.pump();
      expect(voice.capture.opens, 0);
      expect(find.byKey(const ValueKey(WidgetKeys.hfResume)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfResume)));
      await tick(tester, times: 12);
      expect(successfulCues, 3);
      expect(lastCuePlayer, isNot(paused));
      expect(voice.capture.opens, 0);
      await finishCue(lastCuePlayer!);
      await tick(tester, times: 2);
      expect(voice.capture.opens, 1);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      await tester.pump();
      final nativePreparation = preparing = Completer<void>();
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfResume)));
      await until(() => preparingPlayer != null);
      final blockedPlayer = preparingPlayer!;
      final preparedAt = tester.binding.clock.now();
      expect(successfulCues, 3);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await until(() => successfulCues == 4);
      final replacement = lastCuePlayer!;
      expect(replacement, isNot(blockedPlayer));
      expect(stopRequests, contains(blockedPlayer));
      final elapsed = tester.binding.clock.now().difference(preparedAt);
      expect(elapsed, lessThan(const Duration(seconds: 2)));
      await tester.pump(const Duration(milliseconds: 2100) - elapsed);
      expect(stopRequests, isNot(contains(replacement)));
      expect(voice.capture.opens, 1);
      await finishCue(replacement);
      await tick(tester, times: 2);
      expect(voice.capture.opens, 2);
      nativePreparation.complete();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      await tester.pump();
      unawaited(director.playListenDone());
      await until(() => successfulCues == 5);
      final optional = stoppingPlayer = lastCuePlayer!;
      final oldStop = stopping = Completer<void>();
      final nativeBytes = loadingBytes = Completer<void>();
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfResume)));
      await until(() => stopRequests.contains(optional));
      await tester.pump(const Duration(milliseconds: 150));
      expect(loadingBytesPlayer, isNull);
      expect(voice.capture.opens, 2);

      oldStop.complete();
      await until(() => loadingBytesPlayer != null);
      final current = loadingBytesPlayer!;
      expect(current, isNot(optional));
      await finishCue(optional);
      nativeBytes.complete();
      await until(() => successfulCues == 6);
      await tester.pump(const Duration(milliseconds: 250));
      expect(lastCuePlayer, current);
      expect(voice.capture.opens, 2);
      await finishCue(current);
      await tick(tester, times: 2);
      expect(voice.capture.opens, 3);

      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfResume)));
      await until(() => successfulCues == 7);
      final retired = stoppingPlayer = lastCuePlayer!;
      final pendingRetirement = stopping = Completer<void>();
      final settings = providers.read(audioSettingsProvider.notifier);
      await settings.setSpeechRate(.7);
      await until(() => stopRequests.contains(retired));
      expect(providers.read(audioDirectorProvider), isNot(same(director)));

      // Replacing the replacement still leaves the first native stop pending.
      await settings.setPitch(1.1);
      await tester.pump();
      final repeat = find.byKey(const ValueKey(WidgetKeys.hfRepeat));
      await tester.tap(repeat);
      await until(
        () => find
            .text('quiz.audio_release_failed_hf'.tr())
            .evaluate()
            .isNotEmpty,
      );
      expect(audioPlayers.last.spoken, isEmpty);
      expect(successfulCues, 7);
      expect(voice.capture.opens, 3);
      expect(stopRequests.where((id) => id == retired), hasLength(1));

      pendingRetirement.completeError(PlatformException(code: 'StopRefused'));
      await tester.pump();
      final retryRetirement = stopping = Completer<void>();
      await tester.tap(repeat);
      await until(() => stopRequests.where((id) => id == retired).length == 2);
      expect(audioPlayers.last.spoken, isEmpty);
      expect(voice.capture.opens, 3);

      retryRetirement.complete();
      await until(() => successfulCues == 8);
      expect(audioPlayers.last.spoken, ['chat']);
      expect(voice.capture.opens, 3);
      final replacementCue = lastCuePlayer!;
      expect(replacementCue, isNot(retired));
      await finishCue(retired);
      await tester.pump();
      expect(voice.capture.opens, 3);
      await finishCue(replacementCue);
      await tick(tester, times: 2);
      expect(voice.capture.opens, 4);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('Repeat waits for mobile TTS release after native refusal', (
    tester,
  ) async {
    const channel = MethodChannel('vocab_kr/device_speech');
    final messenger = tester.binding.defaultBinaryMessenger;
    final playback = <Completer<int>>[];
    final confirmed = Completer<int>();
    var stops = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'speak':
          final done = Completer<int>();
          playback.add(done);
          return done.future;
        case 'stop':
          switch (++stops) {
            case 1:
              return 0;
            case 2:
              return confirmed.future;
          }
      }
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final voice = _VoiceHarness();
    final settings = _RestoringAudioSettings();
    final directors = <_TestDirector>[];
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      audioSettings: settings,
      audioFactory: (ref) {
        final rate = ref.watch(
          audioSettingsProvider.select((settings) => settings.speechRate),
        );
        final audio = AudioPlayerService(
          usePremium: false,
          tts: FlutterTtsService(speechRate: rate, mobileChannel: channel),
          filePlayer: _SilentFilePlayer(),
        );
        ref.onDispose(audio.dispose);
        return audio;
      },
      directorFactory: (audio) {
        final director = _TestDirector(audio);
        directors.add(director);
        return director;
      },
    );
    expect(playback, hasLength(1));
    settings.restored.complete(.7);
    await tick(tester, times: 3);
    expect(stops, 1);
    expect(find.text('quiz.audio_release_failed_hf'.tr()), findsOneWidget);
    expect(voice.capture.opens, 0);

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
    await tester.pump();
    expect(stops, 2);
    expect(playback, hasLength(1));
    // The retry remains pending until the old utterance actually stops.
    expect(voice.capture.opens, 0);
    expect(directors.every((director) => director.cues == 0), isTrue);

    playback.first.complete(0);
    confirmed.complete(1);
    await tick(tester, times: 10);
    expect(playback, hasLength(2));
    expect(voice.capture.opens, 0);
    expect(directors.every((director) => director.cues == 0), isTrue);
    playback.last.complete(1);
    await tick(tester, times: 10);
    expect(voice.capture.opens, 1);
    expect(directors.map((director) => director.cues), [0, 1]);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('daily review shortcut rates its one due card once', (
    tester,
  ) async {
    await pump(
      tester,
      mode: QuizMode.flashcard,
      words: [('chat', '고양이')],
      fromDailyReview: true,
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
    await tick(tester, times: 2);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
    await tick(tester, times: 6);
    expect(find.byKey(const ValueKey(WidgetKeys.summary)), findsOneWidget);
    expect(progressRepo.saved, hasLength(1));
    expect(progressRepo.saved.single.timesShown, 1);
    await unmountScreen(tester);
  });

  testWidgets('switching accounts hides cards and cancels captured speech', (
    tester,
  ) async {
    AppUser user(String id) => AppUser(
      id: id,
      email: '$id@example.com',
      username: id,
      createdAt: _now,
    );
    final account = StateProvider<AppUser?>((_) => user('u'));
    final voice = _VoiceHarness();
    final decoding = voice.whisper.pendingDecode = Completer<String?>();
    await pump(
      tester,
      mode: QuizMode.voice,
      words: [('chat', '고양이')],
      account: account,
      voice: voice,
    );
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.micButton)));
    await tester.pump();
    final capture = voice.capture.session!;
    capture.answer();
    await tester.pump();

    final providers = ProviderScope.containerOf(
      tester.element(find.byType(QuizScreen)),
    );
    providers.read(account.notifier).state = user('b');
    await tester.pump();
    expect(capture.closed, isTrue);
    expect(find.text('chat'), findsNothing);
    expect(find.text('quiz.account_changed'.tr()), findsOneWidget);
    decoding.complete('고양이');
    await tick(tester, times: 3);
    expect(progressRepo.saved, isEmpty);
    await tester.runAsync(() async {
      expect(await db.reviewEventDao.getByUser('b'), isEmpty);
    });
    await unmountScreen(tester);
  });

  testWidgets('the hands-free end cue waits for the capture to close', (
    tester,
  ) async {
    final voice = _VoiceHarness();
    final decoding = voice.whisper.pendingDecode = Completer<String?>();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    await tick(tester, times: 8);
    final capture = voice.capture.session!;
    final closing = Completer<void>();
    capture.pendingClose = closing.future;
    await tester.pump(const Duration(seconds: 4));
    capture.answer();
    await tester.pump();
    expect(voice.whisper.decodes, 1);
    expect(voice.director.endCues, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(capture.closed, isFalse);
    expect(voice.director.endCues, 0);
    closing.complete();
    await tester.pump();
    expect(capture.closed, isTrue);
    expect(voice.director.endCues, 1);
    decoding.complete();
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('unconfirmed capture release has no cue or overlapping retry', (
    tester,
  ) async {
    final voice = _VoiceHarness();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
    );
    await tick(tester, times: 8);
    final capture = voice.capture.session!;
    final release = Completer<void>();
    capture.pendingClose = release.future;
    capture.answer();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(voice.director.endCues, 0);
    expect(progressRepo.saved, isEmpty);
    expect(find.text('quiz.mic_release_failed_hf'.tr()), findsOneWidget);

    final repeat = find.byKey(const ValueKey(WidgetKeys.hfRepeat));
    await tester.tap(repeat);
    await tick(tester, times: 23);
    expect(voice.capture.opens, 1);
    expect(voice.director.cues, 1);
    expect(voice.director.endCues, 0);

    release.complete();
    await tester.pump();
    await tester.tap(repeat);
    await tick(tester, times: 12);
    expect(voice.director.cues, 2);
    expect(voice.capture.opens, 2);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  for (final hangs in [false, true]) {
    testWidgets(
      'system release blocks grading and a switch to PCM (hangs: $hangs)',
      (tester) async {
        var reject = !hangs;
        final nativeStop = Completer<void>();
        final voice = _VoiceHarness(
          acceptSystemStop: () => !reject,
          systemRelease: hangs ? nativeStop.future : null,
        );
        SharedPreferences.setMockInitialValues({
          'settings_stt_engine_mode': 'system',
        });
        await pump(
          tester,
          mode: QuizMode.handsFree,
          entry: '/daily-path',
          words: [('chat', '고양이')],
          voice: voice,
        );
        await tick(tester, times: 8);
        expect(voice.systemListens, 1);
        expect(voice.director.cues, 1);
        await voice.systemFinalResult('고양이');
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(voice.systemStops, 1);
        expect(voice.director.endCues, 0);
        expect(progressRepo.saved, isEmpty);
        expect(find.text('quiz.mic_release_failed_hf'.tr()), findsOneWidget);
        if (hangs) {
          await voice.systemEvent(
            'released',
            const {},
            session: voice.systemSession! - 1,
          );
        }

        final providers = ProviderScope.containerOf(
          tester.element(find.byType(QuizScreen)),
        );
        await providers
            .read(sttEngineModeProvider.notifier)
            .set(SttEngineMode.race);
        final repeat = find.byKey(const ValueKey(WidgetKeys.hfRepeat));
        await tester.tap(repeat);
        await tick(tester, times: 24);
        expect(voice.capture.opens, 0);
        expect(voice.systemListens, 1);
        expect(voice.director.cues, 1);
        expect(voice.director.endCues, 0);
        if (hangs) {
          expect(await tester.binding.handlePopRoute(), isTrue);
          await tick(tester, times: 12);
          await tester.tap(find.byKey(const ValueKey('open-quiz')));
          await tick(tester, times: 16);
          expect(find.text('quiz.mic_release_failed_hf'.tr()), findsOneWidget);
          expect(voice.capture.opens, 0);
          expect(voice.director.cues, 1);
          expect(voice.systemStops, 1);
          nativeStop.complete();
        }
        reject = false;
        await tester.pump();
        await tester.tap(repeat);
        await tick(tester, times: 12);
        expect(voice.capture.opens, 1);
        expect(voice.director.cues, 2);
        expect(voice.director.endCues, 0);
        expect(progressRepo.saved, isEmpty);
        voice.capture.session!.answer();
        await tick(tester, times: 3);
        expect(progressRepo.saved, hasLength(1));
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 8));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final hangs in [false, true]) {
    testWidgets(
      'unconfirmed audio stop keeps cue and mic idle (hangs: $hangs)',
      (tester) async {
        final release = Completer<void>();
        final audio = _AudioAwaitingRelease()
          ..pendingStop = hangs ? release.future : null
          ..refuseStop = !hangs;
        final voice = _VoiceHarness(
          promptAudio: audio,
          verifyAudioHandoff: true,
        );
        await pump(
          tester,
          mode: QuizMode.handsFree,
          words: [('chat', '고양이')],
          voice: voice,
        );
        await tick(tester, times: 8);
        expect(find.text('quiz.audio_release_failed_hf'.tr()), findsOneWidget);
        expect(audio.playing, isTrue);
        expect(audio.stops, 1);
        expect(voice.director.cues, 0);
        expect(voice.capture.opens, 0);
        expect(voice.systemListens, 0);

        final repeat = find.byKey(const ValueKey(WidgetKeys.hfRepeat));
        if (hangs) {
          await tester.tap(repeat);
          await tick(tester, times: 8);
          expect(audio.stops, 1);
          expect(voice.director.cues, 0);
          expect(voice.capture.opens, 0);
          release.complete();
          await tester.pump();
        } else {
          audio.refuseStop = false;
        }
        await tester.tap(repeat);
        await tick(tester, times: 10);
        expect(audio.playing, isFalse);
        expect(voice.director.cues, 1);
        expect(voice.capture.opens, 1);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 8));
      },
    );
  }

  testWidgets(
    'offline quiz completion keeps the streak warning off after restart',
    (tester) async {
      final learner = AppUser(
        id: 'u',
        email: 'u@example.test',
        username: 'u',
        currentStreak: 6,
        createdAt: _now,
      );
      final user = StateProvider<AppUser?>((_) => learner);
      final update = Completer<void>();
      final auth = _FakeAuthRepo()..pendingStreak = update.future;
      final reminders = _FakeNotifService();
      await pump(
        tester,
        mode: QuizMode.flashcard,
        words: [('chat', '고양이')],
        account: user,
        authRepo: auth,
        reminders: reminders,
      );
      expect(reminders.scheduledStreaks, [6]);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.cartesCard)));
      await tick(tester, times: 2);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.gradeKnew)));
      await tick(tester, times: 3);
      expect(auth.streakUpdates, 1);
      expect(update.isCompleted, isFalse);
      expect(reminders.cancelledStreaks, 1);
      expect(
        await db.quizSessionDao.getSessionsByUser(learner.id),
        hasLength(1),
      );
      final providers = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      providers.read(user.notifier).state = learner.copyWith(currentStreak: 7);
      await tester.pump();
      expect(reminders.scheduledStreaks, [6]);
      await unmountScreen(tester);

      final afterRestart = _FakeNotifService();
      final restarted = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWith((ref) => ref.watch(user)),
          notificationServiceProvider.overrideWithValue(afterRestart),
        ],
      );
      addTearDown(restarted.dispose);
      final restored = authenticatedRemindersProvider(const Locale('ko'));
      restarted.listen(restored, (_, _) {});
      await restarted.read(restored.future);
      expect(update.isCompleted, isFalse);
      expect(afterRestart.cancelledStreaks, 1);
      expect(afterRestart.scheduledStreaks, isEmpty);

      restarted.read(user.notifier).state = learner.copyWith(id: 'other');
      await tester.pump(const Duration(milliseconds: 1));
      await restarted.read(restored.future);
      expect(afterRestart.scheduledStreaks, [6]);
      update.complete();
      await tester.pump();
    },
  );

  testWidgets('recognizer preflight precedes first and retry opening cues', (
    tester,
  ) async {
    final prepared = Completer<bool>();
    final retryConnectivity = Completer<List<String>>();
    var connectivityChecks = 0;
    final voice = _VoiceHarness(
      preparePhone: prepared,
      checkConnectivity: () =>
          ++connectivityChecks == 1 ? ['none'] : retryConnectivity.future,
    );
    final firstCue = voice.director.pendingCue = Completer<void>();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      machineFactory: () => VoiceTurnMachine(
        retryPacing: Duration.zero,
        ladderBeat: Duration.zero,
      ),
    );
    expect(voice.phonePrepares, 1);
    expect(connectivityChecks, 0);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);

    prepared.complete(false);
    await tick(tester, times: 8);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 0);
    firstCue.complete();
    await tester.pump();
    expect(voice.capture.opens, 1);

    await tester.pump(const Duration(seconds: 8));
    await tick(tester, times: 4);
    expect(connectivityChecks, 2);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 1);
    final retryCue = voice.director.pendingCue = Completer<void>();
    retryConnectivity.complete(['none']);
    await tick(tester, times: 8);
    expect(voice.director.cues, 2);
    expect(voice.capture.opens, 1);
    retryCue.complete();
    await tester.pump();
    expect(voice.capture.opens, 2);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  for (final listening in [false, true]) {
    testWidgets(
      'short scaled hands-free surface scrolls (listening: $listening)',
      (tester) async {
        final prepared = Completer<bool>();
        final voice = _VoiceHarness(preparePhone: prepared);
        await pump(
          tester,
          mode: QuizMode.handsFree,
          words: [('un long mot à lire avant de répondre', '고양이')],
          voice: voice,
        );
        tester.view.physicalSize = const Size(1704, 960);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        prepared.complete(false);
        await tester.pump();
        if (listening) {
          await tick(tester, times: 8);
          expect(voice.capture.opens, 1);
          expect(find.byType(SttStatusStrip), findsOneWidget);
        } else {
          expect(find.byKey(const ValueKey('hf_countdown')), findsOneWidget);
        }

        final surface = find.byKey(const ValueKey(WidgetKeys.quizPrompt));
        final scrollable = find.descendant(
          of: surface,
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
        expect(
          find.descendant(
            of: surface,
            matching: find.text('v3.scroll_hint'.tr()),
          ),
          findsOneWidget,
        );
        for (final key in [
          WidgetKeys.hfRepeat,
          WidgetKeys.hfPause,
          WidgetKeys.hfSkip,
        ]) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.pump();
          expect(control.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 8));
      },
    );
  }

  testWidgets('Enter resumes an automatic hands-free pause', (tester) async {
    final voice = _VoiceHarness();
    voice.capture.canOpen = false;
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이'), ('chien', '개')],
      voice: voice,
      machineFactory: () =>
          VoiceTurnMachine(maxListenAttempts: 1, silentCardsBeforePause: 1),
    );
    await tick(tester, times: 10);
    expect(find.text('quiz.hf_paused_silence'.tr()), findsOneWidget);
    expect(find.byKey(const ValueKey(WidgetKeys.hfResume)), findsOneWidget);
    for (final key in [
      WidgetKeys.hfRepeat,
      WidgetKeys.hfPause,
      WidgetKeys.hfSkip,
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing);
    }
    voice.capture.canOpen = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester, times: 8);
    expect(find.byKey(const ValueKey(WidgetKeys.hfResume)), findsNothing);
    expect(find.byKey(const ValueKey(WidgetKeys.hfPause)), findsOneWidget);
    expect(voice.capture.opens, 2);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the first listen uses the restored recognizer mode', (
    tester,
  ) async {
    final delayed = _DelayedSttMode();
    final voice = _VoiceHarness();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      sttMode: delayed,
    );
    await tick(tester, times: 8);
    expect(voice.director.cues, 0);
    expect(voice.phonePrepares, 0);
    expect(voice.capture.opens, 0);
    delayed.preference.complete(SttEngineMode.system);
    await tick(tester, times: 8);
    expect(voice.director.cues, 1);
    expect(voice.systemListens, 1);
    expect(voice.phonePrepares, 0);
    expect(voice.capture.opens, 0);
    await voice.systemEvent('status', const {'status': 'done'});
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3600)),
    );
    await tester.pump(const Duration(seconds: 4));
    await tick(tester, times: 8);
    expect(voice.systemListens, 2, reason: 'retry reuses the prepared mode');
    expect(voice.capture.opens, 0);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 12));
  });

  for (final timesOut in [false, true]) {
    testWidgets('grammar TTS failure permits a retry (timeout: $timesOut)', (
      tester,
    ) async {
      final audio = _BlockingPromptAudio();
      final voice = _VoiceHarness(promptAudio: audio);
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [],
        grammar: true,
        cardLimit: 1,
        voice: voice,
      );
      expect(find.textContaining('은/는'), findsOneWidget);
      if (timesOut) {
        await tester.pump(const Duration(seconds: 16));
      } else {
        audio.utterances.single.$3.completeError(StateError('TTS failed'));
        await tester.pump();
      }
      await tick(tester, times: 2);
      expect(find.text('quiz.grammar_prompt_failed'.tr()), findsOneWidget);
      expect(audio.stops, 1);
      expect(voice.director.cues, 0);
      expect(voice.capture.opens, 0);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
      await tester.pump();
      expect(audio.utterances, hasLength(2));
      audio.utterances.last.$3.complete();
      await tester.pump();
      audio.utterances.last.$3.complete();
      await tick(tester, times: 8);
      expect(voice.director.cues, 1);
      expect(voice.capture.opens, 1);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 12));
    });
  }

  for (final rejectedOperation in ['setLanguage', 'speak']) {
    testWidgets(
      'native $rejectedOperation rejection keeps grammar mic closed',
      (tester) async {
        const channel = MethodChannel('flutter_tts');
        final messenger = tester.binding.defaultBinaryMessenger;
        var reject = true;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getEngines') return <Object>[];
          return reject && call.method == rejectedOperation ? 0 : 1;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final tts = FlutterTtsService();
        final voice = _VoiceHarness(
          promptAudio: AudioPlayerService(
            usePremium: false,
            filePlayer: _SilentFilePlayer(),
            tts: tts,
          ),
        );
        await pump(
          tester,
          mode: QuizMode.handsFree,
          words: [],
          grammar: true,
          cardLimit: 1,
          voice: voice,
        );
        expect(find.text('quiz.grammar_prompt_failed'.tr()), findsOneWidget);
        expect(voice.director.cues, 0);
        expect(voice.capture.opens, 0);
        reject = false;
        await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
        await tick(tester, times: 10);
        expect(voice.director.cues, 1);
        expect(voice.capture.opens, 1);
        await unmountScreen(tester);
        await tester.pump(const Duration(seconds: 8));
      },
    );
  }

  testWidgets('grammar Repeat recovers from a missing setLanguage reply', (
    tester,
  ) async {
    const channel = MethodChannel('flutter_tts');
    final messenger = tester.binding.defaultBinaryMessenger;
    final missingReply = Completer<void>();
    final spokenLocales = <String>[];
    var configuredLocale = '';
    var languageCalls = 0;
    var stopCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getEngines':
          return <Object>[];
        case 'setLanguage':
          configuredLocale = call.arguments as String;
          if (++languageCalls == 1) await missingReply.future;
        case 'speak':
          spokenLocales.add(configuredLocale);
        case 'stop':
          stopCalls++;
      }
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final tts = FlutterTtsService();
    final voice = _VoiceHarness(
      promptAudio: AudioPlayerService(
        usePremium: false,
        filePlayer: _SilentFilePlayer(),
        tts: tts,
      ),
    );
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [],
      grammar: true,
      cardLimit: 1,
      voice: voice,
    );
    expect(languageCalls, 1);
    final instructionLocale = configuredLocale;
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('quiz.grammar_prompt_failed'.tr()), findsOneWidget);
    expect(stopCalls, 1);
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfRepeat)));
    await tick(tester, times: 10);
    expect(spokenLocales, [instructionLocale, 'ko-KR']);
    expect(voice.director.cues, 1);
    expect(voice.capture.opens, 1);
    missingReply.complete();
    await tester.pump();
    expect(languageCalls, 3);
    expect(spokenLocales, [instructionLocale, 'ko-KR']);
    expect(configuredLocale, 'ko-KR');
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('warm import hides the hands-free quiz until its detail closes', (
    tester,
  ) async {
    final voice = _VoiceHarness();
    final decoding = voice.whisper.pendingDecode = Completer<String?>();
    final sharedList = _PendingImportRemote();
    final account = StateProvider<AppUser?>((_) => _importAccount());
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      account: account,
      importRemote: sharedList,
    );
    await tick(tester, times: 8);
    expect(voice.capture.opens, 1);
    final oldCapture = voice.capture.session!;
    oldCapture.answer();
    await tester.pump();
    expect(voice.whisper.decodes, 1);
    final router = GoRouter.of(tester.element(find.byType(QuizScreen)));
    unawaited(router.push('/import?token=warm-link'));
    await tick(tester, times: 3);
    expect(find.byType(ImportFromLinkScreen), findsOneWidget);
    expect(find.byType(QuizScreen, skipOffstage: false), findsOneWidget);
    expect(oldCapture.closed, isTrue);
    decoding.complete('고양이');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tick(tester, times: 8);
    expect(progressRepo.saved, isEmpty);
    expect(voice.capture.opens, 1);

    sharedList.pending.complete(_sharedImport);
    await tick(tester, times: 8);
    expect(find.byType(ListDetailScreen), findsOneWidget);
    expect(voice.capture.opens, 1);
    expect(voice.director.cues, 1);
    expect(progressRepo.saved, isEmpty);
    router.pop();
    await tick(tester, times: 11);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(voice.capture.opens, 2);
    expect(voice.director.cues, 2);
    voice.capture.session!.answer();
    await tick(tester, times: 6);
    expect(progressRepo.saved.single.timesCorrect, 1);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets(
    'a quiz opened by imported list detail keeps the covered quiz intact',
    (tester) async {
      final voice = _VoiceHarness();
      final sharedList = _PendingImportRemote();
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이'), ('félin', '고양이')],
        voice: voice,
        account: StateProvider<AppUser?>((_) => _importAccount()),
        importRemote: sharedList,
      );
      await tick(tester, times: 8);
      voice.capture.session!.answer();
      await tick(tester, times: 7);
      expect(find.text('félin'), findsOneWidget);
      expect(progressRepo.saved.single.timesCorrect, 1);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfPause)));
      await tester.pump();

      final router = GoRouter.of(tester.element(find.byType(QuizScreen)));
      unawaited(router.push('/import?token=warm-link'));
      await tick(tester, times: 3);
      sharedList.pending.complete(_sharedImport);
      await tick(tester, times: 6);
      expect(find.byType(ListDetailScreen), findsOneWidget);
      await tester.tap(find.text('course.free_practice'.tr()));
      await tick(tester, times: 6);
      expect(find.byType(QuizScreen, skipOffstage: false), findsNWidgets(2));
      expect(find.byKey(const ValueKey(WidgetKeys.cartesCard)), findsOneWidget);
      expect(
        find.text('merci').evaluate().isNotEmpty ||
            find.text('감사합니다').evaluate().isNotEmpty,
        isTrue,
      );
      expect(voice.capture.opens, 1);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tick(tester, times: 4);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.listDetailBack)));
      await tick(tester, times: 4);

      expect(find.byKey(const ValueKey(WidgetKeys.hfResume)), findsOneWidget);
      expect(voice.capture.opens, 1);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.hfResume)));
      await tick(tester, times: 8);
      expect(find.text('félin'), findsOneWidget);
      expect(voice.capture.opens, 2);
      voice.capture.session!.answer();
      await tick(tester, times: 7);
      expect(find.text('2 / 2 corrects'), findsOneWidget);
      expect(progressRepo.saved, hasLength(2));
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
  );

  testWidgets('a quiz close waits for the route above it to dismiss', (
    tester,
  ) async {
    final voice = _VoiceHarness();
    final sharedList = _PendingImportRemote();
    await pump(
      tester,
      mode: QuizMode.handsFree,
      words: [('chat', '고양이')],
      voice: voice,
      account: StateProvider<AppUser?>((_) => _importAccount()),
      importRemote: sharedList,
    );
    await tick(tester, times: 8);
    final router = GoRouter.of(tester.element(find.byType(QuizScreen)));
    final stopping = voice.director.pendingStop = Completer<void>();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(voice.director.stops, 1);
    unawaited(router.push('/import?token=warm-link'));
    await tick(tester, times: 3);

    stopping.complete();
    await tick(tester, times: 3);
    expect(find.byType(ImportFromLinkScreen), findsOneWidget);
    expect(find.byType(QuizScreen, skipOffstage: false), findsOneWidget);

    sharedList.pending.complete(_sharedImport);
    await tick(tester, times: 6);
    expect(find.byType(ListDetailScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(WidgetKeys.listDetailBack)));
    await tick(tester, times: 5);
    expect(find.byType(QuizScreen, skipOffstage: false), findsNothing);
    expect(find.byKey(const ValueKey('open-quiz')), findsOneWidget);
    expect(voice.capture.opens, 1);
    await unmountScreen(tester);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets(
    'a covered quiz loading cards cannot stop the visible System mic',
    (tester) async {
      final voice = _VoiceHarness();
      final firstLoad = Completer<void>();
      final sharedList = _PendingImportRemote();
      SharedPreferences.setMockInitialValues({
        'settings_stt_engine_mode': 'system',
      });
      await pump(
        tester,
        mode: QuizMode.handsFree,
        words: [('chat', '고양이')],
        voice: voice,
        account: StateProvider<AppUser?>((_) => _importAccount()),
        importRemote: sharedList,
        pendingInitialLoad: firstLoad.future,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(QuizScreen)));
      unawaited(router.push('/import?token=warm-link'));
      await tick(tester, times: 3);
      sharedList.pending.complete(_sharedImport);
      await tick(tester, times: 6);
      await tester.tap(
        find.byKey(const ValueKey(WidgetKeys.listDetailHandsFree)),
      );
      await tick(tester, times: 12);
      expect(find.byType(QuizScreen, skipOffstage: false), findsNWidgets(2));
      expect(voice.systemListens, 1);
      expect(voice.systemStops, 0);
      final answer = find.text('merci').evaluate().isNotEmpty
          ? '감사합니다'
          : 'merci';

      firstLoad.complete();
      await tick(tester, times: 2);
      expect(
        find.descendant(
          of: find.byType(QuizScreen, skipOffstage: false),
          matching: find.byType(CircularProgressIndicator, skipOffstage: false),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(voice.systemListens, 1);
      expect(voice.systemStops, 0);

      await voice.systemFinalResult(answer);
      await tester.pump();
      expect(
        find.byKey(const ValueKey(WidgetKeys.feedbackCorrect)),
        findsOneWidget,
      );
      expect(progressRepo.saved.single.timesCorrect, 1);
      expect(voice.systemStops, 1);
      await unmountScreen(tester);
      await tester.pump(const Duration(seconds: 8));
    },
  );

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
    expect(voice.director.cues, 0);
    expect(voice.capture.opens, 0);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tick(tester, times: 3);
    expect(navigatedTo, '/home');
    prepared.complete(true);
    await tester.pump(const Duration(seconds: 3));
    expect(voice.capture.opens, 0);
    expect(voice.systemListens, 0);
    expect(voice.director.cues, 0);
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
