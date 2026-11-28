import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/audio/audio_ports.dart';
import 'package:vocab_kr/services/audio/sound_effects_service.dart';

class _FakePlayer implements SoundEffectPlayer {
  bool failPrepare = false;
  bool failPlay = false;
  bool failStop = false;
  Completer<void>? pendingPrepare;
  var prepared = 0;
  var stopped = 0;
  var disposed = 0;
  final played = <Uint8List>[];

  @override
  Future<void> prepare() async {
    prepared++;
    await pendingPrepare?.future;
    if (failPrepare) throw StateError('no audio session');
  }

  @override
  Future<void> play(Uint8List bytes, {bool waitForCompletion = false}) async {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native opening cue observes an error after resume acknowledgement',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const codec = StandardMethodCodec();
      const global = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      const player = MethodChannel('xyz.luan/audioplayers');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final resumed = Completer<void>();
      final disposed = Completer<void>();
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
          case 'setSourceBytes':
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
          case 'dispose':
            disposed.complete();
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(global, null);
        messenger.setMockMethodCallHandler(globalEvents, null);
        messenger.setMockMethodCallHandler(player, null);
        if (events != null) messenger.setMockMethodCallHandler(events!, null);
      });

      final service = SoundEffectsService();
      final cue = service.playListenCue();
      final result = expectLater(
        cue,
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
      await result.timeout(const Duration(seconds: 2));
      service.dispose();
      await disposed.future.timeout(const Duration(seconds: 2));
    },
  );

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

  test(
    'opening cue retries native preparation and propagates play errors',
    () async {
      final player = _FakePlayer()..failPrepare = true;
      final service = SoundEffectsService(player: player);
      await expectLater(service.playListenCue(), throwsStateError);
      expect(player.prepared, 1);
      expect(player.played, isEmpty);

      player.failPrepare = false;
      player.failPlay = true;
      await expectLater(service.playListenCue(), throwsStateError);
      expect(player.prepared, 2);
      expect(player.played, isEmpty);

      player.failPlay = false;
      await service.playListenCue();
      expect(player.prepared, 2);
      expect(player.played, hasLength(1));
    },
  );

  test('fails silently when the device audio session is unavailable', () async {
    final prepareFailure = _FakePlayer()..failPrepare = true;
    await SoundEffectsService(player: prepareFailure).playCorrect();
    expect(prepareFailure.played, isEmpty);

    final outputFailure = _FakePlayer()..failPlay = true;
    final service = SoundEffectsService(player: outputFailure);
    await service.playIncorrect();
    await service.playListenDone();
    expect(outputFailure.prepared, 1);
    expect(outputFailure.played, isEmpty);
  });

  test(
    'refused stop prevents disposal until the same player confirms release',
    () async {
      final player = _FakePlayer()..failStop = true;
      final service = SoundEffectsService(player: player);
      await service.playListenCue();

      await expectLater(service.stop(), throwsStateError);
      service.dispose();
      await expectLater(service.waitForRelease(), throwsStateError);

      expect(player.stopped, 2);
      expect(player.disposed, 0);
      player.failStop = false;
      await service.waitForRelease(retry: true);
      await service.waitForRelease(retry: true);
      expect(player.stopped, 3);
      expect(player.disposed, 1);
    },
  );

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'dispose' : 'stop'} cancels earcons waiting for prepare',
      () async {
        final gate = Completer<void>();
        final player = _FakePlayer()..pendingPrepare = gate;
        final service = SoundEffectsService(player: player);
        final pending = Future.wait([
          service.playCorrect(),
          service.playIncorrect(),
          service.playListenDone(),
        ]);
        final cue = expectLater(
          service.playListenCue(),
          throwsA(isA<AudioPlaybackCancelled>()),
        );
        expect(player.prepared, 1);

        if (dispose) {
          service.dispose();
        } else {
          await service.stop();
        }
        gate.complete();
        await pending;
        await cue;
        expect(player.played, isEmpty);
        expect(player.stopped, 1);

        if (dispose) {
          await expectLater(
            service.playListenCue(),
            throwsA(isA<AudioPlaybackCancelled>()),
          );
        } else {
          await service.playListenCue();
        }
        expect(player.played, hasLength(dispose ? 0 : 1));
      },
    );
  }
}
