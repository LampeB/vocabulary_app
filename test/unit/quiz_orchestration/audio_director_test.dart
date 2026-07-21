import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_player_service.dart';
import 'package:vocab_kr/services/quiz_orchestration/audio_director.dart';

/// AudioDirector owns "when is the audio channel free" (refactor step 1).
/// These pin the semantics extracted from the three historical polling loops.

class _FakeAudio implements AudioPlayerService {
  bool speaking = false;
  final spoken = <String>[];
  final prefetched = <String>[];

  @override
  bool get isSpeaking => speaking;

  @override
  Future<void> speak(String text, String langCode) async {
    spoken.add('$text|$langCode');
  }

  @override
  Future<void> prefetch(String text, String langCode) async {
    prefetched.add('$text|$langCode');
  }

  @override
  Future<void> warmUp(String langCode) async {}

  @override
  Future<void> stop() async {
    speaking = false;
  }

  @override
  Future<PlayerState> get state async =>
      speaking ? PlayerState.playing : PlayerState.stopped;

  @override
  void dispose() {}
}

void main() {
  group('quiet', () {
    test('resolves immediately when nothing is playing', () async {
      final audio = _FakeAudio();
      final sw = Stopwatch()..start();
      await AudioDirector(audio).quiet();
      expect(sw.elapsedMilliseconds, lessThan(80));
    });

    test('waits until the audio ends', () async {
      final audio = _FakeAudio()..speaking = true;
      final director = AudioDirector(audio);
      final future = director.quiet();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      audio.speaking = false;
      await future; // resolves promptly once quiet
    });

    test('a stuck isSpeaking never wedges the caller (timeout cap)', () async {
      final audio = _FakeAudio()..speaking = true; // never ends
      final sw = Stopwatch()..start();
      await AudioDirector(audio)
          .quiet(timeout: const Duration(milliseconds: 200));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('speakWhenQuiet', () {
    test('speaks only after the channel is free', () async {
      final audio = _FakeAudio()..speaking = true;
      final director = AudioDirector(audio);
      final future = director.speakWhenQuiet('bonjour', 'fr');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(audio.spoken, isEmpty, reason: 'must not talk over live audio');
      audio.speaking = false;
      await future;
      expect(audio.spoken, ['bonjour|fr']);
    });
  });

  group('chainQuiet', () {
    test('ends after a start-window with no new speech', () async {
      final audio = _FakeAudio(); // silent throughout
      final sw = Stopwatch()..start();
      await AudioDirector(audio).chainQuiet(
        firstStartWindow: const Duration(milliseconds: 100),
      );
      // One start-window, no speech → done; never enters later cycles.
      expect(sw.elapsedMilliseconds, lessThan(600));
    });

    test('waits out an utterance that starts inside the window, then the '
        'follow-up check ends the chain', () async {
      final audio = _FakeAudio();
      final director = AudioDirector(audio);
      final future = director.chainQuiet(
        firstStartWindow: const Duration(milliseconds: 300),
        nextStartWindow: const Duration(milliseconds: 80),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      audio.speaking = true; // question TTS spins up
      await Future<void>.delayed(const Duration(milliseconds: 200));
      audio.speaking = false; // and finishes
      await future; // resolves via the empty follow-up window
    });

    test('keepGoing=false aborts the wait', () async {
      final audio = _FakeAudio()..speaking = true;
      var alive = true;
      final future = AudioDirector(audio).chainQuiet(keepGoing: () => alive);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      alive = false; // e.g. screen unmounted
      final sw = Stopwatch()..start();
      await future;
      expect(sw.elapsedMilliseconds, lessThan(300));
    });
  });
}
