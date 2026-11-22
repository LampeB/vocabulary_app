import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyLangA = 'settings_default_lang_a';
const _keyLangB = 'settings_default_lang_b';

/// The user's global learning pair — "je parle [a] / j'apprends [b]".
/// Prefills the create-list language picker (each list still carries its own
/// pair; this is only the default). Persisted across sessions.
final defaultPairProvider =
    NotifierProvider<DefaultPairNotifier, (String, String)>(
  DefaultPairNotifier.new,
);

class DefaultPairNotifier extends Notifier<(String, String)> {
  @override
  (String, String) build() {
    _load();
    return ('fr', 'ko');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString(_keyLangA);
    final b = prefs.getString(_keyLangB);
    if (a != null && b != null) state = (a, b);
  }

  Future<void> set(String langA, String langB) async {
    state = (langA, langB);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLangA, langA);
    await prefs.setString(_keyLangB, langB);
  }
}
