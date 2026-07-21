import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keySttEngineMode = 'settings_stt_engine_mode';

/// Which racer set the voice modes run (since refactor step 4b, EVERY vocab
/// voice turn runs on the VoiceTurnMachine + SttRace pipeline).
///
///  * [system] — system-recognizer lane only (the production default).
///  * [race]   — Course (bêta): adds the offline Whisper lane on a miss.
///    Becomes a true parallel race when a sharedPcm engine (e.g.
///    sherpa-onnx) is registered.
///
/// A user-visible toggle in Settings so A/B comparison can happen on-device
/// without a reinstall; persisted across sessions.
enum SttEngineMode { system, race }

final sttEngineModeProvider =
    NotifierProvider<SttEngineModeNotifier, SttEngineMode>(
  SttEngineModeNotifier.new,
);

class SttEngineModeNotifier extends Notifier<SttEngineMode> {
  @override
  SttEngineMode build() {
    _load();
    return SttEngineMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keySttEngineMode);
    if (saved != null) {
      state = SttEngineMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => SttEngineMode.system,
      );
    }
  }

  Future<void> set(SttEngineMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySttEngineMode, mode.name);
  }
}
