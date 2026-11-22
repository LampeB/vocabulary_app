import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'dev_grammar_unlock';

/// DEBUG-ONLY: treat every grammar rule as unlocked (and word-sufficient) so
/// the machine-migrated grammar voice path can be exercised without first
/// mastering the prerequisite starter lists (field need 2026-07-22: "I can't
/// test grammar sessions yet"). Surfaced only in debug builds; release
/// behavior is untouched.
final devGrammarUnlockProvider =
    NotifierProvider<DevGrammarUnlockNotifier, bool>(
  DevGrammarUnlockNotifier.new,
);

class DevGrammarUnlockNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) state = saved;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
