import 'dart:async';

import '../../core/utils/answer_validator.dart';
import '../../core/utils/stt_debug_log.dart';
import 'stt_engine.dart';

/// The result of one recognition turn.
class SttRaceOutcome {
  const SttRaceOutcome({
    required this.matched,
    this.winnerEngineId,
    this.matchedCandidate,
    this.bestTranscript,
    this.hypotheses = const [],
    this.hadRealSession = false,
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

  static const noEngines = SttRaceOutcome(matched: false);
}

/// Runs several [SttEngine]s against the same turn and resolves as soon as ANY
/// of them produces a guess that validates against the known answer — then
/// cancels the losers. Because the quiz answer is known, this is a race with
/// early-accept, not transcript fusion: the fastest correct engine wins, so
/// latency is the best engine's, not the sum of sequential fallbacks.
///
/// Adding/removing racers is done through [SttEngineRegistry]; this coordinator
/// is engine-agnostic and never names a concrete engine.
class SttRace {
  SttRace(this.engines);

  /// The mic-compatible racer set for this turn (see
  /// [SttEngineRegistry.racersFor]). All own-mic engines here must be a single
  /// engine; [SttCapture.sharedPcm] engines may be many (shared capture).
  final List<SttEngine> engines;

  Future<SttRaceOutcome> run({
    required String langCode,
    required List<String> acceptedAnswers,
    List<String> promptHints = const [],
    bool isDrivingMode = true,
    Duration timeout = const Duration(seconds: 8),
    void Function(SttHypothesis partial)? onPartial,
    // Session-end restart tuning (see below); overridable for tests.
    Duration minSessionForRestart = const Duration(milliseconds: 1200),
    Duration restartDelay = const Duration(milliseconds: 1000),
    Duration throttleCooldown = const Duration(milliseconds: 2500),
  }) async {
    final racers =
        engines.where((e) => e.isReady && e.supportsLanguage(langCode)).toList();
    if (racers.isEmpty) {
      sttLog('[RACE] no ready engine for "$langCode"');
      return SttRaceOutcome.noEngines;
    }
    sttLog('[RACE] start langCode=$langCode  racers=${racers.map((e) => e.id).join(",")}  answers=$acceptedAnswers');

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
      completer.complete(outcome);
    }

    void onHyp(SttEngine engine, SttHypothesis h) {
      if (finishing || completer.isCompleted) return;
      sawRealSession = true;
      seen.add(h);
      if (!h.isFinal) onPartial?.call(h);
      final match = AnswerValidator.firstCorrect(
        candidates: h.candidates.isEmpty ? [h.transcript] : h.candidates,
        acceptedAnswers: acceptedAnswers,
        isDrivingMode: isDrivingMode,
      );
      if (match != null) {
        sttLog('[RACE] 🏁 "${engine.id}" wins with "$match" (${h.isFinal ? "final" : "partial"})');
        finish(SttRaceOutcome(
          matched: true,
          winnerEngineId: engine.id,
          matchedCandidate: match,
          bestTranscript: h.transcript,
          hypotheses: List.of(seen),
          hadRealSession: true,
        ));
      }
    }

    final deadline = DateTime.now().add(timeout);
    timer = Timer(timeout, () {
      sttLog('[RACE] ⏱ timeout — no engine validated (${seen.length} hypotheses)');
      // A continuous engine that started ok and never self-ended was live
      // for the whole window.
      final ranFullWindow =
          startedOk.difference(selfEnded).isNotEmpty;
      finish(SttRaceOutcome(
        matched: false,
        bestTranscript: _bestTranscript(seen),
        hypotheses: List.of(seen),
        hadRealSession: sawRealSession || ranFullWindow,
      ));
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
    startEngine = (SttEngine e) => Future(() async {
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
              final used = restarts[e.id] ?? 0;
              final remaining = deadline.difference(DateTime.now());
              if (lived < minSessionForRestart) {
                // Throttle-killed, not a real session.
                final throttled = throttleRetries[e.id] ?? 0;
                if (throttled < 1 &&
                    remaining > throttleCooldown + const Duration(seconds: 1)) {
                  throttleRetries[e.id] = throttled + 1;
                  sttLog('[RACE] 🧯 "${e.id}" throttle-killed after ${lived.inMilliseconds}ms — cooldown retry in ${throttleCooldown.inMilliseconds}ms');
                  Timer(throttleCooldown, () {
                    if (!completer.isCompleted) unawaited(startEngine(e));
                  });
                } else {
                  sttLog('[RACE] "${e.id}" throttle-killed (lived=${lived.inMilliseconds}ms, cooldownRetries=$throttled, remaining=${remaining.inMilliseconds}ms) — giving up this window');
                }
                return;
              }
              if (used >= maxRestarts ||
                  remaining < const Duration(seconds: 2)) {
                sttLog('[RACE] "${e.id}" session ended (lived=${lived.inMilliseconds}ms, restarts=$used, remaining=${remaining.inMilliseconds}ms) — not restarting');
                return;
              }
              restarts[e.id] = used + 1;
              sttLog('[RACE] 🔄 "${e.id}" session ended without a win — restart #${used + 1} in ${restartDelay.inMilliseconds}ms');
              Timer(restartDelay, () {
                if (!completer.isCompleted) unawaited(startEngine(e));
              });
            },
          );
          if (ok) {
            startedOk.add(e.id);
          } else {
            sttLog('[RACE] "${e.id}" failed to start');
          }
        }).catchError((Object err) {
          sttLog('[RACE] "${e.id}" start threw: $err');
        });

    for (final e in racers) {
      unawaited(startEngine(e));
    }

    return completer.future;
  }

  /// Highest-confidence final transcript, else the last thing heard — the
  /// "we heard X" shown on a miss.
  static String? _bestTranscript(List<SttHypothesis> seen) {
    if (seen.isEmpty) return null;
    final finals = seen.where((h) => h.isFinal).toList();
    final pool = finals.isNotEmpty ? finals : seen;
    pool.sort((a, b) => b.confidence.compareTo(a.confidence));
    return pool.first.transcript;
  }
}
