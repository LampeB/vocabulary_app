import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/languages.dart';

/// Last pair used for a free list. A null value prefills from the header;
/// saving this preference never changes the active guided-learning pair.
final createListPairProvider =
    NotifierProvider<CreateListPairNotifier, (String, String)?>(
      CreateListPairNotifier.new,
    );

class CreateListPairNotifier extends Notifier<(String, String)?> {
  static const _key = 'settings_create_list_pair';
  int _revision = 0;

  @override
  (String, String)? build() {
    final revision = ++_revision;
    ref.onDispose(() => ++_revision);
    _load(revision);
    return null;
  }

  Future<void> _load(int revision) async {
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    final pair = prefs.getString(_key)?.split('>');
    if (pair != null &&
        pair.length == 2 &&
        Languages.supported.contains(pair[0]) &&
        Languages.supported.contains(pair[1])) {
      state = (pair[0], pair[1]);
    }
  }

  Future<void> set(String source, String target) async {
    final revision = ++_revision;
    state = (source, target);
    final prefs = await SharedPreferences.getInstance();
    if (revision == _revision) await prefs.setString(_key, '$source>$target');
  }
}
