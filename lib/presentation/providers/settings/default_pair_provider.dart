import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyLangA = 'settings_default_lang_a';
const _keyLangB = 'settings_default_lang_b';

/// The user's global learning pair — "je parle [a] / j'apprends [b]".
/// Selected explicitly in the header. Free-list creation has its own remembered
/// pair and never changes this guided-learning context.
final defaultPairProvider =
    NotifierProvider<DefaultPairNotifier, (String, String)>(
      DefaultPairNotifier.new,
    );

class DefaultPairNotifier extends Notifier<(String, String)> {
  Future<void>? _restoration;
  bool _selected = false;

  Future<void> get restored => _restoration ?? Future.value();

  @override
  (String, String) build() {
    _selected = false;
    _restoration = _load();
    return ('fr', 'ko');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString(_keyLangA);
    final b = prefs.getString(_keyLangB);
    if (!_selected && a != null && b != null) state = (a, b);
  }

  Future<void> set(String langA, String langB) async {
    _selected = true;
    state = (langA, langB);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLangA, langA);
    await prefs.setString(_keyLangB, langB);
  }
}
