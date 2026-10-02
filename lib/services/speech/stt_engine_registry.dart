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
  /// Registration order is quality rank, so register stronger engines first.
  /// An engine is AVAILABLE when it is ready, supports [langCode], and — for
  /// cloud engines — the device is [online]. The best available engine
  /// decides the capture mode, because only one component can own the mic:
  ///
  ///  * a [SttCapture.sharedPcm] engine brings every other available shared
  ///    engine along — they all hear the same utterance, in parallel;
  ///  * a [SttCapture.ownsMicrophone] engine runs alone.
  ///
  /// [rescue] (the last not-heard attempt) drops the first choice so a
  /// DIFFERENT engine set gets a chance; with a single candidate it is kept.
  List<SttEngine> select({
    required String langCode,
    required bool online,
    int maxEngines = 3,
    bool rescue = false,
  }) {
    var available = _engines
        .where((e) =>
            e.isReady &&
            e.supportsLanguage(langCode) &&
            (online || !e.requiresNetwork))
        .toList();
    if (available.isEmpty) return const [];
    if (rescue && available.length > 1) available = available.sublist(1);
    final best = available.first;
    if (best.capture == SttCapture.ownsMicrophone) return [best];
    return available
        .where((e) => e.capture == SttCapture.sharedPcm)
        .take(maxEngines)
        .toList();
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
