import 'package:flutter/material.dart';

import '../../../services/speech/stt_corpus_recorder.dart';

/// Debug-only capture surface for building a labelled, real-speaker STT corpus.
class SttLabScreen extends StatefulWidget {
  const SttLabScreen({super.key});

  @override
  State<SttLabScreen> createState() => _SttLabScreenState();
}

class _SttLabScreenState extends State<SttLabScreen> {
  final _recorder = SttCorpusRecorder();
  final _word = TextEditingController(text: 'bonjour');
  var _langCode = 'fr';
  var _samples = const <SttCorpusSample>[];
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _word.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final samples = await _recorder.samples();
    if (mounted) setState(() => _samples = samples);
  }

  Future<void> _toggleRecording() async {
    if (_recorder.isRecording) {
      final sample = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _message = sample == null
            ? 'Aucun enregistrement sauvegardé.'
            : 'Échantillon enregistré : ${sample.word}';
      });
      await _reload();
      return;
    }
    final ok = await _recorder.start(word: _word.text, langCode: _langCode);
    if (!mounted) return;
    setState(() {
      _message = ok
          ? 'Parle naturellement, puis touche Terminer.'
          : 'Micro indisponible ou mot vide.';
    });
  }

  void _changeLanguage(String langCode) {
    setState(() {
      _langCode = langCode;
      _word.text = langCode == 'ko' ? '안녕하세요' : 'bonjour';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Laboratoire STT')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Enregistre ta voix avec le mot affiché. Les WAV 16 kHz et leurs labels restent uniquement sur ce téléphone de test ; ils serviront à mesurer les moteurs et leurs délais.',
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fr', label: Text('Français')),
                ButtonSegment(value: 'ko', label: Text('Coréen')),
              ],
              selected: {_langCode},
              onSelectionChanged: (value) => _changeLanguage(value.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _word,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Mot attendu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_recorder.isRecording
                  ? Icons.stop_rounded
                  : Icons.mic_rounded),
              label: Text(_recorder.isRecording
                  ? 'Terminer et sauvegarder'
                  : 'Enregistrer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor:
                    _recorder.isRecording ? Colors.red.shade700 : null,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 28),
            Text('Échantillons (${_samples.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final sample in _samples)
              ListTile(
                dense: true,
                leading: const Icon(Icons.graphic_eq_rounded),
                title: Text(sample.word),
                subtitle: Text(
                    '${sample.langCode.toUpperCase()} · ${sample.recordedAt.toLocal()}'),
              ),
          ],
        ),
      );
}
