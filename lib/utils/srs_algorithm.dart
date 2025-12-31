import '../config/constants.dart';

/// Algorithme de répétition espacée (SRS - Spaced Repetition System)
/// Basé sur les principes de l'apprentissage espacé optimal
class SRSAlgorithm {
  /// Calcule la prochaine date de révision pour une variante
  /// 
  /// Paramètres:
  /// - [masteryLevel]: Niveau de maîtrise actuel (0.0 à 1.0)
  /// - [timesCorrect]: Nombre de fois répondu correctement de suite
  /// - [wasCorrect]: La dernière réponse était-elle correcte?
  /// - [lastReviewDate]: Date de la dernière révision
  /// 
  /// Retourne: La prochaine date de révision
  static DateTime calculateNextReviewDate({
    required double masteryLevel,
    required int timesCorrect,
    required bool wasCorrect,
    DateTime? lastReviewDate,
  }) {
    final now = lastReviewDate ?? DateTime.now();
    
    // Si la réponse était fausse, réviser demain
    if (!wasCorrect) {
      return now.add(const Duration(days: 1));
    }

    // Déterminer l'intervalle en fonction du nombre de réussites consécutives
    int intervalDays;
    
    if (timesCorrect >= AppConstants.srsIntervals.length) {
      // Si on a dépassé tous les intervalles, utiliser le dernier (90 jours)
      intervalDays = AppConstants.srsIntervals.last;
    } else {
      // Sinon, utiliser l'intervalle correspondant au nombre de réussites
      intervalDays = AppConstants.srsIntervals[timesCorrect];
    }

    // Ajuster l'intervalle en fonction du niveau de maîtrise
    // Plus le niveau est élevé, plus on peut espacer
    final adjustedInterval = (intervalDays * (0.5 + masteryLevel * 0.5)).round();
    
    return now.add(Duration(days: adjustedInterval));
  }

  /// Calcule le niveau de maîtrise d'une variante
  /// 
  /// Paramètres:
  /// - [timesCorrect]: Nombre de fois répondu correctement
  /// - [timesShown]: Nombre de fois présenté
  /// 
  /// Retourne: Niveau de maîtrise (0.0 à 1.0)
  static double calculateMasteryLevel({
    required int timesCorrect,
    required int timesShown,
  }) {
    if (timesShown == 0) return 0.0;
    return (timesCorrect / timesShown).clamp(0.0, 1.0);
  }

  /// Détermine si un mot est considéré comme "connu"
  /// 
  /// Paramètres:
  /// - [masteryLevel]: Niveau de maîtrise (0.0 à 1.0)
  /// 
  /// Retourne: true si le mot est connu
  static bool isWordKnown(double masteryLevel) {
    return masteryLevel >= AppConstants.masteryThreshold;
  }

  /// Calcule la priorité d'une variante pour la révision
  /// Plus le score est élevé, plus la variante devrait être révisée en priorité
  /// 
  /// Paramètres:
  /// - [masteryLevel]: Niveau de maîtrise (0.0 à 1.0)
  /// - [nextReviewDate]: Prochaine date de révision prévue
  /// - [now]: Date actuelle (optionnel)
  /// 
  /// Retourne: Score de priorité (plus élevé = plus prioritaire)
  static double calculateReviewPriority({
    required double masteryLevel,
    required DateTime nextReviewDate,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    
    // Nombre de jours de retard (négatif si en avance)
    final daysOverdue = currentTime.difference(nextReviewDate).inDays;
    
    // Score de base: mots moins maîtrisés = plus prioritaires
    final masteryScore = (1.0 - masteryLevel) * 10;
    
    // Score de retard: mots en retard = plus prioritaires
    final overdueScore = daysOverdue > 0 ? daysOverdue * 2.0 : 0.0;
    
    return masteryScore + overdueScore;
  }

  /// Sélectionne les variantes à réviser pour une session
  /// 
  /// Paramètres:
  /// - [allVariants]: Liste de toutes les variantes disponibles avec leur progression
  /// - [sessionSize]: Nombre de variantes à sélectionner
  /// - [includeNewWords]: Inclure des mots jamais vus?
  /// - [maxNewWords]: Nombre maximum de nouveaux mots
  /// 
  /// Retourne: Liste triée des variantes à réviser (IDs)
  static List<String> selectVariantsForReview({
    required List<Map<String, dynamic>> allVariants,
    required int sessionSize,
    bool includeNewWords = true,
    int maxNewWords = AppConstants.newWordsPerSession,
  }) {
    final now = DateTime.now();
    
    // Séparer les mots jamais vus et ceux déjà vus
    final newWords = <Map<String, dynamic>>[];
    final reviewWords = <Map<String, dynamic>>[];
    
    for (var variant in allVariants) {
      final timesShown = variant['times_shown_as_answer'] ?? 0;
      final nextReview = variant['next_review_date'] != null
          ? DateTime.parse(variant['next_review_date'] as String)
          : now;
      
      if (timesShown == 0) {
        newWords.add(variant);
      } else if (nextReview.isBefore(now) || nextReview.isAtSameMomentAs(now)) {
        reviewWords.add(variant);
      }
    }

    // Calculer les priorités pour les mots de révision
    final prioritizedReviews = reviewWords.map((variant) {
      final masteryLevel = variant['mastery_level'] ?? 0.0;
      final nextReview = DateTime.parse(variant['next_review_date'] as String);
      
      return {
        'variant_id': variant['variant_id'],
        'priority': calculateReviewPriority(
          masteryLevel: masteryLevel,
          nextReviewDate: nextReview,
          now: now,
        ),
      };
    }).toList();

    // Trier par priorité décroissante
    prioritizedReviews.sort((a, b) => 
      (b['priority'] as double).compareTo(a['priority'] as double)
    );

    // Construire la liste finale
    final selectedIds = <String>[];
    
    // Ajouter les révisions (prioritaires)
    final numReviews = (sessionSize - (includeNewWords ? maxNewWords : 0))
        .clamp(0, prioritizedReviews.length);
    
    for (var i = 0; i < numReviews; i++) {
      selectedIds.add(prioritizedReviews[i]['variant_id'] as String);
    }

    // Ajouter des nouveaux mots si demandé
    if (includeNewWords) {
      final numNew = (sessionSize - selectedIds.length).clamp(0, maxNewWords);
      final actualNew = numNew.clamp(0, newWords.length);
      
      for (var i = 0; i < actualNew; i++) {
        selectedIds.add(newWords[i]['variant_id'] as String);
      }
    }

    return selectedIds;
  }

  /// Calcule les statistiques globales de progression
  /// 
  /// Paramètres:
  /// - [allProgress]: Liste de toutes les progressions
  /// 
  /// Retourne: Map avec les statistiques
  static Map<String, dynamic> calculateGlobalStats(
    List<Map<String, dynamic>> allProgress,
  ) {
    if (allProgress.isEmpty) {
      return {
        'totalWords': 0,
        'knownWords': 0,
        'averageMastery': 0.0,
        'dueForReview': 0,
        'percentKnown': 0.0,
      };
    }

    final now = DateTime.now();
    int knownCount = 0;
    int dueCount = 0;
    double totalMastery = 0.0;

    for (var progress in allProgress) {
      final isKnown = (progress['is_known'] ?? 0) == 1;
      final masteryLevel = progress['mastery_level'] ?? 0.0;
      final nextReview = progress['next_review_date'] != null
          ? DateTime.parse(progress['next_review_date'] as String)
          : now;

      if (isKnown) knownCount++;
      if (nextReview.isBefore(now) || nextReview.isAtSameMomentAs(now)) dueCount++;
      totalMastery += masteryLevel;
    }

    final avgMastery = totalMastery / allProgress.length;
    final percentKnown = (knownCount / allProgress.length * 100);

    return {
      'totalWords': allProgress.length,
      'knownWords': knownCount,
      'averageMastery': avgMastery,
      'dueForReview': dueCount,
      'percentKnown': percentKnown,
    };
  }
}
