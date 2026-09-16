import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/sound_effects_service.dart';

class _FakePlayer implements SoundEffectPlayer {
  bool failPrepare = false;
  bool failPlay = false;
  bool failStop = false;
  var prepared = 0;
  var stopped = 0;
  var disposed = 0;
  final played = <Uint8List>[];

  @override
  Future<void> prepare() async {
    prepared++;
    if (failPrepare) throw StateError('no audio session');
  }

  @override
  Future<void> play(Uint8List bytes) async {
    if (failPlay) throw StateError('no output device');
    played.add(bytes);
  }

  @override
  Future<void> stop() async {
    stopped++;
    if (failStop) throw StateError('already stopped');
  }

  @override
  void dispose() => disposed++;
}

void _expectWav(Uint8List bytes, int dataLength) {
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  expect(ascii.decode(bytes.sublist(12, 16)), 'fmt ');
  expect(ascii.decode(bytes.sublist(36, 40)), 'data');
  final header = ByteData.sublistView(bytes);
  expect(header.getUint32(4, Endian.little), 36 + dataLength);
  expect(header.getUint32(40, Endian.little), dataLength);
  expect(bytes.length, 44 + dataLength);
}

void main() {
  test('creates and caches a valid rising verdict WAV', () async {
    final player = _FakePlayer();
    final service = SoundEffectsService(player: player);

    await service.playCorrect();
    await service.playCorrect();

    expect(player.prepared, 1);
    expect(player.played, hasLength(2));
    expect(identical(player.played.first, player.played.last), isTrue);
    // Two 110 ms, 22.05 kHz, 16-bit mono tones concatenated in one WAV.
    _expectWav(player.played.first, 2 * (22050 * .11).round() * 2);
  });

  test('uses distinct, valid WAV lengths for every hands-free cue', () async {
    final player = _FakePlayer();
    final service = SoundEffectsService(player: player);

    await service.playIncorrect();
    await service.playListenCue();
    await service.playListenDone();

    expect(player.prepared, 1);
    expect(player.played, hasLength(3));
    _expectWav(player.played[0], 2 * (22050 * .14).round() * 2);
    _expectWav(player.played[1], (22050 * .07).round() * 2);
    _expectWav(player.played[2], (22050 * .07).round() * 2);
    expect(identical(player.played[1], player.played[2]), isFalse);
  });

  test('fails silently when the device audio session is unavailable', () async {
    final prepareFailure = _FakePlayer()..failPrepare = true;
    await SoundEffectsService(player: prepareFailure).playCorrect();
    expect(prepareFailure.played, isEmpty);

    final outputFailure = _FakePlayer()..failPlay = true;
    final service = SoundEffectsService(player: outputFailure);
    await service.playIncorrect();
    await service.playListenCue();
    await service.playListenDone();
    expect(outputFailure.prepared, 1);
    expect(outputFailure.played, isEmpty);
  });

  test('stops and disposes safely, including a platform stop failure',
      () async {
    final player = _FakePlayer()..failStop = true;
    final service = SoundEffectsService(player: player);
    await service.playListenCue();

    await service.stop();
    service.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(player.stopped, 2);
    expect(player.disposed, 1);
  });
}
