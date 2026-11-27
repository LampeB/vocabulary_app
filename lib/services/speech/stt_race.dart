import 'dart:async';

import '../../core/utils/answer_validator.dart';
import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import 'shared_pcm_capture.dart';
import 'stt_engine.dart';
import 'stt_race_status.dart';

/// The result of one recognition turn.
class SttRaceOutcome {
  const SttRaceOutcome({
    required this.matched,
    this.winnerEngineId,
    this.matchedCandidate,
    this.bestTranscript,
    this.hypotheses = const [],
    this.hadRealSession = false,
    this.cancelled = false,
  });

  /// A guess validated against the accepted answers.
  final bool matched;

  /// The engine that won the race (first validating guess).
  final String? winnerEngineId;

  /// The exact candidate string that validated (for feedback/logging).
  final String? matchedCandidate;

  /// Best-effort transcript even when nothing matched, so the UI can show
  /// "we heard X" on a miss.
  final String? bestTranscript;

  /// Every hypothesis seen this turn (all engines), newest last.
  final List<SttHypothesis> hypotheses;

  /// Whether the mic was GENUINELY live at least once this window — an engine
  /// session survived past the throttle-kill threshold or produced any
  /// hypothesis. Feeds the turn machine's `hadRealWindow`: a window of
  /// instant engine deaths must not count against the card.
  final bool hadRealSession;

  /// The race was superseded ([SttRace.cancel]) — its caller must ignore it.
  final bool cancelled;

  static const noEngines = SttRaceOutcome(matched: false);
}

/// Runs several [SttEngine]s against the same turn and resolves as soon as ANY
/// of them produces a guess that validates against the known answer — then
/// cancels the losers. Because the quiz answer is known, this is a race with
/// early-accept, not transcript fusion. Local engines run together; network
/// engines receive audio only as a rescue after the local window fails.
///
/// Adding/removing racers is done through [SttEngineRegistry]; this coordinator
/// is engine-agnostic and never names a concrete engine.
class SttRace {
  SttRace(this.engines, {this.capture});

  /// The single microphone shared by [SttCapture.sharedPcm] engines.
  final PcmCaptureSource? capture;

  void Function()? _cancel;
  bool _cancelled = false;

  /// Abandons this race: its timers stop, its own mic window closes, later
  /// results are ignored, and it resolves with [SttRaceOutcome.cancelled].
  /// Cancellable PCM engines invalidate work synchronously before the next
  /// race may dispatch more audio. The screen manages its exclusive engines.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    sttLog('[RACE] ✋ cancelled (superseded)');
    _cancel?.call();
  }

  /// The mic-compatible racer set for this turn (see
  /// [SttEngineRegistry.racersFor]). All own-mic engines here must be a single
  /// engine; [SttCapture.sharedPcm] engines may be many (shared capture).
  final List<SttEngine> engines;

  Future<SttRaceOutcome> run({
    required String langCode,
    required List<String> acceptedAnswers,
    List<String> promptHints = const [],
    bool isDrivingMode = true,
    bool preserveGrammar = false,
    Duration timeout = const Duration(seconds: 8),
    void Function(SttHypothesis partial)? onPartial,
    // Session-end restart tuning (see below); overridable for tests.
    Duration minSessionForRestart = const Duration(milliseconds: 700),
    Duration restartDelay = const Duration(milliseconds: 1000),
    Duration throttleCooldown = const Duration(milliseconds: 3500),
    Duration lateResultGrace = const Duration(milliseconds: 2500),
    bool restartOnSessionEnd = true,
    // Shared-capture tuning (see [_runShared]).
    Duration maxSpeechOverrun = const Duration(seconds: 3),
    Duration analysisTimeout = const Duration(seconds: 6),
    void Function(SttRaceStatus status)? onStatus,
    void Function()? onMicClosedPending,
  }) async {
    final racers = engines
        .where((e) => e.isReady && e.supportsLanguage(langCode))
        .toList();
    if (racers.isEmpty || _cancelled) {
      sttLog('[RACE] no ready engine for "$langCode"');
      return _cancelled
          ? const SttRaceOutcome(matched: false, cancelled: true)
          : SttRaceOutcome.noEngines;
    }
    sttLog(
      '[RACE] start langCode=$langCode  racers=${racers.map((e) => e.id).join(",")}  answers=$acceptedAnswers',
    );

    final shared = racers.every((e) => e.capture == SttCapture.sharedPcm);
    if (shared) {
      if (capture == null) {
        sttLog('[RACE] shared engines need a capture source');
        return SttRaceOutcome.noEngines;
      }
      return _runShared(
        racers: racers,
        source: capture!,
        langCode: langCode,
        acceptedAnswers: acceptedAnswers,
        promptHints: promptHints,
        isDrivingMode: isDrivingMode,
        preserveGrammar: preserveGrammar,
        timeout: timeout,
        maxSpeechOverrun: maxSpeechOverrun,
        analysisTimeout: analysisTimeout,
        onStatus: onStatus,
        onMicClosedPending: onMicClosedPending,
      );
    }

    // ── Mic-owner path (one platform recognizer) ──
    final chips = {
      for (final e in racers)
        e.id: SttEngineStatus(
          engineId: e.id,
          state: SttEngineState.waiting,
          requiresNetwork: e.requiresNetwork,
        ),
    };
    var phase = SttPhase.starting;
    void emit([SttPhase? next]) {
      if (next != null) phase = next;
      if (!_cancelled) {
        onStatus?.call(
          SttRaceStatus(phase: phase, engines: chips.values.toList()),
        );
      }
    }

    emit();

    final completer = Completer<SttRaceOutcome>();
    final seen = <SttHypothesis>[];
    Timer? timer;

    // Set SYNCHRONOUSLY at finish entry: stops are awaited below, so a second
    // hypothesis arriving mid-shutdown must not start a second finish (the
    // completer only completes at the end).
    var finishing = false;

    // Real-window evidence for the turn machine (see
    // SttRaceOutcome.hadRealSession): any hypothesis, any self-end past the
    // throttle threshold, or an engine that started ok and ran to the end of
    // the window without ever self-ending (continuous engines).
    var sawRealSession = false;
    final startedOk = <String>{};
    final selfEnded = <String>{};

    Future<void> finish(SttRaceOutcome outcome) async {
      if (finishing || completer.isCompleted) return;
      finishing = true;
      timer?.cancel();
      // Stop the racers BEFORE completing: an unawaited stop could execute
      // after the caller had already started the NEXT race, clobbering its
      // freshly installed session-end handler — which left the mic dead for
      // the rest of that window (field log 2026-07-21: 12 "nothing heard"
      // cards in one session).
      for (final e in racers) {
        try {
          await e.stop().timeout(const Duration(milliseconds: 800));
        } catch (err) {
          sttLog('[RACE] stop "${e.id}" failed/timed out: $err');
        }
      }
      emit(SttPhase.done);
      completer.complete(outcome);
    }

    _cancel = () {
      if (finishing || completer.isCompleted) return;
      finishing = true;
      timer?.cancel();
      completer.complete(
        SttRaceOutcome(
          matched: false,
          hypotheses: List.of(seen),
          cancelled: true,
        ),
      );
    };

    void onHyp(SttEngine engine, SttHypothesis h) {
      if (finishing || completer.isCompleted) return;
      sawRealSession = true;
      seen.add(h);
      if (!h.isFinal) onPartial?.call(h);
      final provisional = preserveGrammar && !h.isFinal;
      final match = provisional
          ? null
          : AnswerValidator.firstCorrect(
              candidates: h.candidates.isEmpty ? [h.transcript] : h.candidates,
              acceptedAnswers: acceptedAnswers,
              isDrivingMode: isDrivingMode,
              preserveGrammar: preserveGrammar,
            );
      chips[engine.id] = chips[engine.id]!.copyWith(
        state: provisional ? SttEngineState.partial : SttEngineState.heard,
        transcript: h.transcript,
        matched: match != null,
      );
      emit(h.isFinal ? SttPhase.analyzing : SttPhase.speaking);
      if (match != null) {
        sttLog(
          '[RACE] 🏁 "${engine.id}" wins with "$match" (${h.isFinal ? "final" : "partial"})',
        );
        finish(
          SttRaceOutcome(
            matched: true,
            winnerEngineId: engine.id,
            matchedCandidate: match,
            bestTranscript: h.transcript,
            hypotheses: List.of(seen),
            hadRealSession: true,
          ),
        );
      }
    }

    final deadline = DateTime.now().add(timeout);
    var graceUsed = false;
    void finishTimedOut() {
      sttLog(
        '[RACE] ⏱ timeout — no engine validated (${seen.length} hypotheses)',
      );
      // A continuous engine that started ok and never self-ended was live
      // for the whole window.
      final ranFullWindow = startedOk.difference(selfEnded).isNotEmpty;
      finish(
        SttRaceOutcome(
          matched: false,
          bestTranscript: _bestTranscript(seen, finalOnly: preserveGrammar),
          hypotheses: List.of(seen),
          hadRealSession: sawRealSession || ranFullWindow,
        ),
      );
    }

    timer = Timer(timeout, () {
      // Late-result grace: when something WAS heard but nothing validated,
      // the user is often mid-correction at the guillotine — and platform
      // recognizers deliver their final transcript seconds after the fact
      // (field log 2026-07-22: the correct "étudier" arrived 4.8s after the
      // window graded "étudiant" wrong). Hold the verdict briefly; a
      // validating hypothesis during the grace still wins. Pure silence gets
      // no grace — there is no correction pending.
      if (!graceUsed && lateResultGrace > Duration.zero && seen.isNotEmpty) {
        graceUsed = true;
        sttLog(
          '[RACE] ⏳ unmatched at timeout — ${lateResultGrace.inMilliseconds}ms late-result grace',
        );
        timer = Timer(lateResultGrace, finishTimedOut);
        return;
      }
      finishTimedOut();
    });

    // Platform recognizers close their session after ONE utterance — a wrong
    // first answer would leave a dead mic for the rest of the window, so a
    // self-corrected right answer was never heard (field log 2026-07-19:
    // "cheval" then "manger", timeout with the mic long closed). When a
    // session self-ends without a win, restart the engine — guarded against
    // OS-throttle storms: only real sessions (≥ [minSessionForRestart])
    // restart, at most twice, after a [restartDelay] breather, and only while
    // enough window remains for another attempt.
    //
    // A restarted session that dies near-instantly was THROTTLE-KILLED by the
    // OS, not genuinely finished. Burning the budget on it left the mic dead
    // for the back half of every window (field log 2026-07-21: sessions dead
    // at 15ms, users answering into silence until the quiz collapsed). Such a
    // death gets ONE second chance after [throttleCooldown] — long enough for
    // Android's cooldown — without consuming the restart budget.
    final startedAt = <String, DateTime>{};
    final restarts = <String, int>{};
    final throttleRetries = <String, int>{};
    const maxRestarts = 2;

    late Future<void> Function(SttEngine) startEngine;
    startEngine = (SttEngine e) =>
        Future(() async {
          startedAt[e.id] = DateTime.now();
          final ok = await e.start(
            langCode: langCode,
            promptHints: promptHints,
            onHypothesis: (h) => onHyp(e, h),
            onSessionEnd: () {
              if (completer.isCompleted) return;
              selfEnded.add(e.id);
              final lived = DateTime.now().difference(startedAt[e.id]!);
              if (lived >= minSessionForRestart) sawRealSession = true;
              // A system recognizer owns Android's mic. In hybrid mode we do
              // not restart it after a self-end: fully release it and let the
              // offline lane use the same answer window instead. This avoids
              // Samsung's `startListening while listening` throttle storm.
              if (!restartOnSessionEnd) {
                unawaited(
                  finish(
                    SttRaceOutcome(
                      matched: false,
                      bestTranscript: _bestTranscript(
                        seen,
                        finalOnly: preserveGrammar,
                      ),
                      hypotheses: List.of(seen),
                      hadRealSession: sawRealSession,
                    ),
                  ),
                );
                return;
              }
              final used = restarts[e.id] ?? 0;
              final remaining = deadline.difference(DateTime.now());
              if (lived < minSessionForRestart) {
                // Throttle-killed, not a real session.
                final throttled = throttleRetries[e.id] ?? 0;
                if (throttled < 1 && remaining > throttleCooldown) {
                  throttleRetries[e.id] = throttled + 1;
                  sttLog(
                    '[RACE] 🧯 "${e.id}" throttle-killed after ${lived.inMilliseconds}ms — cooldown retry in ${throttleCooldown.inMilliseconds}ms',
                  );
                  Timer(throttleCooldown, () {
                    if (!completer.isCompleted) unawaited(startEngine(e));
                  });
                } else {
                  sttLog(
                    '[RACE] "${e.id}" throttle-killed (lived=${lived.inMilliseconds}ms, cooldownRetries=$throttled, remaining=${remaining.inMilliseconds}ms) — giving up this window',
                  );
                }
                return;
              }
              if (used >= maxRestarts ||
                  remaining < const Duration(seconds: 2)) {
                sttLog(
                  '[RACE] "${e.id}" session ended (lived=${lived.inMilliseconds}ms, restarts=$used, remaining=${remaining.inMilliseconds}ms) — not restarting',
                );
                return;
              }
              restarts[e.id] = used + 1;
              sttLog(
                '[RACE] 🔄 "${e.id}" session ended without a win — restart #${used + 1} in ${restartDelay.inMilliseconds}ms',
              );
              Timer(restartDelay, () {
                if (!completer.isCompleted) unawaited(startEngine(e));
              });
            },
          );
          if (ok) {
            startedOk.add(e.id);
            if (phase == SttPhase.starting) emit(SttPhase.listening);
          } else {
            sttLog('[RACE] "${e.id}" failed to start');
            if (!restartOnSessionEnd) finishTimedOut();
          }
        }).catchError((Object err) {
          sttLog('[RACE] "${e.id}" start threw: $err');
        });

    for (final e in racers) {
      unawaited(startEngine(e));
    }

    return completer.future;
  }

  /// ONE shared microphone feeds local decoders in parallel. Network engines
  /// are a serial fallback when local decoding cannot validate the turn.
  ///
  /// The window is speech-aware (field log 2026-10-02, 7 of 20 right
  /// answers lost to the guillotine):
  ///  * at the deadline a learner who is mid-answer is NOT cut — the mic stays
  ///    open until their utterance ends, up to [maxSpeechOverrun], after which
  ///    the partial utterance is flushed and analysed anyway;
  ///  * transcriptions already in flight are AWAITED (each bounded by
  ///    [analysisTimeout]), never dropped: the verdict is only "nothing
  ///    validated" once every engine has answered.
  Future<SttRaceOutcome> _runShared({
    required List<SttEngine> racers,
    required PcmCaptureSource source,
    required String langCode,
    required List<String> acceptedAnswers,
    required List<String> promptHints,
    required bool isDrivingMode,
    required bool preserveGrammar,
    required Duration timeout,
    required Duration maxSpeechOverrun,
    required Duration analysisTimeout,
    void Function(SttRaceStatus status)? onStatus,
    void Function()? onMicClosedPending,
  }) async {
    final completer = Completer<SttRaceOutcome>();
    final seen = <SttHypothesis>[];
    final chips = {
      for (final e in racers)
        e.id: SttEngineStatus(
          engineId: e.id,
          state: SttEngineState.waiting,
          requiresNetwork: e.requiresNetwork,
        ),
    };
    PcmCaptureSession? session;
    Timer? deadline;
    Timer? overrun;
    var micOpen = false;
    var micClosed = false;
    var micClosing = false;
    var speaking = false;
    var inFlight = 0;
    var finished = false;
    final localRacers = racers.where((e) => !e.requiresNetwork).toList();
    final cloudRacers = racers.where((e) => e.requiresNetwork).toList();
    final captured = <PcmSegment>[];
    var fallbackStarted = false;
    var fallbackRunning = false;
    var cloudTimedOut = false;
    Future<void> cloudChain = Future.value();
    var queuedCloud = 0;
    final turnDecoders = <CancellablePcmSttEngine>{};
    late Future<void> Function(SttEngine, PcmSegment) analyze;

    SttPhase phase() {
      if (finished) return SttPhase.done;
      if (inFlight > 0 || queuedCloud > 0 || fallbackRunning) {
        return SttPhase.analyzing;
      }
      if (micClosed) return SttPhase.done;
      if (speaking) return SttPhase.speaking;
      return micOpen ? SttPhase.listening : SttPhase.starting;
    }

    void emit() {
      if (_cancelled) return;
      onStatus?.call(
        SttRaceStatus(phase: phase(), engines: chips.values.toList()),
      );
    }

    void stopTurn() {
      finished = true;
      deadline?.cancel();
      overrun?.cancel();
      if (!micClosed) {
        micClosed = true;
        unawaited(session?.close());
      }
      for (final decoder in turnDecoders) {
        unawaited(
          decoder.stop().catchError((Object error) {
            sttLog('[RACE] PCM stop "${decoder.id}" failed: $error');
          }),
        );
      }
    }

    void finish(SttRaceOutcome outcome) {
      if (finished) return;
      stopTurn();
      emit();
      completer.complete(outcome);
    }

    void finishIfSettled() {
      if (finished ||
          !micClosed ||
          micClosing ||
          inFlight > 0 ||
          queuedCloud > 0 ||
          fallbackRunning) {
        return;
      }
      if (!fallbackStarted &&
          localRacers.isNotEmpty &&
          cloudRacers.isNotEmpty &&
          captured.isNotEmpty) {
        fallbackStarted = true;
        fallbackRunning = true;
        onMicClosedPending?.call();
        emit();
        // Keep voice on-device until every local hypothesis and the flushed
        // tail have failed. Cloud is a serial rescue, never a parallel upload.
        unawaited(
          Future<void>(() async {
            try {
              for (final segment in captured.reversed) {
                for (final engine in cloudRacers) {
                  if (finished || cloudTimedOut) return;
                  await analyze(engine, segment);
                }
              }
            } finally {
              fallbackRunning = false;
              finishIfSettled();
            }
          }),
        );
        return;
      }
      sttLog(
        '[RACE] ⏱ window over — no engine validated '
        '(${seen.length} hypotheses)',
      );
      finish(
        SttRaceOutcome(
          matched: false,
          bestTranscript: _bestTranscript(seen, finalOnly: preserveGrammar),
          hypotheses: List.of(seen),
          hadRealSession: true,
        ),
      );
    }

    analyze = (engine, segment) async {
      if (finished) return;
      inFlight++;
      chips[engine.id] = chips[engine.id]!.copyWith(
        state: SttEngineState.working,
      );
      emit();
      try {
        if (finished) return;
        if (engine is CancellablePcmSttEngine) turnDecoders.add(engine);
        final h = await engine
            .recognize(segment, langCode: langCode, promptHints: promptHints)
            .timeout(analysisTimeout);
        if (finished) return;
        if (h == null) {
          chips[engine.id] = chips[engine.id]!.copyWith(
            state: SttEngineState.empty,
          );
          return;
        }
        seen.add(h);
        final provisional = preserveGrammar && !h.isFinal;
        final match = provisional
            ? null
            : AnswerValidator.firstCorrect(
                candidates: h.candidates.isEmpty
                    ? [h.transcript]
                    : h.candidates,
                acceptedAnswers: acceptedAnswers,
                isDrivingMode: isDrivingMode,
                preserveGrammar: preserveGrammar,
              );
        chips[engine.id] = chips[engine.id]!.copyWith(
          state: provisional ? SttEngineState.partial : SttEngineState.heard,
          transcript: h.transcript,
          matched: match != null,
        );
        if (match != null) {
          sttLog('[RACE] 🏁 "${engine.id}" wins with "$match"');
          finish(
            SttRaceOutcome(
              matched: true,
              winnerEngineId: engine.id,
              matchedCandidate: match,
              bestTranscript: h.transcript,
              hypotheses: List.of(seen),
              hadRealSession: true,
            ),
          );
        }
      } catch (error) {
        if (finished) return;
        // A Dart deadline does not end the underlying upload. Skip the rest
        // of this turn's cloud queue if a request may still be active.
        if (engine.requiresNetwork && error is TimeoutException) {
          cloudTimedOut = true;
        }
        sttLog('[RACE] "${engine.id}" failed: $error');
        chips[engine.id] = chips[engine.id]!.copyWith(
          state: SttEngineState.failed,
        );
      } finally {
        inFlight--;
        if (!finished) {
          emit();
          finishIfSettled();
        }
      }
    };

    void dispatch(PcmSegment segment) {
      if (finished) return;
      captured.add(segment);
      if (localRacers.isEmpty && !cloudTimedOut) {
        // If local engines are unavailable, cloud can start immediately but
        // still gets at most one request at a time across segments/engines.
        queuedCloud++;
        cloudChain = cloudChain.then((_) async {
          try {
            for (final engine in cloudRacers) {
              if (finished || cloudTimedOut) return;
              await analyze(engine, segment);
            }
          } finally {
            queuedCloud--;
            finishIfSettled();
          }
        });
      }
      for (final engine in localRacers) {
        unawaited(analyze(engine, segment));
      }
      emit();
    }

    Future<void> closeMic() async {
      if (micClosed || micClosing || finished) return;
      micClosing = true;
      overrun?.cancel();
      speaking = false;
      PcmSegment? tail;
      try {
        tail = await session?.close(flush: true);
      } catch (error) {
        sttLog('[RACE] microphone close failed: $error');
      }
      if (tail != null) dispatch(tail);
      micClosing = false;
      micClosed = true;
      if (finished) return;
      if (inFlight > 0) {
        sttLog('[RACE] 🎙️ mic closed — awaiting $inFlight analyses');
        onMicClosedPending?.call();
      }
      emit();
      finishIfSettled();
    }

    _cancel = () {
      if (finished) return;
      stopTurn();
      completer.complete(
        SttRaceOutcome(
          matched: false,
          hypotheses: List.of(seen),
          cancelled: true,
        ),
      );
    };

    emit();
    session = await source.open(
      onSpeechChange: (inSpeech) {
        if (finished || micClosed) return;
        speaking = inSpeech;
        emit();
      },
      onSegment: (segment) {
        if (finished) return;
        speaking = false;
        dispatch(segment);
        // The deadline passed while this answer was being spoken: it is now
        // complete, so the mic can close.
        if (overrun != null) unawaited(closeMic());
      },
    );
    if (finished) {
      // Cancelled while the mic was opening.
      unawaited(session?.close());
      return completer.future;
    }
    if (session == null) {
      sttLog('[RACE] shared mic failed to open');
      micClosed = true;
      finish(const SttRaceOutcome(matched: false));
      return completer.future;
    }
    micOpen = true;
    emit();

    deadline = Timer(timeout, () {
      if (finished) return;
      if (session!.inSpeech) {
        sttLog(
          '[RACE] ⏳ deadline while speaking — waiting for the answer '
          'to end (≤${maxSpeechOverrun.inMilliseconds}ms)',
        );
        overrun = Timer(maxSpeechOverrun, () => unawaited(closeMic()));
        return;
      }
      unawaited(closeMic());
    });

    return completer.future;
  }

  /// Highest-confidence final transcript, else the last thing heard — the
  /// "we heard X" shown on a miss.
  static String? _bestTranscript(
    List<SttHypothesis> seen, {
    required bool finalOnly,
  }) {
    if (seen.isEmpty) return null;
    final finals = seen.where((h) => h.isFinal).toList();
    final pool = finalOnly || finals.isNotEmpty ? finals : [...seen];
    if (pool.isEmpty) return null;
    pool.sort((a, b) => b.confidence.compareTo(a.confidence));
    return pool.first.transcript;
  }
}
