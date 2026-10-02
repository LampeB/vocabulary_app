import '../../../services/speech/stt_race_status.dart';

/// What the hands-free screen tells the learner right now. The sequence the
/// learner experiences (user request 2026-10-02) is:
///
///   reading → 3 · 2 · 1 → [bip] "Écoute en cours" + draining bar
///   → (voice detected) "Je t'entends…" → [bip] "Analyse de la réponse"
enum HfCue {
  /// Session paused — no cue at all.
  none,

  /// The question is being read out.
  reading,

  /// "3 · 2 · 1" before the mic opens.
  countdown,

  /// Mic is being opened.
  opening,

  /// Mic open, waiting for the answer ("Écoute en cours").
  listening,

  /// The learner's voice is being captured.
  hearing,

  /// An answer is being transcribed / the verdict is pending.
  analyzing,

  /// "Pas entendu — essai n/3".
  notHeard,
}

/// Priority: paused > countdown > analysing > hearing > not-heard > opening >
/// listening > reading.
HfCue hfCueFor({
  required bool paused,
  required int? countdown,
  required bool micRequested,
  required SttPhase? phase,
  required bool verdictPending,
  required bool notHeard,
}) {
  if (paused) return HfCue.none;
  if (countdown != null) return HfCue.countdown;
  final live = micRequested ? phase : null;
  if (verdictPending || live == SttPhase.analyzing) return HfCue.analyzing;
  if (live == SttPhase.speaking) return HfCue.hearing;
  if (notHeard) return HfCue.notHeard;
  if (!micRequested) return HfCue.reading;
  if (live == null || live == SttPhase.starting) return HfCue.opening;
  return HfCue.listening;
}

/// The time-left bar runs while the mic is genuinely open and nothing is
/// being analysed — including on a retry, under the "essai n/3" prompt.
bool hfBarVisible({
  required bool paused,
  required int? countdown,
  required bool micRequested,
  required SttPhase? phase,
  required bool verdictPending,
}) =>
    !paused &&
    countdown == null &&
    micRequested &&
    !verdictPending &&
    (phase == SttPhase.listening || phase == SttPhase.speaking);
