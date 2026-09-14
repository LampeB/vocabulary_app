import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vocab_kr/services/audio/audio_asset_path.dart';
import 'package:vocab_kr/services/audio/elevenlabs_service.dart';

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('vocab-audio-cache-');
  });

  tearDown(() async {
    if (await cacheDir.exists()) await cacheDir.delete(recursive: true);
  });

  ElevenLabsService serviceWith(
          Future<Uint8List> Function(String) downloader) =>
      ElevenLabsService(
        assetDownloader: downloader,
        cacheDirectory: () async => cacheDir,
      );

  test('an absent asset path is a no-op and never reaches Storage', () async {
    var downloads = 0;
    final service = serviceWith((_) async {
      downloads++;
      return Uint8List(0);
    });

    expect(await service.downloadAndCache(null), isNull);
    expect(await service.downloadAndCache(''), isNull);
    expect(downloads, 0);
  });

  test('concurrent requests for one asset share one Storage download',
      () async {
    var downloads = 0;
    const asset = 'seed/v1/ko/a.mp3';
    final service = serviceWith((path) async {
      expect(path, asset);
      downloads++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return Uint8List.fromList([1, 2, 3]);
    });

    final results = await Future.wait([
      service.downloadAndCache(asset),
      service.downloadAndCache(asset),
    ]);

    expect(downloads, 1);
    expect(results[0], results[1]);
    expect(await File(results.first!).readAsBytes(),
        Uint8List.fromList([1, 2, 3]));
  });

  test('an in-memory cache hit does not download the asset a second time',
      () async {
    var downloads = 0;
    final service = serviceWith((_) async {
      downloads++;
      return Uint8List.fromList([4, 5, 6]);
    });

    final first = await service.downloadAndCache('seed/v1/ko/memory.mp3');
    final second = await service.downloadAndCache('seed/v1/ko/memory.mp3');

    expect(second, first);
    expect(downloads, 1);
  });

  test('a durable cache hit survives a new service instance', () async {
    const asset = 'seed/v1/fr/bonjour.mp3';
    final first = serviceWith((_) async => Uint8List.fromList([9, 8, 7]));
    final originalPath = await first.downloadAndCache(asset);

    final second =
        serviceWith((_) async => throw StateError('must not download'));
    final cachedPath = await second.downloadAndCache(asset);

    expect(cachedPath, originalPath);
    expect(
        await File(cachedPath!).readAsBytes(), Uint8List.fromList([9, 8, 7]));
  });

  test('a Storage failure leaves no corrupt cache file and returns null',
      () async {
    final service =
        serviceWith((_) async => throw const SocketException('offline'));

    final path = await service.downloadAndCache('seed/v1/fr/missing.mp3');

    expect(path, isNull);
    expect(await service.cacheSize(), 0);
  });

  test('idle cleanup removes expired files but retains recent files', () async {
    const oldAsset = 'seed/v1/en/old.mp3';
    const newAsset = 'seed/v1/en/new.mp3';
    final service = serviceWith((_) async => Uint8List.fromList([1]));
    final oldPath = await service.downloadAndCache(oldAsset);
    final newPath = await service.downloadAndCache(newAsset);
    await File(oldPath!).setLastModified(DateTime.now()
        .subtract(ElevenLabsService.cacheMaxIdle + const Duration(days: 1)));

    await service.cleanIdleCache();

    expect(await File(oldPath).exists(), isFalse);
    expect(await File(newPath!).exists(), isTrue);
  });

  test('cache maintenance is safe when the cache directory is absent',
      () async {
    final service = serviceWith((_) async => Uint8List.fromList([1]));
    await cacheDir.delete(recursive: true);

    await service.cleanIdleCache();

    expect(await service.cacheSize(), 0);
  });

  test('a cache-directory failure is a playback miss and a later retry works',
      () async {
    var calls = 0;
    final service = ElevenLabsService(
      assetDownloader: (_) async => Uint8List.fromList([1]),
      cacheDirectory: () async {
        calls++;
        if (calls == 1) throw const FileSystemException('unavailable');
        return cacheDir;
      },
    );

    expect(await service.downloadAndCache('seed/v1/fr/retry.mp3'), isNull);
    expect(await service.downloadAndCache('seed/v1/fr/retry.mp3'), isNotNull);
  });

  test('the default cache directory is created below application documents',
      () async {
    final originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(cacheDir.path);
    addTearDown(() => PathProviderPlatform.instance = originalPlatform);
    final service = ElevenLabsService(
      assetDownloader: (_) async => Uint8List.fromList([2]),
    );

    final path = await service.downloadAndCache('seed/v1/fr/default-dir.mp3');

    expect(
      File(path!).parent.path.replaceAll('\\', '/'),
      '${cacheDir.path.replaceAll('\\', '/')}/audio_cache',
    );
    expect(await File(path).exists(), isTrue);
  });

  test('cache can be cleared, including its in-memory index', () async {
    var downloads = 0;
    final service = serviceWith((_) async {
      downloads++;
      return Uint8List.fromList([7]);
    });
    const asset = 'seed/v1/en/clear.mp3';

    await service.downloadAndCache(asset);
    await service.clearCache();

    expect(await cacheDir.exists(), isFalse);
    await cacheDir.create();
    expect(await service.downloadAndCache(asset), isNotNull);
    expect(downloads, 2);
  });

  test('service compatibility methods remain available', () async {
    final service = serviceWith((_) async => Uint8List(0));

    expect(service.voiceIdFor('ko'), 'Elli');
    expect(service.voiceIdFor('unknown'), 'Charlotte');
    await service.speak('bonjour', 'fr');
    expect(await service.isAvailable(), isTrue);
    await service.stop();
    service.dispose();
    service.scheduleIdleCacheCleanup();
  });

  test('seed paths are what the Storage publisher creates', () {
    expect(
      AudioAssetPath.seed(text: '안녕하세요', langCode: 'ko'),
      'seed/v1/ko/4df44cd691f8d16845675e32a277d2e68f910d0657b8e31336314d7c96f40e87.mp3',
    );
  });

  test('custom paths are owner-scoped and change when the spoken text changes',
      () {
    final first = AudioAssetPath.user(
        userId: 'user-a',
        variantId: 'variant-a',
        text: 'bonjour',
        langCode: 'fr');
    final edited = AudioAssetPath.user(
        userId: 'user-a',
        variantId: 'variant-a',
        text: 'salut',
        langCode: 'fr');

    expect(first, startsWith('users/user-a/variant-a/'));
    expect(first, endsWith('.mp3'));
    expect(edited, isNot(first));
  });
}
