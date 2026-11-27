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
