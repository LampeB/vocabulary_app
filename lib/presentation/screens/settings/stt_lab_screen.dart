import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/answer_validator.dart';
import '../../../domain/entities/concept.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/entities/word_variant.dart';
import '../../../services/speech/stt_corpus_recorder.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/speech/whisper_speech_provider.dart';

/// Debug-only, local capture flow for testing recognition on a real speaker.
///
/// Captures are deliberately organised by vocabulary concept: tapping one row
/// records its French form, then its Korean form. This makes the resulting WAV
/// corpus directly usable for per-language, per-word STT comparisons.
class SttLabScreen extends ConsumerStatefulWidget {
  const SttLabScreen({super.key});

  @override
  ConsumerState<SttLabScreen> createState() => _SttLabScreenState();
}

class _SttLabScreenState extends ConsumerState<SttLabScreen> {
  final _recorder = SttCorpusRecorder();
  var _samples = const <SttCorpusSample>[];
  String? _selectedListId;
  _CorpusPair? _activePair;
  var _phase = 0;
  var _isBenchmarking = false;
  var _benchmarkDone = 0;
  var _benchmarkTotal = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final samples = await _recorder.samples();
    if (mounted) setState(() => _samples = samples);
  }

  void _selectList(String? listId) {
    setState(() {
      _selectedListId = listId;
      _activePair = null;
      _phase = 0;
      _message = null;
    });
  }

  bool _hasCapture(_CorpusPair pair, String langCode) => _samples.any(
        (sample) =>
            sample.listId == pair.listId &&
            sample.conceptId == pair.conceptId &&
            sample.langCode == langCode,
      );

  bool _isComplete(_CorpusPair pair) =>
      _hasCapture(pair, 'fr') && _hasCapture(pair, 'ko');

  Future<void> _toggleRecording() async {
    final pair = _activePair;
    if (pair == null) return;
    if (_recorder.isRecording) {
      final sample = await _recorder.stop();
      if (!mounted) return;
      await _reload();
      if (sample == null) {
        setState(() => _message = 'Aucun enregistrement sauvegardé.');
      } else if (_phase == 0) {
        setState(() {
          _phase = 1;
          _message = 'Français enregistré. À toi pour le coréen.';
        });
      } else {
        setState(() {
          _activePair = null;
          _phase = 0;
          _message =
              'Paire complète enregistrée : ${pair.french} · ${pair.korean}';
        });
      }
      return;
    }

    final langCode = _phase == 0 ? 'fr' : 'ko';
    final word = _phase == 0 ? pair.french : pair.korean;
    final ok = await _recorder.start(
      word: word,
      langCode: langCode,
      listId: pair.listId,
      conceptId: pair.conceptId,
    );
    if (!mounted) return;
    setState(() => _message = ok
        ? 'Parle naturellement, puis touche Terminer.'
        : 'Micro indisponible.');
  }

  void _openPair(_CorpusPair pair) {
    setState(() {
      _activePair = pair;
      _phase = _hasCapture(pair, 'fr') ? 1 : 0;
      _message = null;
    });
  }

  Future<void> _runWhisperBenchmark(String listId) async {
    final captures =
        _samples.where((sample) => sample.listId == listId).toList();
    if (captures.isEmpty || _isBenchmarking) return;
    setState(() {
      _isBenchmarking = true;
      _benchmarkDone = 0;
      _benchmarkTotal = captures.length;
      _message = 'Chargement du modèle Whisper…';
    });
    final whisper = ref.read(whisperSpeechProvider);
    var correct = 0;
    for (var index = 0; index < captures.length; index++) {
      final sample = captures[index];
      final result = await whisper.transcribeFile(
        path: sample.path,
        langCode: sample.langCode,
        promptHints: [sample.word],
      );
      final transcript = result?.cleanedText;
      final accepted = transcript != null &&
          AnswerValidator.validate(
            userAnswer: transcript,
            acceptedAnswers: [sample.word],
            isDrivingMode: true,
          ).isCorrect;
      if (accepted) correct++;
      await _recorder.saveWhisperResult(
        sampleId: sample.id,
        transcript: transcript,
        durationMs: result?.elapsedMs,
      );
      if (mounted) {
        setState(() {
          _benchmarkDone = index + 1;
          _message = 'Analyse Whisper : ${index + 1}/${captures.length} '
              '· $correct reconnue(s)';
        });
      }
    }
    await _reload();
    if (!mounted) return;
    setState(() {
      _isBenchmarking = false;
      _message = 'Whisper : $correct/${captures.length} prises reconnues.';
    });
  }

  Future<void> _runOpenAiBenchmark(String listId) async {
    final captures =
        _samples.where((sample) => sample.listId == listId).toList();
    if (captures.isEmpty || _isBenchmarking) return;
    setState(() {
      _isBenchmarking = true;
      _benchmarkDone = 0;
      _benchmarkTotal = captures.length;
      _message = 'Connexion à OpenAI…';
    });
    final client = ref.read(supabaseClientProvider);
    var correct = 0;
    try {
      for (var index = 0; index < captures.length; index++) {
        final sample = captures[index];
        final startedAt = DateTime.now();
        String? transcript;
        try {
          final response =
              await client.functions.invoke('whisper-proxy', body: {
            'audio_base64': base64Encode(await File(sample.path).readAsBytes()),
            'language': sample.langCode,
            // The Edge Function turns this known quiz answer into a
            // transcription hint. Keep this key in lockstep with its API.
            'expected_word': sample.word,
          });
          final data = response.data;
          if (data is Map) transcript = data['text'] as String?;
        } catch (_) {
          // A missing result is persisted so the corpus remains diagnostic.
        }
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        final accepted = transcript != null &&
            AnswerValidator.validate(
              userAnswer: transcript,
              acceptedAnswers: [sample.word],
              isDrivingMode: true,
            ).isCorrect;
        if (accepted) correct++;
        await _recorder.saveOpenAiResult(
          sampleId: sample.id,
          transcript: transcript,
          durationMs: elapsedMs,
        );
        if (mounted) {
          setState(() {
            _benchmarkDone = index + 1;
            _message = 'Analyse OpenAI : ${index + 1}/${captures.length} '
                '· $correct reconnue(s)';
          });
        }
      }
      await _reload();
      if (!mounted) return;
      setState(() =>
          _message = 'OpenAI : $correct/${captures.length} prises reconnues.');
    } finally {
      if (mounted) setState(() => _isBenchmarking = false);
    }
  }

  Future<void> _runElevenLabsBenchmark(String listId) async {
    final captures =
        _samples.where((sample) => sample.listId == listId).toList();
    if (captures.isEmpty || _isBenchmarking) return;
    setState(() {
      _isBenchmarking = true;
      _benchmarkDone = 0;
      _benchmarkTotal = captures.length;
      _message = 'Connexion à ElevenLabs…';
    });
    final client = ref.read(supabaseClientProvider);
    var correct = 0;
    var failures = 0;
    try {
      for (var index = 0; index < captures.length; index++) {
        final sample = captures[index];
        final startedAt = DateTime.now();
        String? transcript;
        try {
          final response =
              await client.functions.invoke('elevenlabs-stt-proxy', body: {
            'audio_base64': base64Encode(await File(sample.path).readAsBytes()),
            'language': sample.langCode,
            'expected_word': sample.word,
          });
          final data = response.data;
          if (data is Map) transcript = data['text'] as String?;
        } catch (_) {
          failures++;
        }
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        final accepted = transcript != null &&
            AnswerValidator.validate(
              userAnswer: transcript,
              acceptedAnswers: [sample.word],
              isDrivingMode: true,
            ).isCorrect;
        if (accepted) correct++;
        await _recorder.saveElevenLabsResult(
          sampleId: sample.id,
          transcript: transcript,
          durationMs: elapsedMs,
        );
        if (mounted) {
          setState(() {
            _benchmarkDone = index + 1;
            _message = 'Analyse ElevenLabs : ${index + 1}/${captures.length} '
                '· $correct reconnue(s)';
          });
        }
      }
      await _reload();
      if (!mounted) return;
      setState(() => _message = failures == 0
          ? 'ElevenLabs : $correct/${captures.length} prises reconnues.'
          : 'ElevenLabs : $correct/${captures.length} prises reconnues '
              '($failures erreur(s) de service).');
    } finally {
      if (mounted) setState(() => _isBenchmarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(myListsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_activePair == null ? 'Corpus STT' : 'Enregistrer un mot'),
        leading: _activePair == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _recorder.isRecording
                    ? null
                    : () => setState(() {
                          _activePair = null;
                          _phase = 0;
                        }),
              ),
      ),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Listes indisponibles : $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Aucune liste disponible.'));
          }
          final selected = _selectedListId ?? _preferredList(items).id;
          if (_activePair != null) return _captureView(_activePair!);
          return _listView(items, selected);
        },
      ),
    );
  }

  /// Prefer the actual list a saved corpus belongs to. Starter content can be
  /// synchronised twice while changing accounts/configurations, producing two
  /// same-named lists with different IDs. Falling back to the first name match
  /// made a valid existing corpus look empty after such a sync.
  VocabularyList _preferredList(List<VocabularyList> lists) {
    final capturedListIds = _samples.map((sample) => sample.listId).toSet();
    for (final list in lists) {
      if (capturedListIds.contains(list.id)) return list;
    }
    return lists.firstWhere(
      (list) => list.name.toLowerCase().contains('nourriture'),
      orElse: () => lists.first,
    );
  }

  Widget _listView(List<VocabularyList> lists, String selectedListId) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: DropdownButtonFormField<String>(
              initialValue: selectedListId,
              decoration: const InputDecoration(
                labelText: 'Liste à enregistrer',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final list in lists)
                  DropdownMenuItem(value: list.id, child: Text(list.name)),
              ],
              onChanged: _selectList,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: FilledButton.icon(
              onPressed: _isBenchmarking
                  ? null
                  : () => _runOpenAiBenchmark(selectedListId),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(_isBenchmarking
                  ? 'Analyse $_benchmarkDone / $_benchmarkTotal'
                  : 'Analyser OpenAI (${_samples.where((s) => s.listId == selectedListId).length} prises)'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: OutlinedButton.icon(
              onPressed: _isBenchmarking
                  ? null
                  : () => _runElevenLabsBenchmark(selectedListId),
              icon: const Icon(Icons.record_voice_over_outlined),
              label: Text(_isBenchmarking
                  ? 'Analyse $_benchmarkDone / $_benchmarkTotal'
                  : 'Analyser ElevenLabs (${_samples.where((s) => s.listId == selectedListId).length} prises)'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Touche un mot : tu enregistres d’abord le français, puis le coréen. Les WAV restent sur ce téléphone de test.',
            ),
          ),
          Expanded(
            child: _ConceptPairs(listId: selectedListId, onTap: _openPair),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: OutlinedButton.icon(
              onPressed: _isBenchmarking
                  ? null
                  : () => _runWhisperBenchmark(selectedListId),
              icon: _isBenchmarking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.analytics_outlined),
              label: Text(_isBenchmarking
                  ? 'Analyse $_benchmarkDone / $_benchmarkTotal'
                  : 'Analyser Whisper (${_samples.where((s) => s.listId == selectedListId).length} prises)'),
            ),
          ),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_message!)),
        ],
      );

  Widget _captureView(_CorpusPair pair) {
    final french = _phase == 0;
    final word = french ? pair.french : pair.korean;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_phase + 1} / 2 · ${french ? 'Français' : 'Coréen'}',
              style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          Text(word,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(french ? pair.korean : pair.french,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.icon(
            onPressed: _toggleRecording,
            icon: Icon(
                _recorder.isRecording ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_recorder.isRecording ? 'Terminer' : 'Enregistrer'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor:
                  _recorder.isRecording ? Colors.red.shade700 : null,
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _ConceptPairs extends ConsumerWidget {
  const _ConceptPairs({required this.listId, required this.onTap});

  final String listId;
  final ValueChanged<_CorpusPair> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concepts = ref.watch(listDetailProvider(listId));
    final state = context.findAncestorStateOfType<_SttLabScreenState>();
    return concepts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Mots indisponibles : $error')),
      data: (items) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: items.length,
        itemBuilder: (context, index) => _ConceptPairRow(
          listId: listId,
          concept: items[index],
          onTap: onTap,
          isComplete: (pair) => state?._isComplete(pair) ?? false,
        ),
      ),
    );
  }
}

class _ConceptPairRow extends ConsumerWidget {
  const _ConceptPairRow({
    required this.listId,
    required this.concept,
    required this.onTap,
    required this.isComplete,
  });

  final String listId;
  final Concept concept;
  final ValueChanged<_CorpusPair> onTap;
  final bool Function(_CorpusPair pair) isComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(variantsProvider(concept.id));
    return variants.when(
      loading: () => const ListTile(title: LinearProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (values) {
        final french = _primary(values, 'fr');
        final korean = _primary(values, 'ko');
        if (french == null || korean == null) return const SizedBox.shrink();
        final pair = _CorpusPair(
          listId: listId,
          conceptId: concept.id,
          french: french.word,
          korean: korean.word,
        );
        final complete = isComplete(pair);
        return Card(
          child: ListTile(
            onTap: () => onTap(pair),
            title: Text(french.word),
            subtitle: Text(korean.word),
            trailing: Icon(
              complete ? Icons.check_circle_rounded : Icons.mic_none_rounded,
              color: complete ? Colors.green : null,
            ),
          ),
        );
      },
    );
  }

  WordVariant? _primary(List<WordVariant> variants, String langCode) {
    final matches = variants.where((variant) => variant.langCode == langCode);
    if (matches.isEmpty) return null;
    return matches.firstWhere(
      (variant) => variant.isPrimary,
      orElse: () => matches.first,
    );
  }
}

class _CorpusPair {
  const _CorpusPair({
    required this.listId,
    required this.conceptId,
    required this.french,
    required this.korean,
  });

  final String listId;
  final String conceptId;
  final String french;
  final String korean;
}
