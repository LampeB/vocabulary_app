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
- Décision du 27 novembre, après comparaison des deux maquettes : la pratique
  libre du plateau utilise une feuille **Quoi → Sens → Mode**. Elle conserve
  la paire de l'en-tête et lance directement le quiz. Les leçons gardent leur
  configurateur complet ; le contrat est dans
  [Pratique libre](docs/design/map/pratique-libre.md).
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
  2026-10-02 les décodeurs PCM (Whisper, téléphone via le pont et ElevenLabs)
  transcrivent la même capture partagée. Le reconnaisseur système exclusif
  possède son propre micro en mode Système ou en secours de Course sans
  décodeur local compatible. L'état de chaque moteur est affiché en direct.
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
- L'analyse Flutter est propre ; les **1 105 tests hôte passent**, avec **74,5 %**
  de couverture sur le dernier lot du 27 novembre. Douze tests positifs du
  laboratoire sont exclus sans opt-in ; l'exécution diagnostic explicite
  réussit ses 25 tests ciblés. La sonde compilée en mode produit confirme le
  refus des diagnostics, même avec l'option fournie.
- Sur `90a8298`, les sept anciens checks CI, dont les tests hôte, le wrapper SQL et la
  compilation native Android, sont verts. Le pont utilise le NDK 28.2 de
  l'application. Les douze premières itérations des quatre relecteurs ont été
  bloquées ; leurs corrections sont consignées dans
  [le registre du 27 novembre](docs/reviews/2026-11-27-integration.md).
  Le sas exige deux revues propres sur le commit final ; les verdicts et les
  checks du candidat courant sont consignés dans la PR d'intégration.
- La CI de PR vérifie également la compilation native Android, les frontières
  des fonctions cloud et leurs quotas sur PostgreSQL jetable ; l'audit de
  sécurité couvre tous les workflows et leurs actions épinglées par SHA.
- La suite compte **1 105** tests hôte réussis lors de la dernière validation locale
  complète ; le nombre exact n'est pas un contrat et doit être vérifié par
  `flutter test`.
- Les neuf suites SQL passent sous PostgreSQL 16.11 jetable avec les migrations
  réelles, dont la protection des tombstones et le test intermédiaire de fermeture
  Storage avant activation de la politique finale. Deux connexions ont
  vérifié le verrou du reset et le refus de l'écriture concurrente. Le contrat
  Patrol exige 016 et se ferme si une garde d'écriture est désactivée.
  Les dix tests Python E2E, le test Node de redirection TLS, vingt-neuf tests Deno, vingt-et-un tests du bot,
  quatre tests du déploiement et quatre tests du garde Git passent dans le lot courant. Le bot refuse
  aussi une CI verte issue d'un
  autre workflow ou évaluée contre une autre base.
- La règle anglaise `a/an` exclut les indénombrables. Décision utilisateur du
  27 novembre : ses prérequis regroupent Nourriture et Salutations & politesse,
  avec un minimum conservé de cinq noms éligibles, sans modifier les autres règles.
- Les suggestions d'ajout utilisent un contexte groupé borné et affichent les
  refus de quota sans perdre la sélection. Les imports froids retrouvent la
  bibliothèque ; les leçons et les phases mains-libres défilent à texte doublé.
- Les échecs de fermeture du micro et les refus natifs TTS sont récupérables
  sans signal ni notation prématurés. Le détail des listes suit l'adoption
  des identifiants starter, sans écraser des historiques FSRS divergents.
- Le complément des starters préserve les suppressions restaurées. Les
  événements d'un brouillon restent retenus jusqu'à son rapprochement, y
  compris pendant un envoi concurrent. L'arrêt système exclusif conserve
  aussi sa possession du micro jusqu'à l'accusé natif, même après retour système.
- Les titres longs restent accessibles par défilement ; les commandes Retour
  portent un nom accessible et les prérequis absents un libellé de catalogue.
  La compilation APK ne publie plus de binaire dans les artefacts publics.
- Le namespace serveur est qualifié par propriétaire, sans collision possible
  entre les UUID de deux comptes. Les liaisons d'identité locales conservent
  les copies séparées sur un appareil partagé et les UUID du protocole distant.
- L'arrêt système utilise une confirmation native de session distincte de
  l'acquittement de commande. Le nouveau pont iOS et le fuseau natif doivent
  passer la compilation simulateur macOS, désormais huitième check CI exigé ;
  aucun build iOS ni essai appareil n'est revendiqué sur l'hôte Windows.
- Les checks iOS de `f5f5949` et `90a8298` ont échoué au lien `Pods_Runner`.
  CocoaPods est versionné et SwiftPM automatique désactivé. Le lot courant
  applique aussi la contrainte de GoogleMLKit sur l'architecture simulateur ;
  le prochain check macOS doit confirmer l'édition des liens.
- La feuille compte les cartes par source/paire/sens ; un pool devenu vide
  offre une reprise sans faux bilan. Les titres longs d'aperçu défilent avec
  leurs mots et les locales partielles disposent du repli français réel.
- Les écritures et la restauration ont des échéances bornées, les identités
  starter reconnues survivent aux éditions hors ligne et les rendus audio
  restent liés au compte initial. Les annulations de rappels invalident les
  programmations tardives. Les diagnostics iOS attendent une exclusion des
  sauvegardes confirmée, également réappliquée aux dossiers existants.
- Les boutons de l'accueil et la validation d'authentification sont accessibles
  au clavier ; les deux entrées Bibliothèque du chemin conservent le retour
  contextuel. La saisie reste utilisable avec le clavier en paysage à texte
  doublé. Les rappels sont restaurés depuis le bootstrap authentifié de V3,
  et le rappel de série est annulé lorsque l'activité du jour est connue.
- La migration 016 refuse une écriture arrivée après une version plus récente
  du même appareil, même après expiration HTTP. La restauration conserve ses
  curseurs dans SQLite pour reprendre après redémarrage. Le comptage du chemin
  exclut les questions sans réponse active et la feuille distribue les cartes
  annoncées sans répétition de remplissage.
- La CI Patrol contient neuf suites Android, lançables manuellement avec des
  secrets Supabase : navigation, auth, flux utilisateur, chemin quotidien,
  prérequis de leçon, paires de langues, quiz voix/cartes, écriture et login.
  Ses lancements restent fermés par défaut : activation explicite et sonde
  d'isolation hébergée sont exigées avant tout reset.
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
  historique a été retiré. Whisper local iOS n'est pas livré. Le `Podfile`
  et les configurations CocoaPods de l'application sont versionnés, mais le
  build simulateur échoue encore au lien `Pods_Runner` sur `90a8298` ; une
  compilation native réussie et des essais appareil restent nécessaires.
- Le workflow TestFlight incomplet a été retiré : aucune livraison iOS n'est
  revendiquée. Le workflow Android compile l'APK sans le publier en artefact
  GitHub Actions ; aucun APK généré ne doit être versionné dans Git.
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
  `main` est désormais active : huit checks CI, un statut de convergence,
  une approbation et la résolution des conversations, y compris pour l'admin.
  Le bot GitHub Actions choisi le 27 novembre formalise l'approbation après
  preuve des huit rapports propres et CI verte ; il n'est pas un relecteur
  Copilot. La preuve de convergence et l'approbation portent sur le SHA exact
  de la PR ; la première activation et les garde-fous sont décrits dans
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
