import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/stt/near_miss_prompts.dart';
import '../../../services/speech/stt_corpus_recorder.dart';

/// Records near-miss takes for the STT bake-off (2026-10-03): a participant
/// reads each word once; every take is labelled with what was said, the card
/// answer it stands in for, the speaker and the room condition. Takes stay in
/// the app sandbox (same manifest as the corpus lab) until extracted over adb.
///
/// Participants may not speak French, so a Korean session talks Korean.
class NearMissSessionScreen extends StatefulWidget {
  const NearMissSessionScreen({
    super.key,
    this.recorder,
    this.takeDuration = const Duration(seconds: 3),
  });

  /// How long each take records (shortened in tests).
  final Duration takeDuration;

  /// Injected in tests; the real one opens the microphone.
  final SttCorpusRecorder? recorder;

  @override
  State<NearMissSessionScreen> createState() => _NearMissSessionScreenState();
}

class _Copy {
  const _Copy(this.ko, this.fr);
  final String ko;
  final String fr;
  String of(String lang) => lang == 'ko' ? ko : fr;
}

const _instruction = _Copy(
  '버튼을 누르고, 화면의 단어를 평소처럼 한 번 읽어 주세요. 뜻이 없는 단어도 있어요.',
  'Appuie sur le bouton, puis lis le mot une fois, naturellement. '
      'Certains mots n\'existent pas, c\'est voulu.',
);
const _recordLabel = _Copy('녹음 (3초)', 'Enregistrer (3 s)');
const _recordingLabel = _Copy('녹음 중…', 'Enregistrement…');
const _redoLabel = _Copy('이전 단어 다시', 'Refaire le précédent');
const _skipLabel = _Copy('건너뛰기', 'Passer');
const _doneLabel = _Copy('끝! 감사합니다 🙏', 'Terminé, merci !');
const _consent = _Copy(
  '녹음은 이 앱의 음성 인식 테스트에만 사용됩니다.',
  'Les enregistrements servent uniquement à tester la reconnaissance vocale '
      'de l\'app.',
);

class _NearMissSessionScreenState extends State<NearMissSessionScreen>
    with SingleTickerProviderStateMixin {
  late final SttCorpusRecorder _recorder =
      widget.recorder ?? SttCorpusRecorder();
  final _speaker = TextEditingController();
  late final AnimationController _bar =
      AnimationController(vsync: this, duration: widget.takeDuration);

  String _lang = 'ko';
  String _condition = 'calme';
  List<NearMissPrompt>? _prompts; // null = setup screen
  int _index = 0;
  bool _recording = false;
  String? _error;
  List<NearMissProgress> _progress = const [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  /// Who has recorded what so far — read from the local corpus manifest.
  Future<void> _loadProgress() async {
    final samples = await _recorder.samples();
    if (!mounted) return;
    setState(() {
      _progress = nearMissProgress([
        for (final s in samples)
          (word: s.word, langCode: s.langCode, meta: s.meta, at: s.recordedAt),
      ]);
    });
  }

  void _resume(NearMissProgress row) {
    _speaker.text = row.speaker;
    _lang = row.langCode;
    if (row.condition.isNotEmpty) _condition = row.condition;
    _begin();
  }

  @override
  void dispose() {
    _bar.dispose();
    _speaker.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    final speaker = _speaker.text.trim();
    if (speaker.isEmpty) return;
    final prompts = nearMissPromptsFor(_lang, speaker);
    // Resume where this participant stopped (same language + condition).
    final done = (await _recorder.samples())
        .where((s) =>
            s.meta['speaker'] == speaker &&
            s.meta['condition'] == _condition &&
            s.langCode == _lang)
        .map((s) => s.word)
        .toSet();
    final first = prompts.indexWhere((p) => !done.contains(p.spoken));
    setState(() {
      _prompts = prompts;
      _index = first < 0 ? prompts.length : first;
      _error = null;
    });
  }

  Future<void> _record() async {
    final prompts = _prompts!;
    if (_recording || _index >= prompts.length) return;
    final p = prompts[_index];
    final ok = await _recorder.start(
      word: p.spoken,
      langCode: p.langCode,
      listId: 'near-miss',
      conceptId: p.expected,
      meta: {
        'speaker': _speaker.text.trim(),
        'expected': p.expected,
        'kind': p.kind,
        'condition': _condition,
      },
    );
    if (!ok) {
      setState(() => _error = 'Micro indisponible (permission ?)');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _recording = true;
      _error = null;
    });
    unawaited(_bar.forward(from: 0)); // visual only
    await Future<void>.delayed(widget.takeDuration);
    final saved = await _recorder.stop();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (saved == null) {
        _error = 'Prise non sauvegardée — refais ce mot.';
      } else {
        _index++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _prompts;
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture de mots')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: prompts == null ? _setup() : _session(prompts),
        ),
      ),
    );
  }

  Widget _setup() {
    return ListView(
      children: [
        const Text(
            'Un participant par séance. Le nom sert à retrouver ses prises '
            '(P1, P2… suffit).'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('near_miss_speaker'),
          controller: _speaker,
          decoration:
              const InputDecoration(labelText: 'Participant', hintText: 'P1'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ko', label: Text('한국어')),
            ButtonSegment(value: 'fr', label: Text('Français')),
          ],
          selected: {_lang},
          onSelectionChanged: (v) => setState(() => _lang = v.first),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'calme', label: Text('Calme')),
            ButtonSegment(value: 'bruit', label: Text('Bruit')),
          ],
          selected: {_condition},
          onSelectionChanged: (v) => setState(() => _condition = v.first),
        ),
        const SizedBox(height: 12),
        Text('${nearMissPromptsFor(_lang, 'x').length} mots'),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _speaker.text.trim().isEmpty ? null : _begin,
          child: const Text('Commencer'),
        ),
        const SizedBox(height: 32),
        _ProgressBoard(rows: _progress, onResume: _resume),
      ],
    );
  }

  Widget _session(List<NearMissPrompt> prompts) {
    final theme = Theme.of(context);
    if (_index >= prompts.length) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_doneLabel.of(_lang),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              setState(() {
                _prompts = null;
                _speaker.clear();
              });
              _loadProgress();
            },
            child: const Text('Participant suivant'),
          ),
        ],
      );
    }
    final p = prompts[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${_index + 1} / ${prompts.length}',
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(_instruction.of(_lang), textAlign: TextAlign.center),
        Expanded(
          child: Center(
            child: FittedBox(
              child: Text(
                p.spoken,
                key: const ValueKey('near_miss_word'),
                style: theme.textTheme.displayLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _bar,
          builder: (_, __) => LinearProgressIndicator(
            value: _recording ? _bar.value : 0,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: FilledButton.icon(
            key: const ValueKey('near_miss_record'),
            onPressed: _recording ? null : _record,
            icon: Icon(_recording ? Icons.graphic_eq : Icons.mic_rounded),
            label: Text(
              (_recording ? _recordingLabel : _recordLabel).of(_lang),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _recording || _index == 0
                    ? null
                    : () => setState(() => _index--),
                child: Text(_redoLabel.of(_lang)),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _recording ? null : () => setState(() => _index++),
                child: Text(_skipLabel.of(_lang)),
              ),
            ),
          ],
        ),
        if (_error != null)
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
        Text(_consent.of(_lang),
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Who took part and how far each got. Tapping a row resumes that session.
class _ProgressBoard extends StatelessWidget {
  const _ProgressBoard({required this.rows, required this.onResume});

  final List<NearMissProgress> rows;
  final ValueChanged<NearMissProgress> onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Text('Aucun participant pour l\'instant.',
          style: theme.textTheme.bodyMedium);
    }
    final people = rows.map((r) => r.speaker).toSet().length;
    final complete = rows.where((r) => r.complete).length;
    final takes = rows.fold<int>(0, (n, r) => n + r.done);
    return Column(
      key: const ValueKey('near_miss_board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Participants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            '${_n(people, 'personne')} · ${_n(complete, 'séance complète', 'séances complètes')} · '
            '${_n(takes, 'mot enregistré', 'mots enregistrés')}'),
        const SizedBox(height: 8),
        for (final r in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: r.complete ? null : () => onResume(r),
            leading: Icon(
              r.complete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: r.complete ? Colors.green.shade600 : null,
            ),
            title: Text('${r.speaker} · '
                '${r.langCode == 'ko' ? '한국어' : 'Français'}'
                '${r.condition.isEmpty ? '' : ' · ${r.condition}'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: r.total == 0 ? 0 : r.done / r.total),
                const SizedBox(height: 4),
                Text('${r.done} / ${r.total} · dernière prise '
                    '${TimeOfDay.fromDateTime(r.lastTakeAt.toLocal()).format(context)}'
                    '${r.complete ? '' : ' · toucher pour reprendre'}'),
              ],
            ),
          ),
      ],
    );
  }
}

String _n(int n, String one, [String? many]) =>
    '$n ${n <= 1 ? one : (many ?? '${one}s')}';
