# Intégration — deuxième cycle, 28 novembre 2026

## Ouverture autorisée

L'utilisateur demande de mettre en place les corrections renforcées tout en
conservant la liberté des relecteurs, puis de relancer un cycle de vingt
passes. La [décision](../decisions/2026-11-28-review-corrections-and-cycles.md)
et la [spécification](../pr-validation.md) en fixent les limites.

Le [premier cycle](2026-11-27-integration.md) reste conservé avec ses vingt
passes non convergées. Ses derniers constats sont corrigés dans
`48b12ee21c22bb20c3f005078c20b41e1edd72c6` : 1 249 tests hôte, analyse
propre, couverture 76,0 % et huit checks CI verts. Ce résultat ne constitue
aucune passe propre indépendante du deuxième cycle.

## Préparation du premier candidat

- Missions des quatre relecteurs maintenues ouvertes ; zones examinées et
  limites brièvement rapportées, sans grille exhaustive obligatoire.
- Profil de correction versionné : cause/invariant, recherche de réutilisation,
  cas voisins et consommateurs partagés, effets du changement et preuves
  pertinentes, dans les fichiers attribués et sans décision produit inventée.
- Identifiants stables `C2-P<pass>-<numéro>` pour les constats consolidés ;
  rapports originaux et doublons conservés avec leur sévérité.
- Preuve du bot version 2 : cycle explicite commun aux huit rapports, deux
  passes consécutives 1–20 sur la même tête/base, attestation du propriétaire
  et provenance des huit checks CI. Les 26 tests du bot passent localement.

La première passe du cycle 2 (relecture cumulée 21) commence après le commit
commun de ces consignes et de leur garde. Aucun verdict n'est acquis à
l'ouverture : **0/2**, plafond **20 passes par profil**. Aucun mélange de cycles
ou réemploi d'un verdict d'une ancienne tête n'est autorisé.

Tous les constats Bloquant et Important d'une passe sont réunis avant les
corrections. Les modifications du lot sont livrées ensemble, puis les quatre
instances fraîches relisent le nouveau SHA. Une nouvelle modification remet
les compteurs propres à zéro. Deux passes collectives propres sur un même
commit permettent l'approbation, puis la fusion protégée lorsque la CI est
verte. Un troisième cycle exige une nouvelle décision utilisateur.

## Passe 1 — `116c01d` — relecture cumulée 21

Les quatre verdicts finaux portent sur
`116c01da22fffd72a70fb4be53bfd6dabc57e747`, contre la base
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Ils ont été réunis et archivés
avant toute correction. Les **huit Important sont distincts**. Aucun Bloquant.
La sécurité est propre avec une Suggestion ; la convergence collective reste
**0/2**. Les huit checks CI du commit examiné sont verts.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p1_product` | BLOQUÉ | 4 | 0 |
| Qualité — `/root/c2p1_quality` | BLOQUÉ | 2 | 0 |
| Correction — `/root/c2p1_correctness` | BLOQUÉ | 2 | 0 |
| Sécurité — `/root/c2p1_security` | PROPRE | 0 | 1 |

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P1-01 | Important | Variante générique de négation contredisant l'exception de 좋아하다 |
| C2-P1-02 | Important | Formes 이/가 et 을/를 absentes des consignes affichées et parlées |
| C2-P1-03 | Important | `to be busy` exclu par sa catégorie malgré les formes anglaises enseignées |
| C2-P1-04 | Important | Action Envoyer et erreur de connexion insuffisamment contrastées |
| C2-P1-05 | Important | Fin du chargement d'un quiz recouvert arrêtant le micro du quiz visible |
| C2-P1-06 | Important | Arrêt du signal précédent perdu lors du remplacement du directeur audio |
| C2-P1-07 | Important | Préparation STT initiale hors de la frontière de récupération d'erreur |
| C2-P1-08 | Important | ACK Android TTS inconditionnel pris pour une confirmation d'arrêt |
| C2-P1-S01 | Suggestion | Verrou CocoaPods absent ; Suggestion du premier cycle conservée |

Le lot suit le profil de correction renforcé. L'examen voisin de C2-P1-08
confirme aussi un ACK inconditionnel côté iOS ; la même garantie d'arrêt doit
être rétablie sur les deux plateformes. Les rapports de correction ci-dessous
doivent distinguer cause, cas voisins, preuves exécutées et limites avant
le commit commun puis la passe 2.

### C2-P1-04 — cause, voisinage et validation

La cause est l'emploi de teintes fixes d'accent pour du petit texte, ainsi
qu'une encre d'erreur commune aux deux thèmes. L'invariant est un contraste
d'au moins 4,5:1 sur la surface rendue. L'inspection inclut le dialogue de
reset, les erreurs de connexion, les validations de formulaire et les autres
consommateurs du schéma d'erreur. Les teintes de texte sont adaptées au thème
et leur encre inverse reste cohérente ; les couleurs de palette et de remplissage
existantes restent distinctes.

Les six régressions mesurent le fond réellement rendu pour Envoyer, le refus
de connexion et la validation du champ e-mail dans les deux thèmes. Avant
correction, Envoyer mesure 3,89/3,74 et l'erreur de connexion 4,46/3,03. Après
correction, les six mesures atteignent le seuil. Les **66 tests auth/thèmes**
passent ; les parcours de reset FR/EN/KO et les contrôles de clavier/texte
agrandi existants restent inclus. Il ne s'agit pas d'une validation physique.

### C2-P1-01 à C2-P1-03 — cause, voisinage et validation

La validation de négation ajoutait une réponse dérivée de la découpe suffixale
en `-하다` même lorsqu'une exception auteurée imposait un autre ordre. Une
exception qui place `안` conserve cet ordre ; un antonyme reste compatible
avec la négation ordinaire. Les cartes réelles et les entrées de notation
écrite/vocale persistées dans Drift acceptent `안 좋아해요` et refusent
`좋아 안 해요`, acceptent `맛없어요` et `안 맛있어요`, puis acceptent
`공부 안 해요` et refusent `안 공부해요`.

Les formes phonologiques étaient transmises pour le thème mais pas pour les
variantes sujet/objet. La génération et le quiz prennent désormais les formes
de la variante effectivement choisie pour la consigne et le préfixe coréen.
Les cartes du catalogue sont vérifiées en FR/EN/KO pour thème, sujet et objet,
ainsi que pour le lieu dont la forme ne change pas après consonne/voyelle.

Le filtre de catégorie excluait l'adjectif `to be busy` malgré ses formes
explicitement définies dans les règles anglaises. Des exceptions complètes
propres à ces règles de présent/négation rendent la carte éligible, sans
reclassifier le concept ni le créditer au minimum de cinq verbes. Le présent
réel et les trois négations enseignées sont vérifiés en saisie et en voix ;
`I don't be busy` est refusé. Les autres règles et langues restent contrôlées
par leurs vecteurs ; `a/an` conserve Nourriture + Salutations et son minimum
de cinq noms, et les sens indénombrables restent protégés.

Les **85 tests ciblés** de session grammaticale, modules et seeds passent.
Aucun seed ni fichier de traduction n'est modifié. Les segments parlés sont
préparés et les transcriptions simulées ; le rendu TTS et le microphone sur
appareil ne sont pas exercés par cette validation hôte.

### C2-P1-05 à C2-P1-07 — cause, voisinage et validation

Un chargement de carte recouvert consultait l'état global d'écoute pour
déclencher un arrêt, sans vérifier la possession de la course. Les chemins
chargement, cycle de vie et annulation libèrent désormais la course détenue
par la route ; le prochain prévol visible continue d'attendre les arrêts
natifs globaux en cours. Le test ouvre un second quiz mains-libres depuis le
détail d'un vrai import, finit le chargement retardé du premier pendant la
capture Système du second, puis vérifie sa réponse et sa persistance.

Le remplacement d'un directeur annulait son attente Dart tout en perdant
le résultat de l'arrêt natif du signal. Une barrière portée par les providers
conserve les directeurs retirés et leurs arrêts, joint les attentes en cours
et réessaie les refus avant la prochaine lecture/capture. Le test du canal
`audioplayers` change tempo puis hauteur, retient puis refuse un ancien arrêt,
impose la relance et attend la fin du lecteur courant. Les prompts, signaux
facultatifs, pauses et anciens événements sont aussi examinés.

La préparation initiale du mode et des moteurs précédait la récupération du
tour. Le démarrage et les relances partagent désormais la garde de route,
carte, tour et compte ainsi que le traitement d'erreur ; l'initialisation
détachée supplémentaire est retirée. Le vrai refus de `isSupported` du moteur
Téléphone est exercé en état actif, après pause et après changement de compte,
avec relance et microphone fermé jusqu'au signal. Les refus du recorder, les
changements Système/PCM et la sortie de route restent inclus.

Les **156 tests ciblés** quiz/SFX/directeur/course passent ; l'analyse ciblée,
le formatage et le diff sont propres. La frontière native est simulée sur
l'hôte, sans prétendre à une validation audio physique.

### C2-P1-08 — cause, voisinage et validation

Les plugins mobiles ignoraient le résultat de l'arrêt SDK et renvoyaient un
succès de commande. Leurs callbacks non identifiés ne suffisaient pas à
attribuer une confirmation à la bonne synthèse après une réponse tardive.
Les ponts minimaux de l'application utilisent les mêmes moteurs natifs,
un propriétaire client et l'identité de l'énoncé ; ils attendent le résultat
réel de l'arrêt et son événement terminal. Un refus ou une preuve absente
à **750 ms** laisse la lecture bloquée dans l'échéance externe du quiz ; une
relance peut redemander l'arrêt. Une annulation pendant l'initialisation
Android empêche tout démarrage différé de cet ancien client.

L'examen voisin inclut iOS, les changements de langue/moteur, les demandes
en file, la destruction et les anciens résultats. Les moteurs Android déjà
initialisés sont réutilisés et la synthèse active garde son moteur exact.
Les réglages et les préférences existants sont conservés. Le chemin iOS
garde la politique de session audio partagée existante.

L'APK Android debug final compile. Les 36 tests audio ciblés et le widget
de refus/relance passent. Cinq scénarios JVM exécutent le vrai pont Kotlin :
refus `-1`, succès sans terminal puis expiration, relance sur le même énoncé,
anciens événements/échéance, autre client, annulation avant initialisation
et réutilisation des moteurs. Ces cas sont regroupés en cinq scénarios ;
ils ne constituent pas des essais sur moteur OEM ou microphone physique.
Le harnais utilise des doublures contrôlées du SDK et du canal Flutter.
Il est conservé dans `tool/native-tests/device-speech/`, exécuté par
`tool/test-device-speech.ps1` et ajouté au check Android existant. Il réutilise
le compilateur de la distribution Gradle épinglée, sans nouvelle dépendance.
Le blob Kotlin vérifié est `1ae34a7b1d2dab8d22dbe8b29d0727d92507178a`.

### Validation commune du candidat corrigé

La suite complète réussit **1 264 tests hôte**, avec douze diagnostics
positifs exclus sans opt-in, et une couverture de **76,1 %**
(14 640 / 19 239 lignes). L'analyse Flutter est propre. Les 25 diagnostics
ciblés passent avec opt-in ; le test de refus de l'autre configuration est
exclu. Les périmètres ciblés précédents ne sont pas additionnés.

Le nouveau candidat devra obtenir ses huit checks CI, dont la compilation
iOS macOS, avant la passe 2. Les tests hôte et l'APK Android ne prouvent pas
cette compilation. Aucun déploiement hébergé ni essai physique n'est effectué.
Le commit commun repart à **0/2** ; seule une nouvelle revue indépendante
peut fournir un verdict propre.

## Passe 2 — `f91b561` — relecture cumulée 22

Les quatre verdicts portent sur
`f91b5611278cfd8fc5aa8ea6508c1ee82ea48091`, contre la même base
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Les huit checks sont verts,
y compris le simulateur iOS et les cinq scénarios JVM sous Ubuntu ; la
provenance des exécutions a été vérifiée avant les lectures. Tous les
rapports finaux sont archivés avant correction. Les **quatre Important sont
distincts**, sans Bloquant. La convergence reste **0/2**.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p2_product` | BLOQUÉ | 2 | 1 |
| Qualité — `/root/c2p2_quality` | BLOQUÉ | 1 | 0 |
| Correction — `/root/c2p2_correctness` | BLOQUÉ | 1 | 0 |
| Sécurité — `/root/c2p2_security` | PROPRE | 0 | 1 |

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P2-01 | Important | Présent français enseigné avec sujet, mais accepté seulement sous forme courte |
| C2-P2-02 | Important | Identité de maîtrise partagée utilisée pour dédupliquer des exercices distincts dans la file |
| C2-P2-03 | Important | Consignes de langue Écrit/Voix sous 4,5:1 sur le papier clair |
| C2-P2-04 | Important | Cache audio partagé sur disque mais écrit directement et dédupliqué par instance, puis absence de secours après erreur du lecteur |
| C2-P2-S01 | Suggestion | Texte blanc de la bannière hors ligne sur orange, contraste 2,16:1 |
| C2-P2-S02 | Suggestion | Verrou CocoaPods absent, Suggestion déjà conservée aux passes précédentes |

### C2-P2-02 — cas voisin dans l'animation

La recherche des consommateurs de l'identité a aussi trouvé la clé du
`V3CardStack`. Le même `variantId` gardait l'animation de sortie entre deux
exercices d'une règle. L'identité de séance est utilisée dans cette clé,
avec maintien de la clé métier pour le vocabulaire. Le test de rendu montre
avant correction une nouvelle carte à l'offset `(1,2 ; 0,1)`, puis après
correction une entrée centrée dès sa première image. Aucune identité
FSRS ou de synchronisation n'est changée par cette correction d'animation.

### C2-P2-03 et C2-P2-S01 — cause, voisinage et validation

La teinte `clayDeep` était décrite comme adaptée au petit texte mais n'offrait
que 3,26:1 sur le papier. Ses autres consommateurs, dont des marques d'avatar,
sont examinés sans assombrir leurs contextes existants. Une encre de petit
texte distincte est utilisée par les deux consignes de langue en clair ; leur
encre en thème sombre reste inchangée. Les quatre mesures de rendu testent Écrit et
Voix sous les deux thèmes, avec le fond texturé de production.

La Suggestion hors ligne est traitée dans le même lot : texte et icône foncés
sur le fond orange conservé, avec deux mesures de rendu dans le vrai shell.
Son type reste Suggestion. Les six tests de contraste passent, sans prétendre
à une validation sur appareil. La Suggestion CocoaPods reste conservée.

### C2-P2-01 et C2-P2-02 — cause, voisinage et validation

Le présent Latin produisait uniquement la forme courte. Le français accepte
aussi les pronoms enseignés de la personne demandée, avec élision et pronom
réfléchi ; la forme courte reste prioritaire. Le vrai seeder KO→FR et SQLite
vérifient `travaille`/`je travaille`, `achète`/`j'achète`,
`me lève`/`je me lève`, en refusant personne, terminaison, élision et pronom
incorrects. Une clé de consigne FR spécifique indique le sujet facultatif
dans les trois locales V0, sans changer les autres consignes partagées.

L'examen des autres consommateurs du module confirme le même défaut dans les
leçons anglaises et allemandes, atteignables via les paires restaurées et le
provider générique. Leurs formes enseignées comme `I work`, `she studies`,
`I am busy`, `ich stehe auf`, `du arbeitest` et `er/sie/es geht` sont aussi
acceptées, avec conservation des réponses courtes et de la personne demandée.
L'espagnol et l'italien enseignent les formes sans sujet dans ces exercices :
ils ne sont pas élargis sur la base d'exemples contextualisés avec un groupe
nominal entier. Le présent français reste à l'écrit et les minima, dont cinq
noms pour sept éligibles dans `a/an`, sont inchangés.

La file dédupliquait la progression de règle, commune à plusieurs questions,
au lieu de l'exercice de séance. Chaque carte de grammaire porte désormais
son index d'origine, conservé sur sa copie. Deux cartes de thème et trois de
sujet/objet du vrai catalogue reviennent exactement une fois dans l'ordre,
puis leurs copies sautées terminent au bilan SQLite sans nouvelle reprise,
maîtrise, note FSRS ou événement de réponse. Les identités métier et la
remise en file du vocabulaire sont préservées ; reprise notée, métadonnées
audio et historique de vocabulaire sont examinés aussi.

Les **172 tests ciblés** de grammaire, chargement/historique de séance,
quiz et seeds passent, avec analyse ciblée propre. Aucun seed n'est modifié.
Les transcriptions sont simulées et les contrôles ne constituent pas un
essai de microphone ou de rendu physique.

### C2-P2-04 — cause, voisinage et validation

La déduplication et la mémoire du cache vivaient avec chaque lecteur, alors
que le dossier disque survivait aux changements de vitesse/hauteur. Les
lecteurs successifs utilisent désormais un cache de provider commun et les
instances qui se chevauchent partagent une tâche par destination. Les clips
sont écrits complètement, flushés, publiés par renommage atomique et vérifiés
par SHA-256 à la lecture. Les anciennes entrées sans preuve de complétude sont
écartées à la demande, sans nouvelle génération audio payante pendant le quiz.

Une erreur du décodeur invalide le clip et attend la libération du lecteur
avant la synthèse de l'appareil. Le signal et le microphone attendent la fin
réelle de ce secours. Un refus de libération ou de synthèse reste récupérable
comme échec du prompt ; un arrêt ou remplacement invalide un ancien secours.
Le widget de production retient la libération puis la lecture de l'appareil
et vérifie les deux barrières avant le signal et la capture.

Le cas voisin d'une invalidation pendant téléchargement rend d'abord périmée
la génération. L'exclusion porte sur la phase disque et ne fait pas attendre
le réseau au secours local. Un test publie la nouvelle entrée pendant que
l'ancienne requête Storage est suspendue ; la réponse tardive n'est ni rendue
au lecteur ni autorisée à remplacer ou supprimer la nouvelle publication.
Les gardes de propriétaire et de génération sont revérifiées après renommage.

Les **162 tests ciblés** audio/directeur/quiz passent, avec analyse ciblée et
formatage propres. Les preuves utilisent le système de fichiers hôte et des
canaux natifs simulés, sans Storage hébergé ni lecture physique. Les nombres
de tests ciblés ne sont pas additionnés, car leurs périmètres se recouvrent.

### Validation commune après la passe 2

Les **1 285 tests hôte** passent, avec douze diagnostics positifs exclus
sans opt-in et **76,2 %** de couverture (14 756 / 19 365 lignes). L'analyse
Flutter complète est propre ; les 25 diagnostics ciblés passent avec opt-in,
avec le refus de l'autre configuration exclu. Le code natif et le harnais
JVM sont inchangés depuis les huit checks verts de `f91b561`, incluant la
compilation iOS et les cinq scénarios sous Ubuntu. Le nouveau SHA doit obtenir
sa propre CI ; les relectures peuvent continuer pendant ces contrôles sans
autoriser l'approbation ou la fusion avant leur réussite.

Le commit commun rassemble les quatre Important et la Suggestion de contraste
traitée. Aucun compteur propre n'est acquis : la prochaine passe est **3/20**
du cycle 2, relecture cumulée 23. Les quatre nouvelles instances examineront
le même commit, avant toute nouvelle modification.

## Passe 3 — `f19d6b0` — relecture cumulée 23

Les quatre verdicts portent sur
`f19d6b006c48368e188aa8de736767406e5992b5`, contre la même base
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Les quatre rapports finaux sont
archivés avant toute correction. Les huit checks CI de ce SHA passent ; leur
provenance réelle est vérifiée. Les **huit Important sont distincts**, sans
Bloquant. La convergence reste **0/2**.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p3_product` | BLOQUÉ | 3 | 0 |
| Qualité — `/root/c2p3_quality` | BLOQUÉ | 2 | 1 |
| Correction — `/root/c2p3_correctness` | BLOQUÉ | 1 | 1 |
| Sécurité — `/root/c2p3_security` | BLOQUÉ | 2 | 1 |

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P3-01 | Important | La leçon sujet/objet applique seulement la finale sans enseigner 저→제가, pourtant exigé par son vrai catalogue |
| C2-P3-02 | Important | Une panne du compteur devient zéro sur le chemin et le plateau, avec faux état vide et sans relance |
| C2-P3-03 | Important | Le sélecteur de paire utilise les exonymes au lieu des autonymes décidés |
| C2-P3-04 | Important | Un arrêt audio actif refusé ou expiré est absorbé, permettant à Répéter de démarrer un autre lecteur |
| C2-P3-05 | Important | Tout échec de lecture du profil est interprété comme absence, puis écrase le profil par upsert |
| C2-P3-06 | Important | La migration 11 confond anciens liens publiés et imports dans l'état privé+jeton de SQLite v2 |
| C2-P3-07 | Important | Le filtre Git exclut les suppressions du contrat documentaire, dans l'index et la PR |
| C2-P3-08 | Important | Un check manuel homonyme plus récent masque le vrai check de push `test` pour le bot |
| C2-P3-S01 | Suggestion | Un drainage vide parcourt toutes les listes : 0,35 / 3,86 / 21,07 ms pour 1k / 10k / 50k entrées mesurées |
| C2-P3-S02 | Suggestion | Une erreur tardive d'un clip facultatif, après ACK de démarrage, ne déclenche pas le secours |
| C2-P3-S03 | Suggestion | Les liens Markdown préparés sont vérifiés dans la copie de travail au lieu de l'index |

S01 est une Suggestion dans le rapport final, après mesure du coût par le
relecteur, et reste conservée sans refonte de la synchronisation. S02 reste
aussi une Suggestion : les événements du lecteur facultatif identifient un
lecteur natif réutilisé, pas une requête de lecture. Un secours tardif fiable
exigerait une identité par lecture ; cette limite est conservée dans le
contrat audio. S03 est traitée avec le garde documentaire sans changer son type.

### C2-P3-01 — contrat enseigné et vrai catalogue

La copie de secours du lecteur présentait la finale comme règle exhaustive,
alors que le module générait la contraction. La leçon FR/EN explique désormais
`저→제가`, avec l'exemple `제가 할게요.`, et distingue `저를` et `저는`.
Le test utilise l'asset, l'éligibilité du catalogue et le générateur réels,
accepte `제가`, refuse `저가`, et vérifie objet et thème. Il échoue sur la copie
initiale avant correction. Les contractions `나`, `너`, `누구` sont déjà
couvertes par le module mais absentes du starter KO ; aucun mot, identifiant,
minimum ou prérequis n'est ajouté pour elles. La relecture native de cette
copie et de l'exemple reste à faire, conformément au contrat de contenu.

Le gate seed, le générateur, le lecteur et la régression passent **73 tests** ;
le JSON, l'analyse ciblée et le diff sont propres. Aucun essai appareil ni
relecture native n'est revendiqué.

### C2-P3-02 et C2-P3-03 — compteur partagé et sélecteurs

La valeur absente d'un `AsyncValue` était remplacée par zéro. Les quatre
consommateurs du compteur sont examinés : plateau V3, chemin du jour,
configurateur actif et ancien accueil non routé. Les états de chargement ou
d'erreur ne doivent ni annoncer un compteur connu ni déduire une absence de
révisions. La relance invalide le compteur de la paire concernée ; les listes
et leçons ne dépendent pas de sa disponibilité.

Les autres sélecteurs sont aussi examinés : options et résumé de langue du
configurateur, puis choix des langues du formulaire de liste. Ils réutilisent
`Languages.autonym`. Les textes de direction et consignes rédigés en langue
d'interface conservent `displayName` ; l'ordre des options et le contexte
guidé sont préservés.

Les **78 tests widget ciblés** passent. Les régressions FR/EN/KO parcourent le
vrai provider avec erreurs contrôlées à sa frontière DAO, relance sur plateau
et chemin, ancien zéro suivi d'erreur, puis navigation indépendante vers listes
et leçons. Les trois paires sont vérifiées sous les trois locales à 568 × 320
et texte doublé. Le configurateur, l'ancien accueil et la création de liste
sont aussi exercés. Une attente de fermeture du faux stream bloquait le premier
lancement ; sa fermeture non bloquante après démontage corrige la fixture,
puis le périmètre complet repasse. Le diff est propre. La panne du lecteur
SQLite et le rendu sur appareil ne sont pas injectés ou revendiqués.

### C2-P3-04 — arrêt actif et lecteurs voisins

La couche de cycle de vie absorbait les refus et délais d'arrêt du directeur
actif, tandis que seule la libération des anciens directeurs barrait la lecture
suivante. Le directeur conserve désormais l'accusé natif brut de l'arrêt actif
et le joint à ceux des anciens lecteurs avant prompt, signal ou microphone.
Un nouvel arrêt rejoint une confirmation pendante ou retente un refus.
La retraite d'un lecteur de fichier rejoint son arrêt en cours, sans deuxième
ACK permettant de contourner le premier. Les deux lectures initiale/flip du
provider et la relecture du verdict passent aussi par le directeur existant.

Les deux sens clip↔synthèse, Pause/Reprendre, premier prompt, flip, verdict,
prompt suivant, remplacement de réglage/route et réponses anciennes sont
examinés. **208 tests ciblés** passent, dont deux régressions utilisant les
canaux de méthode réels du lecteur et de la synthèse avec réponses simulées.
L'analyse ciblée, le formatage et le diff sont propres. Ces preuves ne sont
pas des essais physiques.

### C2-P3-05 — absence de profil et concurrence

L'absence et l'échec de lecture étaient confondus. Désormais, seule une requête
réussie sans ligne déclenche une création `ON CONFLICT(id) DO NOTHING`, puis
le profil gagnant est relu. Une indisponibilité conserve l'authentification
locale et le dernier profil enrichi du même compte. Les changements de compte,
la fermeture puis reconnexion au même identifiant et les réponses tardives
sont examinés sans réutiliser le profil d'une autre session.

**128 tests ciblés** passent, dont de vraies requêtes du client Supabase Dart
avec HTTP simulé : réponse vide, refus, panne réseau, conflit de pseudo et
création concurrente. Les chemins inscription, connexion, import froid,
rappels, splash et historique de séance font partie du périmètre ; ces nombres
ne s'additionnent pas aux autres suites. L'analyse ciblée et le diff sont
propres, sans mutation de Supabase hébergé.

Le consommateur voisin du flux GoTrue recevait aussi une erreur asynchrone
non traitée lors d'un renouvellement temporairement indisponible. Avant le
correctif, le vrai widget d'application capte deux erreurs après les retries
HTTP 503 du SDK malgré l'attente explicite de la Future. Les deux abonnés
utilisent maintenant la même frontière, qui traite uniquement
`AuthRetryableFetchException`. Le scénario conserve route, profil enrichi et
session pendant le 503 sans lecture du profil, enrichit après HTTP 200, puis
applique la vraie déconnexion `refresh_token_not_found` après HTTP 400.

### C2-P3-06 — migrations réelles et preuve du partage

Les deux producteurs de SQLite v2 utilisaient le même état privé+jeton pour
publication et import ; les heuristiques de SQLite 11 et PostgreSQL 011 ne
constituaient donc pas une preuve. SQLite 13 conserve l'ambiguïté dans la table
de bootstrap existante, sans rendre artificiellement la ligne à envoyer.
Une source publique active dont propriétaire, UUID distant et jeton concordent
confirme une publication ; une source distincte vérifiée établit la provenance
d'une copie privée. Sans preuve ou hors ligne, la branche reste étudiable et
retenue. Une action explicite de partage ou suppression conserve son effet.

Les migrations depuis le vrai DDL v2 et les versions 10/11/12 sont exercées,
avec redémarrage, ancienne provenance distante erronée, alias local d'un UUIDv5,
copie du même propriétaire, source publique déjà en cache, révocation distante
et édition concurrente protégée par comparaison transactionnelle. La base de
partage étant aussi consommée par l'adoption starter, celle-ci n'est pas
autorisée par une simple modification explicite d'un jeton encore ambigu.
Les identités et historiques FSRS, les autres comptes et visibilités sont
examinés. Un lien déjà écrasé dont la source a disparu reste indéterminé :
aucune ancienne URL n'est recréée sans preuve.

Les **120 tests ciblés** migration, partage, pull, push, namespace, repository,
seeding et reprise réseau passent. L'analyse des onze fichiers Dart concernés
et le diff sont propres. Aucun Supabase hébergé ni appareil n'est utilisé.

### C2-P3-07, C2-P3-08 et C2-P3-S03 — index et provenance CI

Le filtre de chemins est désormais distinct selon le contrôle : les suppressions
comptent dans le contrat documentaire ; formatage et détection des introductions
privées conservent les fichiers ajoutés/modifiés. Les blobs Markdown et cibles
préparés viennent de l'index, avec la casse Git, y compris l'arbre épinglé d'un
sous-module. Les tests opposent index et copie de travail, suppression préparée
avec copie restante, cible non préparée, casse incorrecte et contenu de gitlink.
Les **13 tests du garde** passent, après correction de l'ordre d'une fixture
du nouveau test de suppression ; aucune règle de production n'est relâchée.

Le workflow réserve le nom `test` au push et nomme le lancement manuel
`Manual / test`. Les **27 tests du bot** passent ; le cas ajouté vérifie qu'un
manuel plus récent ne masque ni un push vert ni un push rouge. Le contrôle
d'événement, workflow, suite et SHA du bot reste strict. `test.yml` n'existe pas
encore sur la branche par défaut de cette première intégration ; une preuve
manuelle GitHub ne doit pas être confondue avec les tests locaux.
L'analyse syntaxique de tous les workflows par actionlint passe aussi.

### Validation commune après la passe 3

Les **1 320 tests hôte** passent, avec douze diagnostics positifs exclus sans
opt-in et **76,7 %** de couverture (15 122 / 19 717 lignes). L'analyse Flutter
complète est propre. Elle avait signalé une option de style de complétion
devenue inutilisée dans le chemin ; cette option est retirée, les 23 tests
widget concernés repassent, puis la suite complète et sa couverture sont
réexécutées sur la source figée. Les 25 diagnostics ciblés passent avec opt-in,
avec le test de refus de l'autre configuration exclu. Le garde de licence
Whisper passe aussi.

Commandes communes : `flutter test --no-pub --coverage --reporter expanded`,
`flutter analyze --no-pub`, `tool/check-coverage.ps1`, puis les quatre fichiers
de diagnostic avec `--dart-define=STT_DIAGNOSTICS=true`. Les tests ciblés se
recouvrent et ne sont pas additionnés. Les sources natives et les migrations
PostgreSQL sont inchangées ; la CI propre au nouveau SHA reste exigée, dont
Android et iOS. Aucun déploiement, essai physique ou publication n'est effectué.

Le commit commun rassemble les huit Important et S03, avec tous les contrats
associés. La convergence repart à **0/2** et la prochaine passe est **4/20**
du cycle 2, relecture cumulée 24. Les quatre nouvelles instances examinent
le même commit avant toute nouvelle modification.

## Passe 4 — `5e60e52` — relecture cumulée 24

Les quatre rapports finaux portent sur
`5e60e52ab3ada67ebc6a22bcb9e9d96b6ccb9e1a`, contre la base inchangée
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Ils sont réunis et archivés avant
correction. Les **dix Important sont distincts**, sans Bloquant ni Suggestion.
La convergence reste **0/2**.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p4_product` | BLOQUÉ | 3 | 0 |
| Qualité — `/root/c2p4_quality` | BLOQUÉ | 2 | 0 |
| Correction — `/root/c2p4_correctness` | BLOQUÉ | 2 | 0 |
| Sécurité — `/root/c2p4_security` | BLOQUÉ | 3 | 0 |

Les huit checks de ce SHA sont verts, dont Android, iOS et le harnais JVM.
La provenance workflow/événement/PR/tête/base est vérifiée par le validateur
du bot. Le cas réel de C2-P3-08 est aussi exercé : push `46140638173` et
manuel `46140639276`, tous deux verts sur ce SHA, avec un ID de check manuel
plus récent. `Manual / test` ne masque pas `test` et le validateur retient les
huit bons checks. La preuve factuelle est archivée avec les rapports locaux.
Le workflow `test.yml` est enregistré dans GitHub Actions bien qu'absent du
`main` courant ; sa dispatch réelle a réussi. La procédure du premier bot
d'approbation reste distincte : son workflow permanent exige le ref `main`
et son script n'y est pas encore présent.

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P4-01 | Important | La pratique libre transforme encore un échec du pool dû en zéro et masque sa relance si une autre source est sélectionnée |
| C2-P4-02 | Important | Une lecture de sens échouée et l'autre vide donnent un faux état « aucune carte » |
| C2-P4-03 | Important | Le configurateur de leçon déborde sans signal de défilement à texte doublé |
| C2-P4-04 | Important | Un jour étudié hors ligne n'est pas rejoué après échec de sa RPC malgré l'historique SQLite conservé |
| C2-P4-05 | Important | Une lecture facultative acquittée peut chevaucher l'autre lecteur ; sa préparation peut survivre à une carte périmée |
| C2-P4-06 | Important | La preuve d'une publication historique est utilisée comme nouvelle base d'édition et transforme des écarts distants en modifications locales |
| C2-P4-07 | Important | L'embedding Android et app_links délivrent tous deux l'URI à chaud, remplaçant l'import par une route inconnue |
| C2-P4-08 | Important | Les outils d'approbation/déploiement et le pont natif échappent au garde documentaire |
| C2-P4-09 | Important | Un ami confirmé peut lire la liste réservée aux amis, mais pas ses concepts et variantes |
| C2-P4-10 | Important | Le publieur de seed traite une panne Storage comme absence et lance un rendu facturé |

### C2-P4-01 à C2-P4-03 — même invariant au-delà d'un provider

La pratique libre consomme un snapshot de pools différent du compteur des
quatre écrans corrigés précédemment. Le badge et la quantité de départ
distinguent maintenant échec, chargement et zéro confirmé ; une relance reste
près de la source en échec sans rendre l'autre source indisponible.

Le chargeur conserve les cartes du sens sain. Si aucune carte jouable ne
subsiste après enrichissement et qu'une lecture a échoué, il rend l'erreur
localisée. Les cas liste, dû et apprentissage, cartes retirées pendant
l'enrichissement Drift, deux échecs, un seul échec, vrai vide et ancienne
séance périmée sont exercés. L'ordre des lectures d'enrichissement existant
est conservé après la détection d'un effet voisin par les tests du quiz.

Le configurateur utilise le signal commun de défilement. Le vrai lecteur de
la règle `fr-present-er` ouvre le configurateur à 568 × 320, texte doublé,
avec signal visible à l'offset zéro ; le test défile jusqu'à la quantité et
lance le quiz avec les bons arguments. Les trois locales sont vérifiées.
Le vrai asset est parsé avant le montage pour éviter une attente d'I/O sous
l'horloge simulée. Les **196 tests ciblés** passent avec analyse des six
fichiers concernés propre. Aucun nouveau minimum ou prérequis n'est ajouté.

### C2-P4-04 — jour civil durable et reprise

La tentative de RPC isolée est remplacée par une file SQLite v14 par compte
et jour civil capturé. Historique et jour sont validés dans la même transaction.
La complétion, le démarrage connecté et la reconnexion partagent le drainage.
Seul le succès de la RPC idempotente confirme la ligne, conservée pour éviter
qu'un second quiz du même jour ne la recrée. Une réponse perdue est rejouable.
Le profil est rafraîchi séparément et seulement pour le compte actif.

La date textuelle ne dépend pas du fuseau au moment de la reprise. L'ancien
historique est conservé sans inventer son jour civil d'origine. Si la transaction
locale échoue, le score valide reste affiché mais aucun marqueur local, retrait
de rappel ou envoi distant n'annonce une persistance réussie. Aucun nouveau
parcours de résolution d'erreur n'est introduit.
Les **209 tests ciblés** passent : vraie réouverture SQLite v13→v14, reprise
initiale et reconnexion du shell de production, rollback SQL, vocabulaire et
grammaire, minuit/DST, déduplication avant/pendant/après ACK, réponse perdue
suivie d'une nouvelle journée, changement de compte et échec du profil après
ACK. Deux anciennes fixtures de reconnexion injectent désormais leur base
mémoire pour cette nouvelle dépendance au stockage. L'analyse des douze
fichiers et le diff sont propres. Les transports sont simulés ; aucune
validation hébergée ni chronométrie native n'est revendiquée.
La première suite globale révèle une fixture de reset sans ligne dans la
nouvelle table. Elle crée désormais historique et jour via le DAO de production.
Les **onze tests** reset/scénarios/jours passent : double reset vide toutes les
tables ; un refus tardif restaure toutes les lignes et la date exacte en
attente. Le reset applicatif parcourt déjà chaque table dans une transaction
et ne nécessite pas de réécriture. L'analyse ciblée et le diff repassent.

### C2-P4-05 — possession réelle de la sortie et face courante

Une lecture facultative déjà acquittée ne représentait plus une opération
pendante pour le directeur, mais son clip jouait encore. Le service attribue
une seule possession de la sortie jusqu'à confirmation de l'arrêt. La lecture
valide suivante la reprend, y compris clip↔synthèse. Un refus peut être retenté
et une attente expirée conserve la même confirmation native pendante.

La validité traverse cache, débit de parole, préparation et lancement natif.
Une ancienne réponse de cache ne retire pas le lecteur plus récent. Une
révision de face complète les gardes de carte, séance et compte : elle annule
aussi une question attendant le silence quand la même carte est retournée.
L'ACK de démarrage facultatif et l'attente complète du prompt requis restent
distincts. La Suggestion historique S02 sur l'erreur tardive après ACK reste
conservée avec son type.

Les **245 tests ciblés** passent, dont canaux de méthode avec suivi indépendant
des deux lecteurs actifs, refus d'arrêt, attente expirée puis confirmation,
préparation périmée avec ou sans propriétaire plus récent, et attente de
silence suivie d'un flip. L'analyse des treize fichiers et le diff sont propres.
Ces preuves sont sur hôte avec canaux simulés, sans lecture sur appareil.

### C2-P4-06 — identité du lien et provenance des éditions

La confirmation propriétaire/UUID/jeton identifie une publication mais
n'établit pas quels champs ont été modifiés localement. Le rapprochement
conserve la base d'édition connue et capture l'état précédant les éditions
suivantes. Les patches reprennent ces seules modifications. Un écart historique
sans base fiable reste visible dans la ligne locale et retenu durablement ;
les accusés et pulls ne l'effacent pas et il n'est pas envoyé spontanément.

La sonde initiale changeait l'UUID après migration et orphelinait son marqueur
de retenue. Elle reste archivée intacte. La sonde corrigée place le vrai UUIDv4
dans le DDL v2 avant migration, vérifie son marqueur puis la requête PATCH.
Elle reproduit l'écrasement sur `5e60e52`, puis passe après correction : seuls
nom et date d'édition sont envoyés, la nouvelle description distante reste
intacte, l'ancienne description incertaine reste visible localement et le
jeton public est restauré. Les mêmes attentes distantes sont conservées ;
aucun type de constat n'est rétrogradé pour compenser la fixture.

Les cas de base v13 non fiable après redémarrage disque, vraie base avant
édition d'une copie du même propriétaire, modification pendant l'accusé,
changement de confidentialité et remplacement de partage sont exercés.
Les **119 tests ciblés** passent sur sept suites, dont quatorze cas de
migration, puis la sonde corrigée passe aussi. La batterie examine aussi les
comptes/namespace, FSRS, starters, le rafraîchissement du cache de nombre de mots,
la révocation, la nouvelle publication et la suppression. L'analyse des cinq
fichiers et le diff sont propres. Les métadonnées distantes déjà écrasées par
un ancien build restent irrécupérables sans source ; les tests n'utilisent ni
Supabase hébergé ni appareil.

### C2-P4-07 — entrée native unique

Les deux embeddings mobiles désactivent leur navigation automatique pour les
liens confiés à `app_links`, conformément aux exemples de la version 6.4.1
verrouillée. Les réglages originaux Android et iOS échouent chacun au contrôle
structurel, puis les sources corrigées passent. La CI vérifie aussi les vrais
manifests fusionnés Debug/Profile et l'Info.plist compilé ; cette nouvelle
preuve de compilation appartient au prochain SHA, pas aux builds verts du
parent.

Le test du vrai `PonderinApp` délivre l'enveloppe EventChannel native au plateau,
attend le détail importé, puis utilise son bouton Retour vers le plateau.
Les **dix tests** application/auth/import et **quatre tests** de dispatch
passent, avec analyse ciblée propre. Un premier lancement mentionnait un
chemin de test inexistant ; les commandes corrigées passent. Le contrôle
structurel et cette simulation ne sont pas présentés comme un essai natif.
Les tâches Gradle `processDebugMainManifest`, `processDebugManifestForPackage`
et `processProfileMainManifest` réussissent localement. Le contrôle des vrais
manifests Debug/Profile fusionnés et empaquetés passe. L'Info.plist iOS source
est vérifié ; son artefact compilé reste à vérifier dans la CI du prochain SHA.

### C2-P4-08 — périmètre des outils de livraison

Le garde couvre désormais `tool/`, le pont `packages/ponderin_whisper/`, les
hooks, les profils et skills versionnés, toute la configuration GitHub et les
fichiers racine de dépendances, build, Patrol et configuration Git. Les tests
modifient des chemins existants, vérifient leur refus sans documentation dans
l'index et la PR, puis leur acceptation avec documentation. Les **14 tests**
passent. La fixture de suppression d'un ancien corpus ajoute aussi un document
puisque `tool/` est couvert ; l'interdiction des nouvelles introductions de
données privées reste inchangée.

### C2-P4-09 — visibilité héritée et vraie base PostgreSQL

La migration additive 024 fait hériter la lecture des concepts et variantes
actifs de celle du parent, via les clés qualifiées par propriétaire et les
politiques RLS existantes. Les droits d'écriture ne changent pas. Le
propriétaire conserve les tombstones nécessaires à sa synchronisation.

Le cas avant migration échoue réellement sous PostgreSQL 16.11 : l'ami
confirmé attend les mots `friend` et `public` mais ne reçoit que `public`.
Après migration, les **17 suites SQL**, **trois scénarios concurrents à deux
connexions**, l'activation générée et la mise à niveau d'un ancien 017 passent.
La fixture couvre comptes anonyme/tiers, demandes pendantes ou refusées,
retrait du consentement, listes privées, suppressions et collision d'UUID
entre propriétaires. Les lectures partagées sont vérifiées aussi après
l'activation générée et l'ancienne mise à niveau.

La CI et le générateur d'activation incluent 024. Les **dix tests Python E2E**,
actionlint et le diff passent. Le contrat de reset demeure celui de 023.
La base jetable locale est arrêtée proprement après les essais ; aucun
Supabase hébergé n'est modifié.

### C2-P4-10 — présence confirmée avant dépense

Le publieur et le provisionnement utilisateur partagent le même contrôle de
métadonnées Storage. Seul un `NoSuchKey` qualifié autorise un rendu. Un 503,
un 404 sans ce code, un autre refus ou une panne de transport marque l'entrée
en échec sans TTS, upload ou manifeste. Une autre entrée dont l'absence est
confirmée avance normalement. Un objet présent retrouve son manifeste sans
régénération ; les uploads restent immuables.

Les **27 tests ciblés** avec le vrai SDK et HTTP simulé passent, puis les
**39 tests Edge** complets et la préparation des **sept bundles gelés** avec
sonde hors réseau passent. Aucun nouvel import de dépendance ni changement de
verrou n'est nécessaire. Aucun appel fournisseur réel ni déploiement n'est fait.

### Validation commune après la passe 4

Les **1 347 tests hôte** passent, avec douze diagnostics positifs exclus sans
opt-in et **76,7 %** de couverture (15 428 / 20 122 lignes). L'analyse Flutter
complète est propre ; les 25 diagnostics ciblés passent avec opt-in, avec le
test de refus de l'autre configuration exclu. La suite complète et l'analyse
sont réexécutées après correction de la fixture de reset mentionnée ci-dessus.
Les fichiers Dart partagés ont été formatés après gel de tous les correcteurs.

Les quatorze tests du garde, les 39 tests et sept bundles Edge, les 17 suites
SQL et trois scénarios concurrents, les dix tests Python E2E, actionlint, le
garde de licence et le contrôle des manifests Android fusionnés/empaquetés
passent. Les suites ciblées se recouvrent et ne sont pas additionnées.
La nouvelle vérification de l'Info.plist iOS compilé appartient à la CI du
nouveau SHA. Aucun test physique, déploiement Supabase ou appel fournisseur
réel n'est revendiqué.

Le commit commun rassemble les dix Important et les contrats associés.
La convergence repart à **0/2** et la prochaine passe est **5/20** du cycle 2,
relecture cumulée 25. Les quatre nouvelles instances relisent le même commit
avant toute nouvelle modification. Le cycle 3 reste soumis à une décision
explicite ; le plafond du cycle courant reste vingt passes.

## Passe 5 — `7ff5343` — relecture cumulée 25

Les quatre rapports finaux portent sur
`7ff53438e37dfd63c347dcecb52b2a9f897933c0`, contre la base inchangée
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Ils sont archivés avant correction.
Les neuf observations Important représentent **huit défauts distincts** :
Qualité et Correction rapportent le même défaut de rappel civil. Leur doublon
est regroupé sans modifier son type. Il n'y a pas de Bloquant et une Suggestion.
La convergence reste **0/2**. Les huit checks CI et leur provenance sont verts,
y compris les nouvelles vérifications des artefacts de liens Android/iOS.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p5_product` | BLOQUÉ | 3 | 1 |
| Qualité — `/root/c2p5_quality` | BLOQUÉ | 2 | 0 |
| Correction — `/root/c2p5_correctness` | BLOQUÉ | 2 | 0 |
| Sécurité — `/root/c2p5_security` | BLOQUÉ | 2 | 0 |

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P5-01 | Important | Ajouter ouvre une paire par défaut pendant le chargement et sauvegarde les mots dans les langues inversées |
| C2-P5-02 | Important | Ajouter/Modifier débordent à texte doublé avec clavier et la zone des champs peut disparaître |
| C2-P5-03 | Important | Terminer utilise une encre d'accent à 2,18:1 en clair |
| C2-P5-04 | Important | Le rappel restauré convertit le timestamp du quiz plutôt que son jour civil conservé ; doublon Qualité/Correction |
| C2-P5-05 | Important | Les abonnements grammaticaux persistent sans lecteur et leurs agrégats couvrent les variantes de tous les comptes |
| C2-P5-06 | Important | Deux publications simultanées du même clip manquant déclenchent deux rendus payants |
| C2-P5-07 | Important | L'ancien 012 n'installe pas les restrictions d'écriture Storage ajoutées ensuite en place |
| C2-P5-08 | Important | L'ancienne garde de 015 renvoie un jeton que la chaîne actuelle refuse après mise à niveau |
| C2-P5-S01 | Suggestion | Modifier affiche Requis sans traduction en anglais/coréen |

### C2-P5-01 à C2-P5-03 et C2-P5-S01 — une paire et une saisie stables

Les métadonnées de liste sont asynchrones ; le formulaire ne peut pas les
remplacer par une paire par défaut. Ajouter et Modifier attendent leur valeur
confirmée puis vérifient la même paire, le compte et la destination canonique
dans la transaction d'écriture. Modifier vérifie aussi que ses variantes
appartiennent au même concept et les modifie atomiquement. Une modification
concurrente conserve le texte du formulaire et demande sa réouverture.

Le titre, les champs et les actions utilisent la surface défilante signalée
déjà livrée pour le reset. Les deux champs et Enregistrer restent atteignables
à 568 × 320, texte doublé, clavier de 180 pixels dans les trois locales.
Terminer et les petits libellés utilisent l'encre adaptée au thème. Les erreurs
de champ réutilisent `common.required`, sans changer le type Suggestion de S01.

Les **154 tests ciblés** passent avec analyse propre : chargement retardé,
erreur/null et relance vers KO→FR, codes réellement enregistrés en SQLite,
changement de paire/compte conservant la saisie, paire changée dans la file
transactionnelle et adoption d'un alias starter pendant le formulaire.
Le contraste rendu passe dans les deux thèmes. La fixture de pompe désactive
le ruban Flutter DEBUG, comme le fait déjà l'application ; les pixels de ce
ruban superposé ne sont pas utilisés comme preuve du contraste de Terminer.
Les sondes originales restent intactes ; aucun clavier physique n'est testé.
La première suite globale révèle une fixture smart-list KO→FR utilisant
encore les langues implicites FR→KO et des mots dans l'autre ordre. Elle
fournit désormais la paire et les mots réellement ordonnés, avec direction de
carte identique dans les deux listes pour conserver la preuve d'isolation.
Les huit tests du fichier passent ; le seul appelant applicatif fournit déjà
les langues confirmées. Le garde transactionnel n'est pas relâché.

### C2-P5-04 — date civile et restauration du rappel

Le DAO interroge directement le jour civil du compte dans `quiz_study_days`,
sans filtrer les dates acquittées. Le timestamp de l'historique n'est plus
reconverti dans le fuseau du nouvel appareil pour prouver le jour étudié.
L'ancien historique reste disponible sans date inventée ; une date confirmée
dans le profil reste utilisable pour la suppression du rappel.

Les **40 tests ciblés** passent avec analyse propre. Une vraie fermeture et
réouverture SQLite couvre les deux décalages jour/timestamp et leurs variantes
avant/après ACK, avec un conteneur Riverpod neuf et profil en retard. Un jour
d'un autre compte ne supprime pas le rappel. Les anciennes séances sans date
ne créent pas de jour rétrospectif, tandis que le profil confirmé reste reconnu.
Les validations sont sur hôte avec service de notification contrôlé.

### C2-P5-05 — durée et périmètre des lectures grammaticales

Les agrégats globaux `GROUP_CONCAT` et les lectures de résolution répétées
sont remplacés par des snapshots DAO directement bornés au compte, à la langue
cible et aux copies catalogue concernées. Leur égalité par valeur coupe les
notifications en aval si une invalidation de table étrangère ne change rien.
Le graphe est auto-disposé ; sa source est aussi annulée explicitement, car
la Future interne pouvait retenir un abonnement après disparition de l'élément.
Le quiz maintient un abonnement seulement pendant sa préparation initiale.

Les **158 tests ciblés** passent avec analyse de neuf fichiers propre. Le
retour de la sonde originale est vide après fermeture des deux lecteurs.
Deux écritures observées pour deux langues produisent huit snapshots bornés,
zéro agrégat global, zéro lecture de suivi et zéro notification de statut.
Après fermeture, l'écriture suivante ne produit aucun SELECT. La réactivité
pendant la consultation, le changement de compte et les vrais catalogues
EN→KO/KO→FR sont vérifiés ; un chargement de quiz retardé survit à une frame,
puis libère ses abonnements alors que les cartes restent jouables.

Un concept gradué uniquement sur sa variante française fournit toujours le
mot cible coréen ; deux directions graduées ne le comptent pas deux fois.
Les états review/relearning correspondent au critère de graduation documenté ;
une ancienne ligne newCard n'est pas assimilée à un mot connu. Les seuils et
minima restent inchangés. EXPLAIN confirme les index compte/progression,
concept/langue et identité de progression. Les métadonnées de listes sont
parcourues pour choisir les copies seed exactes, sans scanner les concepts
et variantes des autres comptes. Les relectures bornées normales de Drift
pendant une observation restent une limite explicitement conservée.

### C2-P5-06 — coût partagé et réservation du catalogue

La migration 026 ajoute la réservation serveur des chemins canoniques du
catalogue en réutilisant le registre atomique de 90 secondes. La réservation
privée conserve son namespace utilisateur ; la libération vérifie le jeton.
Le publieur relit Storage après acquisition avant tout rendu. Un concurrent
échoue sur cette entrée sans payer ; après publication la relance compte
l'objet existant. Les doublons dans un lot ne recréent pas un clip.

Le client HTTP audio commun reprend les bornes du provisionnement utilisateur.
Le délai de 60 secondes couvre acquisition, relecture, rendu, upload et
manifeste. Un rendu ou upload incertain garde sa réservation jusqu'à expiration.
Un échec certain avant travail payant peut la libérer. Les compteurs ne
déclarent pas deux créations pour un seul objet immuable.

Les **32 tests SDK ciblés**, **44 tests Edge** complets et **sept bundles gelés**
avec sonde hors réseau passent. Les scénarios contrôlent la concurrence sur
`bonjour`, la reprise après publication, la relecture sous verrou et
l'annulation du travail payant suivie d'une relance bloquée. La réservation
SQL est aussi vérifiée à deux connexions réelles, avec ACL, namespace, expiration
et ancien jeton incapable de libérer le nouveau. Aucun appel fournisseur réel.

### C2-P5-07 et C2-P5-08 — versions réellement installées

Les fixtures 012/015 sont copiées à l'identique de `90a8298` et leur hash de
blob est vérifié. Le premier chemin annonce v1 après 024 mais permet une
insertion audio anonyme via une politique permissive ; le second applique
016–024 sans erreur mais son prévol retourne NULL. Ces échecs sont reproduits
avant la correction additive, sans substituer le 012 déjà corrigé du dépôt.

La migration 025 installe les restrictions Storage et vérifie leurs commandes,
rôles, prédicats, RLS et bucket privé. Elle vérifie les gardes effectives de
namespace/tombstone 015 et d'ordre d'écriture 016 puis préserve les contrôles
018–023. Le contrat `study-catalog-v2` permet aux clients actuels de refuser
les serveurs v1 qui ne prouvent pas ces réparations. Les réglages hébergés et
la variable d'activation GitHub ne sont pas modifiés ; le prévol v2 doit
réussir avant toute activation future.

Les **17 suites SQL**, les **trois courses existantes**, la nouvelle course de
bail seed, l'activation complète générée, son refus de réapplication et les
mises à niveau 012/015/017 testées passent sur PostgreSQL 16.11 jetable. Les
tests retirent ou altèrent aussi des gardes et vérifient le refus du prévol et
du reset. Les **dix tests Python E2E**, actionlint et le diff passent. La base
locale est arrêtée proprement.

Les affirmations historiques portent sur `90a8298`. Une version encore
antérieure de 012 sans gardes SELECT est déjà refusée avant activation à 013 ;
elle nécessite un diagnostic de schéma et n'est pas assimilée au chemin testé.

### Validation commune après la passe 5

Les **1 368 tests hôte** passent, avec douze diagnostics positifs exclus sans
opt-in et **76,8 %** de couverture (15 489 / 20 178 lignes). L'analyse Flutter
complète est propre. La suite et l'analyse sont relancées après la correction
de la fixture smart-list ; le contrat de paire n'est pas assoupli. Les
25 diagnostics ciblés passent avec opt-in, avec le test de refus inverse exclu.

Les 44 tests Edge et sept bundles, les 17 suites SQL, quatre scénarios de
contention, chemins historiques 012/015/017 et activation générée, les dix
tests Python E2E, actionlint, garde de licence et contrôle des manifests
Android fusionnés passent. Les sources natives sont inchangées depuis les
builds Android/iOS verts de `7ff5343`, dont les artefacts vérifient déjà les
liens ; le prochain SHA doit toutefois obtenir ses propres huit checks.
Les suites ciblées se recouvrent et ne sont pas additionnées. Aucun appel
fournisseur réel, réglage hébergé ou essai physique n'est effectué.

Le commit commun rassemble les huit Important distincts, S01 et les contrats
associés. La convergence repart à **0/2** et la prochaine passe est **6/20**
du cycle 2, relecture cumulée 26. Les quatre nouvelles instances relisent le
même commit avant toute nouvelle modification ; aucun troisième cycle n'est
autorisé automatiquement.

## Passe 6 — `7221d63` — relecture cumulée 26

Les quatre rapports finaux portent sur
`7221d63e995ee1671422c36091e3681ce7742703`, contre la base inchangée
`179f9ae0b34fe7c469b73d59ee4d25ef61515f9e`. Ils sont archivés avant correction.
Les neuf Important sont distincts. Aucun Bloquant et une Suggestion ; la
sécurité est propre. La convergence collective reste **0/2**.

| Profil / instance | Verdict | Important | Suggestion |
| --- | --- | --- | --- |
| Produit — `/root/c2p6_product` | BLOQUÉ | 3 | 1 |
| Qualité — `/root/c2p6_quality` | BLOQUÉ | 3 | 0 |
| Correction — `/root/c2p6_correctness` | BLOQUÉ | 3 | 0 |
| Sécurité — `/root/c2p6_security` | PROPRE | 0 | 0 |

| Identifiant | Type | Constat |
| --- | --- | --- |
| C2-P6-01 | Important | Ouvrir Ajouter observe les variantes de tous les concepts avant toute demande d'assistance |
| C2-P6-02 | Important | Le partage natif d'une ancienne session peut s'ouvrir après changement de compte |
| C2-P6-03 | Important | Une erreur ou une fin inattendue du flux PCM n'est pas remontée à la course et ne ferme pas le micro |
| C2-P6-04 | Important | Révéler traite un arrêt expiré comme confirmé et note/lit la réponse avant la libération native |
| C2-P6-05 | Important | La fin d'une sauvegarde de mot ou de suggestions peut dépiler un import qui recouvre la modale |
| C2-P6-06 | Important | L'oracle de reprise SQLite suppose qu'une requête commencée constitue une page durablement appliquée |
| C2-P6-07 | Important | Modifier/Supprimer un mot ne porte pas de nom accessible et n'est pas focalisable au clavier |
| C2-P6-08 | Important | Les suggestions peuvent modifier les champs pendant l'enregistrement de leur ancienne valeur |
| C2-P6-09 | Important | Le plateau et le chemin assimilent une lecture de listes indisponible à une collection vide |
| C2-P6-S01 | Suggestion | L'aperçu d'une liste existante vide invite à créer une liste |

Les sept checks du workflow PR sont verts sur cette tête, y compris les
builds natifs et leurs contrôles de liens. Le check obligatoire `test` du
push échoue sur `reopening SQLite resumes a large list traversal at the same
latency` : deux requêtes de `list-0` au lieu d'une. Sa réussite isolée locale
ne clôt pas ce défaut ; aucune relance GitHub ne remplace sa correction.

### C2-P6-09 — disponibilité des listes

La source asynchrone est conservée jusqu'aux recommandations et aux métriques,
sans repli vers une collection vide en cas de chargement ou d'erreur. Une
absence confirmée reste seule capable de proposer une première liste ou
d'afficher des compteurs mots/listes à zéro. Les états indisponibles ont un
message FR/EN/KO et une relance du seul provider local. Le chemin et le
plateau conservent les entrées indépendantes, même pendant le chargement.

Les **25 tests ciblés** des trois fichiers de plateau/chemin passent. Les
scénarios couvrent les trois locales, chargement, échec, relance, vide confirmé,
liste existante et erreur après donnée. La paire étrangère ne fournit pas la
recommandation. La feuille du parcours ne propose pas de créer une liste
quand sa source est inconnue ; ses leçons restent accessibles. Une lecture
de listes en panne n'empêche pas une révision due confirmée de lancer le vrai
sélecteur de mode et de transmettre les arguments de quiz.

Le consommateur historique `HomeScreen` a aussi été lu : il affiche déjà
l'erreur de listes explicitement et utilise une relance par rafraîchissement,
sans la remplacer par un état vide. Ces tests de widgets contrôlent les flux
du provider ; ils ne simulent pas une panne physique du stockage.

### C2-P6-01, C2-P6-05, C2-P6-07, C2-P6-08 et S01 — formulaires et modales

Le contexte est demandé seulement depuis l'assistance, via l'échantillon groupé
existant limité à 80 paires. La paire attendue est vérifiée dans la même
transaction SQLite. Les contrôles de session, de formulaire et de paire
précèdent l'appel HTTP ; la direction inverse utilise les mots de son côté
source. L'ouverture manuelle n'observe plus chaque concept hors écran.

Le résultat de sauvegarde attend que sa modale soit courante. Le scope de
visibilité de route déjà utilisé par le quiz est extrait en
`ShellRouteVisibility`, afin de reconnaître aussi un import du navigateur
racine qui recouvre une feuille du navigateur imbriqué. La feuille reste
imbriquée pour que l'abonnement s'ouvre au-dessus d'elle puis restitue sa
sélection. Aucun consommateur de liste ne dépend de l'écran Quiz.

Les deux types de suggestions qui remplacent les champs sont désactivés
pendant l'écriture, avec garde dans l'action elle-même. Modifier/Supprimer
utilisent des boutons standard de 48 pixels et un tooltip localisé qui
annonce l'action et le mot. L'aperçu vide d'une liste existante invite à
ajouter des mots, sans changer le type Suggestion du constat.

Les **101 tests ciblés** de cinq fichiers passent, avec analyse propre. Les
18 nouveaux cas couvrent mille concepts sans observation supplémentaire,
échantillon inverse et invalidations, six sauvegardes Add/Edit/IA derrière
la vraie route d'import, une importation réussie après sauvegarde, puces
gelées sur réussite/échec, trois locales pour accessibilité et texte d'aperçu.
Les erreurs d'écriture utilisent un vrai trigger SQLite. Le test voisin de
quota conserve la sélection après Retour du paywall. Le premier lot a révélé
des assertions du banc erronées sur `SemanticsData.tooltip` et le cycle du
handle sémantique ; elles sont corrigées avant le succès final. Aucun
clavier ni lecteur d'écran physique n'est revendiqué.

### C2-P6-02 — effets externes et identité de session

Le partage conserve son repository, son DAO et son `PushSync`, puis vérifie
dans une transaction l'accusé de publication, le propriétaire, le token,
la visibilité et les enfants. Une identité de session mise à jour à la
source distingue déconnexion/reconnexion au même compte d'un enrichissement
du profil. Le retrait local de la session avant l'événement SDK est également
consulté. Un ancien travail ne peut ouvrir le partage sous cette nouvelle
session. Le voisin export suit la même garde avant le plugin et utilise
son propre dossier temporaire ; une préparation abandonnée est nettoyée.

Les **99 tests ciblés** du lot partage/contexte/reprise/auth passent, avec
analyse propre de sept fichiers. Les scénarios de partage utilisent le vrai
`PushSync` et Drift avec canal de partage contrôlé : changement de compte,
retour au même identifiant, déconnexion avant événement, profil stable et
refus d'un enfant. Aucun envoi natif réel ni serveur hébergé n'est testé.

### C2-P6-06 — réponse reçue et checkpoint durable

Le test de réouverture immobilise seulement la première page incomplète et
laisse expirer son délai HTTP réel de 260 ms. Le budget global de production
reste quinze secondes ; le voisin qui prouve son échéance globale de 450 ms
reste conservé. Avant fermeture, le test vérifie le contenu SQLite et le
snapshot durable `contentsDone=1`. Après réouverture du fichier, la page
confirmée n'est pas redemandée et la première page incomplète est rejouée.

Le voisin de plus de 500 lignes présentait la même hypothèse temporelle.
Il utilise désormais trois arrêts ciblés sur inventaire, concepts et progrès,
puis vérifie les curseurs `afterId` et leurs données avant reprise, y compris
une vraie progression FSRS reçue dans la première page. La preuve ne repose
plus sur un nombre de requêtes commencées supposées acquittées. Ces scénarios
font partie des 99 tests ci-dessus ; leurs résultats ne sont pas additionnés
aux suites qui les recouvrent. Les réponses HTTP sont contrôlées sur hôte.

### Cas voisins SDK de C2-P6-01/C2-P6-02

Le SDK épinglé encode les Maps de fonctions dans un isolate avant de consulter
l'autorisation implicite de son client HTTP. La garde UI seule ne protège
donc pas cet intervalle. Le helper commun `AuthenticatedEdgeSession` fixe
l'autorisation de la session d'origine, conserve le renouvellement de cette
session et écarte les résultats devenus étrangers. Il est réutilisé par
traduction, suggestions, transcription ElevenLabs et les deux benchmarks du
laboratoire. Ces derniers capturent leur portée avant la lecture de fichiers
et arrêtent les demandes suivantes après une transition.

Les **17 tests ciblés** additionnels utilisent le SDK réel et HTTP contrôlé.
Dans les deux modes assistant, B est réellement courant lors de l'envoi,
mais l'en-tête porte A et le résultat est rejeté. Le renouvellement de A
utilise son nouveau bearer ; un changement pendant ce renouvellement
n'envoie aucune fonction. La portée multi-échantillons refuse le deuxième
échantillon après A→B→A pendant une lecture contrôlée. Aucun jeton réel ni
appel fournisseur n'est utilisé. Après remise au plugin de partage natif,
son API publique ne permet plus d'annuler l'effet ; la garde applicative
est vérifiée juste avant cette remise.

### C2-P6-03/C2-P6-04 — interruption et libération native

La course reçoit une erreur ou une fin inattendue du flux public PCM, ferme
sa capture puis rend un résultat technique sans note ni signal de fin.
Fermer volontairement le flux ne déclenche pas ce résultat. Les erreurs et
expirations d'arrêt ne sont plus absorbées en tant que preuve de libération
dans l'écran : Révéler, Clavier, Passer et la reprise des prompts attendent
le résultat explicite audio/micro. Une relance rejoint la même fermeture
encore en attente ou redemande un arrêt refusé.

La recherche des consommateurs voisins a reproduit un nouveau quiz Cartes
qui prononçait son premier mot pendant que le micro du quiz Voix recouvert
attendait `released`, malgré l'ACK de `stop`. La garde d'`AudioDirector`
rejoint désormais les arrêts des contrôleurs déjà instanciés avant lecture.
Elle n'instancie pas de recorder pour Cartes/Écrire et n'arrête jamais elle-même
une capture active. Une lecture facultative peut rester muette après le
refus ou l'échéance de deux secondes ; une lecture requise suit son erreur
récupérable. Quitter peut finir la navigation après expiration sans présenter
cet arrêt comme une confirmation autorisant une lecture.

Les **186 tests ciblés** de six fichiers passent, avec analyse propre des
dix fichiers voix/visibilité. Ils comprennent la chaîne du vrai adaptateur
Record au flux partagé puis à la course, avec enveloppe d'erreur injectée
sur le canal `com.llfbandit.record/eventsRecord/<id>`. La course attend
l'ACK de fermeture du recorder avant son résultat technique. Les tests du
reconnaisseur système distinguent cet ACK de l'événement terminal `released`
de sa session ; Révéler/Clavier/Passer ne notent ni ne jouent avant lui.
La sonde interroutes échoue avant la garde puis passe, et le cas Cartes seul
ne crée aucun contrôleur micro. Une régression de relance pendant nettoyage
est corrigée avant le résultat final en renouvelant l'attente UI autour du
même arrêt natif ; aucune nouvelle capture n'est ouverte en parallèle.

Les événements natifs sont simulés. L'EOF public du port est testé, mais
`record` 7.1.1 ne relaie pas la fin spontanée de son flux plateforme interne
dans ce flux public. La détection d'une interruption non exposée par ce
plugin n'est pas revendiquée et reste à vérifier physiquement. Aucun code
tiers n'est modifié pour prétendre obtenir cet événement absent.

### Validation commune après la passe 6

Les **1 418 tests hôte** passent avec douze diagnostics positifs exclus sans
opt-in. La couverture est **77,5 %** (15 830 / 20 427 lignes) et l'analyse
Flutter complète est propre. Les 25 diagnostics ciblés passent avec opt-in,
avec le test de refus inverse exclu. La sonde compilée en mode produit
refuse les diagnostics malgré l'option fournie. Les suites ciblées ci-dessus
se recouvrent et ne sont pas additionnées.
Le garde de politique passe sur l'index et sur tout le diff de PR : formatage,
documentation, liens locaux et absence de nouveaux artefacts privés, y compris
dans l'historique introduit. Le hook reste actif pour le commit commun.

Les neuf Important, S01 et les cas voisins confirmés sont rassemblés dans
un commit commun. Le nouveau SHA doit obtenir sa propre CI ; le succès local
ne réécrit pas le check rouge du parent. Aucun essai physique, appel fournisseur
réel ou réglage hébergé n'est revendiqué. La convergence repart à **0/2**,
avec prochaine passe **7/20** du cycle 2, relecture cumulée 27. Les quatre
nouvelles instances examinent ce même commit avant toute modification.
