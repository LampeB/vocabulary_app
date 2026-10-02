/// What one listen attempt is doing RIGHT NOW — the learner must always know
/// whether the app is listening, hearing them, or analysing (user feedback
/// 2026-10-02: "je sais pas si ça écoute, si ça analyse, si ça envoie").
enum SttPhase {
  /// Engines are being started / the mic is opening.
  starting,

  /// Mic open, waiting for the learner's voice.
  listening,

  /// The learner's voice is being captured.
  speaking,

  /// An utterance is being transcribed (the mic may still be open).
  analyzing,

  /// The attempt is over (verdict reached or nothing left to wait for).
  done,
}

/// Per-engine progress, shown as one chip per active engine.
enum SttEngineState {
  /// Selected for this attempt, nothing to transcribe yet.
  waiting,

  /// Transcribing (cloud: request sent; on-device: inference running).
  working,

  /// Produced a transcript — see [SttEngineStatus.transcript]/[matched].
  heard,

  /// Ran but understood nothing usable.
  empty,

  /// Failed (network, timeout, engine error).
  failed,
}

class SttEngineStatus {
  const SttEngineStatus({
    required this.engineId,
    required this.state,
    this.requiresNetwork = false,
    this.transcript,
    this.matched = false,
  });

  final String engineId;
  final SttEngineState state;

  /// Cloud engine — its "working" state reads as "sending".
  final bool requiresNetwork;
  final String? transcript;

  /// The transcript validated against the expected answer.
  final bool matched;

  SttEngineStatus copyWith({
    SttEngineState? state,
    String? transcript,
    bool? matched,
  }) =>
      SttEngineStatus(
        engineId: engineId,
        state: state ?? this.state,
        requiresNetwork: requiresNetwork,
        transcript: transcript ?? this.transcript,
        matched: matched ?? this.matched,
      );
}

class SttRaceStatus {
  const SttRaceStatus({required this.phase, required this.engines});

  final SttPhase phase;
  final List<SttEngineStatus> engines;
}
