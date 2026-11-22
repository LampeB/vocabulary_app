/// Controls the speech-to-text simulation used by the voice/hands-free quiz in
/// E2E tests, so recognition is deterministic without a real microphone.
///
/// [mode] seeds from the `SIMULATE_SPEECH` build define (so the existing env
/// files keep working), but because Patrol runs the test and the app in the same
/// isolate, a test can also set it **at runtime** to script each answer:
///
/// ```dart
/// SttSimulator.mode = SttSimulator.correct; // next spoken answer is correct
/// ```
///
/// `''` (the default in production builds) means real on-device STT.
abstract final class SttSimulator {
  /// The simulated answer will match the card's expected word.
  static const correct = 'correct';

  /// The simulated answer will be wrong.
  static const wrong = 'wrong';

  /// Current simulation mode: [correct], [wrong], or '' for real STT.
  /// Defaults from `--dart-define=SIMULATE_SPEECH=...`; overridable at runtime.
  static String mode = const String.fromEnvironment('SIMULATE_SPEECH');

  /// Whether STT is being simulated (vs. real on-device recognition).
  static bool get isOn => mode.isNotEmpty;
}
