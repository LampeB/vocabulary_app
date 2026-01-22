# VocabApp - Documentation Fonctionnelle

## Présentation Générale

**VocabApp** est une application mobile d'apprentissage de vocabulaire multilingue utilisant la répétition espacée (SRS - Spaced Repetition System). L'application permet de créer des listes de vocabulaire personnalisées, d'écouter la prononciation native via synthèse vocale, et de s'entraîner via des quiz interactifs.

### Public Cible
- Apprenants de langues étrangères
- Étudiants préparant des examens de langue
- Voyageurs souhaitant apprendre des expressions courantes
- Toute personne souhaitant enrichir son vocabulaire

### Langues Supportées
| Code | Langue | Rôle actuel |
|------|--------|-------------|
| fr | Français | Langue source par défaut |
| ko | Coréen | Langue cible par défaut |
| en | Anglais | Supporté |
| es | Espagnol | Supporté |
| ja | Japonais | Supporté |

---

## Module 1 : Gestion des Listes de Vocabulaire

### 1.1 Écran d'Accueil

L'écran d'accueil affiche toutes les listes de vocabulaire de l'utilisateur avec leurs statistiques de progression.

#### Éléments Affichés
Pour chaque liste :
- **Nom de la liste** : Titre personnalisé
- **Paire de langues** : Ex: "FR ↔ KO"
- **Barre de progression** : Visualisation du pourcentage de maîtrise
- **Compteur de mots** : "X / Y mots maîtrisés"
- **Badge de pourcentage** : Ex: "75%"

#### État Vide
Si aucune liste n'existe :
- Message : "Aucune liste de vocabulaire"
- Instruction : "Créez votre première liste pour commencer"
- Bouton d'ajout bien visible

#### Actions Disponibles

| Action | Déclencheur | Description |
|--------|-------------|-------------|
| Créer une liste | Bouton "+" flottant | Ouvre le dialogue de création |
| Ouvrir une liste | Tap sur la liste | Navigue vers le détail |
| Lancer un quiz | Bouton quiz sur la liste | Démarre une session de révision |
| Supprimer une liste | Appui long → Supprimer | Supprime après confirmation |
| Rafraîchir | Pull-to-refresh | Recharge les statistiques |
| Paramètres | Icône engrenage | Accède aux réglages audio |

### 1.2 Création d'une Liste

#### Dialogue de Création
- **Champ** : Nom de la liste (obligatoire)
- **Langues** : Automatiquement FR ↔ KO (par défaut)
- **Boutons** : Annuler / Créer

#### Validation
- Le nom ne peut pas être vide
- Le nom doit être unique (recommandé)

#### Feedback
- Succès : Snackbar "Liste créée !"
- La nouvelle liste apparaît dans la liste

### 1.3 Suppression d'une Liste

#### Processus
1. Appui long sur la liste
2. Confirmation requise : "Supprimer [nom] ? Cette action est irréversible."
3. Si confirmé : suppression en cascade (liste + mots + audio)

#### Données Supprimées
- La liste elle-même
- Tous les concepts/mots associés
- Toutes les variantes de mots
- Tous les fichiers audio générés
- Toutes les données de progression

---

## Module 2 : Gestion des Mots (Concepts)

### 2.1 Écran de Détail de Liste

Affiche tous les mots d'une liste avec leurs traductions et options audio.

#### Éléments Affichés
Pour chaque mot :
- **Catégorie** : Badge coloré (si différent de "general")
- **Mot source** : Ex: "Bonjour" avec code langue "FR"
- **Traduction** : Ex: "안녕하세요" avec code langue "KO"
- **Icône audio** : Si audio disponible, permet la lecture

#### Informations de Liste
Accessible via le bouton info (i) :
- Nom de la liste
- Paire de langues
- Date de création
- Nombre total de mots

### 2.2 Ajout d'un Mot

#### Dialogue d'Ajout
| Champ | Obligatoire | Description |
|-------|-------------|-------------|
| Mot français | Oui | Le mot dans la langue source |
| Mot coréen | Oui | La traduction |
| Catégorie | Non | Classification (défaut: "general") |

#### Catégories Disponibles
- greetings (Salutations)
- food (Nourriture)
- transport (Transport)
- anatomy (Anatomie)
- numbers (Nombres)
- time (Temps)
- colors (Couleurs)
- family (Famille)
- work (Travail)
- hobbies (Loisirs)
- travel (Voyage)
- education (Éducation)
- health (Santé)
- shopping (Achats)
- sports (Sports)

#### Génération Audio Automatique
À l'ajout d'un mot :
1. Le mot est sauvegardé en base
2. Audio généré pour la langue source (FR)
3. Audio généré pour la langue cible (KO)
4. Confirmation : "Mot ajouté avec audio !"

### 2.3 Lecture Audio

#### Fonctionnement
- Tap sur l'icône haut-parleur
- L'audio est joué dans la langue correspondante
- Utilise les paramètres de voix configurés

#### Sources Audio
- **Cache local** : Si déjà généré
- **Génération à la volée** : Si non disponible

### 2.4 Régénération Audio

#### Cas d'Usage
- Changement de voix dans les paramètres
- Audio corrompu ou manquant
- Amélioration de la qualité

#### Processus
1. Appui long sur le mot
2. Sélectionner "Régénérer audio"
3. Confirmation demandée
4. Barre de progression affichée
5. Ancien audio supprimé
6. Nouveau audio généré avec paramètres actuels
7. Confirmation : "X audio(s) régénéré(s) !"

### 2.5 Suppression d'un Mot

#### Processus
1. Glisser vers la gauche sur le mot (ou appui long)
2. Cliquer sur supprimer
3. Confirmation requise
4. Suppression du mot et de tous ses fichiers audio

---

## Module 3 : Quiz - Mode Texte

### 3.1 Démarrage du Quiz

#### Conditions
- La liste doit contenir au moins 1 mot
- Si liste vide, bouton quiz désactivé

#### Configuration Automatique
- **Nombre de questions** : Min(20, nombre de mots disponibles)
- **Sélection** : Algorithme SRS (priorité aux mots à réviser)
- **Direction** : Alternance FR→KO et KO→FR

### 3.2 Déroulement

#### Interface
- Compteur de questions : "1/20"
- Mot à traduire avec icône audio
- Champ de saisie pour la réponse
- Bouton "Vérifier"

#### Flux par Question
1. Question affichée + audio joué automatiquement
2. Utilisateur tape sa réponse
3. Clic sur "Vérifier"
4. Feedback affiché
5. Bouton "Question suivante" apparaît
6. Passage à la question suivante

### 3.3 Validation des Réponses

#### Critères d'Acceptation
| Type | Condition | Feedback |
|------|-----------|----------|
| Exact | Correspondance parfaite | "Parfait !" |
| Proche | Similarité ≥ 85% | "Presque !" |
| Incorrect | Similarité < 85% | "Incorrect. Réponse attendue: ..." |

#### Tolérances
- **Casse** : Ignorée (bonjour = Bonjour = BONJOUR)
- **Accents** : Ignorés (café = cafe)
- **Espaces** : Tolérés (안녕하세요 = 안녕 하세요)

### 3.4 Résultats

#### Écran de Fin
- Score : "X / Y"
- Pourcentage de réussite
- Barre de progression visuelle

#### Feedback Qualitatif
| Score | Message |
|-------|---------|
| ≥ 95% | Excellent ! |
| ≥ 90% | Très bien ! |
| ≥ 85% | Bien ! |
| ≥ 70% | Pas mal |
| ≥ 50% | À réviser |
| < 50% | Incorrect |

---

## Module 4 : Quiz - Mode Vocal

### 4.1 Fonctionnement

Le mode vocal permet de répondre en parlant au lieu de taper.

#### Interface Spécifique
- Bouton microphone en plus du champ texte
- Indicateur "Parlez maintenant..." pendant l'écoute
- Affichage du texte reconnu en temps réel
- Pourcentage de confiance affiché

### 4.2 Reconnaissance Vocale

#### Processus
1. Tap sur le microphone
2. Reconnaissance activée dans la langue cible
3. Utilisateur prononce sa réponse
4. Texte reconnu affiché progressivement
5. Niveau de confiance indiqué

#### Auto-Validation
- Si confiance > 70% : validation automatique
- Si confiance ≤ 70% : validation manuelle requise

### 4.3 Fallback

Si la reconnaissance ne fonctionne pas :
- L'utilisateur peut taper manuellement
- Le quiz continue normalement

---

## Module 5 : Paramètres Audio

### 5.1 Configuration des Voix

#### Voix Disponibles (ElevenLabs)

**Voix Masculines :**
- Adam, Antoni, Arnold, Callum, Clyde
- Daniel, Eric, George, Josh, Thomas

**Voix Féminines :**
- Bella, Charlotte, Domi, Dorothy, Emily
- Elli, Freya, Gigi, Glinda, Grace
- Jessica, Lily, Matilda, Nicole, Rachel, Sarah

#### Recommandations par Langue
| Langue | Voix Recommandées |
|--------|-------------------|
| Français | Adam, Charlotte, Thomas, Bella |
| Coréen | Rachel, Lily, Sarah, Nicole |
| Anglais | Rachel, Josh, Adam, Bella |

### 5.2 Paramètres de Qualité

#### Stabilité (0.0 - 1.0)
- **Bas (0.0-0.3)** : Plus expressif et varié
- **Moyen (0.4-0.6)** : Équilibré
- **Haut (0.7-1.0)** : Plus stable et prévisible

#### Similarité (0.0 - 1.0)
- **Bas (0.0-0.3)** : Plus de liberté créative
- **Moyen (0.4-0.6)** : Équilibré
- **Haut (0.7-1.0)** : Plus proche de la voix originale

### 5.3 Application des Paramètres

#### Important
- Les nouveaux paramètres s'appliquent **uniquement aux nouveaux mots**
- Les mots existants conservent leur audio
- Pour mettre à jour : utiliser "Régénérer audio" sur chaque mot

### 5.4 Réinitialisation

Remet tous les paramètres aux valeurs par défaut :
- Français : Adam
- Coréen : Rachel
- Anglais : Rachel
- Stabilité : 0.50
- Similarité : 0.75

---

## Module 6 : Système de Répétition Espacée (SRS)

### 6.1 Principe

Le SRS optimise l'apprentissage en espaçant les révisions de manière croissante pour les mots maîtrisés, et en intensifiant les révisions pour les mots difficiles.

### 6.2 Calcul de la Maîtrise

```
Maîtrise = Réponses correctes / Total des présentations
```

#### Seuils
- **Mot maîtrisé** : Maîtrise ≥ 70%
- **Mot à réviser** : Maîtrise < 70%

### 6.3 Intervalles de Révision

| Niveau | Intervalle de Base |
|--------|-------------------|
| 1 | 1 jour |
| 2 | 3 jours |
| 3 | 7 jours |
| 4 | 14 jours |
| 5 | 30 jours |
| 6 | 90 jours |

#### Ajustement
L'intervalle est modulé par le niveau de maîtrise :
```
Intervalle réel = Intervalle base × (0.5 + maîtrise × 0.5)
```

### 6.4 Priorisation dans les Quiz

#### Score de Priorité
```
Priorité = (1 - maîtrise) × 10 + jours_en_retard × 2
```

#### Sélection des Questions
1. Mots en retard de révision (priorité haute)
2. Mots avec faible maîtrise
3. Nouveaux mots (max 5 par session)

### 6.5 Mise à Jour après Quiz

Après chaque réponse :
- Compteur de présentations incrémenté
- Compteur de réponses correctes mis à jour (si correct)
- Maîtrise recalculée
- Date de prochaine révision mise à jour

---

## Module 7 : Statistiques et Progression

### 7.1 Statistiques par Liste

Affichées sur l'écran d'accueil :
- Nombre de mots maîtrisés / total
- Pourcentage de progression
- Visualisation par barre de progression

### 7.2 Statistiques de Quiz

Affichées après chaque quiz :
- Score de la session
- Pourcentage de réussite
- Feedback qualitatif

### 7.3 Persistance

Toutes les données sont sauvegardées localement :
- Progression par mot
- Dates de révision
- Historique (implicite via compteurs)

---

## Glossaire

| Terme | Définition |
|-------|------------|
| **Concept** | Un mot avec toutes ses variantes dans différentes langues |
| **Variante** | Une forme spécifique d'un mot dans une langue |
| **Maîtrise** | Pourcentage de réponses correctes pour un mot |
| **SRS** | Spaced Repetition System - système de révision espacée |
| **TTS** | Text-to-Speech - synthèse vocale |
| **STT** | Speech-to-Text - reconnaissance vocale |

---

*Documentation générée le 21/01/2026*
