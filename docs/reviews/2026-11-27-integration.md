# Revue d'intégration — lot du 27 novembre 2026

Commit examiné : `ec6fc5cff77b787f187b5353de8ef3ee1135c707`.
Les quatre relecteurs indépendants ont rendu `BLOQUÉ`. Les tentatives
interrompues par une limite d'usage n'ont produit aucun verdict propre.

Les quatre rapports ont été recueillis avant les corrections ci-dessous.
Les doublons sont regroupés avec leur sévérité maximale ; aucun Bloquant ou
Important n'est rétrogradé. Cette liste décrit le lot de correction, pas une
nouvelle validation indépendante du commit qui le contient.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Bloquant | Connexion redirigée avant restauration et seed | Passage par splash ; test d'événement de session avant la réponse de profil |
| Bloquant | Suggestions utilisant FR→KO quelle que soit la liste | Requête et insertion selon la paire ; widgets EN→KO et KO→FR |
| Bloquant | Pratique de leçon française routée vers les règles coréennes | Règle et paire transmises lecteur → configurateur → quiz ; test KO→FR |
| Bloquant | Détail/édition de liste limité aux variantes FR/KO | Résolution et ordre depuis langA/langB ; tests des deux autres paires |
| Important | Flashcards impossibles à noter au clavier/lecteur d'écran | Actions focalisables et localisées, glissement conservé |
| Important | Tolérance vocabulaire acceptant article/pluriel manquant en grammaire | Notation écrite stricte ; contre-exemples eau/l’eau et pomme/pommes |
| Important | Échéances mélangées entre paires inverses et heure figée | Filtrage ordonné partagé ; réévaluation temporelle et test sans écriture DB |
| Important | Faux acquis et fausse complétion sur le plateau/chemin | Libellés de disponibilité, sans inventer de nouveaux mots ou d'activité |
| Important | Inventaires de contenu périmés | Inventaires V0/roadmap alignés sur les fichiers ; relecture séparée de l'écriture |
| Bloquant | Partage public vide à cause des droits sur les enfants | RLS SELECT de contenu public actif ; tests SQL à deux comptes |
| Bloquant | Copie importée réutilisant un jeton public globalement unique | Champ de provenance distinct, écriture atomique, migration locale 11 et distante 011 |
| Bloquant | UUID concurrents pour une même progression hors ligne | UUID déterministe, upsert par clé métier, récupération/déduplication ; tests d'identité et migration |
| Bloquant | Cache de vocabulaire empêchant un drill nouvellement déverrouillé | Dépendances réactives ; test de graduation avec le vrai provider dans le même conteneur |
| Important | Concepts supprimés réapparaissant dans les listes intelligentes | Filtrage concept/liste en plus de variante ; test de suppression depuis repository |
| Important | Historique envoyé sans table distante versionnée | Migration 012 de review_events et RLS par propriétaire |
| Important | Avance/prompt différés actifs en arrière-plan | Invalidation par cycle de vie, test de reprise sans double note |
| Important | Dernier segment rejeté pendant la fermeture du micro | Fermeture en deux temps ; test avec arrêt et analyses différés |
| Important | Chemins de clips perdus à l'avance/report de carte | Conservation des chemins ; tests de lecture et de report |
| Bloquant | Chemin audio client et origine starter utilisés comme autorité | Namespace propriétaire et manifeste de publication serveur ; anciens seed non publiés fermés |
| Bloquant | Ancien proxy TTS contournant les quotas | Endpoint inutilisé fermé avec HTTP 410 ; procédure de retrait hébergé documentée |
| Important | Corps facturés non bornés et synthèses audio concurrentes | Corps/champs bornés, délais fournisseurs, réservation atomique par objet ; tests Deno/SQL |
| Important | Relation intercompte insérable pendant le reset E2E | Verrous transactionnels et test PostgreSQL à deux sessions en CI |
| Important | Récepteur debug lisant des chemins arbitraires | Permission shell DUMP, dossier de corpus, contrôle WAV/taille |
| Important | Transcriptions persistées dans une livraison | Journal brut limité au debug avec STT_DIAGNOSTICS explicite |
| Important | Cloud contacté malgré une validation locale possible | Secours après fermeture et analyses locales, requêtes cloud sérialisées ; tests sans appel cloud sur succès local |
| Important | Seed concurrent ou marqué complet après Failure | Exécution partagée et marqueur seulement après succès ; tests concurrence/retry |
| Important | Signal pédagogique matérialisant tout l'historique à chaque ack | Projection SQL dédupliquée ; test qu'un accusé seul ne réémet pas |

Suggestion conservée : figer le graphe Deno consommé par CI/déploiement.
Elle n'est pas présentée comme corrigée par ce lot.

Les tests hôte, les tests SQL jetables, la compilation Android et la CI sont
des garde-fous distincts. La validation physique du corpus reste à réaliser ;
les migrations/fonctions du lot ne sont pas déployées automatiquement.
Le prochain commit repart avec zéro passe propre pour les quatre profils et
doit atteindre deux passes propres consécutives sur le même SHA.

## Revue du commit `08e730f` — lot suivant

Commit examiné : `08e730fe8579322131cce286f2c7257b24fcf7ab`.
Les quatre profils ont rendu `BLOQUÉ` avant toute correction de ce lot.
Le doublon entre qualité et correction sur la récupération distante conserve
le type Bloquant. Les deux contrôles CI rouges sont également à corriger.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Bloquant | Les Cartes ignorent la décision FSRS du 8 août | Notes good/again persistées une fois par carte de vocabulaire |
| Important | Les exercices utilisent des mots hors des listes prérequises | Même pool filtré pour disponibilité et génération ; mot admissible d'une autre liste exclu |
| Important | Fermer le quiz perd son écran d'entrée | Arrêt audio/micro et retour contextuel depuis chemin/liste |
| Important | Configuration et compteurs restent en français | Widgets FR/EN/KO, dont zéro, une et plusieurs cartes |
| Important | Une longue réponse est réduite sur une seule ligne | Retour à la ligne et défilement à 320 × 568, texte doublé |
| Bloquant | Un pull ancien écrase une mutation ou un accusé récents | Snapshot initial et application atomique ; entrelacements contrôlés |
| Important | L'audio et les autres listes retardent le partage | Provisionnement séparé et borné ; partage synchronisant seulement sa liste |
| Important | Un speak suspendu peut repartir après stop/dispose | Annulation des lectures différées, téléchargement contrôlé par Completer |
| Important | Une préparation STT reprend après démontage | Contrôle de cycle de vie après chaque attente de préparation |
| Bloquant | Le timeout du profil boucle sur le splash signé | Session locale utilisable avec le redirect de production |
| Bloquant | Retry ou compte à rebours rouvre le micro pendant une pause | Invalidation immédiate du tour et capture factice |
| Bloquant | Le verdict mains-libres se bloque au retour d'arrière-plan | Reprise au niveau écran, sans double notation |
| Important | Une nouvelle session garde flip/pause/callbacks précédents | Initialisation commune et deux ouvertures dans le même conteneur |
| Important | Deux imports du même lien sur deux appareils créent des doublons | Identités stables par compte/provenance ; anciennes copies tolérées sans perte |
| Important | Report de carte et historique ont des dénominateurs différents | Compteurs capturés à la complétion ; bilan et historique concordants |
| Important | Course sélectionne le système exclusif malgré Whisper prêt | Capture partagée locale prioritaire et validation de la bonne hypothèse |
| Bloquant | La fixture SQL de quota échoue avant les tests de frontières | Identité de test complète et exécution sous les migrations réelles |
| Important | Des liens release ouvrent les diagnostics persistants | Routes, liens et corpus soumis au même opt-in debug |
| Important | Une demande sociale ordinaire peut empoisonner un compte E2E | Isolation serveur des relations intercomptes ; refus non destructif des anciens partages |
| Important | Le workflow TestFlight annonce une signature d'archive incomplète | Retrait du workflow déclenchable, livraison iOS explicitement différée |
| Bloquant | Le lint CI relève deux if sans accolades dans un test | Analyse propre après la dernière modification |

Suggestions conservées : figer le graphe Deno ; grouper l'enrichissement des
variantes du quiz au lieu d'une lecture par carte lorsque cette zone change.

Les tentatives sans verdict à cause d'une limite d'usage ne comptent pas comme
passes propres. Les trois commits ayant reçu les quatre verdicts sont
`47ce871`, `ec6fc5c` et `08e730f` : ils ont tous été bloqués. Le prochain commit
repart donc à zéro passe propre sur les quatre profils, avec le plafond de
vingt itérations conservé.

Validation locale de ce lot : 897 tests hôte réussis, huit tests réservés à
l'opt-in debug exclus de l'exécution normale, couverture 67,1 % ; 21 tests
diagnostic ciblés réussis avec opt-in. Analyse Flutter, gardes documentaires,
formatage et frontière de licence propres. Les cinq suites SQL passent sous
PostgreSQL 16.11 jetable ; deux connexions réelles ont vérifié le verrouillage
et le refus de la relation concurrente. Le wrapper Bash complet reste à
confirmer dans la CI, sa syntaxe ayant été vérifiée localement. Les huit tests
Deno et les trois tests Python E2E passent. Le contrôle AOT refuse les
diagnostics en mode produit.

L'intégration aligne aussi le dispatcher nocturne sur `main` et empêche son
exécution depuis la branche d'intégration avant fusion. Les migrations
hébergées et une vraie validation sur appareils restent distinctes de ce lot.

## Revue de `9ecc70b` — corrections et configuration du sas

Les quatre profils ont rendu `BLOQUÉ` sur
`9ecc70bb8e919188bbb921c1983911709bfc900a` avant les corrections de ce lot.
L'observation audio commune à qualité et correction est regroupée sans changer
son type. Le verrou Deno, précédemment proposé en Suggestion, est cette fois
signalé Important et traité comme tel.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Bloquant | Retours impossibles sur les racines du shell et origine perdue par le configurateur | Routes contextuelles poussées, flèche conditionnelle ; plateau et chemin → leçon → setup → quiz → bilan → retour |
| Important | Explications/traductions pédagogiques choisies par la locale UI | Lecteur et aperçu utilisent langA ; KO→FR avec interface française |
| Important | Titre de liste et validateurs français en dur | Détail et formulaire vide vérifiés en FR/EN/KO |
| Important | Choix de configuration et bilan inutilisables au clavier | Boutons focalisables, état selected annoncé, parcours Tab/Entrée et sortie bilan |
| Important | Longs prompts mains-libres/écrits sans défilement | Tests 320 × 568, texte doublé et clavier ouvert, commandes accessibles |
| Important | Ambre sur papier insuffisamment contrasté | Accent clair adapté et contraste vérifié dans les deux thèmes |
| Important | Pluriel français isolé impossible à distinguer à l'oral | Voix/HF indisponibles pour cette règle, garde d'entrée directe, pomme/pommes à l'écrit |
| Important | Grammaire annonçant une échéance non enregistrée | Verdict de grammaire sans fausse échéance ; vocabulaire conserve son intervalle réel |
| Important | Onglets généraux actifs pendant quiz et bilan | Masquage du chrome avec le vrai ShellRoute et une navigation poussée |
| Important | Notes répétées recalculées depuis l'ancien snapshot | Notation transactionnelle depuis la progression courante ; réponses opposées et concurrence |
| Important | Création importée acquittée sans adopter la réponse canonique | Réconciliation immédiate, delta de champs en cours, tombstone et renommage sans pull de réparation |
| Important | Dates locales envoyées à TIMESTAMPTZ sans fuseau | Payloads UTC explicites et round-trip avec décalage |
| Important | TTS et earcon reprenant après leur préparation interrompue | Annulation à la frontière native ; tests Completer stop/dispose |
| Important | Clavier/Révéler laissant la course PCM active | Invalidation du tour et fermeture capture ; transcription tardive ignorée |
| Important | Tags/exemples de variantes perdus à l'export ou par lien | Deux aller-retours préservent les métadonnées de grammaire |
| Bloquant | Corpus vocal personnel et résultats versionnés publiquement | Corpus conservé localement, ignoré et interdit par le garde ; deux historiques publics filtrés |
| Important | Secret E2E disponible à toute branche et 36 comptes embarqués par suite | Environnement patrol-e2e limité à main ; transfert scellé et suppression de la copie dépôt ; sous-ensemble de comptes par cible |
| Important | Cache de clip privé consulté avant l'autorisation du compte | Contrôle avant mémoire/disque et après attente ; isolation des téléchargements par compte |
| Important | expected_word non borné aux proxys STT | Limite 256 avant authentification/quota/fournisseur ; deux vrais handlers testés |
| Important | Graphe Edge mutable entre CI et déploiement | Versions exactes et verrou transitif ; sept bundles frozen/offline via le même outil |
| Important | Branche par défaut empêchant le déclenchement nocturne prévu | main rétablie par défaut ; exécution du runner intégré à confirmer après fusion/migrations |
| Important | Protection de main absente | Sept checks CI, statut de convergence, une approbation, conversations et administrateurs soumis au sas |
| Important | Compteurs par paire conservant leurs timers hors écran | autoDispose et vérification d'arrêt après le dernier abonné |
| Important | Arriéré réessayé à chaque écriture hors ligne | Aucun drain offline, reprise au réseau ; arrêt sur panne transport et poursuite après refus d'une ligne |
| Important | Progression identique relue/réécrite ligne par ligne au pull | Parents résolus en lot, lignes identiques ignorées, réconciliation groupée |

La validation du lot a aussi reproduit une perte d'incrément de maîtrise de
grammaire lors de deux réponses simultanées. La lecture/incrément/écriture est
désormais transactionnelle ; la régression vérifie la création et le seuil.

Les 941 tests hôte passent, avec 69,1 % de couverture et huit tests réservés à
l'opt-in diagnostic exclus de la passe normale. Analyse Flutter, formatage,
gardes et licence propres ; les tests ciblés comptent notamment 142 cas data,
92 cas produit et 76 cas voix. Les dix tests Deno et cinq tests Python E2E
passent. Les bundles Edge sont préparés et démarrés sans réseau ; un verrou
incomplet est refusé. Aucun backend Supabase n'est modifié.

### Purge et décision de conservation historique

L'utilisateur a autorisé le push forcé des deux historiques affectés. Une
sauvegarde locale complète a été vérifiée avant l'opération. Le filtrage
préserve les fichiers hors corpus et la base signée exacte de main. Les
captures ne sont plus accessibles dans l'historique de ces branches. Les
copies locales et la sauvegarde ne sont pas publiées.

GitHub conserve néanmoins les anciens objets et vues par leur identifiant.
Ce reliquat a été constaté et **explicitement accepté par l'utilisateur le
27 novembre 2026 pour cette intégration**, après explication. Il n'est pas
présenté comme supprimé. Une demande GitHub Support a été préparée localement
mais n'a pas été envoyée. Cette décision ne permet aucune nouvelle capture
personnelle versionnée et ne retire pas le garde empêchant sa réintroduction.

### Compteurs de convergence

Quatre itérations complètes ont rendu des verdicts bloqués avant ce lot :
`47ce871`, `ec6fc5c`, `08e730f` et `9ecc70b` (identifiants antérieurs à la purge).
Les tentatives interrompues sans rapport ne sont pas des verdicts. Le prochain
commit repart à zéro passe propre pour chaque profil ; l'itération suivante
est la cinquième, avec le même plafond de vingt. Le bot d'approbation choisi
par l'utilisateur ne dispense d'aucune de ces relectures.

Le bot d'approbation formelle possède 17 tests de garde. Il vérifie le dernier
résultat des sept jobs de l'application GitHub Actions officielle, la preuve
des huit rapports et son empreinte attestée par le propriétaire, puis relit
la tête de PR avant `APPROVE`. Les tests ne publient aucun verdict synthétique
sur GitHub. Son premier dispatch réel reste subordonné à la convergence.

## Cinquième itération — `602835c`

Les quatre profils ont rendu `BLOQUÉ` sur
`602835cb8115addb98d3ccca3db7df7059fc3be7`, avant toute correction.
Ils remontent **14 Important distincts**, aucun Bloquant et trois Suggestions.
Le contournement du planificateur par le quiz, commun à qualité et correction,
est compté une seule fois, en conservant son type Important.

| Type | Constat regroupé | Correction et preuve ciblée du lot |
| --- | --- | --- |
| Important | Minimums de verbes inatteignables pour les particules coréennes | Compter le vocabulaire de préparation du pool prérequis sans le transformer ; catalogue réel maîtrisé à 100 % |
| Important | Particule sujet de 저 produisant 저가 | Contractions des pronoms sujets et conservation des autres particules |
| Important | Article élidé supprimé lors de la validation orale de grammaire | Même comparaison morphologique stricte dans la course et la confirmation |
| Important | Titres papier et notation flashcards illisibles en sombre | Paires encre/fond explicites, contraste dans les deux thèmes |
| Important | Profil A tardif rétablissant A après passage à B | Génération et identité courantes sur tous les retours asynchrones, abonnement annulé au démontage |
| Important | Accusé canonique non répercuté dans le détail déjà ouvert | Providers réactifs aux modifications de contenu ; détail et variantes après ACK |
| Important | Écriture ordinaire ressuscitant une suppression distante | Dominance atomique du tombstone, aussi après l'import initial |
| Important | Réponse de quiz lançant un drain hors du planificateur | Événement durable seul, aucun envoi hors ligne, reprise regroupée au réseau |
| Important | Timeout cloud laissant la requête active puis autorisant un chevauchement | Barrière de requête réelle ou arrêt du secours cloud pour le tour expiré |
| Important | Clé moderne sb_secret_ envoyée dans le mauvais en-tête GoTrue | Authentification moderne et JWT historique distinguées et testées |
| Important | Bot acceptant des checks d'un autre workflow ou d'une ancienne base | Provenance workflow, événement, PR, tête et base testées |
| Important | Démarrage documenté sans sous-module ni SDK compatible | Clone récursif, initialisation existante, contraintes SDK alignées sur le verrou et la CI |
| Important | Signal de drain recompilant cinq COUNT tous comptes à chaque ACK | Notification de mutation locale par compte, sans lecture de l'arriéré ni déclenchement sur ACK |
| Important | Annulation PCM laissant le décodage natif et sa file actifs | Génération de tour, file périmée écartée, annulation native et reprise indépendante |

Les trois Suggestions sont traitées dans ce même lot : procédure de premier
dispatch réutilisant un chemin déjà présent sur main, arrêt des tickers pour
la réduction des animations et retrait du prototype de parcours non routé.

Les tests ciblés passent : 137 cas data, 106 cas voix/quiz/widgets, ainsi que
les régressions d'identité et de catalogue coréen. Les six suites SQL passent
sous PostgreSQL 16.11 réel, dont la migration 014 ; deux sessions confirment
toujours l'isolation du reset. Les seize tests Deno, les vingt-et-un tests du
bot et les sept bundles Edge figés passent. Kotlin compile avec l'annulation
PCM. La migration reste à appliquer sur le projet hébergé avant activation.

La contrainte SDK est alignée sur les dépendances déjà verrouillées et le
SDK CI existant : Flutter 3.44 et Dart 3.12 au minimum. Ce changement de version
de langage impose son formatage Dart et les corrections automatiques du
linter ; ces modifications mécaniques accompagnent le lot fonctionnel.

La suite hôte complète finale passe : **967 réussis**, huit diagnostics
positifs exclus sans opt-in, couverture **69,0 %** (11 799 / 17 088 lignes).
L'analyse Flutter, le garde documentaire/formatage, la licence, actionlint et
zizmor sont propres. La passe complète a aussi révélé un montage du décor dans
un sous-arbre initialement inactif : il reste statique avant la création du
contrôleur, et les deux parcours de navigation concernés passent désormais.
Les cinq tests Python E2E et vingt-et-un tests du bot passent également.

Les sept checks CI et la compilation Android de `602835c` sont verts.
Cela ne constitue pas une passe propre d'agents. Cinq itérations complètes
ont désormais rendu `BLOQUÉ` ; aucun compteur propre n'est acquis. La prochaine
relecture sera l'itération **6**, avec le plafond de vingt inchangé.

## Sixième itération — `f7827da`

Les quatre profils ont rendu `BLOQUÉ` sur
`f7827da7797ad0c7cce9eba479f2c83daad2c456`, avant toute correction.
Après déduplication, cette passe compte **17 Important**, aucun Bloquant et
une Suggestion. Le rattachement audio périmé est signalé par correction,
qualité et sécurité ; la consigne absente en mains-libres par produit et
correction. Ces doublons restent Important.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Liste personnelle homonyme utilisée comme prérequis | Identité seed et langue cible exactes, migration des anciens noms séparée |
| Important | Création d'une liste libre changeant la paire du plateau | Préférence de formulaire distincte de la paire guidée explicite |
| Important | Grammaire mains-libres ouvrant le micro sans consigne | AudioDirector joue consigne et prompt avant signal/micro sur chaque carte |
| Important | Négation française correcte avec je rejetée | Consigne première personne localisée et réponse complète acceptée sans perdre le contrôle de négation |
| Important | Continuer du verdict inutilisable au clavier | Bouton focalisable et parcours saisie/Entrée/verdict/avance |
| Important | Texte du bouton et rappel insuffisamment contrastés | Encre contrastée sur le fond réel des deux verdicts |
| Important | Rendu audio A tardif rattaché au mot désormais B | CAS centralisé sur mot/langue/état actif, résultat confirmé avant ready |
| Important | Chemin audio canonique retourné mais ignoré dans SQLite | Réconciliation locale conditionnée au contenu rendu, sans nouvel envoi |
| Important | Suppression locale d'un mot gardant sa progression | Nettoyage transactionnel des progrès, tombstones encore à envoyer |
| Important | Résultat système partiel notant une phrase grammaticale tronquée | Partiels affichés, verdict réservé à un résultat final, expiration sans revalidation du partiel |
| Important | Import froid écrivant sous propriétaire vide avant le profil | Identité locale résolue avant repository, gardes d'écriture sans compte et navigation froide testée |
| Important | Reconnaisseur système réseau présenté comme tentative locale | Capacité embarquée vérifiée et option locale obligatoire, secours documenté sinon |
| Important | Erreur Storage assimilée à une absence déclenchant un rendu facturé | Absence confirmée distincte d'une panne, arrêt avant quota/fournisseur sur erreur |
| Important | Déploiement incluant un index local non versionné | Snapshot d'un commit validé et liste versionnée des fonctions autorisées |
| Important | Profil enrichi relançant le pull et échec initial sans retry réseau | Restauration partagée par session, état à réessayer et reprise au réseau |
| Important | Tombstone de concept laissant le compteur de liste incorrect | Recalcul dérivé transactionnel malgré les métadonnées locales conservées |
| Important | Segments Whisper du tour quitté restant en file | Annulation de tour et abandon des segments périmés, inférence engagée toujours sérialisée |

Le rattachement audio côté serveur et l'application du chemin canonique côté
client restent deux constats distincts : leurs symptômes et corrections ne
sont pas équivalents.

La Suggestion précise la portée réelle de `theme_sweep_test`, qui monte
notamment l'ancien HomeScreen et ne prouve pas tous les contrastes du plateau
V3 actif. Elle est traitée dans ce lot documentaire.

Les sept checks GitHub et Android sont verts sur `f7827da`. Le contrôle du bot
en lecture seule confirme aussi leur workflow, événement d'origine, PR et
SHA de tête/base. Aucune approbation n'est publiée : six itérations complètes
restent bloquées et les quatre compteurs propres sont à zéro. Le prochain
commit sera relu à l'itération **7**, avec le plafond de vingt conservé.

Validation finale du lot : **988 tests hôte réussis**, huit diagnostics
positifs exclus de la passe normale, couverture **69,3 %** (11 956 / 17 248
lignes). Les 21 diagnostics ciblés passent avec opt-in ; la sonde AOT refuse
toujours les diagnostics en mode produit. Analyse Flutter, licence,
formatage, actionlint et zizmor propres. Les tests ciblés comprennent 127 cas
data et 254 cas voix/grammaire/widgets ; Kotlin compile. Les 24 tests Deno,
sept bundles Edge figés et 30 tests Python passent. Le contrat SQL 014 est
inchangé depuis les six suites PostgreSQL 16.11 et la concurrence validées
dans le lot précédent, également vertes dans la CI de `f7827da`.

Aucun backend n'est déployé. Le script de déploiement exige le SHA complet
de `origin/main` récupéré et utilise uniquement son manifeste, ses sources,
son verrou et sa sonde. Le contrôle de la CI et des revues de ce SHA reste
une vérification explicite de l'opérateur, pas une attestation inventée par
le script.

## Septième itération — `4dec70c`

Les quatre profils ont rendu `BLOQUÉ` sur
`4dec70c367e45a038d7485b6ebbc3737f261c12e` avant toute correction.
Leurs 23 observations Important correspondent à **22 constats distincts** :
la finalité du pont PCM est signalée par correction et qualité. Aucun
Bloquant et une Suggestion sont remontés. Les deux déclencheurs manquants
du bootstrap — lien froid et changement de paire — gardent chacun leur preuve.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Pont PCM étiquetant un partiel final après erreur/résultat vide | Finalité conservée Kotlin/canal/adaptateur, vocabulaire tolérant et grammaire finale uniquement |
| Important | Démarrage système différé après annulation immédiate | Vérification avant start, run/cancel avant vidage de la file |
| Important | Reconnexion perdue pendant le pull qui finit en erreur | Retour réseau mémorisé et nouvelle restauration avant push |
| Important | Pull partiel rétablissant un compteur distant périmé | Compteur local conservé si la lecture de ses concepts échoue |
| Important | Lien initial livré par API et stream démarrant deux imports | Dispatcher partagé, replay initial ignoré, lien à chaud distinct conservé |
| Important | Quiz A gardé visible et écrit sous B après remplacement du compte | Compte capturé, invalidation et arrêt des opérations sur changement d'identité |
| Important | Paire d'en-tête nouvelle sans abonnement au seeding | Bootstrap commun observé et attente du réglage restauré, vraie action d'en-tête testée |
| Important | allDue répétant une seule échéance vingt fois | Limite comme plafond, remplissage de pratique de liste conservé |
| Important | Consigne ne nommant pas la particule attendue | Formes de thème explicites dans les trois locales, écran et voix |
| Important | a/an imposé aux noms indénombrables | Exceptions zéro article via le contrat existant ; Salutations ajouté aux prérequis avec cinq noms minimum |
| Important | Splash paysage et verdict à texte doublé débordants | Squelette adapté et défilement annoncé, Continuer atteignable |
| Important | Résumés affirmant à tort une capture unique pour le moteur exclusif | Décodeurs PCM partagés et reconnaisseur système exclusif distingués |
| Important | HTTP 404 Storage ambigu autorisant un rendu facturé | Métadonnées GET et NoSuchKey explicite exigés, avant et après bail |
| Important | Travail Storage dépassant le bail audio | Échéance HTTP commune de 60 s, bail de 90 s conservé sur issue incertaine |
| Important | Session compilée TEST_SESSION encore restaurée | Injection retirée du point d'entrée, refus Patrol conservé |
| Important | Corpus/logs de diagnostic éligibles au backup Android | Exclusions cloud et transfert, anciens Android et 12+, manifestes fusionnés vérifiés |
| Important | Tombstone reporté considéré comme restauration terminée | Restauration incomplète et vraie reconnexion appliquant la suppression |
| Important | Bootstrap hors ligne créant un doublon starter serveur historique | Identité catalogue/compte/paire, adoption transactionnelle et protection des historiques divergents |
| Important | Import froid sautant le seeding du splash | SessionBootstrap au-dessus du routeur, import et bootstrap observés ensemble |
| Important | Signal de fin émis pendant que le micro capture encore | Fermeture confirmée distincte de l'activité des décodeurs, ordre des signaux testé |
| Important | Préférence STT changeant entre préparation et retry | Réglage initial attendu et mode capturé pour tout le tour |
| Important | Échec TTS mains-libres laissant la lecture bloquée | Attente bornée, nettoyage et reprise explicite via Répéter |

Le rapprochement starter a aussi révélé un cas introduit par cette correction :
un quiz déjà chargé garde les anciens IDs. Les alias par compte sont écrits
dans la transaction d'adoption et résolus au moment de noter, journaliser et
enregistrer le bilan. La régression charge le brouillon avant adoption puis
fait passer la progression canonique existante de trois à quatre révisions.
Les historiques FSRS réellement divergents restent conservés, sans fusion
inventée ni double publication du brouillon.

Suggestion conservée : borner et mesurer les projections GROUP_CONCAT par
compte avant une optimisation plus large. Les ACK de statut seuls restent
silencieux ; cette Suggestion n'est pas présentée comme une correction faite.

### Décision pédagogique — 27 novembre

Après correction des indénombrables, starter-food fournit trois noms éligibles
pour a/an, alors que la règle en exige cinq. L'utilisateur choisit explicitement
d'ajouter starter-greetings et de conserver le seuil de cinq : les deux listes
fournissent sept noms éligibles dans les sens enseignés. Le contenu utilise
les overrides existants, sans nouvelle mécanique ni extension des tags de genre.

### Validation du lot courant

La suite complète finale passe : **1 013 tests**, huit diagnostics positifs exclus,
couverture **70,6 %** (12 511 / 17 710 lignes). L'analyse Flutter est propre ;
les 21 diagnostics ciblés passent avec opt-in. Les 28 tests Deno et les sept
bundles Edge figés passent. Kotlin et la fusion des manifestes/ressources
debug et release sont vérifiés. Les 129 cas data et les contrôles conjoints
de rapprochement/quiz passent, ainsi que les widgets paysage, texte doublé,
en-tête et import froid. Le gate seed/grammaire passe **63 tests**, dont la
régression sur le minimum réel anglais : sept noms éligibles, plus restaurant
dans la catégorie lieu, et huit réponses exactes générées sans indénombrable.

Les sept checks GitHub et Android sont verts sur `4dec70c`. Le bot confirme
leur provenance en lecture seule, sans approbation. Sept itérations complètes
restent bloquées ; les quatre compteurs sont à zéro. La prochaine relecture
sera l'itération **8**, après un commit commun complet, avec le plafond de
vingt conservé. Aucun service hébergé n'est modifié.

## Huitième itération — `9031dcc`

Les quatre profils ont rendu `BLOQUÉ` sur
`9031dccaedd9267ecf197ed29ffcdf196e332d5b` avant toute correction.
Leurs 16 observations Important correspondent à **15 constats distincts** :
l'arrêt PCM non confirmé est signalé par qualité et correction. Aucun
Bloquant et une Suggestion sont remontés. Les compteurs propres restent à
zéro ; le prochain commit commun sera relu à l'itération **9**, avec le
plafond de vingt conservé.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Retour depuis une liste importée à froid sans route précédente | Repli bibliothèque, vrai détail froid et retour contextuel à chaud testés |
| Important | Aperçu réel de leçon débordant à texte doublé | Défilement annoncé, bouton de pratique atteint à 320 × 568 |
| Important | Phases mains-libres trop hautes en paysage | Surface entière adaptable, compte à rebours et écoute à 568 × 320, texte doublé |
| Important | Pause et reprise inaccessibles au clavier | Commandes focalisables localisées, contrôles masqués exclus du focus |
| Important | Traduction envoyant un thème null refusé par le service | Champ optionnel omis, corps HTTP réel testé |
| Important | Suggestions chargeant toutes les variantes en N+1 et dépassant les limites | Contexte groupé et borné, garde de sérialisation côté client |
| Important | Ajout multiple de suggestions masquant les refus de quota | Résultats conservés, sélection restante et accès abonnement testés |
| Important | Reconnexion perdue pendant un envoi qui échoue | Réveil mémorisé pour une nouvelle tentative, sans boucle de panne autonome |
| Important | Arrêt PCM en erreur ou bloqué assimilé à un micro fermé | Attente bornée, échec propagé, capture en quarantaine et reprise explicite |
| Important | Historique starter écrasé malgré des IDs déjà identiques | Détection du conflit avant libération du brouillon, progression locale préservée |
| Important | Détail ouvert et écritures conservant des IDs adoptés périmés | Flux réactifs aux alias et destination canonique validée dans la transaction |
| Important | Signal de début avant la préparation du moteur | Préparation attendue avant le signal, au premier tour et à la reprise |
| Important | Refus natif TTS retournant zéro considéré comme une lecture | Accusé vérifié, langue mémorisée après succès, refus récupérable sans micro |
| Important | Publication Appetize disponible avant décision de distribution | Envoi externe retiré ; artefact CI conservé pour les validations internes |
| Important | Ancienne politique Storage lisible entre migrations 007 et 012 | Fermeture restrictive initiale, activation atomique et test SQL intermédiaire |

La Suggestion sur le pluriel anglais de kimchi reste un travail de contenu
séparé à faire relire ; elle n'est pas présentée comme une correction livrée.
Elle ne modifie ni le seuil de cinq ni les prérequis anglais décidés par
l'utilisateur.

Validation du lot : **1 036 tests hôte réussis**, huit diagnostics positifs
exclus de la passe normale, couverture **71,4 %** (12 806 / 17 943 lignes).
Les 21 diagnostics ciblés passent avec opt-in et la sonde AOT confirme le
refus en mode produit. Les 131 tests data ciblés, les imports froid et chaud,
le vrai contenu grammatical à texte doublé et les nouveaux cas voix/clavier
passent. PostgreSQL 16.11 valide le nouveau sas Storage intermédiaire, les
six suites finales, deux connexions de reset et le script d'activation avec
réapplication et rollback. Les 30 tests Python, la frontière de licence,
actionlint et zizmor passent. Aucun backend ni publication externe n'est activé.

## Neuvième itération — `be081c8`

Les quatre profils ont rendu `BLOQUÉ` sur
`be081c8404577c1df8ed0ae688c7e0d4cb984523` avant toute correction.
Leurs 11 observations Important correspondent à **10 constats distincts** :
la fermeture PCM au démontage est signalée par qualité et correction. Aucun
Bloquant et une Suggestion sont remontés. Les quatre compteurs propres
restent à zéro ; le prochain commit sera relu à l'itération **10**, avec
le plafond de vingt inchangé.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Commandes Retour sans nom accessible | Libellés localisés et arbre sémantique du parcours réel vérifiés |
| Important | Titres longs ou agrandis rognés par la barre d'application | Titres dans le contenu défilant, dernière ligne et titre grammatical accessibles |
| Important | Prérequis absent affichant son identifiant technique | Repli catalogue en FR/EN/KO et nom résolu conservé si les statistiques échouent |
| Important | Complément du catalogue ressuscitant un starter supprimé | Tombstones inclus et IDs déterministes partagés avec l'import, deux SQLite vérifiées |
| Important | Retour système lançant un arrêt micro non géré | Nettoyage sûr au démontage, refus et arrêt bloqué testés |
| Important | Moteur système exclusif non libéré avant verdict ou changement de voie | Accusé d'arrêt conservé, échec propagé et nouvelle écoute bloquée jusqu'au nettoyage |
| Important | Événement d'un brouillon créé pendant le push publié trop tôt | Éligibilité et candidats dans le même snapshot, ACK conditionnel et réexpédition canonique |
| Important | Politique Storage permissive contournant l'activation finale | Garde restrictif final et politique permissive historique conservée dans le test |
| Important | APK téléversé dans les artefacts d'un dépôt public | Workflow de compilation sans publication binaire, usage privé local documenté |
| Important | Planification Patrol active avant isolation hébergée | Verrou fermé par défaut et vérification en lecture seule avant tout reset |

Suggestion conservée : le publieur audio administrateur devrait distinguer
une absence Storage confirmée d'une panne avant tout rendu facturé. Cette
amélioration ne fait pas partie des corrections revendiquées dans ce lot.

Les sept checks GitHub, dont Android natif, sont verts sur `be081c8`.
Ils ne constituent pas une convergence des agents ni une autorisation
d'activation du backend hébergé.

Validation du lot : **1 052 tests hôte réussis**, huit diagnostics positifs
exclus sans opt-in, couverture **72,1 %** (12 978 / 18 011 lignes).
L'analyse Flutter est propre ; les 21 diagnostics ciblés passent avec opt-in.
Les tests ciblés comptent 73 cas data, 57 cas interface/grammaire et 213 cas
voix/quiz/thèmes, dont les retours système et les transitions entre moteurs.
Les huit tests Python E2E et les 25 tests Python bot/déploiement passent.
PostgreSQL 16.11 valide les refus E2E après 009 et 012, le sas Storage après
007, les six suites finales avec règle permissive préexistante, la désactivation
d'un déclencheur d'isolation, deux connexions de reset et le bundle d'activation.
Actionlint, zizmor et la frontière de licence passent. Aucune variable
d'activation ni modification hébergée n'est appliquée.

## Dixième itération — `9735b9c`

Les quatre profils ont rendu `BLOQUÉ` sur
`9735b9cc41145daf28385d292f33739d0a54e4a5` avant toute correction.
Leurs 17 observations Important correspondent à **16 constats distincts** :
l'acquittement système prématuré est signalé par qualité et correction.
Aucun Bloquant ni Suggestion n'est remonté. Les compteurs propres restent
à zéro ; le prochain commit sera relu à l'itération **11**, sur vingt au maximum.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Feuille validée contredite par le configurateur complet | Comparaison des deux maquettes puis choix utilisateur 2/2 : feuille Quoi/Sens/Mode depuis le plateau |
| Important | Libellé bidirectionnel FR/KR pour d'autres paires | Libellé neutre localisé, arguments de lancement et trois paires vérifiés |
| Important | Motif de verrouillage du configurateur montrant des IDs | Résolution partagée avec le hub, nom renommé et repli catalogue en FR/EN/KO |
| Important | Navigation sans clavier/état sélectionné et texte réduit | Boutons focalisables, sémantique et barre à hauteur intrinsèque à 320 px/texte doublé |
| Important | Procédure U6 obsolète et U7 encore annoncée bloquée par P3 | Audit de clusters, décision anglaise conservée et rédaction U7 distinguée du schéma livré |
| Important | Acquittement du plugin système avant arrêt natif | Pont de session avec événement de libération distinct, réponse canal anticipée et mauvaise session testées |
| Important | Page réseau pendante bloquant restauration et reprise | Échéance à la frontière distante et état incomplet récupérable |
| Important | Configuration TTS pendante bloquant chaque Répéter | Barrière d'arrêt et nouvelle génération indépendante d'un ancien retour |
| Important | Réservation malveillante d'IDs déterministes d'un autre compte | Namespace serveur par propriétaire et parents qualifiés, isolation locale lors du changement de compte |
| Important | Statuts audio différents révélant une variante privée | Recherche active par propriétaire, même 404 sans quota ni fournisseur |
| Important | Chemins Git accentués échappant au garde de corpus | Lecture NUL commune, index/diff avec accents et saut de ligne testés |
| Important | Hook ignoré sur Unix faute de bit exécutable | Mode 100755, LF et vrai commit de contrôle sous Windows et en CI Unix |
| Important | Phonétique française validant cat/cap en anglais | Langue de réponse explicite en écrit et dans les deux voies STT |
| Important | Session due bidirectionnelle arrêtée à la moitié disponible | Remplissage depuis le sens disponible sans doublon, vingt cartes dues testées |
| Important | Notifications comparant des fuseaux différents | Fuseau effectif et jours calendaires, Paris/UTC et deux transitions DST testés |
| Important | Synonyme parlé ne correspondant pas au clip principal | Même variante pour texte et chemin audio, synonymes toujours acceptés |

Le choix de feuille est confirmé par l'utilisateur le 27 novembre, après
prévisualisation interactive. La nouvelle capture système iOS est compilée
par un job macOS simulateur sans signature, secret ni publication ; ce
check rejoint les validations obligatoires du bot et de la protection main.
Les sept anciens checks GitHub sont verts sur `9735b9c` ; la nouvelle CI
et la convergence restent à obtenir sur le prochain commit complet.

Validation locale du lot : **1 075 tests hôte réussis**, huit diagnostics
positifs exclus sans opt-in, couverture **72,9 %** (13 386 / 18 358 lignes).
Analyse Flutter propre ; les 21 diagnostics ciblés passent avec opt-in et
la sonde AOT refuse les diagnostics en mode produit. Les 183 tests data
ciblés et les régressions de feuille/clavier/prérequis passent. La passe
voix/audio compte 331 réussites ; son seul échec initial venait du fixture
de notifications, dont les 17 tests passent après correction. Kotlin compile.
Les 36 tests Python, 29 tests Deno et sept bundles figés passent.

PostgreSQL 16.11 valide les sept suites finales, les sas intermédiaires,
le reset sur deux connexions et le bundle d'activation avec rejet de
réapplication. Une base historique garde ses tombstones, ses 14 révisions
FSRS intercompte et son défi après 015 ; une base orpheline est refusée
atomiquement. Le test SQLite ouvre successivement deux comptes dans le
même fichier puis rouvre le repository : les objets locaux restent isolés,
les écritures, événements et chemins audio gardent les bonnes clés distantes.
L'exécution Unix du hook et la compilation iOS restent à confirmer en CI.

## Onzième itération — `f5f5949`

Les quatre profils ont rendu `BLOQUÉ` sur
`f5f594923334c3a8d9f467585b8afdf8e42cdb7b` avant toute correction.
Leurs 14 observations Important correspondent à **13 constats distincts** :
le comptage de la feuille dans un sens vide est signalé par produit et
correction. Aucun Bloquant et deux Suggestions sont remontés. Les quatre
compteurs propres restent à zéro ; la prochaine relecture sera l'itération
**12**, avec le plafond de vingt conservé.

| Type | Constat regroupé | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Feuille lançant un sens/source sans carte et affichant un faux plafond | Comptage réactif commun aux prédicats du chargeur ; état vide avec Réessayer/Retour, sans bilan artificiel |
| Important | Clés brutes dans les locales proposées hors V0 | Configuration de localisation partagée avec repli FR activé ; trajet japonais réel plateau/feuille testé |
| Important | Titre long empêchant la lecture des mots de l'aperçu | Titre et mots dans un défilement commun paresseux à texte doublé |
| Important | Texte inactif de navigation insuffisamment contrasté | Encre secondaire lisible et mesure des cinq libellés dans les deux thèmes |
| Important | Écriture ou lecture d'ACK pendante bloquant envois et partage | Échéance distante, ligne non acquittée, partage récupérable et reprise réseau testés |
| Important | Délais par liste cumulant plusieurs minutes de restauration | Budget global de quinze secondes, arrêt des nouvelles lectures après panne et données partielles conservées |
| Important | Indicateur de scroll absent après chargement tardif | Notifications de métriques et redimensionnement traités sans geste |
| Important | Prévol E2E acceptant le schéma 013 incompatible avec le binaire | Nouveau contrat exact owner-scoped-v1 requis par clients et reset ; refus 013/014, succès 015 |
| Important | Diagnostics iOS inclus dans les sauvegardes | Exclusion Foundation posée et relue avant écriture, réappliquée aux deux dossiers existants |
| Important | Jeton supabase/.env.deploy accepté après ajout forcé | Refus local et PR du fichier réel, modèle .example conservé |
| Important | Starter établi remis en quarantaine après édition/révision hors ligne | Identité reconnue durable, vrais brouillons divergents toujours retenus |
| Important | Rendu audio différé exécuté sous le compte suivant | Propriétaire capturé vérifié à l'appel et à l'attachement, deux rendus suspendus testés |
| Important | Annulation de rappel dépassée par une résolution tardive du fuseau | Générations et commandes natives ordonnées par ID, annulations quotidiennes/série/globales testées |

La Suggestion sur l'inventaire des tests est traitée : les trajets du plateau,
de la feuille et des cinq onglets remplacent les anciens contrôles de l'accueil.
La Suggestion sur le coût des réservations unitaires d'alias reste conservée
pour une optimisation mesurée, sans correction revendiquée dans ce lot.

### Échec déterministe iOS du même candidat

Les sept anciens checks CI sont verts sur `f5f5949`, y compris le vrai hook
Unix et le PostgreSQL jetable. Le nouveau build simulateur échoue à l'édition
des liens : `Framework 'Pods_Runner' not found`. Le projet utilisait une
intégration CocoaPods non versionnée et la migration SwiftPM automatique.
Le lot versionne le Podfile et les inclusions Debug/Profile/Release, puis
choisit explicitement CocoaPods. Le prochain check macOS devra confirmer
la correction ; aucun contournement du check obligatoire n'est introduit.

Validation du lot : **1 092 tests hôte réussis**, douze diagnostics positifs
exclus sans opt-in, couverture **73,6 %** (13 681 / 18 585 lignes).
L'analyse Flutter est propre ; les 25 diagnostics ciblés passent avec opt-in
et la sonde AOT refuse les diagnostics en mode produit. Les 190 tests data
ciblés passent. Le trajet japonais utilise la configuration réelle de
localisation ; les tests de mots accessibles après un très long titre,
de contraste et de métriques de scroll passent sans geste initial requis.
La passe voix/notifications compte 44 réussites avec opt-in et 24 sans.

PostgreSQL 16.11 valide les sept suites, les refus de reset après 009, 012,
013 et 014, le contrat après 015, la concurrence à deux connexions et le
bundle d'activation avec rejet de réapplication. Les 37 tests Python,
actionlint, zizmor et la frontière de licence passent. Les fonctions Edge
restent inchangées depuis les 29 tests Deno et sept bundles figés validés.
La configuration iOS est vérifiée statiquement ; son édition des liens
et le contrôle de la nouvelle exclusion native attendent la CI macOS.

## Douzième itération — `90a8298`

Les quatre verdicts `BLOQUÉ` portent sur
`90a8298266ea567d89a4076b269bff2f82b1fcdc` et ont été réunis avant le lot
de corrections. Aucun Bloquant ; **14 Important bruts, 11 distincts**, et
deux Suggestions. Les doublons concernent l'ordre des écritures après délai,
la reprise de restauration et la sélection asymétrique de cartes.

| Profil / instance | Important | Suggestion |
| --- | --- | --- |
| Produit — `/root/r12_product` | 5 | 0 |
| Qualité — `/root/r12_quality` | 3 | 1 |
| Correction — `/root/r12_correctness` | 4 | 0 |
| Sécurité — `/root/r12_security` | 2 | 1 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Écriture expirée arrivant après l'ACK d'une version récente | Séquence SQLite durable par installation et garde transactionnel serveur 016 ; anciennes métadonnées/FSRS refusés, autre appareil et rôle audio préservés |
| Important | Restauration recommençant au même préfixe | Checkpoint SQLite par compte, validé avec les pages appliquées ; 25 listes et pages listes/concepts/FSRS repris après réouverture réelle |
| Important | Comptage et chargeur divergents, répétitions dans la feuille | Cartes distinctes dans la feuille, remplissage des deux sens et des cartes planifiées ; liste 1 due/9 futures et six cartes d'un seul sens testées |
| Important | Compteur quotidien incluant une question sans réponse active | Prédicat de carte jouable partagé ; retrait/réajout de réponse réévalue le compteur |
| Important | Rappels absents de la véritable route V3 | Bootstrap authentifié après restauration des préférences ; vrai trajet splash/plateau, heure enregistrée et annulation après activité testés |
| Important | Commandes de saisie dépassant le clavier en paysage | Contenu et commandes défilants à faible hauteur, champ stable ; 568 × 320, inset 180 et texte doublé avec validation effective |
| Important | Credentials administratifs transmis lors de redirections | Origine HTTPS et refus de redirection Python/Node ; cible sans requête, deux formats de clé et cinq statuts couverts |
| Important | Écritures Storage clientes via une ancienne règle permissive | Gardes restrictives par opération dans le bucket audio, fermeture intermédiaire 007 ; vrai rôle client avec FOR ALL préexistant et autres buckets testés |
| Important | Entrées Bibliothèque perdant le retour du chemin | Navigation poussée pour les deux entrées ; retour AppBar de la véritable bibliothèque testé |
| Important | Accueil/authentification sans activation clavier | Boutons standards ; deux parcours accueil/formulaire/validation réalisés avec Tab/Entrée |
| Important | État du projet obsolète sur Podfile et APK | Paragraphes actifs corrigés : CocoaPods versionné, compilation sans artefact public et iOS encore à confirmer |

La Suggestion de liaison du check iOS à l'application GitHub Actions est
appliquée à la protection de `main` : les huit checks CI exigent l'application
15368. Le statut indépendant reste attesté par le propriétaire. La Suggestion
sur la durée de vie des observateurs de leçons et le coût de projection reste
conservée pour une optimisation mesurée.

Les sept autres checks CI sont verts sur `90a8298`, mais le build simulateur
échoue encore au lien `Pods_Runner`. Le lot aligne Runner et ses pods sur la
contrainte GoogleMLKit du seul SDK simulateur, sur le runner Intel existant.
Le SDK iPhone garde ses architectures. La prochaine CI macOS doit confirmer
l'édition des liens ; aucune compilation iOS réussie n'est revendiquée.
Les compteurs propres sont **0/2 pour les quatre profils**. La prochaine
relecture complète sera l'itération **13**, dans la limite de vingt.

Les validations ciblées comptent **208 tests data**, **71 tests voix/quiz/
notifications** et **17 tests d'accueil/authentification/retour** réussis.
PostgreSQL 16.11 valide neuf suites, les refus de reset jusqu'à 015, le contrat
016 et son refus lorsqu'une garde d'écriture est désactivée, la concurrence
à deux connexions et le bundle d'activation. Les dix tests Python E2E, le test
Node de redirection TLS, actionlint et zizmor passent. Aucun service hébergé
n'est activé ; les nouveaux clients Patrol exigent `write-order-v1`.

La suite complète du lot passe : **1 105 tests hôte**, douze diagnostics
positifs exclus sans opt-in, couverture **74,5 %** (13 966 / 18 739 lignes).
L'analyse Flutter est propre ; les 25 diagnostics ciblés passent avec opt-in
et la sonde AOT refuse l'accès en mode produit. Les 29 tests Python des outils
s'ajoutent aux dix tests E2E, soit 39 tests Python réussis. Les fonctions Edge
restent inchangées depuis leurs 29 tests Deno et sept bundles figés validés.

## Treizième itération — `5c9d0f0`

Les quatre instances ont rendu `BLOQUÉ` sur
`5c9d0f0b09e255b24b7f786ca584df9daa121143` avant toute correction.
Les **17 Important bruts donnent 12 constats distincts**. L'ACK d'import,
le rattrapage de restauration et l'arrêt audio apparaissent dans deux
rapports ; le rappel de série apparaît dans trois rapports. Aucun Bloquant
et trois Suggestions. Les compteurs propres restent **0/2** ; la prochaine
passe sera l'itération **14**, sans dépasser vingt.

| Profil / instance | Important | Suggestion |
| --- | --- | --- |
| Produit — `/root/r13_product` | 6 | 2 |
| Qualité — `/root/r13_quality` | 4 | 0 |
| Correction — `/root/r13_correctness` | 5 | 0 |
| Sécurité — `/root/r13_security` | 2 | 1 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | ACK d'import sans consommation de séquence | PATCH versionné limité au protocole, sans remplacer les métadonnées ; ancien PATCH livré après ACK rejeté |
| Important | Checkpoint déclarant un succès avec un préfixe devenu périmé | Journal 017 par compte et rattrapage borné/persistant ; suppression et insertion derrière curseur, SQLite rouvert pendant le rattrapage |
| Important | Rappel de série après logout ou activité locale | Annulation immédiate et invalidation des programmations en vol ; historique local écrit avant réseau et consulté après redémarrage, isolation entre comptes |
| Important | Échec d'arrêt audio absorbé avant écoute | Erreur remontée et reprise explicite ; widget vérifie l'absence de signal et de STT pendant refus/timeout |
| Important | Messages d'authentification bruts ou français | Motifs indépendants de langue et traduction UI ; vrais refus HTTP Supabase et formulaires FR/EN/KO vérifiés |
| Important | Clavier/Révéler et saisie Voix inaccessibles | Boutons focalisables, défilement compact et champ stable ; clavier physique et paysage avec inset 180/texte doublé |
| Important | Notifications anglaises et drapeaux fixes | Textes FR/EN/KO neutres pour la paire, intention réservée avant chargement asynchrone et reprogrammation au changement de locale |
| Important | Cartes des deux sens présentées comme des mots | Libellés cartes dans les trois locales ; un concept SQLite dû dans deux sens affiché comme deux cartes sur plateau et chemin |
| Important | Spécification STT sans Podfile | Document corrigé : CocoaPods est versionné, le pont Whisper iOS reste à livrer |
| Important | Série rompue au changement d'heure | Dates civiles dans le calcul partagé ; vrais appels HTTP de fin de quiz aux deux transitions Paris enregistrent la série continue |
| Important | Référence FSRS servant d'oracle privé | Garde 018 avant FK, même SQLSTATE/message pour privé/inexistant ; références propres/publiques et historiques existants préservés |
| Important | DELETE physique effaçant tombstones et historiques | Droits clients révoqués et défense RLS ; trois tombstones, rejeu tardif, FSRS d'un autre compte, reset autorisé et purge serveur testés |

La Suggestion sur le nombre de tests répété dans l'inventaire est traitée en
renvoyant au statut courant sans recopier de métrique volatile. L'accord
féminin de l'exemple espagnol reste à examiner lors de la relecture native
du contenu ; aucune correction de seed n'est revendiquée. La Suggestion
d'identité dédiée pour l'approbation est consignée comme préalable à tout
nouvel accès en écriture : le propriétaire reste actuellement seul.

### Première compilation iOS réussie

Les **huit checks CI sont verts** sur `5c9d0f0`. Le simulateur iOS termine
en 18 min 02 s après l'alignement des architectures Runner/Pods pour MLKit.
Cette preuve couvre la compilation native de l'application, pas Whisper
local iOS ni une exécution sur appareil. Chaque nouveau commit reste soumis
aux huit contrôles et à la convergence complète ; ces résultats ne sont pas
réutilisés pour approuver un autre SHA.

Les 89 tests data ciblés et les 74 tests auth/date/cartes passent. Les 122
tests voix/rappels initiaux, puis les 80 tests du complément de redémarrage
passent ; ces périmètres se recouvrent et ne sont pas additionnés. Le test du
vrai quiz recrée un container sur le même fichier SQLite avec le profil
périmé et le réseau suspendu, puis vérifie qu'un autre compte reste distinct.

PostgreSQL 16.11 valide onze suites, le refus du contrat jusqu'à 017,
l'acceptation après 018, les gardes désactivées et droits DELETE/TRUNCATE
réintroduits, le reset concurrent à deux connexions et l'activation atomique
avec rejet de réapplication. Le dernier rerun couvre aussi le tombstone
synthétique sans contenu privé pour une suppression administrative dans le
journal 017. Les dix tests Python E2E et les 29 tests des outils passent,
ainsi qu'actionlint et zizmor. Le contrat exact est `progress-boundaries-v1` ;
aucune activation hébergée n'est revendiquée.

La validation finale du lot passe : **1 139 tests hôte**, douze diagnostics
positifs exclus sans opt-in, couverture **74,9 %** (14 124 / 18 852 lignes).
L'analyse complète est propre. Les 25 diagnostics ciblés passent avec opt-in
et la sonde AOT refuse toujours les diagnostics en mode produit. Une première
passe complète était déjà verte ; elle a été répétée après le complément
durable du rappel, qui réutilise l'historique SQLite existant au lieu d'un
second stockage de journées. Les fonctions Edge restent inchangées depuis
leurs 29 tests Deno et sept bundles figés validés.

## Quatorzième itération — `6a1ec29`

Les quatre instances ont rendu `BLOQUÉ` sur
`6a1ec2918f84ec4126ffe9c6378f86bfd0697930` avant le lot de corrections.
Les **15 Important bruts donnent 14 constats distincts** : le départ du bilan
avant écriture est commun aux rapports produit et correction. La date de
série franchissant minuit reste un constat distinct. Aucun Bloquant et deux
Suggestions. Compteurs propres **0/2**, prochaine passe **15**, plafond vingt.

| Profil / instance | Important | Suggestion |
| --- | --- | --- |
| Produit — `/root/r14_product` | 6 | 1 |
| Qualité — `/root/r14_quality` | 3 | 1 |
| Correction — `/root/r14_correctness` | 3 | 0 |
| Sécurité — `/root/r14_security` | 3 | 0 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | FSRS orphelin ignoré lorsque son contenu change de fenêtre | Lignes et baseline CAS conservées dans SQLite puis rejouées ; deux fenêtres et réouverture du fichier testées |
| Important | Purge antérieure au parcours complet absente de l'inventaire | Inventaire paginé mêlant listes et purges synthétiques ; anciens checkpoints et cache préexistant testés |
| Important | Résultat A remplaçant/dépilant l'import B | Résultat retenu dans sa propre route jusqu'à visibilité ; succès et échec de A avec B ouvert testés |
| Important | Micro actif sous un import | Visibilité réelle des routes interne et racine, interruption et reprise conditionnelle ; vrai import/détail/retour avec cycle de vie testés |
| Important | Sortie ou relance annulant une séance terminée | Compte et métadonnées capturés avant attente, persistance indépendante de l'écran ; maîtrise suspendue, sortie/relance et réouverture SQLite testées |
| Important | Série attribuée au lendemain après GET tardif | Jour civil capturé transmis avec le compte, garde de compte et filtre de date ; GET franchissant minuit et date distante plus récente testés |
| Important | Bip/micro avant configuration du prompt | Résultat du prompt courant attendu, échec récupérable ; configuration native retenue au-delà de 2,5 s testée |
| Important | Transcription repoussant les commandes Voix | Corps complet défilant avec signal, transcription longue et commandes atteignables en paysage/texte doublé |
| Important | Micro non focalisable et non nommé | Vrai bouton et libellés FR/EN/KO, activation Tab/Entrée et sémantique vérifiées |
| Important | Reset affichant une adresse introuvable pour tout refus | Motifs réseau/429 conservés, autres échecs neutres ; vrai HTTP et trois locales UI vérifiés, durée de vie du champ de dialogue corrigée |
| Important | Choix sous le bord des feuilles sans signal | Affordance partagée ; six tests paire/mode FR/EN/KO à 568 × 320/texte doublé avant geste |
| Important | JWT rejetant la clé moderne du publieur | `verify_jwt=false` limité au publieur admin, TOML réellement transmis à la CLI vérifié |
| Important | Défi révélant le propriétaire d'une liste privée | Garde 019 avant résolution, même refus privé/supprimé/inexistant ; références qualifiées/non qualifiées et historiques testés |
| Important | Reset ouvert sur les migrations intermédiaires | Droit client retiré jusqu'à 019 ; huit appels inscrits réellement refusés avec données conservées, puis reset autorisé et garde désactivée refusée |

Les Suggestions sont traitées dans le lot : l'ultime sonde stable n'effectue
plus l'instantané local complet, et U8 précise les quatre règles françaises
A1 déjà rédigées en coréen, encore à relire nativement. Aucun seed n'est régénéré.

Les huit checks CI sont verts sur `6a1ec29`, dont Android en 10 min 01 s et
le simulateur iOS en 7 min 42 s. La convergence reste requise indépendamment
de ces résultats ; un nouveau commit devra obtenir sa propre CI et ses revues.

Les cibles passent : 129 tests data, 150 tests de complétion/auth, 89 tests
audio/quiz/import, 34 tests UI auth/reset/import et six tests des feuilles.
Ces ensembles se recouvrent et ne sont pas additionnés. PostgreSQL 16.11
valide douze suites, les huit refus de reset intermédiaires avec données
préservées, le sas 019 et sa garde désactivée, la concurrence à deux connexions
et l'activation atomique avec refus de réapplication. Le contrat exact devient
`challenge-boundaries-v1` ; aucun changement hébergé n'est effectué.

Les cinq tests de déploiement, dix tests Python E2E, 29 tests Deno et sept
bundles passent, ainsi qu'actionlint et zizmor. Le publieur conserve son
contrôle administrateur Supabase Auth avant tout appel fournisseur.

La suite finale du lot passe : **1 171 tests hôte**, douze diagnostics positifs
exclus sans opt-in, couverture **75,4 %** (14 277 / 18 929 lignes).
L'analyse complète est propre ; les trois anciens tests du micro ont été
adaptés au vrai bouton accessible et repassent avec les 25 diagnostics
positifs, soit 28 tests ciblés avec opt-in. La sonde AOT refuse les diagnostics
en mode produit. Les 30 tests Python des outils et les dix tests E2E passent,
soit **40 tests Python**. Le garde documentaire et le formatage restent
obligatoires avant le commit commun et la relecture 15.

## Quinzième itération — `2626f20`

Les quatre instances ont rendu `BLOQUÉ` sur
`2626f2080a49981052b153be08f985d61c2a0bb6` avant toute correction.
Les **19 Important bruts donnent 16 constats distincts** : la séance partagée
entre deux routes, la fermeture de la mauvaise route et la série concurrente
sont chacun communs aux rapports qualité et correction. Aucun Bloquant ni
Suggestion. Compteurs propres **0/2**, prochaine passe **16**, plafond vingt.

| Profil / instance | Important | Suggestion |
| --- | --- | --- |
| Produit — `/root/r15_product` | 4 | 0 |
| Qualité — `/root/r15_quality` | 5 | 0 |
| Correction — `/root/r15_correctness` | 5 | 0 |
| Sécurité — `/root/r15_security` | 5 | 0 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Manifeste Android Profile sans libellé | Libellé par défaut, suffixe développement en debug ; vraie tâche Gradle Profile réussie et ajoutée à la CI |
| Important | Série calculée sur un profil modifié entre lecture et écriture | Comparaison exacte des trois champs, relecture/recalcul bornés ; deux journées concurrentes produisent une série et un record de sept |
| Important | Dialogue de reset inaccessible avec clavier en paysage | Titre, formulaire et actions dans le défilement signalé ; envoi réel de formulaire FR/EN/KO à 568 × 320, texte doublé, inset 180 |
| Important | Bilan défilant sans indication | Affordance commune ; signal avant geste et deux actions atteignables en paysage à texte doublé |
| Important | Purges physiques de concepts/variantes ignorées par les caches | Identités minimales de purge exposées à l'inventaire initial et au delta ; cache et re-seeding ne réactivent pas leurs tombstones |
| Important | INSERT périmé recréant un identifiant purgé | Identités de purge durables, garde sérialisée avec suppression ; vrai rejeu concurrent bloqué puis refusé, ACK local convergent |
| Important | Installation ayant déjà appliqué l'ancien 017 non mise à niveau | Migration additive 020 ; fixture exacte de l'ancien 017 avec journal et données, puis 018–021 vérifiés |
| Important | Droit TRUNCATE survivant aux GRANT de review_events | Révocation exhaustive dès 012 et réparation en 021 ; droits effectifs du rôle authentifié vérifiés, sans prétendre à une route REST TRUNCATE |
| Important | Relation d'amitié forgeable ouvrant des listes privées aux amis | RPC authentifiés et consentement du destinataire ; anciennes relations visibles, nouvelle acceptation exigée pour l'accès, rejeu après retrait refusé |
| Important | Bail fournisseur libéré après une réponse STT incertaine | Bail conservé jusqu'au TTL après transport incertain ; nouveau départ refusé, réponse fournisseur définitive libérant le bail testée |
| Important | Quiz B remplaçant le quiz A recouvert | Séance par route ; vrai import puis détail puis quiz B puis retour A avec carte, score et pause conservés |
| Important | Quitter dépilant un import au lieu du quiz | Fermeture attachée à la visibilité de sa route ; arrêt suspendu puis import et retour testés |
| Important | Erreur native de lecture non traitée | Erreur propagée à l'attente, abonnement libéré ; vrai canal natif simulé et widget de reprise sans microphone vérifiés |
| Important | Remplacement du lecteur validant un prompt inachevé | Annulation distincte du succès et prompt rejoué sur le nouveau service ; aucun signal ni micro avant fin réelle |
| Important | Négation anglaise refusant les formes enseignées | Consigne première personne FR/EN/KO, formes avec/sans I et don't/do not acceptées en saisie et en voix ; variantes de be couvertes |
| Important | Pluriel coffee incohérent avec le sens commandable du catalogue | Exception lexicale et exemple explicites pour les portions commandées ; seuil/prérequis de a/an conservés |

Les huit checks CI sont verts sur `2626f20`. La tâche Profile réelle termine
en 35 secondes. Les 15 tests HTTP/date d'authentification, 66 tests auth/grammaire
et le bilan compact passent. Les 134 tests data et 152 tests voix/quiz passent ;
ces périmètres se recouvrent et ne sont pas additionnés.

PostgreSQL 16.11 valide quinze suites, les dix refus de reset intermédiaires
avec données conservées, le contrat `friend-consent-v1` en 021, le reset et la
purge concurrents à deux connexions, ainsi que l'activation atomique et son
refus de réapplication. La mise à niveau depuis le vrai 017 historique garde
le journal et ses données. Le journal des purges enfants commence en 020 ;
aucune reconstitution des suppressions enfants antérieures n'est revendiquée.
Les 31 tests Deno et sept bundles Edge passent. Aucun service hébergé n'est
activé.

La suite finale du lot passe : **1 197 tests hôte**, douze diagnostics positifs
exclus sans opt-in, couverture **75,6 %** (14 368 / 18 995 lignes). L'analyse
complète est propre. Les 28 tests diagnostics/micro passent avec opt-in et la
sonde AOT refuse les diagnostics en mode produit. Les 30 tests Python des
outils et dix tests E2E passent ; actionlint et zizmor ne signalent aucun
défaut. La gate élargie de contenu réussit 113 tests et les quatre JSON sont
valides ; les textes anglais révisés et la consigne coréenne restent à relire
nativement. La règle a/an et ses prérequis ne sont pas modifiés.

## Seizième itération — `284f468`

Les quatre instances ont rendu `BLOQUÉ` sur
`284f4687c99923ae334d4663fce6081203b0610c` avant toute correction.
Les **10 Important bruts donnent 9 constats distincts** : l'arrivée inversée
de deux journées de série est commune aux rapports qualité et correction.
Aucun Bloquant et une Suggestion. Compteurs propres **0/2**, prochaine passe
**17**, plafond vingt conservé.

| Profil / instance | Important | Suggestion |
| --- | --- | --- |
| Produit — `/root/r16_product` | 4 | 0 |
| Qualité — `/root/r16_quality` | 2 | 1 |
| Correction — `/root/r16_correctness` | 3 | 0 |
| Sécurité — `/root/r16_security` | 1 | 0 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Pluriel demandé à un indénombrable sans consigne adaptée | Consigne FR/EN/KO : pluriel si possible, sinon forme indénombrable inchangée ; `water`, refus de `waters` et `coffees` vérifiés en saisie et en voix |
| Important | Deux boutons de liste sans nom accessible | Noms localisés distincts et activation exposés dans l'arbre sémantique du vrai détail |
| Important | Contraste sombre des commandes secondaires | Fonds opaques par thème pour connexion et deux icônes de liste ; contrastes texte et icônes mesurés dans les deux thèmes |
| Important | Lecteur de leçon sans hauteur de contenu en paysage | Titre, contenu et pagination défilent ensemble en format compact ; vrai shell, règle coréenne au titre anglais long, texte doublé, swipe/Précédent/Suivant/pratique vérifiés |
| Important | Refus du signal d'ouverture absorbé et préparation non réessayable | Signal d'écoute strict et préparation réessayable ; reprise après refus natif sans ouverture prématurée du microphone |
| Important | Journée étudiée perdue lorsqu'elle arrive après la suivante | RPC transactionnelle `record_study_day` ; journées idempotentes, série et record identiques dans les deux ordres depuis une série historique |
| Important | Starters historiques recréés sous un nouvel UUID après purge | Migration additive 023 conservant les clés catalogue minimales ; fixture PostgreSQL réelle puis SQLite neuf et seeding sans résurrection des anciens UUID aléatoires |
| Important | Refus transitoire de fermeture audio mémorisé indéfiniment | Distinction fermeture en cours/confirmée/refusée ; seule une fermeture refusée est réessayée avant relecture du prompt |
| Important | Capture ajoutée puis retirée invisible au garde de PR | Vérification des chemins interdits de chaque commit introduit ; dépôt temporaire avec ajout puis retrait et historique de fusion testés, garde d'index conservé |

La Suggestion de performance est traitée : une réservation unitaire de
progression lit sa seule clé primaire. Le test de collision parmi 20 000
lignes étrangères retourne une ligne et conserve l'alias. Les lectures
groupées restent utilisées pour les imports et restaurations.

Un constat préliminaire de sécurité sur les purges Patrol a été retiré par
son auteur avant le verdict : le mode TEST_MODE coupe le push et le pull,
donc le scénario supposait un envoi inexistant dans ce parcours. Il ne compte
pas parmi les constats finaux et n'entraîne aucun changement du reset starter.

Les huit checks CI sont verts sur `284f468`. Les 98 tests ciblés root passent,
dont les vrais parcours de leçon compacts et les frontières HTTP de la RPC.
Les 176 tests data passent ; la fixture des clés catalogue a été produite par
PostgreSQL 16.11 puis restaurée sur SQLite. Les nouvelles purges conservent
leur identité catalogue, sans reconstituer les clés effacées par une ancienne
version de 020.

La suite finale passe : **1 212 tests hôte**, douze diagnostics positifs
exclus sans opt-in, couverture **75,8 %** (14 400 / 18 996 lignes). L'analyse
complète est propre. Les 25 diagnostics ciblés passent avec opt-in. Les six
régressions audio ciblées utilisent notamment les vrais canaux natifs simulés
pour les refus de préparation, de lecture et d'arrêt, suivis d'une reprise.

PostgreSQL 16.11 valide dix-sept suites et douze vrais refus de reset
intermédiaires avec données conservées. Trois courses à deux connexions
couvrent reset, purge et ordre inversé des journées sous verrou de profil.
Le reset efface les plages de jours par cascade. Le contrat exact devient
`study-catalog-v1`, acquis après 022 et 023. Le bundle atomique, son rejeu
refusé et les trois contrôles de mise à niveau depuis 017 passent. Aucun
changement hébergé n'est effectué.

Les 33 tests Python des outils, dont sept pour le garde Git, et les dix tests
E2E passent, soit **43 tests Python**. Actionlint, zizmor et la syntaxe Bash
des tests de concurrence sont propres. Les fonctions Edge restent inchangées
depuis leurs 31 tests Deno et sept bundles validés. Le garde documentaire et
le formatage restent obligatoires avant le commit commun et la revue 17.

## Dix-septième itération — `295bdcd`

Les quatre verdicts ont été réunis sur
`295bdcd229900abaad4f4c3f2e50a8bcf10d369b` avant toute correction. Le profil
sécurité rend `PROPRE` ; les trois autres rendent `BLOQUÉ`. Les **6 Important
bruts donnent 5 constats distincts** : la disposition partielle du vrai
lecteur est commune aux rapports qualité et correction. Aucun Bloquant ni
Suggestion. La convergence collective reste **0/2** ; le commit de correction
remet les compteurs à zéro. Prochaine passe **18**, plafond vingt conservé.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/r17_product` | BLOQUÉ | 3 | 0 |
| Qualité — `/root/r17_quality` | BLOQUÉ | 1 | 0 |
| Correction — `/root/r17_correctness` | BLOQUÉ | 2 | 0 |
| Sécurité — `/root/r17_security` | PROPRE | 0 | 0 |

| Type | Constat distinct | Correction et preuve ciblée |
| --- | --- | --- |
| Important | Lecteur marqué disposed avant refus du dernier nettoyage natif | Étapes de libération et de nettoyage distinguées dans un adaptateur utilisant l'interface publique ; la libération confirmée autorise la suite sans rappeler des méthodes sur l'objet détruit |
| Important | Signal d'ouverture accepté puis échouant sur le flux natif | Fin réelle, erreur, échéance et annulation du signal traitées ; aucune ouverture du micro sur un simple ACK de resume |
| Important | Lancement annonçant des mots au lieu des cartes | Libellés de cartes ; une vraie base SQLite avec un concept EN/KO annonce et lance deux cartes en FR/EN/KO |
| Important | Kimchi indénombrable noté faux dans le pluriel | Exception lexicale et vecteur conservant son éligibilité ; mot et catégorie du vrai catalogue vérifiés dans un quiz écrit et vocal, `coffees` préservé |
| Important | Popup de leçon sans traduction entièrement lisible en format compact | Titre, traduction et Fermer dans un défilement signalé ; vrai exemple KO→FR à 568 × 320 et 320 × 568, texte doublé, position restituée |

Deux scénarios préliminaires ont été retirés par leurs auteurs avant verdict :
l'ACK ordinaire ne notifie pas Drift et ne produit donc pas la cascade
supposée ; `rice / meal` est déjà exclu avant génération. Ils ne comptent pas
parmi les constats finaux et n'entraînent aucun élargissement de ces corrections.

Les huit checks CI sont verts sur `295bdcd`. Les 43 tests ciblés d'interface
et de grammaire passent. La gate élargie de contenu réussit 118 tests ; la
comparaison structurée limite l'édition de seed à une exception et un vecteur
dans la seule règle de pluriel. Les identifiants, prérequis, minima et la
règle a/an restent identiques.

La suite finale passe : **1 218 tests hôte**, douze diagnostics positifs
exclus sans opt-in, couverture **75,9 %** (14 472 / 19 074 lignes). L'analyse
complète est propre et les 25 diagnostics ciblés passent avec opt-in. Les
douze régressions audio ciblées valident notamment le dernier appel natif
de nettoyage refusé puis repris, l'erreur après ACK et l'attente réelle de
fin du signal avant ouverture du microphone.

L'interface publique `audioplayers_platform_interface` 7.1.1, déjà résolue
dans le lock, devient une dépendance directe pour reprendre l'opération
native finale sans appeler une méthode sur un objet détruit. Aucune version
de paquet n'est changée. Les sept JSON de traduction sont valides.

Les migrations, fonctions Edge, outils et workflows restent inchangés depuis
leurs dix-sept suites SQL, 31 tests Deno, sept bundles et 43 tests Python
validés dans le lot précédent. Le garde documentaire, le formatage et le
contrôle de tout l'historique de PR restent requis avant la revue 18.
