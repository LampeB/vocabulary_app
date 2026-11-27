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
