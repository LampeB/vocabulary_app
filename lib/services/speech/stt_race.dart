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
    Duration restartDelay = const Duration(milliseconds: 350),
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

    Future<void> finish(SttRaceOutcome outcome) async {
      if (completer.isCompleted) return;
      timer?.cancel();
      for (final e in racers) {
        unawaited(Future(() => e.stop()).catchError((_) {}));
      }
      completer.complete(outcome);
    }

    void onHyp(SttEngine engine, SttHypothesis h) {
      if (completer.isCompleted) return;
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
        ));
      }
    }

    final deadline = DateTime.now().add(timeout);
    timer = Timer(timeout, () {
      sttLog('[RACE] ⏱ timeout — no engine validated (${seen.length} hypotheses)');
      finish(SttRaceOutcome(
        matched: false,
        bestTranscript: _bestTranscript(seen),
        hypotheses: List.of(seen),
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
    final startedAt = <String, DateTime>{};
    final restarts = <String, int>{};
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
              final lived = DateTime.now().difference(startedAt[e.id]!);
              final used = restarts[e.id] ?? 0;
              final remaining = deadline.difference(DateTime.now());
              if (lived < minSessionForRestart ||
                  used >= maxRestarts ||
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
          if (!ok) sttLog('[RACE] "${e.id}" failed to start');
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
