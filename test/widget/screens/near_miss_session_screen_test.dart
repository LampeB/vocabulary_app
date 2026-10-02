import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/stt/near_miss_prompts.dart';
import 'package:vocab_kr/presentation/screens/settings/near_miss_session_screen.dart';
import 'package:vocab_kr/services/speech/stt_corpus_recorder.dart';

class _FakeAudio implements CorpusAudioRecorder {
  String? path;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(config, {required String path}) async => this.path = path;
  @override
  Future<String?> stop() async {
    await File(path!).writeAsBytes(const [1, 2, 3]);
    return path;
  }

  @override
  void dispose() {}
}

void main() {
  late Directory dir;
  var tick = 0;
  SttCorpusRecorder recorder() => SttCorpusRecorder(
        recorder: _FakeAudio(),
        documentsDirectory: () async => dir,
        clock: () => DateTime.utc(2026, 10, 3).add(Duration(seconds: tick++)),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('near_miss');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> start(WidgetTester tester, SttCorpusRecorder rec) async {
    await tester.pumpWidget(MaterialApp(
      home: NearMissSessionScreen(
        recorder: rec,
        takeDuration: const Duration(milliseconds: 20),
      ),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('near_miss_speaker')), 'P1');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Commencer'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  String shownWord(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('near_miss_word'))).data!;

  testWidgets('a Korean session records a labelled take and moves on',
      (tester) async {
    final rec = recorder();
    await start(tester, rec);
    final prompts = nearMissPromptsFor('ko', 'P1');
    expect(shownWord(tester), prompts[0].spoken);
    expect(find.textContaining('평소처럼'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('near_miss_record')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(shownWord(tester), prompts[1].spoken);
    final saved = await tester.runAsync(rec.samples);
    final take = saved!.single;
    expect(take.word, prompts[0].spoken);
    expect(take.meta['speaker'], 'P1');
    expect(take.meta['expected'], prompts[0].expected);
    expect(take.meta['kind'], prompts[0].kind);
    expect(take.meta['condition'], 'calme');
  });

  testWidgets('a returning participant resumes at the first missing word',
      (tester) async {
    final rec = recorder();
    final prompts = nearMissPromptsFor('ko', 'P1');
    await tester.runAsync(() async {
      for (final p in prompts.take(3)) {
        await rec.start(
            word: p.spoken,
            langCode: 'ko',
            meta: {'speaker': 'P1', 'condition': 'calme'});
        await rec.stop();
      }
    });
    await start(tester, rec);
    expect(shownWord(tester), prompts[3].spoken);
    expect(find.text('4 / ${prompts.length}'), findsOneWidget);
  });

  testWidgets('the participant board lists progress and resumes on tap',
      (tester) async {
    final rec = recorder();
    final prompts = nearMissPromptsFor('ko', 'P7');
    await tester.runAsync(() async {
      for (final p in prompts.take(5)) {
        await rec.start(
            word: p.spoken,
            langCode: 'ko',
            meta: {'speaker': 'P7', 'condition': 'bruit'});
        await rec.stop();
      }
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: NearMissSessionScreen(
          recorder: rec,
          takeDuration: const Duration(milliseconds: 20),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('1 personne · 0 séance complète · 5 mots enregistrés'),
        findsOneWidget);
    expect(find.text('P7 · 한국어 · bruit'), findsOneWidget);
    expect(find.textContaining('5 / ${prompts.length}'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('P7 · 한국어 · bruit'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(shownWord(tester), prompts[5].spoken);
  });
}
