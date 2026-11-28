# Ponderin — état actuel

**Mis à jour : 28 novembre 2026**

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
- La synthèse de l'appareil sur Android/iOS utilise des ponts de l'application
  qui attendent l'arrêt natif identifié avant de permettre une autre lecture
  ou le microphone. Le protocole et les limites de validation sont dans
  [le contrat voix](docs/stt-improvement-plan.md).
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
- L'analyse Flutter est propre ; les **1 368 tests hôte passent**, avec **76,8 %**
  de couverture sur le dernier lot du 28 novembre. Douze tests positifs du
  laboratoire sont exclus sans opt-in ; l'exécution diagnostic explicite
  réussit ses 25 tests ciblés. La sonde compilée en mode produit confirme le
  refus des diagnostics, même avec l'option fournie.
- Sur `5e60e52`, les huit checks CI, dont les tests hôte, le wrapper SQL,
  Android et le simulateur iOS, sont verts. Le pont utilise le NDK 28.2 de
  l'application. Le premier cycle a atteint son plafond de vingt passes sans
  convergence. Le 28 novembre, l'utilisateur autorise le cycle 2, avec vingt
  nouvelles passes au maximum,
  des relecteurs libres d'explorer et des correcteurs chargés de chercher la
  cause, les cas voisins et les effets de leurs changements. Les cinq premières
  passes y relèvent huit, quatre, huit, dix puis huit Important distincts, traités ensemble
  après chaque collecte des quatre verdicts. Les ponts TTS mobiles ont compilé
  sur Android/iOS ; le cache partagé publie atomiquement des clips vérifiés et
  se replie sur l'appareil après libération du lecteur défaillant. Les anciens
  rapports restent conservés ; aucun compteur propre n'est acquis. La
  [décision et ses limites](docs/decisions/2026-11-28-review-corrections-and-cycles.md)
  s'appliquent avant toute nouvelle revue. Les corrections sont consignées dans
  [le registre du 27 novembre](docs/reviews/2026-11-27-integration.md).
  Le nouveau cycle est suivi dans
  [le registre du 28 novembre](docs/reviews/2026-11-28-integration-cycle2.md).
  La troisième passe distingue une panne du compteur d'un vrai zéro, conserve
  le profil enrichi sans écriture de remplacement après une panne, et retient
  les anciens jetons de partage ambigus jusqu'à preuve de leur origine.
  Les lectures de quiz attendent aussi l'arrêt actif. La leçon coréenne
  enseigne `저→제가` ; les sélecteurs utilisent les autonymes. Le garde couvre
  les suppressions et l'index Markdown ; le check manuel est distinct du push.
  La quatrième passe étend la distinction inconnu/zéro aux pools de pratique
  libre et aux séances partielles, et signale le défilement du configurateur.
  Les lectures facultatives arbitrent réellement clip/synthèse et suivent la
  face courante. SQLite 14 conserve les jours à rejouer jusqu'à ACK et les
  éditions historiques incertaines restent visibles sans écraser le distant.
  `app_links` possède seul les liens natifs. La migration 024 ouvre aux amis
  confirmés la lecture des mots de leur liste ; le publieur audio exige une
  absence Storage confirmée avant rendu payant. Les outils et règles de
  validation sont aussi couverts par le garde documentaire.
  La cinquième passe protège la paire des formulaires de mots dans leur
  transaction, fait défiler leurs commandes avec le clavier et adapte leur
  contraste. Les rappels lisent la date civile conservée, le graphe grammatical
  se libère sans lecteurs et reste limité au compte/pool. Les publications
  audio concurrentes partagent un bail de catalogue en 026. La migration 025
  répare les chemins historiques 012/015 testés et le prévol exige désormais
  `study-catalog-v2` ; aucun réglage hébergé n'est activé.
  Le sas exige deux revues propres sur le commit final ; les verdicts et les
  checks du candidat courant sont consignés dans la PR d'intégration.
- La CI de PR vérifie également la compilation native Android, les frontières
  des fonctions cloud et leurs quotas sur PostgreSQL jetable ; l'audit de
  sécurité couvre tous les workflows et leurs actions épinglées par SHA.
- La suite compte **1 368** tests hôte réussis lors de la dernière validation locale
  complète ; le nombre exact n'est pas un contrat et doit être vérifié par
  `flutter test`.
- Les dix-sept suites SQL passent sous PostgreSQL 16.11 jetable avec les migrations
  réelles, dont la protection des tombstones et le test intermédiaire de fermeture
  Storage avant activation de la politique finale. Deux connexions ont
  vérifié trois scénarios concurrents : reset, purge et jour étudié. La migration
  024 et les lectures des amis sont aussi exercées après activation générée et
  mise à niveau d'un ancien 017. Le contrat
  Patrol exige 022, 023 et 025 et se ferme si une garde de référence ou d'écriture est
  désactivée, ou si un droit client de suppression physique est réintroduit.
  Les dix tests Python E2E, le test Node de redirection TLS, trente-et-un tests Deno, vingt-six tests du bot,
  cinq tests du déploiement et sept tests du garde Git passent dans le lot courant. Le bot refuse
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
  l'acquittement de commande. Le pont système iOS, le fuseau natif et l'exclusion
  des diagnostics des sauvegardes ont passé la compilation simulateur macOS
  sur `5c9d0f0`, huitième check CI exigé ; aucun essai appareil n'est revendiqué.
- Les checks iOS de `f5f5949` et `90a8298` ont échoué au lien `Pods_Runner`.
  CocoaPods est versionné et SwiftPM automatique désactivé. Le lot courant
  applique la contrainte de GoogleMLKit sur l'architecture simulateur : le
  check macOS de `5c9d0f0` passe en 18 minutes. Ses huit checks CI sont verts.
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
  L'historique SQLite du compte empêche son réarmement après redémarrage,
  même si le profil distant n'a pas encore reçu la fin de quiz.
- La migration 016 refuse une écriture arrivée après une version plus récente
  du même appareil, même après expiration HTTP. La restauration conserve ses
  curseurs dans SQLite pour reprendre après redémarrage. Le comptage du chemin
  exclut les questions sans réponse active et la feuille distribue les cartes
  annoncées sans répétition de remplissage.
- Un ACK d'import sans changement métier consomme aussi sa séquence. Le
  rattrapage 017 reprend les mutations distantes intervenues derrière les
  curseurs avant de terminer la restauration. La migration 018 refuse une
  nouvelle référence FSRS privée sans révéler son existence, préserve les
  références historiques et réserve les suppressions physiques au serveur.
- Les erreurs d'authentification et les rappels disposent de textes FR/EN/KO.
  Les compteurs affichent des cartes, cohérentes avec les deux sens de
  révision. Le calcul partagé des séries utilise les dates civiles ; une
  journée de 23 ou 25 heures ne rompt pas la série.
- La fin du quiz conserve son compte, son résultat et son jour civil quand
  l'apprenant quitte le bilan ou recommence pendant une lecture SQLite.
  La série distante ne bascule pas au lendemain après une attente réseau et
  ne réécrit pas une date de profil plus récente.
- La RPC `record_study_day` conserve les journées d'étude et recalcule la
  série dans une transaction par compte. Les deux ordres d'arrivée donnent
  les mêmes compteurs et le même record, sans reculer la dernière date.
  Les plages historiques sont reprises sans matérialiser chaque date et
  le reset du profil efface ces plages par cascade.
- La migration additive 020 conserve le journal d'une installation ayant
  déjà appliqué l'ancien 017. Les purges physiques de concepts et variantes
  se propagent aux caches ; leurs identifiants durables empêchent le rejeu
  d'une ancienne création, y compris lors du complément starter. Le suivi
  des purges enfants commence en 020, sans reconstitution antérieure.
- La migration 021 exige un consentement d'amitié authentifié pour ouvrir
  les listes réservées aux amis. Les anciens liens restent visibles et
  exigent une nouvelle demande acceptée pour cet accès. Le contrat Patrol
  `study-catalog-v2` exige aussi 025 : protections Storage actives et garde
  d'upgrade 012/015, en plus de 022/023 et des étapes intermédiaires testées.
- Les nouvelles purges gardent les seules clés catalogue nécessaires aux
  starters historiques à UUID aléatoires. Une base SQLite neuve ne les recrée
  plus sous un nouvel UUID. Les clés effacées par une ancienne version de 020
  restent irrécupérables depuis son journal seul.
- Chaque route de quiz conserve sa séance ; un import ou un deuxième quiz
  n'altère pas la carte, le score ou la pause du premier. Quitter reste
  attaché à sa propre route malgré un arrêt audio suspendu. Le bilan et le
  dialogue de reset signalent leur défilement sur écran compact.
- Les erreurs natives de lecture interrompent l'attente du prompt. Un
  changement de réglages rejoue le prompt sur le lecteur remplacé avant
  signal et micro. Les proxys STT gardent le bail fournisseur jusqu'au TTL
  lorsque le transport laisse incertaine la fin de la requête.
- La négation anglaise précise la première personne et accepte les formes
  enseignées, avec ou sans I, contractées ou longues, en saisie et en voix.
  Le pluriel des portions de café suit le sens commandable du catalogue.
  La règle a/an et sa décision de prérequis restent identiques.
- Le pluriel demande explicitement de conserver la forme d'un indénombrable,
  contrairement aux portions de café qui prennent `coffees`. Le lecteur de
  leçon garde titre, contenu et pagination dans un même défilement lorsqu'il
  manque de hauteur ou que le texte est fortement agrandi. Les commandes de
  liste ont des noms accessibles et des contrastes vérifiés dans les deux thèmes.
- Un refus natif du signal d'ouverture garde le microphone fermé et offre
  Répéter. Une fermeture de lecteur refusée peut être réessayée sans répéter
  une fermeture déjà confirmée. Le garde de PR vérifie aussi les commits
  intermédiaires : ajouter puis retirer une capture ne contourne plus le sas.
- Le signal d'ouverture attend sa fin native, pas seulement l'acceptation de
  la commande. Erreur asynchrone, expiration ou annulation gardent le micro
  fermé. Le lecteur distingue la libération audio acquise du nettoyage final,
  retenté une fois s'il est refusé ; un objet déjà disposé n'est pas réutilisé.
- Les boutons de lancement comptent des cartes : un concept dans les deux
  sens annonce deux cartes. La popup d'exemple laisse défiler son titre,
  sa traduction et Fermer à texte doublé, puis restitue la position de la
  leçon. Le pluriel conserve `kimchi`, issu du catalogue, parmi ses noms
  éligibles indénombrables ; les portions de café restent `coffees`.
- La consigne des indénombrables appartient au seul module anglais : les
  autres langues conservent leur consigne générique. Les aides de leçon et
  traductions d'aperçu atteignent 4,5:1 dans les deux thèmes. Une erreur de
  lecture du quiz affiche un message FR/EN/KO, un Retour activable au clavier
  et conserve son détail technique dans le diagnostic debug.
- Chaque lecture dont la fin autorise le micro utilise une identité native
  propre. Une ancienne préparation, expiration ou fin de son ne peut pas
  valider ni arrêter sa remplaçante ; le son précédent doit être arrêté
  avant de préparer le nouveau signal.
- Après un arrêt TTS acquitté, l'attente Dart de la génération arrêtée se
  termine même si le plugin iOS ne répond jamais à l'ancien `speak`. Une
  réponse tardive ne retire pas l'activité d'une nouvelle lecture.
- La frontière d'erreur du quiz couvre toute la préparation, y compris
  SQLite après sélection et les futurs de grammaire, sans écraser une séance
  plus récente. Le bouton du configurateur grandit avec le texte et réserve
  son vrai pied ; 100 cartes restent lisibles et lançables à texte doublé.
- Les imports superposés ne consomment leur résultat que sur leur propre
  route visible. Une route masquant le quiz interrompt son micro. Les tours
  mains-libres attendent le résultat du prompt, les transcriptions longues
  défilent avec les commandes et le micro est activable au clavier.
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
  et les configurations CocoaPods de l'application sont versionnés. La
  compilation simulateur de l'application passe sur `5c9d0f0` ; elle ne livre
  pas le pont Whisper iOS ni les essais appareil encore nécessaires.
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
