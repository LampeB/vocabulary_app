import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keySttEngineMode = 'settings_stt_engine_mode';

/// Which racer set the voice modes run (since refactor step 4b, EVERY vocab
/// voice turn runs on the VoiceTurnMachine + SttRace pipeline).
///
///  * [system] — system-recognizer lane only (fallback / troubleshooting).
///  * [race]   — Hybrid: adds the offline Whisper lane on a miss.
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
  late Future<void> _restoring;
  var _revision = 0;

  Future<SttEngineMode> get restored async {
    await _restoring;
    return state;
  }

  @override
  SttEngineMode build() {
    _restoring = _load(_revision);
    ref.onDispose(() => _revision++);
    return SttEngineMode.race;
  }

  Future<void> _load(int revision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keySttEngineMode);
      if (saved != null && _revision == revision) {
        state = SttEngineMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => SttEngineMode.race,
        );
      }
    } catch (_) {
      // Keep the default when platform storage is unavailable.
    }
  }

  Future<void> set(SttEngineMode mode) async {
    _revision++;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySttEngineMode, mode.name);
  }
}
