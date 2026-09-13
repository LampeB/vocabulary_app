import 'dart:io';
import 'dart:async' show unawaited;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_service.dart';
import 'audio_asset_path.dart';

class ElevenLabsService implements AudioService {
  ElevenLabsService({Map<String, String>? voiceIds})
      : voiceIds = voiceIds ?? _defaultVoices;

  /// Default rendering voice per content language. Voice selection is applied
  /// by the server when an asset is published, never while a learner quizzes.
  static const _defaultVoices = <String, String>{
    'fr': 'Charlotte',
    'en': 'Rachel',
    'it': 'Bella',
    'de': 'Antoni',
    'es': 'Domi',
    'ko': 'Elli',
  };

  /// Kept for the publishing/provisioning layer and settings compatibility.
  final Map<String, String> voiceIds;
  static const _defaultVoiceId = 'Charlotte';

  String voiceIdFor(String langCode) => voiceIds[langCode] ?? _defaultVoiceId;

  final _cache = <String, String>{}; // hash → file path
  final _inFlight = <String, Future<String?>>{};

  /// Audio is durable across sessions but should not occupy the learner's
  /// storage forever. A file's modification time is our lightweight LRU
  /// marker: every cache hit touches it, and startup removes dormant files.
  static const cacheMaxIdle = Duration(days: 30);

  /// Runs independently from playback; an I/O failure must never delay a
  /// spoken word. Called once when the app's audio service is created.
  void scheduleIdleCacheCleanup() => unawaited(cleanIdleCache());

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {}

  /// Downloads a pre-rendered Storage object into the device cache.
  ///
  /// This deliberately has no ElevenLabs request: all synthesis happens when
  /// content is created or published. A cache miss is only a cheap Storage
  /// download and an expired cache simply downloads the same immutable object.
  Future<String?> downloadAndCache(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return Future.value(null);
    return _getOrDownload(audioPath);
  }

  Future<String?> _getOrDownload(String audioPath) async {
    final key = _cacheKey(audioPath);
    final memoryPath = _cache[key];
    if (memoryPath != null) {
      _touch(File(memoryPath));
      return memoryPath;
    }

    // Question playback and the next-card prefetch can request the same word
    // at almost the same time. Share one network render instead of competing
    // calls that both delay cache population.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final task = _downloadAndCache(key, audioPath);
    _inFlight[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_inFlight[key], task)) _inFlight.remove(key);
    }
  }

  Future<String?> _downloadAndCache(String key, String audioPath) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$key.mp3');
    if (file.existsSync()) {
      _cache[key] = file.path;
      _touch(file);
      return file.path;
    }

    try {
      final bytes = await Supabase.instance.client.storage
          .from(AudioAssetPath.bucket)
          .download(audioPath)
          .timeout(const Duration(seconds: 3));
      await file.writeAsBytes(bytes, flush: true);
      _cache[key] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(String audioPath) =>
      md5.convert(audioPath.codeUnits).toString();

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<int> cacheSize() async {
    final dir = await _cacheDir();
    if (!dir.existsSync()) return 0;
    return dir
        .listSync()
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
  }

  /// Removes generated clips that have not been played or prefetched for
  /// [maxIdle]. This intentionally leaves freshly preloaded quiz audio alone.
  Future<void> cleanIdleCache({Duration maxIdle = cacheMaxIdle}) async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(maxIdle);
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.mp3')) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          _cache.remove(_keyFromPath(entity.path));
        }
      }
    } catch (_) {
      // Cache maintenance is opportunistic; playback remains best-effort.
    }
  }

  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _cache.clear();
    _inFlight.clear();
  }

  void _touch(File file) {
    unawaited(file.setLastModified(DateTime.now()).catchError((_) => file));
  }

  String _keyFromPath(String path) => path
      .split(Platform.pathSeparator)
      .last
      .replaceFirst(RegExp(r'\.mp3$'), '');

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
