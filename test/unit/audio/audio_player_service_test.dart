import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';

class _FakeCache implements AudioAssetCache {
  _FakeCache({this.path});

  String? path;
  Completer<String?>? pendingDownload;
  final requested = <String>[];
  var cleanupScheduled = 0;

  @override
  Future<String?> downloadAndCache(String audioPath) async {
    requested.add(audioPath);
    if (pendingDownload != null) return pendingDownload!.future;
    return path;
  }

  @override
  void scheduleIdleCacheCleanup() => cleanupScheduled++;
}

class _FakeTts implements DeviceSpeech {
  final spoken = <String>[];
  final warmed = <String>[];
  var stopped = 0;
  var disposed = 0;
  bool speaking = false;
  bool refuseDisposal = false;
  Completer<void>? disposalGate;

  @override
  Future<void> speak(String text, String langCode) async {
    spoken.add('$text|$langCode');
  }

  @override
  Future<void> warmUp(String langCode) async => warmed.add(langCode);

  @override
  Future<void> stop() async => stopped++;

  @override
  bool get isSpeaking => speaking;

  @override
  Future<void> dispose() async {
    disposed++;
    if (refuseDisposal) throw StateError('TTS still playing');
    await disposalGate?.future;
  }
}

class _FakeFilePlayer implements FileAudioPlayer {
  final played = <String>[];
  final rates = <double>[];
  var stopped = 0;
  var disposed = 0;
  bool playing = false;
  Completer<void>? pendingRate;
  Completer<void>? playbackEnded;

  @override
  Future<void> setPlaybackRate(double rate) async {
    rates.add(rate);
    await pendingRate?.future;
  }

  @override
  Future<void> playFile(String path, {bool waitForCompletion = false}) async {
    played.add(path);
    playing = true;
    if (waitForCompletion) await playbackEnded?.future;
  }

  @override
  Future<void> stop() async {
    stopped++;
    playing = false;
  }

  @override
  Future<PlayerState> get state async =>
      playing ? PlayerState.playing : PlayerState.stopped;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> dispose() async => disposed++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioPlayerService service({
    required bool premium,
    String? cachedPath,
    double speechRate = .8,
    _FakeCache? cache,
    _FakeTts? tts,
    _FakeFilePlayer? player,
  }) => AudioPlayerService(
    usePremium: premium,
    speechRate: speechRate,
    assetCache: cache ?? _FakeCache(path: cachedPath),
    tts: tts ?? _FakeTts(),
    filePlayer: player ?? _FakeFilePlayer(),
  );

  test('non-premium playback always uses the device voice', () async {
    final cache = _FakeCache(path: '/cache/bonjour.mp3');
    final tts = _FakeTts();
    final player = _FakeFilePlayer();
    final audio = service(
      premium: false,
      cache: cache,
      tts: tts,
      player: player,
    );

    await audio.speak('bonjour', 'fr', audioPath: 'seed/v1/fr/bonjour.mp3');

    expect(tts.spoken, ['bonjour|fr']);
    expect(cache.requested, isEmpty);
    expect(player.played, isEmpty);
    expect(cache.cleanupScheduled, 0);
  });

  test(
    'premium playback falls back to device TTS when no asset is published',
    () async {
      final cache = _FakeCache(path: '/cache/unused.mp3');
      final tts = _FakeTts();
      final audio = service(premium: true, cache: cache, tts: tts);

      await audio.speak('salut', 'fr');

      expect(tts.spoken, ['salut|fr']);
      expect(cache.requested, isEmpty);
      expect(cache.cleanupScheduled, 1);
    },
  );

  test(
    'premium playback uses a cached Storage clip at the chosen language rate',
    () async {
      final cache = _FakeCache(path: '/cache/annyeong.mp3');
      final tts = _FakeTts();
      final player = _FakeFilePlayer();
      final audio = service(
        premium: true,
        cache: cache,
        tts: tts,
        player: player,
        speechRate: .8,
      );

      await audio.speak('안녕하세요', 'ko', audioPath: 'seed/v1/ko/a.mp3');

      expect(cache.requested, ['seed/v1/ko/a.mp3']);
      expect(player.rates.single, closeTo(.656, .0001));
      expect(player.played, ['/cache/annyeong.mp3']);
      expect(tts.spoken, isEmpty);
    },
  );

  test(
    'a premium cache miss keeps playback responsive with device TTS',
    () async {
      final cache = _FakeCache();
      final tts = _FakeTts();
      final player = _FakeFilePlayer();
      final audio = service(
        premium: true,
        cache: cache,
        tts: tts,
        player: player,
      );

      await audio.speak('house', 'en', audioPath: 'seed/v1/en/house.mp3');

      expect(cache.requested, ['seed/v1/en/house.mp3']);
      expect(tts.spoken, ['house|en']);
      expect(player.played, isEmpty);
    },
  );

  test('prefetch only downloads published premium assets', () async {
    final cache = _FakeCache(path: '/cache/word.mp3');
    final audio = service(premium: true, cache: cache);
    final freeAudio = service(premium: false, cache: cache);

    await audio.prefetch('mot', 'fr', audioPath: 'seed/v1/fr/mot.mp3');
    await audio.prefetch('sans clip', 'fr');
    await freeAudio.prefetch('mot', 'fr', audioPath: 'seed/v1/fr/mot.mp3');

    expect(cache.requested, ['seed/v1/fr/mot.mp3']);
  });

  test('required cached playback waits through the end of the clip', () async {
    final finished = Completer<void>();
    final player = _FakeFilePlayer()..playbackEnded = finished;
    final audio = service(
      premium: true,
      cachedPath: '/cache/mot.mp3',
      player: player,
    );
    var returned = false;
    final speaking = audio
        .speak('mot', 'fr', audioPath: 'mot.mp3', requirePlayback: true)
        .then((_) => returned = true);
    await Future<void>.delayed(Duration.zero);
    expect(player.played, ['/cache/mot.mp3']);
    expect(returned, isFalse);
    finished.complete();
    await speaking;
    expect(returned, isTrue);
  });

  test('a native audio event error settles required cached playback', () async {
    const codec = StandardMethodCodec();
    const global = MethodChannel('xyz.luan/audioplayers.global');
    const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
    const player = MethodChannel('xyz.luan/audioplayers');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final resumed = Completer<void>();
    MethodChannel? events;
    Future<void> emit(ByteData payload) =>
        messenger.handlePlatformMessage(events!.name, payload, null);
    messenger.setMockMethodCallHandler(global, (_) async => null);
    messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
    messenger.setMockMethodCallHandler(player, (call) async {
      switch (call.method) {
        case 'create':
          events = MethodChannel(
            'xyz.luan/audioplayers/events/${call.arguments['playerId']}',
          );
          messenger.setMockMethodCallHandler(events!, (_) async => null);
        case 'setSourceUrl':
          await emit(
            codec.encodeSuccessEnvelope({
              'event': 'audio.onPrepared',
              'value': true,
            }),
          );
        case 'getCurrentPosition':
          return 0;
        case 'resume':
          resumed.complete();
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(global, null);
      messenger.setMockMethodCallHandler(globalEvents, null);
      messenger.setMockMethodCallHandler(player, null);
      if (events != null) messenger.setMockMethodCallHandler(events!, null);
    });
    final audio = AudioPlayerService(
      usePremium: true,
      assetCache: _FakeCache(path: '/cache/prompt.mp3'),
      tts: _FakeTts(),
    );
    final playback = audio.speak(
      'mot',
      'fr',
      audioPath: 'mot.mp3',
      requirePlayback: true,
    );
    final failure = expectLater(
      playback,
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'AndroidAudioError',
        ),
      ),
    );
    await resumed.future.timeout(const Duration(seconds: 2));
    await emit(codec.encodeErrorEnvelope(code: 'AndroidAudioError'));
    await failure.timeout(const Duration(seconds: 2));
    audio.dispose();
    await audio.stop();
  });

  for (final dispose in [false, true]) {
    for (final cacheHit in [false, true]) {
      test('${dispose ? 'dispose' : 'stop'} cancels a pending cache lookup '
          '(${cacheHit ? 'hit' : 'miss'})', () async {
        final download = Completer<String?>();
        final cache = _FakeCache()..pendingDownload = download;
        final tts = _FakeTts();
        final player = _FakeFilePlayer();
        final audio = service(
          premium: true,
          cache: cache,
          tts: tts,
          player: player,
        );

        final speaking = audio.speak('house', 'en', audioPath: 'house.mp3');
        if (dispose) {
          audio.dispose();
        } else {
          await audio.stop();
        }
        download.complete(cacheHit ? '/cache/house.mp3' : null);
        await speaking;

        expect(tts.spoken, isEmpty);
        expect(player.rates, isEmpty);
        expect(player.played, isEmpty);
      });
    }

    test(
      '${dispose ? 'dispose' : 'stop'} cancels playback pending its rate',
      () async {
        final rate = Completer<void>();
        final player = _FakeFilePlayer()..pendingRate = rate;
        final audio = service(
          premium: true,
          cachedPath: '/cache/mot.mp3',
          player: player,
        );
        final speaking = audio.speak('mot', 'fr', audioPath: 'mot.mp3');
        await Future<void>.delayed(Duration.zero);
        expect(player.rates, hasLength(1));

        if (dispose) {
          audio.dispose();
        } else {
          await audio.stop();
        }
        rate.complete();
        await speaking;
        expect(player.played, isEmpty);
      },
    );
  }

  test(
    'warm-up, state, stop, and disposal delegate to their engines',
    () async {
      final tts = _FakeTts()..speaking = true;
      final player = _FakeFilePlayer();
      final audio = service(premium: true, tts: tts, player: player);

      await audio.warmUp('ko');
      expect(audio.isSpeaking, isTrue);
      expect(await audio.state, PlayerState.stopped);
      player.playing = true;
      expect(audio.isSpeaking, isTrue);
      expect(await audio.state, PlayerState.playing);
      await audio.stop();
      audio.dispose();

      expect(tts.warmed, ['ko']);
      expect(tts.stopped, 1);
      expect(player.stopped, 1);
      expect(tts.disposed, 1);
      expect(player.disposed, 1);
    },
  );

  test('retry retains confirmed and pending releases', () async {
    final tts = _FakeTts()..refuseDisposal = true;
    final file = _FakeFilePlayer();
    final audio = service(premium: false, tts: tts, player: file);
    audio.dispose();
    await expectLater(audio.stop(), throwsStateError);
    expect(file.disposed, 1);
    expect(tts.disposed, 1);

    final stopping = Completer<void>();
    tts
      ..refuseDisposal = false
      ..disposalGate = stopping;
    final retries = [
      audio.retryDisposal(),
      audio.retryDisposal(),
      audio.stop(),
    ];
    expect(file.disposed, 1);
    expect(tts.disposed, 2);
    stopping.complete();
    await Future.wait(retries);
    await audio.retryDisposal();
    expect(file.disposed, 1);
    expect(tts.disposed, 2);
  });
}
