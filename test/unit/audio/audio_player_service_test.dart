import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';
import 'package:vocab_kr/services/audio/flutter_tts_service.dart';
import 'package:vocab_kr/services/audio/native_playback_player.dart';
import 'package:vocab_kr/services/quiz_orchestration/audio_director.dart';

class _FakeCache implements AudioAssetCache {
  _FakeCache({this.path});

  String? path;
  Completer<String?>? pendingDownload;
  final requested = <String>[];
  final invalidated = <String>[];
  var cleanupScheduled = 0;

  @override
  Future<String?> downloadAndCache(String audioPath) async {
    requested.add(audioPath);
    if (pendingDownload != null) return pendingDownload!.future;
    return path;
  }

  @override
  Future<void> invalidate(String audioPath) async {
    invalidated.add(audioPath);
    path = null;
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
  bool refuseSpeech = false;
  Completer<void>? disposalGate;

  @override
  Future<void> speak(
    String text,
    String langCode, {
    bool Function()? keepGoing,
  }) async {
    spoken.add('$text|$langCode');
    if (refuseSpeech) throw TtsRejected('speak', langCode);
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
  var releases = 0;
  bool playing = false;
  bool rejectClip = false;
  bool refuseRelease = false;
  Completer<void>? releaseGate;
  Completer<void>? pendingRate;
  Completer<void>? playbackEnded;

  @override
  Future<void> setPlaybackRate(double rate) async {
    rates.add(rate);
    await pendingRate?.future;
  }

  @override
  Future<void> playFile(
    String path, {
    bool waitForCompletion = false,
    bool Function()? keepGoing,
  }) async {
    played.add(path);
    playing = true;
    if (rejectClip) throw PlatformException(code: 'UnreadableClip');
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
  Future<void> release() async {
    releases++;
    if (refuseRelease) throw PlatformException(code: 'ReleaseRefused');
    await releaseGate?.future;
    playing = false;
  }

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

  test(
    'optional clips and speech share one acknowledged native owner',
    () async {
      const codec = StandardMethodCodec();
      const global = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const player = MethodChannel('xyz.luan/audioplayers');
      const tts = MethodChannel('vocab_kr/device_speech');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final events = <String, MethodChannel>{};
      final clips = <String, String>{};
      final starts = <String>[];
      final stoppedPlayers = <String>[];
      final fileStop = Completer<void>();
      final fileStopSent = Completer<void>();
      final ttsStarted = Completer<void>();
      final ttsStopSent = Completer<void>();
      final ttsStop = Completer<int>();
      final ttsCompleted = Completer<int>();
      final prepareSent = Completer<void>();
      final prepare = Completer<void>();
      String? playingClip;
      var ttsPlaying = false;
      var refuseFileStop = true;
      Future<void> prepared(String id) => messenger.handlePlatformMessage(
        events[id]!.name,
        codec.encodeSuccessEnvelope({
          'event': 'audio.onPrepared',
          'value': true,
        }),
        null,
      );
      messenger.setMockMethodCallHandler(global, (_) async => null);
      messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
      messenger.setMockMethodCallHandler(player, (call) async {
        final id = call.arguments['playerId'] as String;
        switch (call.method) {
          case 'create':
            final channel = events[id] = MethodChannel(
              'xyz.luan/audioplayers/events/$id',
            );
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          case 'setSourceUrl':
            final path = clips[id] = call.arguments['url'] as String;
            if (path == '/cache/preparing.mp3') {
              prepareSent.complete();
              await prepare.future;
            }
            await prepared(id);
          case 'getCurrentPosition':
            return 0;
          case 'resume':
            expect(ttsPlaying, isFalse);
            expect(playingClip, isNull);
            playingClip = id;
            starts.add(clips[id]!);
          case 'stop':
            stoppedPlayers.add(id);
            if (id == playingClip && clips[id] == '/cache/question.mp3') {
              if (refuseFileStop) throw PlatformException(code: 'StopRefused');
              fileStopSent.complete();
              await fileStop.future;
            }
            if (id == playingClip) playingClip = null;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(tts, (call) async {
        if (call.method == 'speak') {
          expect(playingClip, isNull);
          ttsPlaying = true;
          starts.add(call.arguments['text'] as String);
          ttsStarted.complete();
          return ttsCompleted.future;
        }
        if (call.method == 'stop' && ttsPlaying) {
          ttsStopSent.complete();
          final accepted = await ttsStop.future;
          if (accepted == 1) ttsPlaying = false;
          return accepted;
        }
        return 1;
      });
      addTearDown(() {
        for (final channel in [
          global,
          globalEvents,
          player,
          tts,
          ...events.values,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      const deadline = Duration(seconds: 2);
      final cache = _FakeCache(path: '/cache/question.mp3');
      final audio = AudioPlayerService(
        usePremium: true,
        assetCache: cache,
        tts: FlutterTtsService(mobileChannel: tts),
      );
      final director = AudioDirector(audio);
      await director
          .speak('question', 'fr', audioPath: 'question.mp3')
          .timeout(deadline);
      final oldPlayer = playingClip!;
      expect(audio.isSpeaking, isTrue);
      cache.path = null;
      await director
          .speak('refused', 'ko', audioPath: 'answer.mp3')
          .timeout(deadline);
      expect(starts, ['/cache/question.mp3']);
      expect(playingClip, oldPlayer);

      refuseFileStop = false;
      final expired = director.speak('expired', 'ko', audioPath: 'answer.mp3');
      await fileStopSent.future.timeout(deadline);
      await expired.timeout(deadline);
      final speech = director.speak('answer', 'ko', audioPath: 'answer.mp3');
      await Future<void>.delayed(Duration.zero);
      expect(ttsStarted.isCompleted, isFalse);
      expect(stoppedPlayers, [oldPlayer, oldPlayer]);
      fileStop.complete();
      await ttsStarted.future.timeout(deadline);
      expect(starts, ['/cache/question.mp3', 'answer']);

      cache.path = '/cache/next.mp3';
      final next = director.speak('next', 'fr', audioPath: 'next.mp3');
      await ttsStopSent.future.timeout(deadline);
      expect(playingClip, isNull);
      ttsStop.complete(1);
      await next.timeout(deadline);
      await speech.timeout(deadline);
      final currentPlayer = playingClip!;
      expect(currentPlayer, isNot(oldPlayer));
      ttsCompleted.complete(0);
      expect(starts, ['/cache/question.mp3', 'answer', '/cache/next.mp3']);

      cache.path = '/cache/preparing.mp3';
      var cardCurrent = true;
      final preparing = director.speak(
        'preparing',
        'fr',
        audioPath: 'preparing.mp3',
        keepGoing: () => cardCurrent,
      );
      await prepareSent.future.timeout(deadline);
      cardCurrent = false;
      prepare.complete();
      await preparing.timeout(deadline);
      expect(starts, ['/cache/question.mp3', 'answer', '/cache/next.mp3']);
      expect(stoppedPlayers.where((id) => id == currentPlayer), hasLength(1));
      director.dispose();
      audio.dispose();
      await audio.stop().timeout(deadline);
    },
  );

  for (final newerOwner in [false, true]) {
    test(
      'optional cache reply respects card invalidation (new owner: $newerOwner)',
      () async {
        final download = Completer<String?>();
        final cache = _FakeCache()..pendingDownload = download;
        final file = _FakeFilePlayer();
        final director = AudioDirector(
          service(premium: true, cache: cache, player: file),
        );
        var current = true;
        final old = director.speak(
          'ancien',
          'fr',
          audioPath: 'ancien.mp3',
          keepGoing: () => current,
        );
        expect(cache.requested, ['ancien.mp3']);
        current = false;
        if (newerOwner) {
          cache
            ..pendingDownload = null
            ..path = '/cache/actuel.mp3';
          await director.speak('actuel', 'fr', audioPath: 'actuel.mp3');
        }

        download.complete('/cache/ancien.mp3');
        await old;
        expect(file.played, newerOwner ? ['/cache/actuel.mp3'] : isEmpty);
        expect(file.isPlaying, newerOwner);
        expect(file.stopped + file.releases, 0);
        director.dispose();
      },
    );
  }

  test(
    'a cached player releases audio before retrying final native cleanup',
    () async {
      const codec = StandardMethodCodec();
      const global = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const player = MethodChannel('xyz.luan/audioplayers');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final optionalResumed = Completer<String>();
      final promptResumed = Completer<String>();
      final firstCleanup = Completer<void>();
      final allowRefusal = Completer<void>();
      final cleanedUp = Completer<void>();
      final waitingForRelease = Completer<void>();
      Completer<void>? releaseGate;
      final releaseCalls = <(String, String)>[];
      var cleanupCalls = 0;
      String? promptPlayer;
      final events = <String, MethodChannel>{};
      Future<void> emit(String id, ByteData payload) =>
          messenger.handlePlatformMessage(events[id]!.name, payload, null);
      messenger.setMockMethodCallHandler(global, (_) async => null);
      messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
      messenger.setMockMethodCallHandler(player, (call) async {
        final id = call.arguments['playerId'] as String;
        switch (call.method) {
          case 'create':
            final channel = events[id] = MethodChannel(
              'xyz.luan/audioplayers/events/$id',
            );
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          case 'setSourceUrl':
            await emit(
              id,
              codec.encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
            );
          case 'getCurrentPosition':
            return 0;
          case 'resume':
            if (optionalResumed.isCompleted) {
              promptPlayer = id;
              promptResumed.complete(id);
            } else {
              optionalResumed.complete(id);
            }
          case 'stop':
            releaseCalls.add((id, call.method));
          case 'release':
            releaseCalls.add((id, call.method));
            if (id == promptPlayer) {
              waitingForRelease.complete();
              await releaseGate!.future;
            }
          case 'dispose':
            releaseCalls.add((id, call.method));
            if (id != promptPlayer) return null;
            if (++cleanupCalls == 1) {
              firstCleanup.complete();
              await allowRefusal.future;
              throw PlatformException(code: 'FinalCleanupRefused');
            }
            cleanedUp.complete();
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(global, null);
        messenger.setMockMethodCallHandler(globalEvents, null);
        messenger.setMockMethodCallHandler(player, null);
        for (final channel in events.values) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final tts = _FakeTts();
      final cache = _FakeCache(path: '/cache/prompt.mp3');
      final audio = AudioPlayerService(
        usePremium: true,
        assetCache: cache,
        tts: tts,
      );
      await audio.speak('ancien', 'fr', audioPath: 'ancien.mp3');
      final old = await optionalResumed.future.timeout(
        const Duration(seconds: 2),
      );
      final playback = audio.speak(
        'mot',
        'fr',
        audioPath: 'mot.mp3',
        requirePlayback: true,
      );
      final prompt = await promptResumed.future.timeout(
        const Duration(seconds: 2),
      );
      expect(prompt, isNot(old));
      expect(releaseCalls.take(2), [(old, 'stop'), (old, 'release')]);
      await emit(
        old,
        codec.encodeSuccessEnvelope({'event': 'audio.onComplete'}),
      );
      final completedEarly = await Future.any<bool>([
        playback.then((_) => true, onError: (Object _, StackTrace _) => true),
        Future<void>.delayed(Duration.zero).then((_) => false),
      ]);
      expect(completedEarly, isFalse);

      final released = Completer<void>();
      releaseGate = released;
      await emit(prompt, codec.encodeErrorEnvelope(code: 'AndroidAudioError'));
      await waitingForRelease.future.timeout(const Duration(seconds: 2));
      expect(tts.spoken, isEmpty);
      expect(cache.invalidated, isEmpty);
      released.complete();
      await playback.timeout(const Duration(seconds: 2));
      expect(cache.invalidated, ['mot.mp3']);
      expect(tts.spoken, ['mot|fr']);
      await firstCleanup.future.timeout(const Duration(seconds: 2));
      audio.dispose();
      await audio.stop().timeout(const Duration(seconds: 2));
      Iterable<String> promptReleaseCalls() => releaseCalls
          .where((call) => call.$1 == prompt)
          .map((call) => call.$2);
      expect(promptReleaseCalls(), ['stop', 'release', 'dispose']);
      expect(cleanedUp.isCompleted, isFalse);
      allowRefusal.complete();
      await cleanedUp.future.timeout(const Duration(seconds: 2));
      await audio.retryDisposal();
      expect(promptReleaseCalls(), ['stop', 'release', 'dispose', 'dispose']);
    },
  );

  test(
    'native retirement joins a file stop still waiting for acknowledgement',
    () async {
      const global = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const player = MethodChannel('xyz.luan/audioplayers');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final confirmed = Completer<void>();
      final stopSent = Completer<void>();
      final releaseCalls = <String>[];
      MethodChannel? events;
      messenger.setMockMethodCallHandler(global, (_) async => null);
      messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
      messenger.setMockMethodCallHandler(player, (call) async {
        switch (call.method) {
          case 'create':
            events = MethodChannel(
              'xyz.luan/audioplayers/events/${call.arguments['playerId']}',
            );
            messenger.setMockMethodCallHandler(events!, (_) async => null);
          case 'getCurrentPosition':
            return 0;
          case 'stop':
            releaseCalls.add('stop');
            if (!stopSent.isCompleted) stopSent.complete();
            await confirmed.future;
          case 'release':
            releaseCalls.add('release');
        }
        return null;
      });
      addTearDown(() {
        for (final channel in [global, globalEvents, player, ?events]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      final native = NativePlaybackPlayer();
      final stopping = native.stop();
      await stopSent.future.timeout(const Duration(seconds: 2));
      final retiring = native.releaseForDisposal();
      await Future<void>.delayed(Duration.zero);
      expect(releaseCalls, ['stop']);
      confirmed.complete();
      await Future.wait([
        stopping,
        retiring,
      ]).timeout(const Duration(seconds: 2));
      expect(releaseCalls, ['stop', 'release']);
      await native.dispose();
    },
  );

  test('a failed file release and rejected TTS both fail the prompt', () async {
    final file = _FakeFilePlayer()
      ..rejectClip = true
      ..refuseRelease = true;
    final cache = _FakeCache(path: '/cache/mot.mp3');
    final tts = _FakeTts()..refuseSpeech = true;
    final audio = service(premium: true, player: file, cache: cache, tts: tts);
    final director = AudioDirector(audio);
    addTearDown(director.dispose);
    Future<StudyPromptResult> prompt() => director.speakVocabularyPrompt(
      word: 'mot',
      wordLang: 'fr',
      audioPath: 'mot.mp3',
      keepGoing: () => true,
    );
    expect(await prompt(), StudyPromptResult.failed);
    expect(tts.spoken, isEmpty);
    expect(cache.invalidated, isEmpty);

    file.refuseRelease = false;
    await director.stopAll();
    expect(await prompt(), StudyPromptResult.failed);
    expect(cache.invalidated, ['mot.mp3']);
    expect(tts.spoken, ['mot|fr']);
    expect(file.played, ['/cache/mot.mp3']);

    tts.refuseSpeech = false;
    expect(await prompt(), StudyPromptResult.completed);
    expect(tts.spoken, ['mot|fr', 'mot|fr']);
    expect(file.played, ['/cache/mot.mp3']);
  });

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'disposal' : 'stop'} joins file release and cancels its fallback',
      () async {
        final released = Completer<void>();
        final file = _FakeFilePlayer()
          ..rejectClip = true
          ..releaseGate = released;
        final cache = _FakeCache(path: '/cache/mot.mp3');
        final tts = _FakeTts();
        final audio = service(
          premium: true,
          player: file,
          cache: cache,
          tts: tts,
        );
        final speaking = audio.speak(
          'mot',
          'fr',
          audioPath: 'mot.mp3',
          requirePlayback: true,
        );
        final cancelled = expectLater(
          speaking,
          throwsA(isA<AudioPlaybackCancelled>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(file.releases, 1);
        if (dispose) audio.dispose();
        final stopped = audio.stop();
        await cancelled;
        expect(file.releases, 1);
        expect(tts.spoken, isEmpty);

        released.complete();
        await stopped;
        expect(tts.spoken, isEmpty);
        expect(cache.invalidated, ['mot.mp3']);
        final next = dispose
            ? service(premium: true, cache: cache, tts: tts)
            : audio;
        await next.speak(
          'new word',
          'en',
          audioPath: 'mot.mp3',
          requirePlayback: true,
        );
        expect(tts.spoken, ['new word|en']);
      },
    );

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
      await audio.stop();

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
