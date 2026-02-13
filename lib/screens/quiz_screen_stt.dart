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
import '../services/audio/sound_effects_service.dart';
import '../services/audio/local_audio_service.dart';
import '../utils/answer_validator.dart';
import '../utils/srs_algorithm.dart';
import '../config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
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

  // Hands-free voice mode
  bool _isHandsFreeMode = false;
  bool _isHandsFreeProcessing = false;
  int _handsFreeConsecutiveFailures = 0;
  static const int _maxHandsFreeFailures = 5;
  int _handsFreeWordAttempts = 0;
  static const int _maxWordAttempts = 3;
  static const String _handsFreeKey = 'quiz_hands_free_mode';
  static const String _correctAnswerPhrase = 'La réponse correcte était';
  String? _correctAnswerPhraseHash;
  final SoundEffectsService _soundEffects = SoundEffectsService();

  // STT language availability
  bool _sttLanguagesChecked = false;

  // Driving UI animations
  late final AnimationController _flashController;
  late final AnimationController _micPulseController;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _flashColor = null);
        }
      });
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadQuestions();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _listenTimer?.cancel();
    _flashController.dispose();
    _micPulseController.dispose();
    _answerController.dispose();
    _audioPlayer.dispose();
    _speechService.dispose();
    _soundEffects.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechService.initialize();
    setState(() {
      _isSpeechAvailable = available;
    });

    if (available) {
      // When listening stops (pauseFor/listenFor), process partial text if available
      _speechService.onListeningDone = () {
        if (!mounted || _hasAnswered) return;
        if (_isListening && _answerController.text.isNotEmpty) {
          _listenTimer?.cancel();
          setState(() {
            _isListening = false;
            _listeningStatus = '';
          });
          if (_isHandsFreeMode) {
            _handsFreeConsecutiveFailures = 0;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && !_hasAnswered) {
                _handleHandsFreeResult();
              }
            });
          }
        }
      };

      final prefs = await SharedPreferences.getInstance();
      final drivingMode = prefs.getBool('driving_mode_enabled') ?? false;
      final savedPref = prefs.getBool(_handsFreeKey) ?? false;
      if (mounted && (savedPref || drivingMode)) {
        setState(() {
          _isHandsFreeMode = true;
        });
        if (_questions.isNotEmpty && !_isLoading) {
          _startHandsFreeCycle();
        }
      }
    }

    // Pre-generate the "correct answer was" phrase with ElevenLabs
    try {
      final audioService = LocalAudioService();
      final result = await audioService.getOrGenerateAudio(
        text: _correctAnswerPhrase,
        langCode: 'fr',
      );
      _correctAnswerPhraseHash = result.hash;
    } catch (_) {
      // If generation fails, playAudioSmartAndWait will fall back to system TTS
      _correctAnswerPhraseHash = null;
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
            'answerLangCode': widget.list.lang2Code,
          });

          questions.add({
            'questionVariant': WordVariant.fromMap(lang2Variants.first),
            'answerVariants':
                lang1Variants.map((v) => WordVariant.fromMap(v)).toList(),
            'direction': 'lang2_to_lang1',
            'conceptId': concept['id'],
            'answerLangCode': widget.list.lang1Code,
          });
        }
      }

      questions.shuffle(Random());
      final selectedQuestions = questions.take(widget.questionCount).toList();

      setState(() {
        _questions = selectedQuestions;
        _isLoading = false;
      });

      if (_questions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isHandsFreeMode) {
            _startHandsFreeCycle();
          } else {
            _playQuestionAudio();
          }
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

    final questionLangCode = direction == 'lang1_to_lang2'
        ? widget.list.lang1Code
        : widget.list.lang2Code;

    await _audioPlayer.playAudioSmart(
      audioHash: questionVariant.audioHash,
      text: questionVariant.word,
      langCode: questionLangCode,
    );
  }

  Future<void> _startListening() async {
    if (!_isSpeechAvailable) {
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
        _listenTimer?.cancel();

        setState(() {
          _answerController.text = text;
          _isListening = false;
          _listeningStatus = '';
        });

        if (_isHandsFreeMode) {
          _handsFreeConsecutiveFailures = 0; // mic is working
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasAnswered) {
              _handleHandsFreeResult();
            }
          });
        } else if (_confidence > 0.7) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasAnswered) {
              _checkAnswer();
            }
          });
        }
      },
      onPartialResult: (text) {
        setState(() {
          _answerController.text = text;
        });
      },
      onConfidence: (confidence) {
        setState(() {
          _confidence = confidence;
        });
      },
    );

    if (success) {
      _startListenTimer();
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
    final timeout = _isHandsFreeMode ? 15 : 4;
    _listenTimer = Timer(Duration(seconds: timeout), () {
      if (!mounted || _hasAnswered) return;
      _listenRetryCount++;

      if (_isHandsFreeMode) {
        _speechService.stopListening();
        setState(() {
          _isListening = false;
          _listeningStatus = '';
        });

        if (_answerController.text.isNotEmpty) {
          // We have partial text — try to validate it
          _handleHandsFreeResult();
        } else {
          // Truly nothing heard
          _handsFreeConsecutiveFailures++;
          if (_handsFreeConsecutiveFailures >= _maxHandsFreeFailures) {
            setState(() {
              _isHandsFreeMode = false;
            });
            _showSnackBar(
              'Mode mains libres en pause (micro non détecté). Réactivez-le quand vous êtes prêt.',
              Colors.orange,
            );
            return;
          }
          // Force submit empty = wrong
          _checkAnswer();
        }
        return;
      }

      // Normal mode: just stop listening — user taps mic again if needed
      _speechService.stopListening();
      setState(() {
        _isListening = false;
        _listeningStatus = '';
      });
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

  void _showSnackBar(String message, Color? backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkAnswer() async {
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

    if (_isHandsFreeMode) {
      _onHandsFreeAnswerChecked(result.isCorrect);
    } else {
      // Play sound effect in normal mode (no correction phrase)
      if (result.isCorrect) {
        await _soundEffects.playCorrect();
      } else {
        await _soundEffects.playIncorrect();
      }
    }
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
        if (_isHandsFreeMode) {
          _startHandsFreeCycle();
        } else {
          _playQuestionAudio();
        }
      });
    } else {
      if (_isHandsFreeMode) {
        _stopListening();
      }
      _showResults();
    }
  }

  // ═══════════════════════════════════════════════════
  // HANDS-FREE VOICE MODE
  // ═══════════════════════════════════════════════════

  Future<void> _toggleHandsFreeMode() async {
    if (!_isSpeechAvailable) {
      _showSnackBar(
        'Le mode mains libres nécessite la reconnaissance vocale.',
        Colors.orange,
      );
      return;
    }

    final newValue = !_isHandsFreeMode;
    setState(() {
      _isHandsFreeMode = newValue;
      _handsFreeConsecutiveFailures = 0;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_handsFreeKey, newValue);

    if (newValue && !_hasAnswered && !_isListening) {
      _startHandsFreeCycle();
    } else if (!newValue && _isListening) {
      _stopListening();
    }
  }

  /// Check STT availability for answer languages. If a language is missing,
  /// prompt the user to install it or filter out those questions.
  Future<void> _checkSttLanguages() async {
    if (_sttLanguagesChecked || !_isSpeechAvailable) return;
    _sttLanguagesChecked = true;

    // Collect answer language codes used in current questions
    final answerLangs = _questions
        .map((q) => q['answerLangCode'] as String)
        .toSet();

    final missingLangs = <String>[];
    for (final lang in answerLangs) {
      final available = await _speechService.isLanguageAvailable(lang);
      if (!available) missingLangs.add(lang);
    }

    if (missingLangs.isEmpty || !mounted) return;

    final langNames = missingLangs
        .map((l) => AppConstants.languageNames[l] ?? l)
        .join(', ');

    // Get available locales for diagnostic display
    final availableLocales = await _speechService.getAvailableLanguages();
    final localesSummary = availableLocales.take(20).join(', ');

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Langue vocale manquante'),
        content: Text(
          'La reconnaissance vocale pour $langNames n\'est pas disponible.\n\n'
          'Langues STT installées : $localesSummary\n\n'
          'Pour installer la langue manquante :\n'
          'Google app → Paramètres → Voix → Reconnaissance vocale hors connexion\n\n'
          'Voulez-vous ouvrir les paramètres ou continuer sans $langNames ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('Continuer sans'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'install'),
            child: const Text('Installer'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'install') {
      await SpeechRecognitionService.openVoiceInputSettings();
      // Reset the flag so we re-check when user comes back
      _sttLanguagesChecked = false;
      return;
    }

    // "skip" — filter out questions requiring the missing language
    setState(() {
      _questions.removeWhere(
        (q) => missingLangs.contains(q['answerLangCode']),
      );
      // Reset index in case current question was removed
      if (_currentQuestionIndex >= _questions.length) {
        _currentQuestionIndex = 0;
      }
    });

    if (_questions.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune question disponible avec les langues vocales installées')),
        );
      }
    }
  }

  Future<void> _startHandsFreeCycle() async {
    if (!_isHandsFreeMode || !mounted || _isHandsFreeProcessing) return;

    _isHandsFreeProcessing = true;
    _handsFreeWordAttempts = 0;

    try {
      await _checkSttLanguages();
      if (!mounted || !_isHandsFreeMode || _questions.isEmpty) return;

      await _playQuestionAudioAndWait();

      if (!mounted || !_isHandsFreeMode) return;

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted || !_isHandsFreeMode || _hasAnswered) return;

      await _startListening();
    } finally {
      _isHandsFreeProcessing = false;
    }
  }

  Future<void> _playQuestionAudioAndWait() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;

    final question = _questions[_currentQuestionIndex];
    final questionVariant = question['questionVariant'] as WordVariant;
    final direction = question['direction'] as String;

    final questionLangCode = direction == 'lang1_to_lang2'
        ? widget.list.lang1Code
        : widget.list.lang2Code;

    await _audioPlayer.playAudioSmartAndWait(
      audioHash: questionVariant.audioHash,
      text: questionVariant.word,
      langCode: questionLangCode,
    );
  }

  Future<void> _handleHandsFreeResult() async {
    if (_hasAnswered) return;

    final question = _questions[_currentQuestionIndex];
    final answerVariants = question['answerVariants'] as List<WordVariant>;
    final expectedAnswers = answerVariants
        .map((v) => {'word': v.word, 'register_tag': v.registerTag})
        .toList();

    final result = AnswerValidator.validate(
      userAnswer: _answerController.text,
      expectedAnswers: expectedAnswers,
      strictRegister: false,
    );

    if (result.isCorrect) {
      // Correct — commit and advance
      _checkAnswer();
    } else {
      _handsFreeWordAttempts++;
      if (_handsFreeWordAttempts >= _maxWordAttempts) {
        // 3 wrong attempts — commit as wrong and advance
        _checkAnswer();
      } else {
        // Wrong but retries left — buzz, flash, and restart listening
        _triggerFlash(Colors.red);
        await _soundEffects.playIncorrect();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _isHandsFreeMode && !_hasAnswered) {
          setState(() {
            _answerController.clear();
            _listeningStatus = 'Essayez encore... ($_handsFreeWordAttempts/$_maxWordAttempts)';
          });
          await _startListening();
        }
      }
    }
  }

  Future<void> _onHandsFreeAnswerChecked(bool isCorrect) async {
    _triggerFlash(isCorrect ? Colors.green : Colors.red);
    if (isCorrect) {
      _handsFreeConsecutiveFailures = 0;
      await _soundEffects.playCorrect();
    } else {
      await _soundEffects.playIncorrect();

      // Speak the correct answer so the user learns from the mistake
      final question = _questions[_currentQuestionIndex];
      final answerVariants = question['answerVariants'] as List<WordVariant>;
      final answerLangCode = question['answerLangCode'] as String;
      final primaryAnswer = answerVariants.first;

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && _isHandsFreeMode) {
        // Speak "la réponse correcte était" phrase
        await _audioPlayer.playAudioSmartAndWait(
          audioHash: _correctAnswerPhraseHash,
          text: _correctAnswerPhrase,
          langCode: 'fr',
        );

        // Then speak the correct answer word
        if (mounted && _isHandsFreeMode) {
          await _audioPlayer.playAudioSmartAndWait(
            audioHash: primaryAnswer.audioHash,
            text: primaryAnswer.word,
            langCode: answerLangCode,
          );
        }
      }
    }

    await Future.delayed(
      const Duration(milliseconds: AppConstants.feedbackDisplayDuration),
    );

    if (!mounted || !_isHandsFreeMode) return;

    _nextQuestion();
  }

  void _triggerFlash(Color color) {
    setState(() => _flashColor = color);
    _flashController.forward(from: 0.0);
  }

  Future<void> _showResults() async {
    final percentage = (_correctCount / _questions.length * 100).round();

    if (!mounted) return;

    // Show dialog first, then announce via TTS (so the user sees the result immediately)
    final shouldSpeak = _isHandsFreeMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const Key('quiz_results_dialog'),
        title: const Text('Quiz terminé !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_correctCount / ${_questions.length}',
              key: const Key('quiz_score'),
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
            key: const Key('finish_quiz_button'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    // Announce score via TTS after dialog is visible
    if (shouldSpeak && mounted) {
      _audioPlayer.playAudioSmartAndWait(
        text: 'Quiz terminé. $_correctCount sur ${_questions.length} correct. $percentage pourcent.',
        langCode: 'fr',
      );
    }
  }

  // ═══════════════════════════════════════════════════
  // SIMPLIFIED DRIVING UI
  // ═══════════════════════════════════════════════════

  Widget _buildDrivingUI(WordVariant questionVariant, List<WordVariant> answerVariants) {
    return Scaffold(
      key: const Key('quiz_screen'),
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top bar: close + progress + exit driving
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                        tooltip: 'Quitter le quiz',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentQuestionIndex + 1} / ${_questions.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('hands_free_toggle'),
                        icon: const Icon(Icons.headset_off, color: Colors.white70, size: 28),
                        tooltip: 'Quitter mode conduite',
                        onPressed: _toggleHandsFreeMode,
                      ),
                    ],
                  ),
                ),

                // Score
                Text(
                  'Score : $_correctCount / ${_currentQuestionIndex + (_hasAnswered ? 1 : 0)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 16),
                ),

                const Spacer(flex: 2),

                // Question word — large and centered
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    questionVariant.word,
                    key: const Key('quiz_question_word'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Correct answer (shown when wrong) or recognized text
                if (_hasAnswered && _lastResult != null && !_lastResult!.isCorrect)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      answerVariants.map((v) => v.word).join(', '),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_answerController.text.isNotEmpty && !_hasAnswered)
                  Text(
                    _answerController.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const Spacer(flex: 2),

                // Mic icon with pulse animation
                AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (context, child) {
                    final scale = _isListening
                        ? 1.0 + (_micPulseController.value * 0.3)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 52,
                          color: _isListening ? Colors.red : Colors.white38,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Listening status
                SizedBox(
                  height: 24,
                  child: _listeningStatus.isNotEmpty
                      ? Text(
                          _listeningStatus,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),

          // Flash overlay (green/red)
          if (_flashColor != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flashController,
                  builder: (context, child) {
                    final opacity = (1.0 - _flashController.value) * 0.4;
                    return Container(
                      color: _flashColor!.withValues(alpha: opacity),
                    );
                  },
                ),
              ),
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

    if (_isHandsFreeMode) {
      return _buildDrivingUI(questionVariant, answerVariants);
    }

    return Scaffold(
      key: const Key('quiz_screen'),
      appBar: AppBar(
        title: Text('Quiz - ${widget.list.name}'),
        actions: [
          if (_isSpeechAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: IconButton.filled(
                key: const Key('hands_free_toggle'),
                icon: Icon(
                  _isHandsFreeMode ? Icons.headset_mic : Icons.headset_off,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _isHandsFreeMode
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: _isHandsFreeMode
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  minimumSize: const Size(48, 48),
                ),
                tooltip: _isHandsFreeMode
                    ? 'Désactiver mode mains libres'
                    : 'Activer mode mains libres',
                onPressed: _toggleHandsFreeMode,
              ),
            ),
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
            if (_isHandsFreeMode) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headset_mic, size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      'Mode mains libres',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    questionVariant.word,
                    key: const Key('quiz_question_word'),
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

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('quiz_answer_field'),
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
                    autofocus: !_isHandsFreeMode,
                    onSubmitted: (_) =>
                        _hasAnswered ? _nextQuestion() : _checkAnswer(),
                  ),
                ),
                const SizedBox(width: 8),

                IconButton(
                  key: const Key('mic_button'),
                  tooltip: _isSpeechAvailable
                      ? (_isListening ? 'Arrêter l\'écoute' : 'Répondre par la voix')
                      : 'Micro non disponible (testez sur un appareil physique)',
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
              ],
            ),

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
                key: Key(_lastResult!.isCorrect ? 'correct_feedback' : 'incorrect_feedback'),
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
              key: Key(_hasAnswered ? 'next_question_button' : 'submit_answer_button'),
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
