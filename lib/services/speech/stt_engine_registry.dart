import 'stt_engine.dart';

/// The set of STT engines available to race. This is the single place engines
/// are added or removed as the technology/offering evolves — register a new
/// [SttEngine] (e.g. sherpa-onnx) and it joins the race with no other changes;
/// unregister one to drop it.
class SttEngineRegistry {
  final _engines = <SttEngine>[];

  List<SttEngine> get all => List.unmodifiable(_engines);

  void register(SttEngine engine) {
    _engines.removeWhere((e) => e.id == engine.id);
    _engines.add(engine);
  }

  void unregister(String id) => _engines.removeWhere((e) => e.id == id);

  bool has(String id) => _engines.any((e) => e.id == id);

  /// The best available engines for one listen attempt — at most
  /// [maxEngines] of them (user rule 2026-10-02: "activate the 3 best
  /// available engines").
  ///
  /// Course uses shared capture when a local shared decoder is ready.
  /// Compatible network decoders can join that attempt; `SttRace` runs
  /// them only after local recognition fails. An exclusive local recognizer
  /// runs alone when no local shared decoder is ready. Network-only capture
  /// is available if local engines are absent or the exclusive lane failed
  /// on earlier attempts ([rescue]).
  List<SttEngine> select({
    required String langCode,
    required bool online,
    int maxEngines = 3,
    bool rescue = false,
  }) {
    final available = _engines
        .where(
          (e) =>
              e.isReady &&
              e.supportsLanguage(langCode) &&
              (online || !e.requiresNetwork),
        )
        .toList();
    final localShared = available
        .where(
          (engine) =>
              !engine.requiresNetwork && engine.capture == SttCapture.sharedPcm,
        )
        .toList();
    final networkShared = available.where(
      (engine) =>
          engine.requiresNetwork && engine.capture == SttCapture.sharedPcm,
    );
    if (localShared.isNotEmpty) {
      return [
        ...(rescue && localShared.length > 1
            ? localShared.skip(1)
            : localShared),
        ...networkShared,
      ].take(maxEngines).toList();
    }
    final exclusive = available
        .where((engine) => engine.capture == SttCapture.ownsMicrophone)
        .toList();
    final localExclusive = exclusive.where((engine) => !engine.requiresNetwork);
    if (!rescue && localExclusive.isNotEmpty) return [localExclusive.first];
    if (networkShared.isNotEmpty) {
      return networkShared.take(maxEngines).toList();
    }
    if (exclusive.isEmpty) return const [];
    return [exclusive[rescue && exclusive.length > 1 ? 1 : 0]];
  }

  /// Prepares every engine (loads models / inits platforms) concurrently.
  Future<void> prepareAll() => Future.wait(_engines.map((e) => e.prepare()));

  void dispose() {
    for (final e in _engines) {
      e.dispose();
    }
    _engines.clear();
  }
}
