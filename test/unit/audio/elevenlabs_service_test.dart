import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
    Future<Uint8List> Function(String) downloader,
  ) => ElevenLabsService(
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

  test(
    'concurrent requests for one asset share one Storage download',
    () async {
      var downloads = 0;
      const asset = 'seed/v1/ko/a.mp3';
      final started = Completer<void>();
      final content = Completer<Uint8List>();
      Future<Uint8List> download(String path) async {
        expect(path, asset);
        downloads++;
        if (!started.isCompleted) started.complete();
        return content.future;
      }

      final prefetched = serviceWith(download).downloadAndCache(asset);
      await started.future;
      final played = serviceWith(download).downloadAndCache(asset);
      await Future<void>.delayed(Duration.zero);
      expect(await cacheDir.list().toList(), isEmpty);

      content.complete(Uint8List.fromList([1, 2, 3]));
      final results = await Future.wait([prefetched, played]);

      expect(downloads, 1);
      expect(results[0], results[1]);
      expect(
        await File(results.first!).readAsBytes(),
        Uint8List.fromList([1, 2, 3]),
      );
    },
  );

  test(
    'a verified cache hit does not download the asset a second time',
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
    },
  );

  test('a durable cache hit survives a new service instance', () async {
    const asset = 'seed/v1/fr/bonjour.mp3';
    final first = serviceWith((_) async => Uint8List.fromList([9, 8, 7]));
    final originalPath = await first.downloadAndCache(asset);

    final second = serviceWith(
      (_) async => throw StateError('must not download'),
    );
    final cachedPath = await second.downloadAndCache(asset);

    expect(cachedPath, originalPath);
    expect(
      await File(cachedPath!).readAsBytes(),
      Uint8List.fromList([9, 8, 7]),
    );
  });

  test('account switches cannot read another owner’s cached clip', () async {
    const asset = 'users/user-a/variant/private.mp3';
    String? account = 'user-a';
    var cacheReads = 0;
    var downloads = 0;
    ElevenLabsService serviceForSession() => ElevenLabsService(
      currentUserId: () => account,
      cacheDirectory: () async {
        cacheReads++;
        return cacheDir;
      },
      assetDownloader: (_) async {
        downloads++;
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final original = serviceForSession();
    final cached = (await original.downloadAndCache(asset))!;
    expect(await File(cached).exists(), isTrue);

    account = 'user-b';
    final newService = serviceForSession();
    expect(await original.downloadAndCache(asset), isNull);
    expect(await newService.downloadAndCache(asset), isNull);
    expect(await newService.downloadAndCache('seed/../users/user-a'), isNull);
    expect(
      await newService.downloadAndCache('seed/%2e%2e/users/user-a'),
      isNull,
    );
    account = null;
    expect(await newService.downloadAndCache(asset), isNull);
    await newService.invalidate(asset);
    expect(await File(cached).exists(), isTrue);
    expect(cacheReads, 1);
    expect(downloads, 1);

    account = 'user-a';
    expect(await newService.downloadAndCache(asset), cached);
    expect(downloads, 1);
  });

  test(
    'a private download started by the previous account is discarded',
    () async {
      const first = 'users/user-a/variant/private.mp3';
      const second = 'users/user-b/variant/private.mp3';
      String? account = 'user-a';
      final started = Completer<void>();
      final oldDownload = Completer<Uint8List>();
      final service = ElevenLabsService(
        currentUserId: () => account,
        cacheDirectory: () async => cacheDir,
        assetDownloader: (path) async {
          if (path == first) {
            started.complete();
            return oldDownload.future;
          }
          expect(path, second);
          return Uint8List.fromList([4]);
        },
      );
      final pending = service.downloadAndCache(first);
      await started.future;

      account = 'user-b';
      expect(await service.downloadAndCache(first), isNull);
      final ownPath = (await service.downloadAndCache(second))!;
      oldDownload.complete(Uint8List.fromList([1, 2, 3]));
      expect(await pending, isNull);
      expect(await File(ownPath).readAsBytes(), [4]);
      final clips = await cacheDir
          .list()
          .where((file) => file.path.endsWith('.mp3'))
          .map((file) => file.path)
          .toList();
      expect(clips, [ownPath]);
    },
  );

  test(
    'a seed file cached before the publishing manifest is ignored',
    () async {
      const asset = 'seed/v1/fr/unpublished.mp3';
      final oldKey = md5.convert(asset.codeUnits);
      await File('${cacheDir.path}/$oldKey.mp3').writeAsBytes([1]);
      var downloads = 0;
      final service = serviceWith((_) async {
        downloads++;
        throw const SocketException('not published');
      });

      expect(await service.downloadAndCache(asset), isNull);
      expect(downloads, 1);
    },
  );

  test(
    'a Storage failure leaves no corrupt cache file and returns null',
    () async {
      final service = serviceWith(
        (_) async => throw const SocketException('offline'),
      );

      final path = await service.downloadAndCache('seed/v1/fr/missing.mp3');

      expect(path, isNull);
      expect(await service.cacheSize(), 0);
    },
  );

  for (final bytes in [
    <int>[],
    [73, 68, 51, 4],
  ]) {
    test(
      'an unverified legacy MP3 (${bytes.length} bytes) is discarded',
      () async {
        const asset = 'seed/v1/fr/legacy.mp3';
        final key = sha256.convert('v2\u0000\u0000$asset'.codeUnits);
        final legacy = File('${cacheDir.path}/$key.mp3');
        await legacy.writeAsBytes(bytes);

        final offline = serviceWith(
          (_) async => throw const SocketException('offline'),
        );
        expect(await offline.downloadAndCache(asset), isNull);
        expect(await legacy.exists(), isFalse);

        final recovered = serviceWith((_) async => Uint8List.fromList([7, 8]));
        final path = (await recovered.downloadAndCache(asset))!;
        expect(await File(path).readAsBytes(), [7, 8]);
      },
    );
  }

  test(
    'same-length corruption and decoder eviction are visible to every reader',
    () async {
      const asset = 'seed/v1/fr/verified.mp3';
      final service = serviceWith((_) async => Uint8List.fromList([1, 2]));
      final path = (await service.downloadAndCache(asset))!;
      await File(path).writeAsBytes([2, 1]);

      final replacement = serviceWith((_) async => Uint8List.fromList([1, 2]));
      expect(await replacement.downloadAndCache(asset), path);
      expect(await File(path).readAsBytes(), [1, 2]);
      await replacement.invalidate(asset);
      expect(await File(path).exists(), isFalse);
      expect(await service.cacheSize(), 0);
    },
  );

  test(
    'eviction and a new reader do not wait for an obsolete download',
    () async {
      const asset = 'seed/v1/fr/evicted.mp3';
      final started = Completer<void>();
      final late = Completer<Uint8List>();
      final previous = serviceWith((_) async {
        started.complete();
        return late.future;
      });
      final pending = previous.downloadAndCache(asset);
      await started.future;

      final replacement = serviceWith((_) async => Uint8List.fromList([9]));
      await replacement.invalidate(asset).timeout(const Duration(seconds: 1));
      final published = (await replacement.downloadAndCache(asset))!;
      expect(await File(published).readAsBytes(), [9]);

      late.complete(Uint8List.fromList([1, 2]));
      expect(await pending, isNull);
      expect(await previous.downloadAndCache(asset), published);
      expect(await File(published).readAsBytes(), [9]);
    },
  );

  test(
    'an empty download or refused rename cannot publish a cache entry',
    () async {
      const asset = 'seed/v1/fr/write.mp3';
      final empty = serviceWith((_) async => Uint8List(0));
      expect(await empty.downloadAndCache(asset), isNull);
      expect(await cacheDir.list().toList(), isEmpty);

      final key = sha256.convert('v2\u0000\u0000$asset'.codeUnits);
      final blocker = await Directory('${cacheDir.path}/$key.mp3').create();
      final service = serviceWith((_) async => Uint8List.fromList([3]));
      expect(await service.downloadAndCache(asset), isNull);
      expect(
        await cacheDir.list().where((file) => file is File).toList(),
        isEmpty,
      );

      await blocker.delete();
      final path = (await service.downloadAndCache(asset))!;
      expect(await File(path).readAsBytes(), [3]);
    },
  );

  test('idle cleanup removes expired files but retains recent files', () async {
    const oldAsset = 'seed/v1/en/old.mp3';
    const newAsset = 'seed/v1/en/new.mp3';
    final service = serviceWith((_) async => Uint8List.fromList([1]));
    final oldPath = await service.downloadAndCache(oldAsset);
    final newPath = await service.downloadAndCache(newAsset);
    await File(oldPath!).setLastModified(
      DateTime.now().subtract(
        ElevenLabsService.cacheMaxIdle + const Duration(days: 1),
      ),
    );

    await service.cleanIdleCache();

    expect(await File(oldPath).exists(), isFalse);
    expect(await File(newPath!).exists(), isTrue);
  });

  test(
    'cache maintenance is safe when the cache directory is absent',
    () async {
      final service = serviceWith((_) async => Uint8List.fromList([1]));
      await cacheDir.delete(recursive: true);

      await service.cleanIdleCache();

      expect(await service.cacheSize(), 0);
    },
  );

  test(
    'a cache-directory failure is a playback miss and a later retry works',
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
    },
  );

  test(
    'the default cache directory is created below application documents',
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
    },
  );

  test(
    'clearing the cache removes the clip and its verification data',
    () async {
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
    },
  );

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

  test(
    'custom paths are owner-scoped and change when the spoken text changes',
    () {
      final first = AudioAssetPath.user(
        userId: 'user-a',
        variantId: 'variant-a',
        text: 'bonjour',
        langCode: 'fr',
      );
      final edited = AudioAssetPath.user(
        userId: 'user-a',
        variantId: 'variant-a',
        text: 'salut',
        langCode: 'fr',
      );

      expect(first, startsWith('users/user-a/variant-a/'));
      expect(first, endsWith('.mp3'));
      expect(edited, isNot(first));
    },
  );
}
