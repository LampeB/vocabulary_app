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
