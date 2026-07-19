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

  /// The mic-compatible racer set for [langCode], respecting the one-mic-owner
  /// constraint:
  ///
  ///  * If any ready [SttCapture.sharedPcm] engine supports the language, race
  ///    the whole shared pool — they run in true parallel on one capture.
  ///  * Otherwise fall back to a single [SttCapture.ownsMicrophone] engine
  ///    (the first registered that supports the language), since two mic
  ///    owners can't run at once.
  ///
  /// Registration order is priority order, so register stronger engines first.
  List<SttEngine> racersFor(String langCode) {
    final ready =
        _engines.where((e) => e.isReady && e.supportsLanguage(langCode));
    final shared =
        ready.where((e) => e.capture == SttCapture.sharedPcm).toList();
    if (shared.isNotEmpty) return shared;
    final micOwner = ready
        .where((e) => e.capture == SttCapture.ownsMicrophone)
        .cast<SttEngine?>()
        .firstWhere((_) => true, orElse: () => null);
    return micOwner == null ? const [] : [micOwner];
  }

  /// Prepares every engine (loads models / inits platforms) concurrently.
  Future<void> prepareAll() =>
      Future.wait(_engines.map((e) => e.prepare()));

  void dispose() {
    for (final e in _engines) {
      e.dispose();
    }
    _engines.clear();
  }
}
