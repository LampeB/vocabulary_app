import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/vocabulary_list.dart';
import '../models/word_variant.dart';
import '../models/variant_progress.dart';
import '../services/database/database_service.dart';
import '../services/audio/audio_player_service.dart';
import '../services/speech/speech_recognition_service.dart';
import '../utils/answer_validator.dart';
import '../utils/srs_algorithm.dart';
import '../config/constants.dart';

class QuizScreen extends StatefulWidget {
  final VocabularyList list;
  final int questionCount;

  const QuizScreen({
    super.key,
    required this.list,
    this.questionCount = 20,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final DatabaseService _db = DatabaseService();
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final TextEditingController _answerController = TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  bool _hasAnswered = false;
  ValidationResult? _lastResult;

  // STT states
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _listeningStatus = '';
  double _confidence = 0.0;
  int _listenRetryCount = 0;
  Timer? _listenTimer;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    // Audio initialization is lazy - done on first play via _ensureInitialized()
    _initializeSpeech();
    print('🎮 QuizScreen initialisé');
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _answerController.dispose();
    _audioPlayer.dispose();
    _speechService.dispose();
    print('🎮 QuizScreen disposed');
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechService.initialize();
    setState(() {
      _isSpeechAvailable = available;
    });

    if (available) {
      print('✅ Reconnaissance vocale disponible');
    } else {
      print('❌ Reconnaissance vocale non disponible');
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    try {
      final concepts = await _db.getConceptsByListId(widget.list.id);

      if (concepts.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Aucun mot à réviser dans cette liste')),
          );
        }
        return;
      }

      final questions = <Map<String, dynamic>>[];

      for (var concept in concepts) {
        final variants = await _db.getVariantsByConceptId(concept['id']);

        final lang1Variants = variants
            .where((v) => v['lang_code'] == widget.list.lang1Code)
            .toList();
        final lang2Variants = variants
            .where((v) => v['lang_code'] == widget.list.lang2Code)
            .toList();

        if (lang1Variants.isNotEmpty && lang2Variants.isNotEmpty) {
          questions.add({
            'questionVariant': WordVariant.fromMap(lang1Variants.first),
            'answerVariants':
                lang2Variants.map((v) => WordVariant.fromMap(v)).toList(),
            'direction': 'lang1_to_lang2',
            'conceptId': concept['id'],
            'answerLangCode': widget.list.lang2Code, // Pour STT
          });

          questions.add({
            'questionVariant': WordVariant.fromMap(lang2Variants.first),
            'answerVariants':
                lang1Variants.map((v) => WordVariant.fromMap(v)).toList(),
            'direction': 'lang2_to_lang1',
            'conceptId': concept['id'],
            'answerLangCode': widget.list.lang1Code, // Pour STT
          });
        }
      }

      questions.shuffle(Random());
      final selectedQuestions = questions.take(widget.questionCount).toList();

      setState(() {
        _questions = selectedQuestions;
        _isLoading = false;
      });

      print('✅ ${_questions.length} questions chargées');

      // Jouer automatiquement le premier mot
      if (_questions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _playQuestionAudio();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _playQuestionAudio() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      return;
    }

    final question = _questions[_currentQuestionIndex];
    final questionVariant = question['questionVariant'] as WordVariant;
    final direction = question['direction'] as String;

    // Déterminer la langue de la question
    final questionLangCode = direction == 'lang1_to_lang2'
        ? widget.list.lang1Code
        : widget.list.lang2Code;

    await _audioPlayer.playAudioSmart(
      audioHash: questionVariant.audioHash,
      text: questionVariant.word,
      langCode: questionLangCode,
    );
  }

  // 🎤 Démarrer la reconnaissance vocale
  Future<void> _startListening() async {
    if (!_isSpeechAvailable) {
      // Try re-initializing in case permission was granted after first attempt
      final available = await _speechService.initialize();
      if (!available) {
        _showSnackBar('Reconnaissance vocale non disponible. Vérifiez les permissions du micro dans les paramètres.', Colors.red);
        return;
      }
      setState(() {
        _isSpeechAvailable = true;
      });
    }

    if (_hasAnswered) return;

    final question = _questions[_currentQuestionIndex];
    final answerLangCode = question['answerLangCode'] as String;

    setState(() {
      _isListening = true;
      _listeningStatus = 'Parlez maintenant...';
      _confidence = 0.0;
      _listenRetryCount = 0;
    });

    final success = await _speechService.startListening(
      langCode: answerLangCode,
      onResult: (text) {
        print('🎤 Texte reconnu: "$text"');
        _listenTimer?.cancel();

        setState(() {
          _answerController.text = text;
          _isListening = false;
          _listeningStatus = '';
        });

        // Validation automatique si confiance élevée
        if (_confidence > 0.7) {
          print('✅ Confiance élevée ($_confidence), validation auto');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasAnswered) {
              _checkAnswer();
            }
          });
        }
      },
      onConfidence: (confidence) {
        setState(() {
          _confidence = confidence;
        });
      },
    );

    if (success) {
      print('🔍 startListening réussi, démarrage du timer...');
      _startListenTimer();
      print('🔍 Timer démarré');
    }

    if (!success) {
      setState(() {
        _isListening = false;
        _listeningStatus = '';
      });
      final errorMsg = _speechService.lastError;
      _showSnackBar(
        errorMsg != null
          ? 'Erreur micro: $errorMsg'
          : 'Erreur lors du démarrage du micro. Vérifiez que la permission microphone est accordée.',
        Colors.red,
      );
    }
  }

  void _startListenTimer() {
    _listenTimer?.cancel();
    // Timer slightly longer than pauseFor (2s) + buffer
    // The STT will timeout after ~2-5s of silence
    _listenTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _hasAnswered || !_isListening) return;
      print('⏱️ Timer expiré, pas de résultat reçu');
      _listenRetryCount++;
      setState(() {
        _listeningStatus = 'Pas compris, nouvelle écoute... (×$_listenRetryCount)';
      });
      _restartListening();
    });
  }

  void _stopListening() async {
    _listenTimer?.cancel();
    await _speechService.stopListening();
    setState(() {
      _isListening = false;
      _listeningStatus = '';
    });
  }

  Future<void> _restartListening() async {
    if (!mounted || _hasAnswered) return;

    final question = _questions[_currentQuestionIndex];
    final answerLangCode = question['answerLangCode'] as String;

    setState(() {
      _listeningStatus = 'Écoute en cours... (×$_listenRetryCount)';
    });

    await _speechService.startListening(
      langCode: answerLangCode,
      onResult: (text) {
        print('🎤 Texte reconnu: "$text"');
        _listenTimer?.cancel();
        setState(() {
          _answerController.text = text;
          _isListening = false;
          _listeningStatus = '';
        });
        if (_confidence > 0.7) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasAnswered) {
              _checkAnswer();
            }
          });
        }
      },
      onConfidence: (confidence) {
        setState(() {
          _confidence = confidence;
        });
      },
    );

    _startListenTimer();
  }

  void _showSnackBar(String message, Color? backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkAnswer() {
    if (_hasAnswered) return;

    final question = _questions[_currentQuestionIndex];
    final answerVariants = question['answerVariants'] as List<WordVariant>;

    final expectedAnswers = answerVariants
        .map((v) => {
              'word': v.word,
              'register_tag': v.registerTag,
            })
        .toList();

    final result = AnswerValidator.validate(
      userAnswer: _answerController.text,
      expectedAnswers: expectedAnswers,
      strictRegister: false,
    );

    setState(() {
      _lastResult = result;
      _hasAnswered = true;
      if (result.isCorrect) {
        _correctCount++;
      }
    });

    _updateProgress(question, result.isCorrect);
  }

  Future<void> _updateProgress(
      Map<String, dynamic> question, bool wasCorrect) async {
    final questionVariant = question['questionVariant'] as WordVariant;
    final direction = question['direction'] as String;

    var progress = await _db.getProgressByVariantAndDirection(
      questionVariant.id,
      direction,
    );

    if (progress == null) {
      final newProgress = VariantProgress(
        id: const Uuid().v4(),
        variantId: questionVariant.id,
        direction: direction,
      );
      await _db.insertVariantProgress(newProgress.toMap());
      progress = newProgress.toMap();
    }

    final timesShown = (progress['times_shown_as_answer'] ?? 0) + 1;
    final timesCorrect = wasCorrect
        ? (progress['times_answered_correctly'] ?? 0) + 1
        : (progress['times_answered_correctly'] ?? 0);

    final masteryLevel = SRSAlgorithm.calculateMasteryLevel(
      timesCorrect: timesCorrect,
      timesShown: timesShown,
    );

    final nextReview = SRSAlgorithm.calculateNextReviewDate(
      masteryLevel: masteryLevel,
      timesCorrect: timesCorrect,
      wasCorrect: wasCorrect,
    );

    await _db.updateVariantProgress(progress['id'], {
      'times_shown_as_answer': timesShown,
      'times_answered_correctly': timesCorrect,
      'last_seen_date': DateTime.now().toIso8601String(),
      'next_review_date': nextReview.toIso8601String(),
      'mastery_level': masteryLevel,
      'is_known': masteryLevel >= AppConstants.masteryThreshold ? 1 : 0,
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answerController.clear();
        _hasAnswered = false;
        _lastResult = null;
        _confidence = 0.0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playQuestionAudio();
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final percentage = (_correctCount / _questions.length * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Quiz terminé !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_correctCount / ${_questions.length}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% de réussite',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _correctCount / _questions.length,
              minHeight: 8,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(
          child: Text('Aucune question disponible'),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final questionVariant = question['questionVariant'] as WordVariant;
    final answerVariants = question['answerVariants'] as List<WordVariant>;
    final direction = question['direction'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz - ${widget.list.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              minHeight: 4,
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                direction == 'lang1_to_lang2'
                    ? '${widget.list.lang1Code.toUpperCase()} → ${widget.list.lang2Code.toUpperCase()}'
                    : '${widget.list.lang2Code.toUpperCase()} → ${widget.list.lang1Code.toUpperCase()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 48),

            Text(
              'Traduisez :',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),

            // Question avec bouton audio
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    questionVariant.word,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Semantics(
                  label: 'quiz_audio',
                  child: IconButton(
                    key: const Key('quiz_audio_button'),
                    icon: const Icon(Icons.volume_up),
                    iconSize: 32,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _playQuestionAudio,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Champ de réponse avec bouton micro
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    enabled: !_hasAnswered && !_isListening,
                    decoration: InputDecoration(
                      labelText: 'Votre réponse',
                      border: const OutlineInputBorder(),
                      suffixIcon: _hasAnswered
                          ? Icon(
                              _lastResult?.isCorrect == true
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _lastResult?.isCorrect == true
                                  ? Colors.green
                                  : Colors.red,
                            )
                          : null,
                    ),
                    autofocus: true,
                    onSubmitted: (_) =>
                        _hasAnswered ? _nextQuestion() : _checkAnswer(),
                  ),
                ),
                const SizedBox(width: 8),

                // 🎤 BOUTON MICRO - toujours affiché
                Tooltip(
                  message: _isSpeechAvailable
                      ? (_isListening ? 'Arrêter l\'écoute' : 'Répondre par la voix')
                      : 'Micro non disponible\n(testez sur un appareil physique)',
                  child: IconButton(
                    key: const Key('mic_button'),
                    icon: Icon(
                      _isListening
                          ? Icons.mic
                          : (_isSpeechAvailable ? Icons.mic_none : Icons.mic_off),
                      size: 32,
                    ),
                    color: _isListening
                        ? Colors.red
                        : (_isSpeechAvailable
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    onPressed: !_isSpeechAvailable || _hasAnswered
                        ? null
                        : (_isListening ? _stopListening : _startListening),
                    style: IconButton.styleFrom(
                      backgroundColor: _isListening
                          ? Colors.red.withValues(alpha: 0.1)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            // Statut écoute ou message d'aide
            if (_isListening) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _listeningStatus,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _listenRetryCount > 0 ? Colors.orange : Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ),
            ] else if (!_isSpeechAvailable && !_hasAnswered) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Micro non disponible sur émulateur. Utilisez un appareil physique pour la saisie vocale.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (_hasAnswered && _lastResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastResult!.isCorrect
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastResult!.isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult!.isCorrect
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _lastResult!.isCorrect
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _lastResult!.isCorrect ? 'Correct !' : 'Incorrect',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _lastResult!.isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    if (!_lastResult!.isCorrect) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Réponse(s) correcte(s) :',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        answerVariants.map((v) => v.word).join(', '),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const Spacer(),

            FilledButton.icon(
              onPressed: _hasAnswered ? _nextQuestion : _checkAnswer,
              icon: Icon(_hasAnswered ? Icons.arrow_forward : Icons.check),
              label: Text(_hasAnswered ? 'Suivant' : 'Valider'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Score : $_correctCount / ${_currentQuestionIndex + (_hasAnswered ? 1 : 0)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
