import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../models/vocabulary_list.dart';
import '../models/word_variant.dart';
import '../models/variant_progress.dart';
import '../services/database/database_service.dart';
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
  final TextEditingController _answerController = TextEditingController();
  
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  bool _hasAnswered = false;
  ValidationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    try {
      // Récupérer tous les concepts de la liste
      final concepts = await _db.getConceptsByListId(widget.list.id);
      
      if (concepts.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun mot à réviser dans cette liste')),
          );
        }
        return;
      }

      // Créer les questions à partir des concepts
      final questions = <Map<String, dynamic>>[];
      
      for (var concept in concepts) {
        // Récupérer les variantes
        final variants = await _db.getVariantsByConceptId(concept['id']);
        
        final lang1Variants = variants.where((v) => v['lang_code'] == widget.list.lang1Code).toList();
        final lang2Variants = variants.where((v) => v['lang_code'] == widget.list.lang2Code).toList();
        
        if (lang1Variants.isNotEmpty && lang2Variants.isNotEmpty) {
          // Question FR → KO
          questions.add({
            'questionVariant': WordVariant.fromMap(lang1Variants.first),
            'answerVariants': lang2Variants.map((v) => WordVariant.fromMap(v)).toList(),
            'direction': 'lang1_to_lang2',
            'conceptId': concept['id'],
          });
          
          // Question KO → FR
          questions.add({
            'questionVariant': WordVariant.fromMap(lang2Variants.first),
            'answerVariants': lang1Variants.map((v) => WordVariant.fromMap(v)).toList(),
            'direction': 'lang2_to_lang1',
            'conceptId': concept['id'],
          });
        }
      }

      // Mélanger et limiter
      questions.shuffle(Random());
      final selectedQuestions = questions.take(widget.questionCount).toList();

      setState(() {
        _questions = selectedQuestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _checkAnswer() {
    if (_hasAnswered) return;

    final question = _questions[_currentQuestionIndex];
    final answerVariants = question['answerVariants'] as List<WordVariant>;
    
    // Préparer les réponses attendues
    final expectedAnswers = answerVariants.map((v) => {
      'word': v.word,
      'register_tag': v.registerTag,
    }).toList();

    // Valider la réponse
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

    // Mettre à jour la progression
    _updateProgress(question, result.isCorrect);
  }

  Future<void> _updateProgress(Map<String, dynamic> question, bool wasCorrect) async {
    final questionVariant = question['questionVariant'] as WordVariant;
    final direction = question['direction'] as String;

    // Récupérer ou créer la progression
    var progress = await _db.getProgressByVariantAndDirection(
      questionVariant.id,
      direction,
    );

    if (progress == null) {
      // Créer une nouvelle progression
      final newProgress = VariantProgress(
        id: const Uuid().v4(),
        variantId: questionVariant.id,
        direction: direction,
      );
      await _db.insertVariantProgress(newProgress.toMap());
      progress = newProgress.toMap();
    }

    // Mettre à jour les stats
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

    // Sauvegarder
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
              Navigator.pop(context); // Fermer le dialogue
              Navigator.pop(context); // Retour à l'écran précédent
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
            // Progression
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              minHeight: 4,
            ),
            const SizedBox(height: 32),
            
            // Direction
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
            
            // Question
            Text(
              'Traduisez :',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              questionVariant.word,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // Champ de réponse
            TextField(
              controller: _answerController,
              enabled: !_hasAnswered,
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
              onSubmitted: (_) => _hasAnswered ? _nextQuestion() : _checkAnswer(),
            ),
            
            const SizedBox(height: 16),
            
            // Feedback
            if (_hasAnswered && _lastResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastResult!.isCorrect 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
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
                          _lastResult!.isCorrect ? Icons.check_circle : Icons.cancel,
                          color: _lastResult!.isCorrect ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _lastResult!.isCorrect ? 'Correct !' : 'Incorrect',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _lastResult!.isCorrect ? Colors.green : Colors.red,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            const Spacer(),
            
            // Bouton
            FilledButton.icon(
              onPressed: _hasAnswered ? _nextQuestion : _checkAnswer,
              icon: Icon(_hasAnswered ? Icons.arrow_forward : Icons.check),
              label: Text(_hasAnswered ? 'Suivant' : 'Valider'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Score
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
