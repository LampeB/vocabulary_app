import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/services/speech/stt_corpus_recorder.dart';

void main() {
  const recordedAt = '2026-09-13T12:00:00.000Z';

  SttCorpusSample sample() => SttCorpusSample(
        id: 'sample_fr',
        word: 'bonjour',
        langCode: 'fr',
        path: '/tmp/sample.wav',
        recordedAt: DateTime.parse(recordedAt),
      );

  test('keeps an OpenAI result when a Whisper result is saved afterwards', () {
    final withOpenAi = sample().withOpenAiResult(
      transcript: 'Bonjour.',
      durationMs: 800,
    );
    final withElevenLabs = withOpenAi.withElevenLabsResult(
      transcript: 'bonjour',
      durationMs: 600,
    );
    final updated = withElevenLabs.withWhisperResult(
      transcript: 'bonjour',
      durationMs: 2300,
    );

    expect(updated.openAiTranscript, 'Bonjour.');
    expect(updated.openAiDurationMs, 800);
    expect(updated.elevenLabsTranscript, 'bonjour');
    expect(updated.elevenLabsDurationMs, 600);
    expect(updated.whisperTranscript, 'bonjour');
    expect(updated.whisperDurationMs, 2300);
  });
}
