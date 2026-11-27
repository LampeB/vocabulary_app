# Ponderin — état actuel

**Mis à jour : 27 novembre 2026**

## Produit en une phrase

Ponderin est une application Flutter d'apprentissage de vocabulaire et de
grammaire, hors ligne d'abord, avec répétition espacée FSRS, listes libres,
parcours guidé optionnel et révision vocale ou par flashcards.

Les trois paires présentées dans la V0 sont **FR→KO**, **EN→KO** et **KO→FR**.
Le modèle de données et les listes libres restent génériques pour d'autres
langues.

## Ce qui est réellement livré

### Noyau pédagogique

- Listes personnelles/importées étudiables immédiatement, sans cursus.
- Quiz flashcards, saisie, voix et mains-libres ; FSRS et historique local.
- Les flashcards de vocabulaire enregistrent good/again en FSRS, conformément
  à la décision du 8 août ; les cartes de grammaire restent une pratique libre.
- Pré-requis de leçon isolés de la pratique libre : 80 % pondéré de mots
  gradués, avec au moins 70 % dans chaque liste requise.
- Règles de grammaire, lecteur de leçon et drills issus des données seedées.
- Drift/SQLite local, synchronisation Supabase et opérations hors ligne.
- Les correctifs d'intégration unifient les envois dans la file durable,
  protègent les éditions locales, propagent les suppressions et préservent
  les paires lors des exports/imports. Leur contrat est dans
  [la spécification de synchronisation](docs/synchronization.md).

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

- Les entrées V3, le plateau, le chemin et les commandes de sortie utilisent
  FR/EN/KO. L'audit des autres flux de révision reste à compléter.
- Décider et créer les variantes claires du plateau, du chemin et du splash.
- Les piles décoratives du plateau/chemin sont retirées et leur scroll est
  signalé ; la généralisation des plongées reste à terminer.
- Migrer les écrans non inclus : bibliothèque globale, leçons, voix/écrire,
  profil, réglages, shell/navigation, social et paiement.

### Validation avant bêta

- Vérification visuelle V3 sur petits écrans, grandes polices, deux thèmes et
  trois locales.
- Tests réels microphone, latence réseau, cache audio, reprise arrière-plan et
  synchronisation sur deux appareils.
- Audit de la configuration Supabase/Edge Functions, secrets, JWT, limites et
  coût ; les limites bêta sont décidées mais leur configuration opérationnelle
  dans les tableaux de bord fournisseurs reste à vérifier.

## Tests et CI

- La suite hôte (unitaires, intégration Drift, widgets et seeds) est exécutée
  sur chaque push et pull request avec un seuil de couverture de **47,5 %**.
- L'analyse Flutter est propre ; les **988 tests hôte passent**, avec **69,3 %**
  de couverture sur le dernier lot du 27 novembre. Huit tests positifs du
  laboratoire sont exclus sans opt-in ; l'exécution diagnostic explicite
  réussit ses 21 tests ciblés. La sonde compilée en mode produit confirme le
  refus des diagnostics, même avec l'option fournie.
- Sur `f7827da`, les sept checks CI, dont les tests hôte, le wrapper SQL et la
  compilation native Android, sont verts. Le pont utilise le NDK 28.2 de
  l'application. Les six premières itérations des quatre relecteurs restent
  bloquées ; le lot courant traite les 17 Important de la sixième passe dans
  [le registre du 27 novembre](docs/reviews/2026-11-27-integration.md). Aucun
  compteur propre n'est acquis : il faut deux revues propres sur le commit final.
- La CI de PR vérifie également la compilation native Android, les frontières
  des fonctions cloud et leurs quotas sur PostgreSQL jetable ; l'audit de
  sécurité couvre tous les workflows et leurs actions épinglées par SHA.
- La suite compte **988** tests hôte réussis lors de la dernière validation locale
  complète ; le nombre exact n'est pas un contrat et doit être vérifié par
  `flutter test`.
- Les six suites SQL passent sous PostgreSQL 16.11 jetable avec les migrations
  réelles, dont la nouvelle protection des tombstones. Deux connexions ont
  vérifié le verrou du reset et le refus de l'écriture concurrente ; la CI de
  `f7827da` confirme le wrapper Bash des six suites.
  Les cinq tests Python E2E, vingt-quatre tests Deno, vingt-et-un tests du bot
  et quatre tests du déploiement passent dans le lot courant. Le bot refuse
  aussi une CI verte issue d'un
  autre workflow ou évaluée contre une autre base.
- La CI Patrol contient neuf suites Android, lançables manuellement avec des
  secrets Supabase : navigation, auth, flux utilisateur, chemin quotidien,
  prérequis de leçon, paires de langues, quiz voix/cartes, écriture et login.
- Le reset E2E par scénario, le verrou commun et le planning quotidien à
  22 h 17 (Séoul) sont implémentés. Le dispatcher livré par
  [la PR #1](https://github.com/LampeB/vocabulary_app/pull/1) ciblait la branche
  de développement ; cette intégration le fait exécuter uniquement depuis et
  vers `main` après fusion. **Les 36 comptes distincts sont provisionnés** et
  le secret CI est installé. Les nouvelles migrations restent à appliquer
  sur le projet hébergé avant une validation de ce runner.
  Le passage Patrol réel reste à valider : le premier run a validé la
  configuration, puis échoué avant les tests sur une incompatibilité du CLI.
  La CI fixe désormais Patrol CLI 4.4.0 pour Patrol 4.6.1. Le reset refuse
  une identité attribuée à un autre scénario et les relations intercomptes.
  La migration 013 interdit de nouvelles relations intercomptes impliquant
  un scénario E2E. Le provisioning protège aussi ses fichiers par ACL sur
  Windows. Procédure et validation dans le [runbook E2E](docs/runbooks/e2e-account.md).
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
- Whisper local Android utilise désormais un pont Ponderin minimal vers le
  moteur MIT `whisper.cpp`, avec modèle épinglé et vérifié. Le wrapper GPL
  historique a été retiré. L'intégration iOS n'est pas livrée : le dossier iOS
  n'a pas de `Podfile` et doit faire l'objet d'un chantier Xcode/test appareil
  avant toute promesse de disponibilité locale sur cette plateforme.
- Le workflow TestFlight incomplet a été retiré : aucune livraison iOS n'est
  revendiquée. Le workflow Android peut produire un artefact GitHub Actions ;
  aucun APK généré ne doit être versionné dans Git.
- Les routes du laboratoire STT, leurs liens et la persistance du corpus
  exigent un build debug avec `STT_DIAGNOSTICS=true`. La CI exerce aussi le
  refus en mode produit, même si cette option est fournie.

## Documentation et gouvernance

- **Ponderin** est le nom de travail interne de l'application. Le renommage
  visible peut avancer pendant le développement ; la disponibilité de marque,
  domaine et stores reste à vérifier avant toute diffusion externe, et les
  identifiants `vocab_kr` restent temporairement stables. Voir la
  [décision](docs/decisions/2026-11-23-ponder-working-name.md).
- Le nom retenu pour le dépôt GitHub est **PonderIn** (décision utilisateur du
  26 novembre). L'opération distante suit la fusion de l'intégration dans `main`
  et ne change pas les identifiants techniques Flutter.

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
- Le protocole de validation des PR est décidé : quatre relecteurs agents
  indépendants doivent converger sur deux passes propres consécutives, sans se
  substituer à la CI ni à l'approbation formelle GitHub. Le skill, les quatre profils,
  le hook et la CI sont implémentés sur la branche d'intégration ; l'activation
  du Dependency Graph et des alertes Dependabot a été réalisée le 26 novembre
  (la comparaison des dépendances répond désormais). La protection GitHub de
  `main` est désormais active : sept checks CI, un statut de convergence,
  une approbation et la résolution des conversations, y compris pour l'admin.
  Le bot GitHub Actions choisi le 27 novembre formalise l'approbation après
  preuve des huit rapports propres et CI verte ; il n'est pas un relecteur
  Copilot. Son premier dispatch et la convergence restent à obtenir ; voir
  [`docs/pr-validation.md`](docs/pr-validation.md).
- Le corpus vocal de travail reste local et interdit par le garde de PR.
  Les deux historiques affectés ont été purgés avec sauvegarde ; l'utilisateur
  a explicitement accepté le reliquat des anciens objets GitHub pour cette
  intégration. Aucun effacement de ces caches n'est revendiqué.
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
