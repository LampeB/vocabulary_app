/// Stable widget-key strings shared between the app and the E2E (Patrol) tests.
///
/// Selecting by key (not localized text) keeps the test steps robust against
/// copy/translation changes. Both sides reference these constants, so a rename
/// is caught by the compiler instead of silently breaking a test.
///
/// Plain strings only (no layer imports) so this stays usable from anywhere.
abstract final class WidgetKeys {
  // ── Bottom nav ─────────────────────────────────────────────────────────────
  static const navStudy = 'nav.study'; // raised centre "start studying" button

  // ── Start-a-session accordion ──────────────────────────────────────────────
  static const startSessionStart = 'ss.start';
  static String startQuizType(String modeName) => 'ss.quiz.$modeName';
  static String startDirection(String dirName) => 'ss.dir.$dirName';
  static String startCount(int n) => 'ss.count.$n';

  // ── Study modes ────────────────────────────────────────────────────────────
  static const micButton = 'mic_button'; // pre-existing; kept for compatibility
  static const voiceReveal = 'study.voice.reveal';
  static const voiceKeyboard = 'study.voice.keyboard';
  static const cartesCard = 'study.cartes.card';
  static const gradeAgain = 'study.grade.again';
  static const gradeKnew = 'study.grade.knew';
  static const ecrireInput = 'study.ecrire.input';
  static const ecrireValidate = 'study.ecrire.validate';

  // ── Full-screen feedback flood ─────────────────────────────────────────────
  static const feedbackCorrect = 'study.feedback.correct';
  static const feedbackWrong = 'study.feedback.wrong';
  static const feedbackContinue = 'study.feedback.continue';

  // ── Hands-free controls ────────────────────────────────────────────────────
  static const hfRepeat = 'study.hf.repeat';
  static const hfSkip = 'study.hf.skip';

  // ── Summary ────────────────────────────────────────────────────────────────
  static const summary = 'summary';
}
