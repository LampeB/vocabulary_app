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
