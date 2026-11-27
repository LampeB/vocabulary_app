import 'package:easy_localization/easy_localization.dart';
import '../providers/quiz/quiz_provider.dart' show QuizMode;

String quizModeLabel(QuizMode mode) => switch (mode) {
  QuizMode.voice => 'quiz_setup.mode_voice_label'.tr(),
  QuizMode.flashcard => 'quiz_setup.mode_flashcard_label'.tr(),
  QuizMode.typing => 'quiz_setup.mode_typing_label'.tr(),
  QuizMode.handsFree => 'quiz_setup.mode_hands_free_label'.tr(),
};
