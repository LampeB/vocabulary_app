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
  /// Bottom-nav tab by destination name: `home` | `lists` | `social` | `profile`.
  static String navTab(String name) => 'nav.tab.$name';

  // ── Screen roots ───────────────────────────────────────────────────────────
  // One per destination, on the screen's top-level Scaffold, so a test can
  // assert *which* screen is showing without matching localized text.
  static const screenHome = 'screen.home';
  static const screenLists = 'screen.lists';
  static const screenListDetail = 'screen.list_detail';
  static const screenStartSession = 'screen.start_session';
  static const screenSocial = 'screen.social';
  static const screenProfile = 'screen.profile';
  static const screenStats = 'screen.stats';
  static const screenSettings = 'screen.settings';
  static const screenNotifications = 'screen.notifications';
  static const screenPaywall = 'screen.paywall';
  static const screenImport = 'screen.import';

  // ── Home ───────────────────────────────────────────────────────────────────
  static const homeBell = 'home.bell'; // header bell → notifications

  // ── Profile nav tiles ──────────────────────────────────────────────────────
  static const profileTileStats = 'profile.tile.stats';
  static const profileTileSettings = 'profile.tile.settings';
  static const profileTileNotifications = 'profile.tile.notifications';
  static const profileSignOut = 'profile.tile.sign_out';

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

  // ── Lists screen + create/rename dialog ────────────────────────────────────
  static const listsFab = 'lists.fab'; // "Nouvelle liste"
  static const listNameField = 'lists.name_field'; // create/rename text field
  static const listNameConfirm = 'lists.name_confirm'; // create/rename confirm

  // ── List detail: word management ───────────────────────────────────────────
  static const listDetailBack = 'list_detail.back';
  static const listDetailAddWord = 'list_detail.add_word'; // bottom add bar
  static const listDetailMenu = 'list_detail.menu'; // ⋮ menu
  static const listDetailEditItem = 'list_detail.menu.edit'; // → edit mode
  static const addWordFr = 'word.add.fr';
  static const addWordKo = 'word.add.ko';
  static const addWordConfirm = 'word.add.confirm';
  static const editWordFr = 'word.edit.fr';
  static const editWordKo = 'word.edit.ko';
  static const editWordConfirm = 'word.edit.confirm';
  static const deleteWordConfirm = 'word.delete.confirm';
  /// Per-tile edit / delete icons (visible only in edit mode), keyed by the
  /// tile's current French word so a step can target a specific word.
  static String conceptEditIcon(String frWord) => 'word.tile.edit.$frWord';
  static String conceptDeleteIcon(String frWord) => 'word.tile.delete.$frWord';

  // ── Start-session accordion sections + type tile ───────────────────────────
  static String startSection(int index) => 'ss.section.$index'; // header
  static String startType(String name) => 'ss.type.$name'; // e.g. 'vocab'

  // ── Auth flows (sign-out, password reset) ──────────────────────────────────
  static const screenWelcome = 'screen.welcome';
  static const signOutConfirm = 'profile.signout.confirm';
  static const authForgotPassword = 'auth.forgot_password';
  static const authResetEmail = 'auth.reset.email';
  static const authResetSend = 'auth.reset.send';
  static const authResetSuccess = 'auth.reset.success';
  static const authResetError = 'auth.reset.error';
}
