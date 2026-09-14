import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';

class _FakeCache implements AudioAssetCache {
  _FakeCache({this.path});

  String? path;
  final requested = <String>[];
  var cleanupScheduled = 0;

  @override
  Future<String?> downloadAndCache(String audioPath) async {
    requested.add(audioPath);
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
  void dispose() => disposed++;
}

class _FakeFilePlayer implements FileAudioPlayer {
  final played = <String>[];
  final rates = <double>[];
  var stopped = 0;
  var disposed = 0;
  bool playing = false;

  @override
  Future<void> setPlaybackRate(double rate) async => rates.add(rate);

  @override
  Future<void> playFile(String path) async {
    played.add(path);
    playing = true;
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
  void dispose() => disposed++;
}

void main() {
  AudioPlayerService service({
    required bool premium,
    String? cachedPath,
    double speechRate = .8,
    _FakeCache? cache,
    _FakeTts? tts,
    _FakeFilePlayer? player,
  }) =>
      AudioPlayerService(
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
    final audio =
        service(premium: false, cache: cache, tts: tts, player: player);

    await audio.speak('bonjour', 'fr', audioPath: 'seed/v1/fr/bonjour.mp3');

    expect(tts.spoken, ['bonjour|fr']);
    expect(cache.requested, isEmpty);
    expect(player.played, isEmpty);
    expect(cache.cleanupScheduled, 0);
  });

  test('premium playback falls back to device TTS when no asset is published',
      () async {
    final cache = _FakeCache(path: '/cache/unused.mp3');
    final tts = _FakeTts();
    final audio = service(premium: true, cache: cache, tts: tts);

    await audio.speak('salut', 'fr');

    expect(tts.spoken, ['salut|fr']);
    expect(cache.requested, isEmpty);
    expect(cache.cleanupScheduled, 1);
  });

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
  });

  test('a premium cache miss keeps playback responsive with device TTS',
      () async {
    final cache = _FakeCache();
    final tts = _FakeTts();
    final player = _FakeFilePlayer();
    final audio =
        service(premium: true, cache: cache, tts: tts, player: player);

    await audio.speak('house', 'en', audioPath: 'seed/v1/en/house.mp3');

    expect(cache.requested, ['seed/v1/en/house.mp3']);
    expect(tts.spoken, ['house|en']);
    expect(player.played, isEmpty);
  });

  test('prefetch only downloads published premium assets', () async {
    final cache = _FakeCache(path: '/cache/word.mp3');
    final audio = service(premium: true, cache: cache);
    final freeAudio = service(premium: false, cache: cache);

    await audio.prefetch('mot', 'fr', audioPath: 'seed/v1/fr/mot.mp3');
    await audio.prefetch('sans clip', 'fr');
    await freeAudio.prefetch('mot', 'fr', audioPath: 'seed/v1/fr/mot.mp3');

    expect(cache.requested, ['seed/v1/fr/mot.mp3']);
  });

  test('warm-up, state, stop, and disposal delegate to their engines',
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
  });
}
