# État des Lieux - VocabApp

> Application Flutter d'apprentissage de vocabulaire multilingue
> Date d'analyse : 21 janvier 2026

---

## 1. Vue d'Ensemble

**VocabApp** est une application Flutter cross-platform dédiée à l'apprentissage du vocabulaire avec :
- Support multilingue (Français, Coréen, Anglais, Espagnol, Japonais)
- Algorithme de répétition espacée (SRS)
- Synthèse vocale premium (ElevenLabs)
- Reconnaissance vocale intégrée
- Mode quiz texte et vocal

---

## 2. Structure du Projet

```
vocabulary_app/
├── lib/                          # Code source principal
│   ├── main.dart                 # Point d'entrée
│   ├── screens/                  # 5 écrans UI
│   ├── models/                   # 5 modèles de données
│   ├── services/                 # Services (database, audio, speech)
│   ├── config/                   # Configuration
│   └── utils/                    # Utilitaires
├── test/                         # Tests unitaires
├── integration_test/             # Tests d'intégration
├── appium-tests/                 # Tests E2E (Appium)
├── android/, ios/, windows/...   # Code plateforme
├── assets/                       # Ressources statiques
└── audio/                        # Fichiers audio générés
```

### Métriques du Code

| Catégorie | Lignes | % |
|-----------|--------|---|
| Écrans | 2 494 | 65% |
| Utilitaires | 438 | 11% |
| Modèles | 426 | 11% |
| Config | 292 | 8% |
| Services | ~800 | - |
| **Total** | **~3 800** | - |

---

## 3. Architecture Technique

### 3.1 Pattern d'Architecture

```
┌─────────────────────────────────┐
│     Presentation (Screens)      │  ← StatefulWidgets
├─────────────────────────────────┤
│     Services (Audio, Speech)    │  ← Singletons
├─────────────────────────────────┤
│     Repositories (CRUD)         │  ← Pattern Repository
├─────────────────────────────────┤
│     Models (Data Classes)       │  ← toMap/fromMap
├─────────────────────────────────┤
│     Database (SQLite)           │  ← sqflite + FFI
└─────────────────────────────────┘
```

### 3.2 Gestion d'État
- **Provider** (`provider: ^6.1.0`) pour l'état global
- **StatefulWidget** pour l'état local des écrans
- **Singleton** pour les services (DatabaseService, AudioPlayerService)

### 3.3 Modes de Déploiement
| Mode | Description |
|------|-------------|
| `local` | API ElevenLabs directe, stockage audio local |
| `cloud` | Backend hébergé, stockage centralisé |
| `localBackend` | Backend localhost (développement) |

---

## 4. Fonctionnalités

### 4.1 Écrans (5 au total)

| Écran | Fichier | Lignes | Fonction |
|-------|---------|--------|----------|
| Accueil | `home_screen.dart` | 345 | Liste des collections, CRUD |
| Détail Liste | `list_detail_screen.dart` | 556 | Gestion des mots/concepts |
| Quiz Texte | `quiz_screen.dart` | 636 | Quiz avec saisie clavier |
| Quiz Vocal | `quiz_screen_STT.dart` | 615 | Quiz avec reconnaissance vocale |
| Paramètres | `settings_screen.dart` | 342 | Configuration TTS |

### 4.2 Gestion du Vocabulaire
- Création/suppression de listes par paires de langues
- Variantes de mots avec registres (formel, informel, neutre)
- Catégorisation (15 catégories prédéfinies)
- Contexte et phrases d'exemple

### 4.3 Système de Quiz
- **Mode texte** : saisie clavier avec validation tolérante
- **Mode vocal** : reconnaissance vocale multilingue
- Validation avec tolérance aux fautes de frappe (seuil: 0.85)
- Feedback de qualité basé sur le score

### 4.4 Audio (ElevenLabs)
- 16+ voix disponibles (Adam, Rachel, Charlotte...)
- Sélection de voix par langue
- Paramètres ajustables : stabilité, similarité
- Stockage local des fichiers MP3
- Hash MD5 pour identification

### 4.5 Algorithme SRS

```
Intervalles de révision : [1, 3, 7, 14, 30, 90] jours

masteryLevel = correctAnswers / totalShown
Seuil de maîtrise = 0.7 (70%)

Intervalle adaptatif = baseInterval × (0.5 + masteryLevel × 0.5)
```

---

## 5. Modèles de Données

### 5.1 Schéma de Base de Données

```
┌──────────────────┐     ┌──────────────────┐
│ vocabulary_lists │     │     concepts     │
├──────────────────┤     ├──────────────────┤
│ id (PK)          │────<│ id (PK)          │
│ name             │     │ listId (FK)      │
│ lang1Code        │     │ category         │
│ lang2Code        │     │ context1, context2│
│ createdAt        │     │ exampleSentences │
└──────────────────┘     └────────┬─────────┘
                                  │
                         ┌────────┴─────────┐
                         │  word_variants   │
                         ├──────────────────┤
                         │ id (PK)          │
                         │ conceptId (FK)   │
                         │ word             │
                         │ langCode         │
                         │ registerTag      │
                         │ audioHash        │
                         └────────┬─────────┘
                                  │
                         ┌────────┴─────────┐
                         │ variant_progress │
                         ├──────────────────┤
                         │ variantId (FK)   │
                         │ direction        │
                         │ timesShown       │
                         │ timesCorrect     │
                         │ masteryLevel     │
                         │ nextReviewDate   │
                         └──────────────────┘
```

### 5.2 Modèles Dart

| Modèle | Lignes | Description |
|--------|--------|-------------|
| `VocabularyList` | 77 | Liste de vocabulaire |
| `Concept` | 89 | Unité d'apprentissage |
| `WordVariant` | 100 | Variante de mot |
| `VariantProgress` | 110 | Progression SRS |
| `AudioSettings` | 150 | Configuration TTS |

---

## 6. Services

### 6.1 Services Base de Données

```
services/database/
├── DatabaseService.dart      # Singleton SQLite
├── DatabaseSchema.dart       # Définition des tables
├── VocabularyListRepository  # CRUD listes
└── ConceptRepository         # CRUD concepts/variants
```

### 6.2 Services Audio

```
services/audio/
├── AudioService.dart         # Interface abstraite
├── LocalAudioService.dart    # Stockage local
├── BackendAudioService.dart  # Stockage cloud
├── ElevenLabsService.dart    # API TTS
├── AudioPlayerService.dart   # Lecture audio
└── AudioFileManager.dart     # Gestion fichiers
```

### 6.3 Services Parole

```
services/speech/
└── SpeechRecognitionService.dart  # Reconnaissance vocale
```

---

## 7. Dépendances

### Principales
```yaml
# Base de données
sqflite: ^2.3.0
sqflite_common_ffi: ^2.3.0
path_provider: ^2.1.0

# État
provider: ^6.1.0

# Audio/Parole
audioplayers: ^5.2.1
speech_to_text: ^7.0.0

# Utilitaires
uuid: ^4.0.0
crypto: ^3.0.0
http: ^1.0.0
string_similarity: ^2.0.0
shared_preferences: ^2.2.2
```

### Développement
```yaml
flutter_test
flutter_driver
mockito: ^5.4.0
integration_test
```

---

## 8. Tests

### 8.1 Couverture Actuelle

| Type | Emplacement | État |
|------|-------------|------|
| Tests unitaires | `test/utils/` | ✅ Complet (AnswerValidator) |
| Tests widget | `test/` | ⚠️ Minimal (template) |
| Tests intégration | `integration_test/` | ✅ Présent |
| Tests E2E | `appium-tests/` | ✅ Configuré |

### 8.2 Tests AnswerValidator
- 8 groupes de tests
- 30+ assertions
- Couverture : matching exact, similarité, registres, accents, entrées vides

### 8.3 Commandes de Test
```bash
flutter test                           # Tous les tests
flutter test --coverage                # Avec rapport
flutter test integration_test/         # Intégration
```

---

## 9. Configuration

### 9.1 Fichiers de Config

| Fichier | Lignes | Contenu |
|---------|--------|---------|
| `AppConfig.dart` | 90 | Mode déploiement, factory services |
| `ApiConfig.dart` | 92 | Clés API, URLs, timeouts |
| `Constants.dart` | 120 | Codes langue, intervalles SRS, seuils |

### 9.2 Langues Supportées
- Français (fr)
- Coréen (ko)
- Anglais (en)
- Espagnol (es)
- Japonais (ja)

### 9.3 Registres Linguistiques
- `formal` - Formel
- `neutral` - Neutre
- `informal` - Informel
- `very_informal` - Très informel

---

## 10. Plateformes Supportées

| Plateforme | Support | Notes |
|------------|---------|-------|
| Android | ✅ Complet | Standard Flutter |
| iOS | ✅ Complet | Standard Flutter |
| Windows | ✅ Complet | FFI requis |
| macOS | ✅ Complet | FFI requis |
| Linux | ✅ Complet | FFI requis |
| Web | ⚠️ Expérimental | - |

---

## 11. Points Forts

1. **Architecture propre** - Séparation claire des responsabilités
2. **Cross-platform** - Support mobile et desktop
3. **SRS avancé** - Algorithme de répétition espacée adaptatif
4. **Audio premium** - Intégration ElevenLabs professionnelle
5. **Multilingue** - 5 langues avec gestion Unicode
6. **Tests structurés** - Unit, integration, E2E
7. **Flexible** - 3 modes de déploiement

---

## 12. Points d'Amélioration Potentiels

### Code
- [ ] Augmenter la couverture des tests widget
- [ ] Ajouter des tests pour les services audio
- [ ] Documenter les API publiques (dartdoc)

### Fonctionnalités
- [ ] Mode hors-ligne complet
- [ ] Synchronisation cloud des progrès
- [ ] Import/export de listes (CSV déjà supporté partiellement)
- [ ] Statistiques détaillées de progression

### UX
- [ ] Thème sombre
- [ ] Internationalisation de l'interface (i18n)
- [ ] Onboarding utilisateur

### Performance
- [ ] Pagination des listes longues
- [ ] Cache des requêtes API
- [ ] Lazy loading des audios

---

## 13. Commandes Utiles

```bash
# Développement
flutter run                    # Lancer l'app
flutter run -d windows         # Lancer sur Windows
flutter run -d chrome          # Lancer sur Web

# Build
flutter build apk              # APK Android
flutter build ios              # iOS
flutter build windows          # Windows

# Tests
flutter test                   # Tests unitaires
flutter test --coverage        # Avec couverture
flutter analyze                # Analyse statique

# Maintenance
flutter pub get                # Installer dépendances
flutter pub upgrade            # Mettre à jour
flutter clean                  # Nettoyer le build
```

---

## 14. Résumé

**VocabApp** est une application Flutter mature et bien architecturée pour l'apprentissage du vocabulaire multilingue. Le projet démontre de bonnes pratiques de développement avec une architecture en couches, des patterns de conception appropriés (Repository, Singleton, Factory), et une infrastructure de tests solide.

Le code est organisé, maintenable, et prêt pour la production avec environ 3 800 lignes de Dart réparties entre les écrans, services, modèles et utilitaires.

---

*Document généré automatiquement le 21/01/2026*
