import 'dart:async';

/// Combines the initial-link API with its first stream replay. Later openings
/// of the same URI remain genuine warm links and are never deduplicated.
class IncomingLinkDispatcher {
  IncomingLinkDispatcher({
    required Future<Uri?> Function() getInitialLink,
    required Stream<Uri> links,
    required this.onLink,
  }) {
    _subscription = links.listen(_receive);
    initialized = _initialize(getInitialLink);
  }

  final void Function(Uri uri, bool coldStart) onLink;
  late final StreamSubscription<Uri> _subscription;
  late final Future<void> initialized;
  final _buffer = <Uri>[];
  bool _active = true;
  bool _initializing = true;
  bool _firstStreamEvent = true;
  Uri? _initial;

  Future<void> _initialize(Future<Uri?> Function() getInitialLink) async {
    Uri? initial;
    try {
      initial = await getInitialLink();
    } catch (_) {
      // A failed initial lookup must not discard subsequent valid links.
    }
    if (!_active) return;
    _initial = initial;
    if (initial != null) onLink(initial, true);
    _initializing = false;
    final buffered = List<Uri>.of(_buffer);
    _buffer.clear();
    for (final uri in buffered) {
      _dispatchStream(uri);
    }
  }

  void _receive(Uri uri) {
    if (!_active) return;
    if (_initializing) {
      _buffer.add(uri);
    } else {
      _dispatchStream(uri);
    }
  }

  void _dispatchStream(Uri uri) {
    if (!_active) return;
    if (_firstStreamEvent) {
      _firstStreamEvent = false;
      if (uri == _initial) return;
    }
    onLink(uri, false);
  }

  Future<void> dispose() async {
    _active = false;
    _buffer.clear();
    await _subscription.cancel();
  }
}
