# VocabApp - Propositions d'Améliorations

Ce document propose des améliorations fonctionnelles et techniques pour chaque module de l'application, classées par priorité.

---

## Légende des Priorités

| Priorité | Description | Effort |
|----------|-------------|--------|
| 🔴 **Critique** | Bug ou manque bloquant | Variable |
| 🟠 **Haute** | Amélioration importante UX/performance | Moyen |
| 🟡 **Moyenne** | Nice-to-have significatif | Moyen |
| 🟢 **Basse** | Amélioration mineure | Faible |

---

## Module 1 : Gestion des Listes

### Améliorations Fonctionnelles

#### 🟠 1.1 Personnalisation des langues par liste
**Situation actuelle** : Toutes les listes sont FR ↔ KO par défaut.

**Proposition** : Permettre de choisir les langues à la création.
```
Dialogue de création :
- Nom de la liste : [___________]
- Langue source : [Français ▼]
- Langue cible : [Coréen ▼]
```

**Bénéfice** : Supporter l'apprentissage de n'importe quelle paire de langues.

---

#### 🟡 1.2 Recherche et filtrage des listes
**Situation actuelle** : Pas de recherche possible.

**Proposition** :
- Barre de recherche en haut de l'écran
- Filtres : par langue, par progression, par date

**Bénéfice** : Retrouver rapidement une liste parmi plusieurs.

---

#### 🟡 1.3 Organisation en dossiers/tags
**Situation actuelle** : Liste plate sans organisation.

**Proposition** :
- Tags colorés assignables aux listes
- Filtrage par tag
- Option de groupement

**Bénéfice** : Meilleure organisation pour utilisateurs avancés.

---

#### 🟢 1.4 Import/Export de listes
**Situation actuelle** : Pas possible de partager ses listes.

**Proposition** :
- Export en CSV/JSON
- Import depuis fichier
- Partage via QR code ou lien

**Bénéfice** : Partage entre apprenants, sauvegarde externe.

---

### Améliorations Techniques

#### 🟠 1.5 Pagination des listes
**Situation actuelle** : Toutes les listes chargées en mémoire.

**Proposition** :
```dart
Future<List<VocabularyList>> getLists({
  int limit = 20,
  int offset = 0,
}) async {
  return await db.query(
    'vocabulary_lists',
    limit: limit,
    offset: offset,
    orderBy: 'created_at DESC',
  );
}
```

**Bénéfice** : Performance avec de nombreuses listes.

---

#### 🟢 1.6 Cache des statistiques
**Situation actuelle** : Statistiques recalculées à chaque affichage.

**Proposition** :
- Table `list_stats_cache` avec last_updated
- Invalidation au changement de progression
- Rafraîchissement en background

**Bénéfice** : Affichage instantané de l'écran d'accueil.

---

## Module 2 : Gestion des Mots

### Améliorations Fonctionnelles

#### 🔴 2.1 Édition des mots existants
**Situation actuelle** : Impossible de modifier un mot après création.

**Proposition** :
- Tap sur un mot ouvre un dialogue d'édition
- Modification du texte, catégorie, etc.
- Option de régénérer l'audio si le texte change

**Bénéfice** : Corriger les erreurs sans supprimer/recréer.

---

#### 🟠 2.2 Ajout par lot (bulk import)
**Situation actuelle** : Ajout un mot à la fois.

**Proposition** :
- Import depuis CSV/Excel
- Zone de texte multi-lignes (un mot par ligne)
- Format : `mot_source;traduction;catégorie`

**Bénéfice** : Création rapide de listes volumineuses.

---

#### 🟠 2.3 Synonymes et variantes multiples
**Situation actuelle** : Un seul mot source et une seule traduction.

**Proposition** :
- Plusieurs variantes acceptées par langue
- Ex: "Bonjour" → "안녕하세요", "안녕"
- Toutes les variantes valides en quiz

**Bénéfice** : Meilleure couverture linguistique.

---

#### 🟡 2.4 Images et exemples
**Situation actuelle** : Champs prévus mais non utilisés (imageUrl, exampleSentence).

**Proposition** :
- Upload d'image depuis galerie ou URL
- Champs exemples dans le dialogue d'ajout
- Affichage enrichi dans le détail

**Bénéfice** : Mémorisation visuelle et contextuelle.

---

#### 🟡 2.5 Détection de doublons
**Situation actuelle** : Possibilité d'ajouter le même mot plusieurs fois.

**Proposition** :
- Vérification à l'ajout
- Avertissement : "Ce mot existe déjà. Ajouter quand même ?"
- Suggestion de fusion

**Bénéfice** : Éviter les doublons accidentels.

---

### Améliorations Techniques

#### 🟠 2.6 Génération audio asynchrone
**Situation actuelle** : L'UI attend la fin de la génération audio.

**Proposition** :
```dart
// Sauvegarder le mot immédiatement
await conceptRepository.create(concept);

// Générer l'audio en background
_audioGenerationQueue.add(() async {
  await audioService.generateForConcept(concept);
  _notifyAudioReady(concept.id);
});
```

**Bénéfice** : Ajout instantané, audio disponible progressivement.

---

#### 🟡 2.7 Compression audio
**Situation actuelle** : Fichiers MP3 stockés tels quels.

**Proposition** :
- Compression à 64kbps pour la voix (suffisant)
- Réduction de ~50% de l'espace
- Option qualité haute/basse dans settings

**Bénéfice** : Réduction de l'espace disque.

---

#### 🟢 2.8 Préchargement audio intelligent
**Situation actuelle** : Audio chargé à la demande.

**Proposition** :
- Précharger les 5 prochains audios en quiz
- Cache LRU pour les audios récemment joués

**Bénéfice** : Lecture sans latence.

---

## Module 3 : Quiz Mode Texte

### Améliorations Fonctionnelles

#### 🟠 3.1 Modes de quiz variés
**Situation actuelle** : Un seul mode (traduction).

**Proposition** :
- **Traduction** : Mode actuel
- **QCM** : Choix parmi 4 réponses
- **Association** : Relier mots et traductions
- **Écriture** : Écrire le mot entendu

**Bénéfice** : Variété pour maintenir l'engagement.

---

#### 🟠 3.2 Configuration du quiz
**Situation actuelle** : Configuration fixe (20 questions).

**Proposition** :
```
Écran de configuration :
- Nombre de questions : [10] [20] [50] [Tout]
- Direction : [FR→KO] [KO→FR] [Les deux]
- Inclure : [Nouveaux] [À réviser] [Tous]
- Catégories : [Tout] [Sélection...]
```

**Bénéfice** : Quiz adaptés aux besoins.

---

#### 🟡 3.3 Indices progressifs
**Situation actuelle** : Aucun indice disponible.

**Proposition** :
- Bouton "Indice" (pénalité sur le score)
- Indice 1 : Première lettre
- Indice 2 : Nombre de caractères
- Indice 3 : Catégorie

**Bénéfice** : Aide sans révéler la réponse complète.

---

#### 🟡 3.4 Mode révision des erreurs
**Situation actuelle** : Pas de récap des erreurs.

**Proposition** :
- Écran de fin avec liste des erreurs
- Bouton "Réviser les erreurs" pour quiz ciblé
- Export des erreurs pour étude

**Bénéfice** : Focus sur les points faibles.

---

#### 🟢 3.5 Streak et motivation
**Situation actuelle** : Pas de gamification.

**Proposition** :
- Compteur de série quotidienne
- Badges d'accomplissement
- Objectifs journaliers

**Bénéfice** : Motivation à pratiquer régulièrement.

---

### Améliorations Techniques

#### 🟠 3.6 Validation côté serveur (optionnel)
**Situation actuelle** : Validation 100% locale.

**Proposition** :
- Option de validation via API pour cas complexes
- Utilisation de modèle linguistique pour synonymes
- Fallback local si hors ligne

**Bénéfice** : Validation plus intelligente.

---

#### 🟡 3.7 Analytics de session
**Situation actuelle** : Seuls les compteurs basiques sont stockés.

**Proposition** :
```dart
class QuizSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int questionsCount;
  final int correctCount;
  final List<QuestionResult> results;
  final Duration averageResponseTime;
}
```

**Bénéfice** : Analyse des patterns d'apprentissage.

---

## Module 4 : Quiz Mode Vocal

### Améliorations Fonctionnelles

#### 🟠 4.1 Feedback de prononciation
**Situation actuelle** : Juste validation texte reconnu.

**Proposition** :
- Analyse phonétique de la prononciation
- Score de prononciation (pas juste correct/incorrect)
- Mise en évidence des phonèmes problématiques

**Bénéfice** : Amélioration de l'oral.

---

#### 🟡 4.2 Mode conversation
**Situation actuelle** : Questions isolées.

**Proposition** :
- Dialogues contextuels (A: Bonjour ! B: ?)
- Scénarios de conversation
- Réponses attendues multiples

**Bénéfice** : Pratique plus naturelle.

---

#### 🟡 4.3 Calibration du micro
**Situation actuelle** : Pas de calibration.

**Proposition** :
- Écran de test du micro au premier usage
- Ajustement automatique du seuil
- Indication du niveau sonore

**Bénéfice** : Meilleure reconnaissance.

---

### Améliorations Techniques

#### 🔴 4.4 Gestion des erreurs de reconnaissance
**Situation actuelle** : Erreurs silencieuses parfois.

**Proposition** :
```dart
try {
  await speechService.startListening(...);
} on SpeechRecognitionException catch (e) {
  if (e.code == 'no_match') {
    _showRetryDialog('Aucune parole détectée');
  } else if (e.code == 'audio_error') {
    _showMicrophoneHelp();
  }
}
```

**Bénéfice** : UX claire en cas de problème.

---

#### 🟡 4.5 Support multi-moteurs STT
**Situation actuelle** : speech_to_text uniquement.

**Proposition** :
- Fallback vers Google Cloud Speech
- Option Whisper (OpenAI) pour meilleure qualité
- Détection automatique du meilleur moteur

**Bénéfice** : Meilleure reconnaissance selon le contexte.

---

## Module 5 : Paramètres Audio

### Améliorations Fonctionnelles

#### 🟡 5.1 Prévisualisation des voix
**Situation actuelle** : Pas d'écoute avant sélection.

**Proposition** :
- Bouton "Écouter" à côté de chaque voix
- Phrase d'exemple dans la langue
- Comparaison avant/après changement

**Bénéfice** : Choix éclairé de la voix.

---

#### 🟡 5.2 Profils de paramètres
**Situation actuelle** : Un seul jeu de paramètres.

**Proposition** :
- Sauvegarder des profils nommés
- Ex: "Naturel", "Clair pour débutant", "Rapide"
- Changement rapide de profil

**Bénéfice** : Adaptation selon le contexte.

---

#### 🟢 5.3 Vitesse de lecture
**Situation actuelle** : Vitesse fixe.

**Proposition** :
- Slider de vitesse (0.5x à 2.0x)
- Applicable globalement ou par langue
- Option "ralentir pour les nouveaux mots"

**Bénéfice** : Adaptation au niveau.

---

### Améliorations Techniques

#### 🟠 5.4 Migration des paramètres audio
**Situation actuelle** : Nouveaux paramètres ignorent les anciens mots.

**Proposition** :
- Détection des mots avec anciens paramètres
- Proposition de régénération groupée
- Barre de progression pour migration

**Bénéfice** : Cohérence audio dans la liste.

---

#### 🟢 5.5 Fallback TTS natif
**Situation actuelle** : ElevenLabs ou rien.

**Proposition** :
```dart
Future<AudioResult> generateAudio(String text, String lang) async {
  try {
    return await elevenLabsService.generate(text, lang);
  } catch (e) {
    // Fallback sur TTS Flutter natif
    return await flutterTtsService.generate(text, lang);
  }
}
```

**Bénéfice** : Audio toujours disponible hors ligne.

---

## Module 6 : Système SRS

### Améliorations Fonctionnelles

#### 🟠 6.1 Visualisation de la progression
**Situation actuelle** : Juste le pourcentage global.

**Proposition** :
- Graphique d'évolution dans le temps
- Heatmap des révisions (style GitHub)
- Prédiction de maîtrise

**Bénéfice** : Motivation et visibilité.

---

#### 🟡 6.2 Ajustement manuel de la maîtrise
**Situation actuelle** : Maîtrise uniquement par quiz.

**Proposition** :
- Marquer un mot comme "connu" manuellement
- Réinitialiser la progression d'un mot
- "Je connais déjà ce mot" à l'ajout

**Bénéfice** : Flexibilité pour mots déjà connus.

---

#### 🟢 6.3 Objectifs personnalisés
**Situation actuelle** : Pas d'objectifs.

**Proposition** :
- Définir un objectif : "Maîtriser 100 mots d'ici le 01/03"
- Calcul du rythme nécessaire
- Rappels si en retard

**Bénéfice** : Apprentissage structuré.

---

### Améliorations Techniques

#### 🟠 6.4 Algorithme SM-2 complet
**Situation actuelle** : SRS simplifié.

**Proposition** :
Implémenter l'algorithme SuperMemo SM-2 complet :
```dart
class SM2Algorithm {
  static const double defaultEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;

  static SM2Result calculate({
    required int quality, // 0-5
    required int repetitions,
    required double easeFactor,
    required int interval,
  }) {
    double newEF = easeFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

    newEF = max(minEaseFactor, newEF);

    int newInterval;
    int newReps;

    if (quality < 3) {
      newReps = 0;
      newInterval = 1;
    } else {
      newReps = repetitions + 1;
      if (newReps == 1) {
        newInterval = 1;
      } else if (newReps == 2) {
        newInterval = 6;
      } else {
        newInterval = (interval * newEF).round();
      }
    }

    return SM2Result(
      interval: newInterval,
      repetitions: newReps,
      easeFactor: newEF,
    );
  }
}
```

**Bénéfice** : Révisions optimisées scientifiquement.

---

#### 🟡 6.5 Sync multi-appareils
**Situation actuelle** : Données locales uniquement.

**Proposition** :
- Backend pour synchronisation
- Authentification utilisateur
- Résolution de conflits

**Bénéfice** : Continuité sur plusieurs appareils.

---

## Module 7 : Tests & Qualité

### Améliorations Techniques

#### 🔴 7.1 Tests unitaires
**Situation actuelle** : Très peu de tests.

**Proposition** :
- Tests pour chaque Repository
- Tests pour les algorithmes (SRS, Validation)
- Coverage > 80%

```dart
// Exemple
test('SRS calculates correct next review date', () {
  final result = SRSAlgorithm.calculateNextReview(
    wasCorrect: true,
    masteryLevel: 0.8,
    currentInterval: 7,
  );
  expect(result.difference(DateTime.now()).inDays, greaterThan(10));
});
```

**Bénéfice** : Confiance dans le code.

---

#### 🟠 7.2 Tests d'intégration
**Situation actuelle** : Tests E2E Appium uniquement.

**Proposition** :
- Tests d'intégration Flutter (integration_test/)
- Tests des flux complets sans UI
- Tests de la couche service

**Bénéfice** : Détection précoce des bugs.

---

#### 🟠 7.3 CI/CD Pipeline
**Situation actuelle** : Pas de CI.

**Proposition** :
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter build apk --debug
```

**Bénéfice** : Qualité maintenue automatiquement.

---

#### 🟡 7.4 Monitoring des erreurs
**Situation actuelle** : Pas de tracking des crashs.

**Proposition** :
- Intégration Sentry ou Firebase Crashlytics
- Logs structurés
- Alertes sur erreurs critiques

**Bénéfice** : Détection proactive des problèmes.

---

## Module 8 : UX/UI

### Améliorations Fonctionnelles

#### 🟠 8.1 Mode sombre
**Situation actuelle** : Thème clair uniquement (selon système).

**Proposition** :
- Toggle manuel clair/sombre/système
- Persistance du choix
- Thème cohérent sur tous les écrans

**Bénéfice** : Confort visuel.

---

#### 🟡 8.2 Onboarding
**Situation actuelle** : Pas d'introduction.

**Proposition** :
- Tutoriel au premier lancement
- Explication des fonctionnalités clés
- Option de skip

**Bénéfice** : Prise en main facilitée.

---

#### 🟡 8.3 Accessibilité
**Situation actuelle** : Accessibilité basique.

**Proposition** :
- Semantics complets sur tous les widgets
- Support lecteur d'écran
- Tailles de police ajustables
- Contraste suffisant

**Bénéfice** : App utilisable par tous.

---

#### 🟢 8.4 Animations et transitions
**Situation actuelle** : Transitions basiques.

**Proposition** :
- Animations de feedback (réponse correcte/incorrecte)
- Transitions fluides entre écrans
- Micro-interactions engageantes

**Bénéfice** : Expérience plus agréable.

---

## Récapitulatif par Priorité

### 🔴 Critiques (À faire rapidement)
1. Édition des mots existants
2. Gestion des erreurs de reconnaissance vocale
3. Tests unitaires

### 🟠 Haute Priorité
1. Personnalisation des langues
2. Ajout par lot
3. Modes de quiz variés
4. Configuration du quiz
5. Feedback de prononciation
6. Génération audio asynchrone
7. Visualisation de la progression
8. Pagination des listes
9. Tests d'intégration
10. CI/CD Pipeline
11. Mode sombre

### 🟡 Moyenne Priorité
1. Recherche et filtrage
2. Organisation en dossiers
3. Synonymes et variantes
4. Images et exemples
5. Indices progressifs
6. Mode révision des erreurs
7. Prévisualisation des voix
8. Algorithme SM-2 complet
9. Analytics de session
10. Onboarding
11. Accessibilité

### 🟢 Basse Priorité
1. Import/Export de listes
2. Cache des statistiques
3. Streak et gamification
4. Vitesse de lecture
5. Animations

---

## Roadmap Suggérée

### Phase 1 : Fondations (1-2 mois)
- [ ] Édition des mots
- [ ] Tests unitaires
- [ ] CI/CD
- [ ] Gestion erreurs STT

### Phase 2 : Core Features (2-3 mois)
- [ ] Personnalisation des langues
- [ ] Modes de quiz variés
- [ ] Configuration du quiz
- [ ] Visualisation progression

### Phase 3 : Polish (1-2 mois)
- [ ] Mode sombre
- [ ] Onboarding
- [ ] Prévisualisation voix
- [ ] Animations

### Phase 4 : Avancé (optionnel)
- [ ] Sync multi-appareils
- [ ] Import/Export
- [ ] Feedback prononciation

---

*Document généré le 21/01/2026*
