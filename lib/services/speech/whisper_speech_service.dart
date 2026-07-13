import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../core/utils/answer_validator.dart';
import '../../core/utils/pcm_segmenter.dart';
import '../../core/utils/stt_debug_log.dart';
import '../../core/utils/wav_writer.dart';

/// Device-independent recognition: OUR mic capture + OUR endpointing
/// ([PcmSegmenter]) + on-device Whisper inference (whisper.cpp, ggml-base
/// multilingual). No vendor recognizer anywhere in the loop — the same
/// model makes the same decision on any phone (user decision 2026-07-09
/// after Samsung's engine dropped short words and Vosk's grammar mode
/// couldn't tell right from wrong).
///
/// One model serves ALL languages (no fr↔ko engine switching), it is
/// open-vocabulary (wrong answers are real transcripts, so they can be
/// graded), and the segmenter's pre-roll means the first syllable of a
/// short word is never lost.
class WhisperSpeechService {
  WhisperSpeechService();

  /// ggml-base multilingual (~142MB): tiny's French on short words was
  /// garbage ("pomme" → "Bonne", field log 2026-07-10); base was accurate
  /// but slow — until the vendored audio_ctx patch, which cuts the fixed
  /// 30s encoder window down to the actual clip length.
  static const _model = WhisperModel.base;
  static const _sampleRate = 16000;

  Whisper? _whisper;
  bool _modelReady = false;
  bool _preparing = false;

  final _recorder = AudioRecorder();
  StreamSubscription<dynamic>? _micSub;
  PcmSegmenter? _segmenter;
  bool _isListening = false;
  DateTime? _listenStart;
  int _inferenceSerial = 0;
  int _pendingInferences = 0;
  Future<void> _inferenceChain = Future.value();

  // Active per-window callbacks (swapped on every startListening).
  void Function(String text, int segmentMs)? _onFinal;
  void Function()? _onSpeechStart;
  void Function()? _onSegment;
  String _promptHints = '';

  bool get isReady => _modelReady;
  bool get isListening => _isListening;

  int get listenElapsedMs => _listenStart == null
      ? 0
      : DateTime.now().difference(_listenStart!).inMilliseconds;

  /// Downloads (first run) and loads the model, then warms the native
  /// context with a 200ms silent clip so the first real inference isn't
  /// paying initialization costs. Fire-and-forget; gate on [isReady].
  Future<void> ensureModel() async {
    if (_modelReady || _preparing) return;
    _preparing = true;
    try {
      _whisper = Whisper(model: _model);
      sttLog('[WSP] ensureModel — ggml-${_model.modelName} (downloads ~142MB on first run)');
      final sw = Stopwatch()..start();
      final silence = pcm16ToWav(
        // 200ms of silence.
        Uint8List(_sampleRate ~/ 5 * 2),
        sampleRate: _sampleRate,
      );
      final dir = await getTemporaryDirectory();
      final warmup = File('${dir.path}/wsp_warmup.wav');
      await warmup.writeAsBytes(silence, flush: true);
      await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: warmup.path,
          language: 'fr',
          isNoTimestamps: true,
        ),
      );
      _modelReady = true;
      sttLog('[WSP] ✅ model ready in ${sw.elapsed.inSeconds}s');
    } catch (e) {
      sttLog('[WSP] 💥 ensureModel failed: $e');
    } finally {
      _preparing = false;
    }
  }

  /// Whisper hallucinates boilerplate on noise/near-silence (training-data
  /// artifacts: subtitle credits, "thanks for watching", …). Any transcript
  /// containing one of these is discarded, never graded.
  static const _hallucinationMarkers = [
    'sous-titr', // sous-titre(s), sous-titrage
    'sous titrage',
    'amara.org',
    'merci d\'avoir regardé',
    "merci d'avoir regardé",
    'abonnez-vous',
    'thank you for watching',
    'thanks for watching',
    'subscribe',
    'subtitles',
    '자막',
    '시청해',
    '구독',
  ];

  /// Cleans a raw Whisper transcript for validation: trims, strips
  /// bracketed/parenthesized event tags ("[Musique]", "(rires)") and edge
  /// punctuation. Returns null when nothing usable remains or the text
  /// looks like a known hallucination.
  static String? cleanTranscript(String raw) {
    var t = raw
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\*[^*]*\*'), ' ') // *musique d'outro*
        .replaceAll(RegExp(r'[.,!?;:…"«»*]'), ' ')
        .replaceAll(RegExp(r'(^|\s)-+|-+(?=\s|\$)'), ' ') // caption dashes
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    for (final marker in _hallucinationMarkers) {
      if (lower.contains(marker)) return null;
    }
    return t;
  }

  /// Opens the mic and transcribes each detected utterance in [langCode].
  /// [onFinal] receives cleaned non-empty transcripts; [onSpeechStart]
  /// fires when the segmenter detects speech onset (UI feedback).
  /// [promptHints]: expected answers used as decoder-bias context —
  /// dramatically improves short-word transcription ("thé" → "T" without
  /// it, field 2026-07-10). Annotations/slashes are cleaned here.
  Future<bool> startListening({
    required String langCode,
    required void Function(String text, int segmentMs) onFinal,
    void Function()? onSpeechStart,
    void Function()? onSegment,
    List<String> promptHints = const [],
  }) async {
    if (!_modelReady) {
      sttLog('[WSP] startListening skipped — model not ready');
      return false;
    }
    if (_isListening) await stopListening();

    _onFinal = onFinal;
    _onSpeechStart = onSpeechStart;
    _onSegment = onSegment;
    _promptHints = {
      for (final h in promptHints)
        ...h.split('/').map(AnswerValidator.stripAnnotations),
    }.where((h) => h.isNotEmpty).join(', ');
    final windowSerial = ++_inferenceSerial;

    try {
      if (!await _recorder.hasPermission()) {
        sttLog('[WSP] ❌ mic permission denied');
        return false;
      }
      // maxUtterance 3s: an answer is a word or two. Longer capture is
      // ambient conversation — two people testing together produced 5-6s
      // blobs whisper described as '*bruit de la chanson*' (2026-07-13).
      _segmenter = PcmSegmenter(sampleRate: _sampleRate, maxUtteranceMs: 3000);
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ));
      var wasInSpeech = false;
      var lastLevelLog = DateTime.now();
      _micSub = stream.listen((chunk) {
        final seg = _segmenter!;
        final segments = seg.feed(chunk);
        if (seg.inSpeech && !wasInSpeech) {
          sttLog('[WSP] 🗣 speech onset  floor=${seg.noiseFloor.toStringAsFixed(0)}');
          _onSpeechStart?.call();
        }
        wasInSpeech = seg.inSpeech;
        final now = DateTime.now();
        if (now.difference(lastLevelLog).inMilliseconds >= 1000) {
          lastLevelLog = now;
          sttLog('[WSP] 🎚 floor=${seg.noiseFloor.toStringAsFixed(0)}  inSpeech=${seg.inSpeech}  elapsed=${listenElapsedMs}ms');
        }
        for (final s in segments) {
          sttLog('[WSP] segment complete: ${s.durationMs}ms  peak=${s.peakRms.toStringAsFixed(0)}');
          _onSegment?.call(); // utterance captured — inference starting
          _enqueueInference(s, langCode, windowSerial);
        }
      });
      _isListening = true;
      _listenStart = DateTime.now();
      sttLog('[WSP] 🎙️ startListening lang=$langCode (own capture, base model)');
      return true;
    } catch (e) {
      sttLog('[WSP] 💥 startListening failed: $e');
      _isListening = false;
      return false;
    }
  }

  void _enqueueInference(PcmSegment segment, String langCode, int serial) {
    // Backpressure: a conversation-heavy room can produce segments faster
    // than inference clears them; an unbounded queue is how the 2026-07-13
    // session snowballed. Newest segments matter least (the answer usually
    // comes first) — drop them when the queue is deep.
    if (_pendingInferences >= 3) {
      sttLog('[WSP] inference queue full ($_pendingInferences) — dropping ${segment.durationMs}ms segment');
      return;
    }
    _pendingInferences++;
    _inferenceChain = _inferenceChain.then((_) async {
      _pendingInferences--;
      if (serial != _inferenceSerial) return; // window closed meanwhile
      try {
        final sw = Stopwatch()..start();
        final dir = await getTemporaryDirectory();
        final f = File(
            '${dir.path}/wsp_seg_${DateTime.now().millisecondsSinceEpoch}.wav');
        await f.writeAsBytes(pcm16ToWav(segment.bytes), flush: true);
        final res = await _whisper!.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: f.path,
            language: langCode,
            isNoTimestamps: true,
          ),
          initialPrompt: _promptHints,
        );
        unawaited(f.delete().catchError((_) => f));
        final cleaned = cleanTranscript(res.text);
        sttLog('[WSP] 📝 transcribed ${segment.durationMs}ms in ${sw.elapsedMilliseconds}ms: raw="${res.text}" cleaned="${cleaned ?? "<discarded>"}"');
        if (cleaned == null) return;
        if (serial != _inferenceSerial) {
          sttLog('[WSP] transcript arrived after window closed — dropped');
          return;
        }
        _onFinal?.call(cleaned, segment.durationMs);
      } catch (e) {
        sttLog('[WSP] 💥 inference failed: $e');
      }
    });
  }

  /// Stops the mic. By default queued/in-flight transcripts are dropped
  /// (card changed, quiz quit). [keepPendingTranscripts] lets the window-
  /// expiry path close the mic while a segment captured near the deadline
  /// finishes inference and can still grade.
  Future<void> stopListening({bool keepPendingTranscripts = false}) async {
    if (!_isListening) return;
    _isListening = false;
    if (!keepPendingTranscripts) {
      _inferenceSerial++; // drop queued/in-flight transcripts
    }
    sttLog('[WSP] stopListening(keepPending=$keepPendingTranscripts)');
    try {
      await _micSub?.cancel();
      _micSub = null;
      await _recorder.stop();
    } catch (e) {
      sttLog('[WSP] stop failed: $e');
    }
  }

  void dispose() {
    unawaited(stopListening());
    _recorder.dispose();
  }
}
