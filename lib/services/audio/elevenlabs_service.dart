import 'dart:io';
import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_service.dart';
import 'audio_asset_path.dart';
import 'audio_ports.dart';

class _AssetAccess {
  _AssetAccess(this.disk);

  late final Future<String?> result;
  Future<void>? disk;

  Future<T> onDisk<T>(Future<T> Function() action) async {
    final operation = Future<T>.sync(action);
    disk = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      return await operation;
    } finally {
      disk = null;
    }
  }
}

class ElevenLabsService implements AudioService, AudioAssetCache {
  ElevenLabsService({
    Map<String, String>? voiceIds,
    Future<Uint8List> Function(String audioPath)? assetDownloader,
    Future<Directory> Function()? cacheDirectory,
    String? Function()? currentUserId,
  }) : voiceIds = voiceIds ?? _defaultVoices,
       _assetDownloader = assetDownloader ?? _downloadFromStorage,
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
       _currentUserId = currentUserId ?? _authenticatedUserId;

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
  final Future<Uint8List> Function(String audioPath) _assetDownloader;
  final Future<Directory> Function() _cacheDirectory;
  final String? Function() _currentUserId;
  static const _defaultVoiceId = 'Charlotte';

  String voiceIdFor(String langCode) => voiceIds[langCode] ?? _defaultVoiceId;

  // Multiple audio services can overlap while the settings provider replaces
  // its player. Coalesce by destination, including across cache instances.
  static final _inFlight = <String, _AssetAccess>{};
  bool _cleanupScheduled = false;

  /// Audio is durable across sessions but should not occupy the learner's
  /// storage forever. A file's modification time is our lightweight LRU
  /// marker: every cache hit touches it, and startup removes dormant files.
  static const cacheMaxIdle = Duration(days: 30);

  /// Runs independently from playback; an I/O failure must never delay a
  /// spoken word. Called once when the app's audio service is created.
  @override
  void scheduleIdleCacheCleanup() {
    if (_cleanupScheduled) return;
    _cleanupScheduled = true;
    unawaited(cleanIdleCache());
  }

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {}

  /// Downloads a pre-rendered Storage object into the device cache.
  ///
  /// This deliberately has no ElevenLabs request: all synthesis happens when
  /// content is created or published. A cache miss is only a cheap Storage
  /// download and an expired cache simply downloads the same immutable object.
  @override
  Future<String?> downloadAndCache(String? audioPath) async {
    final asset = _parseAsset(audioPath);
    if (asset == null || !_mayRead(asset.$1)) return null;
    final (ownerId, key) = asset;
    try {
      final file = await _cacheFile(key);
      final path = await _access(
        file,
        (access, isCurrent) =>
            _downloadAndCache(file, audioPath!, ownerId, access, isCurrent),
      );
      return _mayRead(ownerId) ? path : null;
    } catch (_) {
      return null;
    }
  }

  static (String?, String)? _parseAsset(String? audioPath) {
    if (audioPath == null ||
        audioPath.contains('\\') ||
        audioPath.contains('%')) {
      return null;
    }
    final segments = audioPath.split('/');
    if (segments.length != 4 ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      return null;
    }
    final namespace = segments.first;
    if (namespace != 'seed' && namespace != 'users') return null;
    final ownerId = namespace == 'users' ? segments[1] : null;
    // Ignore files cached before Storage required the seed publishing manifest.
    final key = sha256
        .convert(utf8.encode('v2\u0000${ownerId ?? ''}\u0000$audioPath'))
        .toString();
    return (ownerId, key);
  }

  bool _mayRead(String? ownerId) =>
      ownerId == null || ownerId == _currentUserId();

  static Future<String?> _access(
    File file,
    Future<String?> Function(_AssetAccess, bool Function()) action, {
    bool invalidate = false,
  }) async {
    final key = file.path;
    final pending = _inFlight[key];
    if (pending != null && !invalidate) return pending.result;
    final access = _inFlight[key] = _AssetAccess(pending?.disk);
    bool isCurrent() => identical(_inFlight[key], access);
    return access.result =
        Future<String?>.sync(() async {
          // Eviction invalidates the previous task and joins its disk work.
          // An old Storage request may still be pending without blocking it.
          await access.disk;
          access.disk = null;
          if (!isCurrent()) return null;
          return action(access, isCurrent);
        }).catchError((Object _) => null).then((result) {
          if (!isCurrent()) return null;
          _inFlight.remove(key);
          return result;
        });
  }

  Future<String?> _downloadAndCache(
    File file,
    String audioPath,
    String? ownerId,
    _AssetAccess access,
    bool Function() isCurrent,
  ) async {
    bool canUse() => isCurrent() && _mayRead(ownerId);
    final hit = await access.onDisk(() async {
      if (!canUse()) return false;
      final valid = await _matchesChecksum(file);
      if (!canUse()) return false;
      if (valid) {
        await file.setLastModified(DateTime.now()).catchError((_) => file);
      } else {
        await _deleteEntry(file);
      }
      return valid;
    });
    if (!canUse()) return null;
    if (hit) return file.path;
    final bytes = await _assetDownloader(
      audioPath,
    ).timeout(const Duration(seconds: 3));
    if (bytes.isEmpty || !canUse()) return null;
    return access.onDisk(() => _publish(file, bytes, canUse));
  }

  static Future<String?> _publish(
    File file,
    Uint8List bytes,
    bool Function() canUse,
  ) async {
    final marker = _checksum(file);
    final partial = File('${file.path}.part');
    final partialMarker = File('${marker.path}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partialMarker.writeAsString(
        sha256.convert(bytes).toString(),
        flush: true,
      );
      if (!canUse()) return null;
      await partialMarker.rename(marker.path);
      if (!canUse()) return null;
      // Readers can only open the final MP3 after the complete write.
      await partial.rename(file.path);
      if (!canUse()) {
        await _deleteEntry(file);
        return null;
      }
      return file.path;
    } finally {
      await _deleteIfPresent(partial);
      await _deleteIfPresent(partialMarker);
      if (!await file.exists()) await _deleteIfPresent(marker);
    }
  }

  static File _checksum(File file) => File('${file.path}.sha256');

  static Future<bool> _matchesChecksum(File file) async {
    try {
      // Legacy MP3s have no marker and could have been interrupted at any
      // byte. Reacquire them from the same immutable Storage object on demand.
      final expected = await _checksum(file).readAsString();
      if (expected.length != 64 || await file.length() == 0) return false;
      return (await sha256.bind(file.openRead()).first).toString() == expected;
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<void> invalidate(String audioPath) async {
    final asset = _parseAsset(audioPath);
    if (asset == null || !_mayRead(asset.$1)) return;
    final (ownerId, key) = asset;
    try {
      final file = await _cacheFile(key);
      await _access(
        file,
        (access, _) => access.onDisk(() async {
          if (_mayRead(ownerId)) await _deleteEntry(file);
          return null;
        }),
        invalidate: true,
      );
    } catch (_) {
      // Playback can still recover locally when eviction fails.
    }
  }

  static Future<void> _deleteEntry(File file) async {
    await _deleteIfPresent(_checksum(file));
    await _deleteIfPresent(file);
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<File> _cacheFile(String key) async {
    final dir = await _cacheDirectory();
    return File(p.normalize(p.absolute(dir.path, '$key.mp3')));
  }

  static Future<Uint8List> _downloadFromStorage(String audioPath) => Supabase
      .instance
      .client
      .storage
      .from(AudioAssetPath.bucket)
      .download(audioPath);

  static String? _authenticatedUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  static Future<Directory> _defaultCacheDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio_cache');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<int> cacheSize() async {
    final dir = await _cacheDirectory();
    if (!dir.existsSync()) return 0;
    return dir.listSync().whereType<File>().fold<int>(
      0,
      (sum, f) => sum + f.lengthSync(),
    );
  }

  /// Removes generated clips that have not been played or prefetched for
  /// [maxIdle]. This intentionally leaves freshly preloaded quiz audio alone.
  Future<void> cleanIdleCache({Duration maxIdle = cacheMaxIdle}) async {
    try {
      final dir = await _cacheDirectory();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(maxIdle);
      await for (final entity in dir.absolute.list()) {
        if (entity is! File) continue;
        final path = p.normalize(entity.path);
        final name = p.basename(path);
        if (!_cacheFileName.hasMatch(name)) continue;
        final clip = File(path.substring(0, path.lastIndexOf('.mp3') + 4));
        if (_inFlight.containsKey(clip.path)) continue;
        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.notFound ||
            !stat.modified.isBefore(cutoff) ||
            _inFlight.containsKey(clip.path)) {
          continue;
        }
        await _access(
          clip,
          (access, isCurrent) => access.onDisk(() async {
            // A cache hit can touch the file while the directory scan waits.
            final latest = await entity.stat();
            if (!isCurrent() || !latest.modified.isBefore(cutoff)) return null;
            if (path == clip.path) {
              await _deleteEntry(clip);
            } else if (path.endsWith('.part') || !await clip.exists()) {
              await _deleteIfPresent(entity);
            }
            return null;
          }),
        );
      }
    } catch (_) {
      // Cache maintenance is opportunistic; playback remains best-effort.
    }
  }

  Future<void> clearCache() async {
    final dir = await _cacheDirectory();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  static final _cacheFileName = RegExp(
    r'^[a-f0-9]+\.mp3(?:\.sha256)?(?:\.part)?$',
  );

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
