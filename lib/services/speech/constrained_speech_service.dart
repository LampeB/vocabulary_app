import 'dart:async';
import 'dart:convert';

import 'package:vosk_flutter/vosk_flutter.dart';

import '../../core/utils/answer_validator.dart';
import '../../core/utils/stt_debug_log.dart';

/// Grammar-constrained offline recognition (Vosk) for vocabulary hands-free.
///
/// The system recognizer treats a single spoken syllable in a noisy room as
/// noise and returns nothing (field log 2026-07-08: "thé"/"차" → zero
/// hypotheses). A vocabulary card is not open dictation though — the answer
/// is one of a handful of known words, so the recognizer runs with a
/// per-card grammar (accepted answers + [unk]) and stays reliable on short
/// utterances. Grammar sessions keep the system engine (free-form sentences).
///
/// Semantics with a constrained grammar: any recognized text IS one of the
/// accepted answers, so voice can only answer correctly or stay silent —
/// a wrong word maps to [unk], which the quiz treats as "not heard"
/// (retry → requeue, never a wrong grade). Wrong-answer detection via word
/// confidences is a follow-up (Notion ticket 2026-07-08).
class ConstrainedSpeechService {
  ConstrainedSpeechService();

  /// Small on-device models from the Vosk project (Alpha Cephei).
  static const modelUrls = <String, String>{
    'fr': 'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
    'ko': 'https://alphacephei.com/vosk/models/vosk-model-small-ko-0.22.zip',
  };
  static const _sampleRate = 16000;

  VoskFlutterPlugin? _plugin;
  ModelLoader? _loader;
  final _models = <String, Model>{};
  final _downloading = <String>{};

  Recognizer? _recognizer;
  SpeechService? _speech;
  String? _recognizerLang;
  StreamSubscription<String>? _resultSub;
  StreamSubscription<String>? _partialSub;
  // Active per-card callbacks — swapped on every startListening (the stream
  // subscriptions outlive individual cards).
  void Function(String text, double? minConfidence)? _onFinal;
  void Function(String text)? _onPartial;

  bool _isListening = false;
  DateTime? _listenStart;

  bool get isListening => _isListening;

  int get listenElapsedMs => _listenStart == null
      ? 0
      : DateTime.now().difference(_listenStart!).inMilliseconds;

  /// Whether [langCode] has a known model at all.
  static bool supportsLang(String langCode) =>
      modelUrls.containsKey(langCode);

  /// Whether the model for [langCode] is downloaded AND loaded — the gate
  /// the quiz uses to route to this engine (falls back to system STT).
  bool isReady(String langCode) => _models.containsKey(langCode);

  /// Downloads (first run: ~41MB fr / ~82MB ko) and loads the model in the
  /// background. Fire-and-forget: quiz routing checks [isReady] per card.
  Future<void> ensureModel(String langCode) async {
    if (!supportsLang(langCode) ||
        _models.containsKey(langCode) ||
        _downloading.contains(langCode)) {
      return;
    }
    _downloading.add(langCode);
    try {
      _plugin ??= VoskFlutterPlugin.instance();
      _loader ??= ModelLoader();
      final url = modelUrls[langCode]!;
      sttLog('[VOSK] ensureModel($langCode) — loading $url');
      final sw = Stopwatch()..start();
      final modelPath = await _loader!.loadFromNetwork(url);
      final model = await _plugin!.createModel(modelPath);
      _models[langCode] = model;
      sttLog('[VOSK] ✅ model $langCode ready in ${sw.elapsed.inSeconds}s ($modelPath)');
    } catch (e) {
      sttLog('[VOSK] 💥 ensureModel($langCode) failed: $e');
    } finally {
      _downloading.remove(langCode);
    }
  }

  /// The per-card grammar: normalized accepted answers plus [unk], which
  /// absorbs everything else (noise, wrong words, other speech).
  /// Annotations are stripped ("café (boisson)" → "café") — the recognizer
  /// can only ever hear the spoken form (field log 2026-07-09).
  static List<String> buildGrammar(List<String> acceptedAnswers) {
    final phrases = <String>{
      for (final a in acceptedAnswers)
        AnswerValidator.stripAnnotations(a).toLowerCase(),
    }..removeWhere((p) => p.isEmpty);
    return [...phrases, '[unk]'];
  }

  /// Parses a Vosk FINAL result: cleaned text plus the minimum word-level
  /// confidence across non-[unk] words (null when the engine gave none).
  /// Confidence is the false-accept gate: with a tiny grammar Vosk force-
  /// maps almost any speech onto a grammar word (field log 2026-07-09 —
  /// deliberately wrong answers were validated), but forced matches come
  /// back with low conf while true matches sit near 1.0.
  static ({String text, double? minConfidence})? parseFinal(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final text = parseText(json, partial: false);
      if (text == null) return null;
      double? minConf;
      final words = map['result'];
      if (words is List) {
        for (final w in words) {
          if (w is! Map || w['word'] == '[unk]') continue;
          final conf = (w['conf'] as num?)?.toDouble();
          if (conf != null && (minConf == null || conf < minConf)) {
            minConf = conf;
          }
        }
      }
      return (text: text, minConfidence: minConf);
    } catch (_) {
      return null;
    }
  }

  /// Extracts usable text from a Vosk result/partial JSON payload.
  /// Returns null for empty results and pure-[unk] matches.
  static String? parseText(String json, {required bool partial}) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final raw = (map[partial ? 'partial' : 'text'] as String?)?.trim();
      if (raw == null || raw.isEmpty) return null;
      final cleaned =
          raw.replaceAll('[unk]', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleaned.isEmpty ? null : cleaned;
    } catch (_) {
      return null;
    }
  }

  /// Opens the mic with a grammar built from [acceptedAnswers].
  /// [onFinal]/[onPartial] receive cleaned text (never empty, never [unk]);
  /// [onFinal] also gets the minimum word confidence (null = engine gave
  /// none) so the caller can gate forced grammar matches.
  Future<bool> startListening({
    required String langCode,
    required List<String> acceptedAnswers,
    required void Function(String text, double? minConfidence) onFinal,
    void Function(String text)? onPartial,
  }) async {
    final model = _models[langCode];
    if (model == null) {
      sttLog('[VOSK] startListening skipped — model $langCode not ready');
      return false;
    }
    if (_isListening) await stopListening();

    final grammar = buildGrammar(acceptedAnswers);
    // Callbacks live in fields, NOT in the stream subscriptions' closures:
    // the subscriptions are created once per speech service, and a same-
    // language card swap keeps them — a closure would deliver results to
    // the FIRST card forever.
    _onFinal = onFinal;
    _onPartial = onPartial;
    try {
      if (_recognizer == null || _recognizerLang != langCode) {
        // The native plugin allows ONE SpeechService bound to ONE recognizer,
        // so a language switch means teardown + re-init (~AudioRecord reopen).
        await _teardownSpeech();
        _recognizer?.dispose();
        _recognizer = await _plugin!.createRecognizer(
          model: model,
          sampleRate: _sampleRate,
          grammar: grammar,
        );
        // Word-level confidences in final results — the false-accept gate.
        await _recognizer!.setWords(words: true);
        _recognizerLang = langCode;
        sttLog('[VOSK] recognizer created lang=$langCode grammar=$grammar');
      } else {
        await _recognizer!.setGrammar(grammar);
        sttLog('[VOSK] grammar swapped lang=$langCode grammar=$grammar');
      }

      _speech ??= await _plugin!.initSpeechService(_recognizer!);
      _resultSub ??= _speech!.onResult().listen((json) {
        sttLog('[VOSK] result: $json  elapsed=${listenElapsedMs}ms');
        final parsed = parseFinal(json);
        if (parsed != null && _isListening) {
          _onFinal?.call(parsed.text, parsed.minConfidence);
        }
      });
      _partialSub ??= _speech!.onPartial().listen((json) {
        final text = parseText(json, partial: true);
        if (text != null && _isListening) {
          sttLog('[VOSK] partial: $json  elapsed=${listenElapsedMs}ms');
          _onPartial?.call(text);
        }
      });

      await _speech!.reset();
      final ok = await _speech!.start(
            onRecognitionError: (Object? e) =>
                sttLog('[VOSK] 💥 recognition error: $e'),
          ) ??
          false;
      _isListening = ok;
      _listenStart = DateTime.now();
      sttLog('[VOSK] 🎙️ startListening lang=$langCode ok=$ok');
      return ok;
    } catch (e) {
      sttLog('[VOSK] 💥 startListening failed: $e');
      _isListening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    sttLog('[VOSK] stopListening()');
    try {
      await _speech?.stop();
    } catch (e) {
      sttLog('[VOSK] stop failed: $e');
    }
  }

  Future<void> _teardownSpeech() async {
    await _resultSub?.cancel();
    await _partialSub?.cancel();
    _resultSub = null;
    _partialSub = null;
    if (_speech != null) {
      try {
        await _speech!.dispose();
      } catch (e) {
        sttLog('[VOSK] speech dispose failed: $e');
      }
      _speech = null;
    }
  }

  void dispose() {
    unawaited(stopListening());
    unawaited(_teardownSpeech());
    _recognizer?.dispose();
    _recognizer = null;
  }
}
