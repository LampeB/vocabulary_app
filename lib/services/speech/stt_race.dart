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

    timer = Timer(timeout, () {
      sttLog('[RACE] ⏱ timeout — no engine validated (${seen.length} hypotheses)');
      finish(SttRaceOutcome(
        matched: false,
        bestTranscript: _bestTranscript(seen),
        hypotheses: List.of(seen),
      ));
    });

    for (final e in racers) {
      unawaited(Future(() async {
        final ok = await e.start(
          langCode: langCode,
          promptHints: promptHints,
          onHypothesis: (h) => onHyp(e, h),
        );
        if (!ok) sttLog('[RACE] "${e.id}" failed to start');
      }).catchError((Object err) {
        sttLog('[RACE] "${e.id}" start threw: $err');
      }));
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
