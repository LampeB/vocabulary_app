# VocabKR — état actuel

**Mis à jour : 1 octobre 2026** · **Branche de travail :**
`feat/multi-language-learning`

## Produit en une phrase

VocabKR est une application Flutter d'apprentissage de vocabulaire et de
grammaire, hors ligne d'abord, avec répétition espacée FSRS, listes libres,
parcours guidé optionnel et révision vocale ou par flashcards.

Les trois paires présentées dans la V0 sont **FR→KO**, **EN→KO** et **KO→FR**.
Le modèle de données et les listes libres restent génériques pour d'autres
langues.

## Ce qui est réellement livré

### Noyau pédagogique

- Listes personnelles/importées étudiables immédiatement, sans cursus.
- Quiz flashcards, saisie, voix et mains-libres ; FSRS et historique local.
- Pré-requis de leçon isolés de la pratique libre : 80 % pondéré de mots
  gradués, avec au moins 70 % dans chaque liste requise.
- Règles de grammaire, lecteur de leçon et drills issus des données seedées.
- Drift/SQLite local, synchronisation Supabase et opérations hors ligne.

### Voix et audio

- `VoiceTurnMachine` pilote les tours mains-libres ; `AudioDirector` séquence
  les prompts, réponses et signaux.
- `SttRace` valide une hypothèse contre la réponse attendue et coordonne les
  moteurs système, Whisper et ElevenLabs selon leur disponibilité ; depuis
  2026-10-02 tous transcrivent la même capture partagée (y compris le
  recognizer du téléphone via le pont PCM) et l'état est affiché en direct.
- Les enregistrements de corpus et le laboratoire STT permettent de comparer
  les moteurs sur un appareil.
- Les audios de quiz sont provisionnés à la création/publication puis téléchargés
  en cache local ; un quiz ne génère pas de TTS ElevenLabs à chaque carte.

### Slice V3 livrée

Le flux visible suivant est implémenté et relié :

```text
splash/auth + seed → plateau → chemin du jour → liste/prérequis
→ configurateur → flashcards ou mains-libres → bilan
```

La portée, les composants et les écarts de cette slice sont documentés dans
[docs/design/v3-sentier-de-cartes.md](docs/design/v3-sentier-de-cartes.md).

## Ce qui n'est pas terminé

### V0 pédagogique

La **définition de sortie complète** de `docs/v0-daily-loop-plan.md` n'est pas
encore satisfaite. Il manque notamment : découverte réellement séquencée, écho
non noté, plan quotidien figé/persistant, complétion, et validation physique
sur les trois paires.

Les pages et exemples de leçon rédigés et relus pour KO→FR restent un bloqueur
de contenu avant bêta pédagogique.

### Finition V3

- Localiser tous les textes V3 en FR/EN/KO ; des libellés sont encore en
  français dans le code.
- Décider et créer les variantes claires du plateau, du chemin et du splash.
- Retirer les piles décoratives hors révision, généraliser les plongées et
  signaler les surfaces scrollables.
- Migrer les écrans non inclus : bibliothèque globale, leçons, voix/écrire,
  profil, réglages, shell/navigation, social et paiement.

### Validation avant bêta

- Vérification visuelle V3 sur petits écrans, grandes polices, deux thèmes et
  trois locales.
- Tests réels microphone, latence réseau, cache audio, reprise arrière-plan et
  synchronisation sur deux appareils.
- Audit de la configuration Supabase/Edge Functions, secrets, JWT, limites et
  coût ; ce point n'est pas vérifiable depuis ce dépôt seul.

## Tests et CI

- La suite hôte (unitaires, intégration Drift, widgets et seeds) est exécutée
  sur chaque push et pull request avec un seuil de couverture de **47,5 %**.
- La suite compte **752** tests hôte lors de la dernière validation locale
  complète ; le nombre exact n'est pas un contrat et doit être vérifié par
  `flutter test`.
- La CI Patrol contient neuf suites Android, lançables manuellement avec des
  secrets Supabase : navigation, auth, flux utilisateur, chemin quotidien,
  prérequis de leçon, paires de langues, quiz voix/cartes, écriture et login.
- Le reset E2E par scénario, le verrou commun et le planning quotidien à
  22 h 17 (Séoul) sont implémentés. Le dispatcher est activé sur `main`
  ([PR #1](https://github.com/LampeB/vocabulary_app/pull/1)) et cible
  `feat/multi-language-learning`. **Les 36 comptes distincts sont provisionnés** et le secret CI est installé.
  Le passage Patrol réel reste à valider : le premier run a validé la
  configuration, puis échoué avant les tests sur une incompatibilité du CLI.
  La CI fixe désormais Patrol CLI 4.4.0 pour Patrol 4.6.1. Le reset refuse
  une identité attribuée à un autre scénario et les relations intercomptes.
  Les 752 tests hôte, les contrôles Python et les tests SQL sur base jetable
  passent ; `flutter analyze` ne rapporte aucun problème. Procédure dans le
  [runbook E2E](docs/runbooks/e2e-account.md).
- Le run parallèle a validé sept suites sur neuf. Le chemin quotidien a
  révélé un seeding automatique encore actif lors de la création de listes
  en mode test ; ce déclenchement est désormais désactivé. Le quiz a terminé
  quatre scénarios sur cinq sans rapport Android conservé ; les artefacts
  de diagnostic sont désormais collectés. Validation CI des corrections en attente.
- Les neuf suites CI sont réparties en neuf jobs indépendants, avec trois
  jobs simultanés maximum, une tentative par suite, `fail-fast: false` et
  40 minutes par job. Le verrou entre runs reste actif.
- Chaque scénario Patrol a un timeout de **3 minutes**, également appliqué
  par défaut par le helper commun. Cette limite ne couvre pas la compilation
  ni le démarrage de l’émulateur.
- Les comportements audio, microphone réel, rendu et réseau restent à tester
  sur appareil : la simulation rend les E2E déterministes mais ne prouve pas
  l'expérience physique.

## Documentation et gouvernance

- La racine du dépôt est un vault Obsidian versionné. Son point d'entrée est
  [`docs/knowledge-base/00-Accueil.md`](docs/knowledge-base/00-Accueil.md) ;
  Git et Markdown, et non une base Obsidian séparée, restent la source de
  vérité.
- [`AGENTS.md`](AGENTS.md) oblige tout agent à consulter le portail et la
  spécification active avant une décision matérielle, à demander une décision
  absente ou ambiguë, puis à documenter la réponse.
- Le hook versionné `.githooks/pre-commit`, installé par
  `tool/install-git-hooks.ps1`, vérifie les liens Markdown et refuse un commit
  de code/configuration sans mise à jour documentaire. Son usage et l'exception
  rare sont documentés dans
  [`docs/runbooks/documentation-et-commits.md`](docs/runbooks/documentation-et-commits.md).
- Les anciennes maquettes, audits et plans V1/V2 ont été retirés du vault pour
  éviter les sources concurrentes ; leur historique reste récupérable dans Git.

## Priorités recommandées

1. Fermer les écarts V3 visibles : localisation, thème clair, plongée/scroll,
   piles décoratives hors quiz.
2. Finaliser une unité pédagogique V0 relue, incluant KO→FR, leçon, exemples et
   écho non noté.
3. Transformer le chemin quotidien de recommandation en plan persistant et
   complétable, sans jamais bloquer la pratique libre.
4. Valider sur appareil et sécuriser/configurer les services externes avant
   ouverture bêta.

## Références

- [Portail documentaire](docs/README.md)
- [Base de connaissances](docs/knowledge-base/00-Accueil.md)
- [Décisions produit](docs/design/map/app-map.md)
- [Couverture et stratégie de test](TESTS.md)
- [Roadmap de contenu](docs/content-roadmap.md)
