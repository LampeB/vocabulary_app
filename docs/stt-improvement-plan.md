---
tags:
  - architecture
  - voice
  - audio
status: active
---

# Architecture voix, STT et audio

Cette note décrit le contrat actuel du mode voix et mains-libres. L'état de
livraison et les validations qui manquent sont dans
[`../PROJECT_STATUS.md`](../PROJECT_STATUS.md).

## Principes

- Une réponse de quiz est une reconnaissance **contrainte** : l'application
  connaît le mot attendu et ses variantes, elle n'effectue pas une dictée libre.
- L'expérience doit enchaîner prompt, signal, écoute, validation et carte
  suivante sans chevauchement audio ni callback tardif.
- Les clips de vocabulaire sont générés/provisionnés une fois, puis téléchargés
  et mis en cache localement. Un quiz ne crée pas une synthèse ElevenLabs à
  chaque carte.
- Les écrans ne font jamais d'appel audio ou STT ad hoc.

## Composants responsables

| Composant | Responsabilité |
| --- | --- |
| `VoiceTurnMachine` | Politique d'un tour mains-libres : retries, pause silencieuse, validation unique et transition. |
| `AudioDirector` | Sérialise TTS, clips, earcons et remise du microphone. |
| `SttRace` | Coordonne les hypothèses des moteurs, rejette les callbacks périmés et accepte la première réponse validée. Expose l'état en direct (`SttRaceStatus`). |
| `SharedPcmCapture` | Les décodeurs PCM transcrivent la même capture (décision utilisateur 2026-10-02). Le reconnaisseur système exclusif ouvre son propre micro lorsqu'il est sélectionné. |
| `PhoneSttEngine` / `PcmSpeechRecognizer.kt` | Reconnaissance du téléphone appliquée à NOTRE enregistrement (Android 13+ `EXTRA_AUDIO_SOURCE`, canal `vocab_kr/pcm_speech`). |
| `SttStatusStrip` | Montre à l'apprenant s'il est écouté, entendu, ou si chaque moteur envoie/analyse/échoue. |
| `hf_cue.dart` | Séquence mains-libres visible : lecture → 3·2·1 → bip « Écoute en cours » + barre qui se vide (durée réglable dans les paramètres). |
| `answer_validator.dart` | Compare l'hypothèse au mot attendu et à ses variantes, y compris les normalisations coréennes. |
| Adaptateurs STT | STT système, Whisper local Android quand disponible et ElevenLabs Scribe selon disponibilité. |
| `SttLabScreen` / `SttCorpusRecorder` | Outils de diagnostic sur appareil : corpus étiqueté et comparaison des moteurs. |
| `NearMissSessionScreen` (`/stt-lab/near-miss`) | Enregistre des « mots proches » étiquetés (locuteur, pièce, mot attendu) pour le comparatif des moteurs. `DebugRecognizeReceiver` (debug uniquement) rejoue `tool/stt_corpus` dans le recognizer du téléphone. |

## Flux mains-libres

```text
audio du prompt → vérification des moteurs → compte à rebours → signal d'ouverture → microphone → hypothèses STT
→ validation contrainte → feedback audio → carte suivante
```

`AudioDirector` doit terminer ou annuler l'audio précédent avant l'écoute.
Un échec ou une attente trop longue de l'arrêt affiche une reprise du tour.
Le signal d'ouverture et la capture attendent l'arrêt confirmé du lecteur,
y compris si l'apprenant réessaie pendant une demande d'arrêt déjà en cours.
Le microphone attend l'événement natif de fin du signal d'ouverture. Une
erreur native pendant la lecture ou une attente de plus de deux secondes
rend Répéter disponible sur la carte. L'arrêt invalide le signal en cours.
L'attente de préparation est aussi annulée. L'échéance peut arrêter seulement
le signal auquel elle appartient. Chaque signal utilise un lecteur natif
dédié après confirmation de l'arrêt du son précédent. Un clip dont la fin
est requise avant le micro utilise également un lecteur dédié.
En mains-libres, le compte à rebours, le signal et le micro suivent la fin
confirmée du prompt de la carte courante. Le tour attend aussi la configuration
de la voix ou la lecture complète de l'enregistrement local. En grammaire,
la consigne dans la langue de l'interface précède le mot à transformer.
Si la lecture échoue ou dépasse son délai, le tour reste disponible via le
bouton Répéter. Le microphone reste fermé. Un refus explicite du moteur
vocal de l'appareil, lors du réglage de la langue ou du lancement de la
lecture, suit le même chemin. Une erreur native de lecture d'un clip
interrompt l'attente dès sa réception. Si le lecteur est remplacé pendant
un prompt, le tour attend sa libération puis rejoue le prompt sur le nouveau
lecteur. Répéter redemande une libération refusée. Une libération en cours ou
déjà confirmée conserve son résultat. Seule la fin de la lecture confirme que
le prompt a été joué. Pour un clip, la libération native de l'audio suffit
au nouveau lecteur. Le nettoyage final de l'ancien lecteur continue en
arrière-plan et réessaie une fois la seule opération native refusée.
Un arrêt TTS confirmé permet de rejouer la consigne quand une réponse de
configuration de langue est perdue. La réponse tardive d'un ancien tour
ne remet pas sa voix en service.
L'arrêt confirmé termine aussi l'attente Dart d'une synthèse interrompue,
même si le moteur natif ne répond plus à la commande de lecture. Une réponse
tardive de cette synthèse laisse l'activité de la lecture suivante intacte.
Un refus d'arrêt conserve l'activité des lectures encore en cours.
La synthèse de l'appareil traite une seule demande à la fois, de la
configuration de sa voix jusqu'à la fin du son. Un arrêt confirmé peut
interrompre cette demande immédiatement et annule les demandes déjà en file.
`SttRace` et `VoiceTurnMachine` ignorent les résultats arrivés après la fin du
tour pour empêcher une réponse de contaminer la carte suivante.
La fermeture de la capture attend sa dernière portion audio et l'inscrit dans
les analyses en cours avant de permettre un verdict d'absence de réponse.
Un décodeur peut travailler pendant l'écoute. Le signal de fin d'écoute
attend la fermeture confirmée du microphone et un verdict encore en cours.
Si la fermeture est refusée ou dépasse deux secondes, le tour se termine
sans signal de fin ni notation. Cette règle couvre le microphone partagé
et le reconnaisseur système exclusif. Répéter relance le tour après
confirmation de la fermeture. Un arrêt qui attend toujours sa réponse
native bloque toute nouvelle ouverture, même si le mode ou la route du
quiz change. Le retour système demande aussi la fermeture et journalise
les échecs. Sur Android et iOS, le pont système associe la capture et
sa libération à un identifiant de session. Le retour de la commande
d'arrêt n'autorise pas à ouvrir un autre micro : la course attend
l'événement de libération de cette session après le nettoyage natif.
Chaque tour attend la restauration du mode STT et garde ce mode pour les
nouvelles tentatives. Le premier essai et chaque relance attendent la
sélection des moteurs disponibles et la vérification du microphone avant
le compte à rebours et le signal d'ouverture.
Un échec de lecture de la connectivité conserve les moteurs locaux éligibles
sans lancer de moteur cloud ; le mode Système ne dépend pas de cette lecture.
Une exception de permission ou de préparation termine la tentative avec un
message FR/EN/KO et attend la fermeture du microphone avant une relance.
Les résultats tardifs d'une tentative ou d'un ancien compte sont ignorés.
La mise en arrière-plan, le recouvrement de la route du quiz et la pause
volontaire invalident le tour, y compris le compte à rebours et les relances.
Le mode mains-libres reprend quand l'application est à nouveau active et le
quiz visible, y compris après fermeture d'un import ouvert par lien. Pendant
un feedback, il reprend l'avance différée et conserve la notation déjà écrite.
Une pause volontaire reste active jusqu'à la reprise par l'apprenant.
Chaque route de quiz conserve sa session, ses cartes, son score et sa pause.
Un quiz lancé depuis un détail importé peut ainsi se terminer, puis rendre la
main au quiz précédemment couvert. Une fermeture demandée pendant un arrêt
audio reste attachée à sa route et se termine quand celle-ci redevient visible.
Le bouton Pause et le bouton Reprendre sont accessibles au clavier. En
pause, Reprendre reçoit le focus et les actions d'écoute sont retirées.
Lorsque la hauteur ou le grossissement du texte réduit l'espace disponible,
la carte entière défile avec un indicateur pour accéder à la consigne, à
l'état d'écoute et aux commandes.
Un changement d'identifiant de compte ferme la session, retire ses cartes
et invalide le tour audio et les opérations différées de cette session.
L'arrêt d'un tour invalide les portions PCM en file pour le reconnaisseur du
téléphone. Le pont Android annule et détruit le reconnaisseur actif et ferme
ses deux descripteurs de capture. Le nouveau tour attend cette remise à zéro
et peut décoder sans attendre une ancienne transcription.
Pour Whisper, l'inférence native déjà lancée libère elle-même son fichier.
Les portions PCM annulées en attente sont abandonnées avant leur écriture
WAV et le nouveau tour attend seulement l'inférence déjà lancée.
En Voix, passer au clavier ou révéler la réponse invalide également le tour
et ferme sa capture. Une transcription reçue ensuite ne peut plus décider du
résultat. L'arrêt de la synthèse et des signaux invalide les demandes audio
en attente de configuration native avant qu'elles puissent jouer.
Les boutons Microphone, Clavier et Révéler s'utilisent avec Tab et Entrée.
En Voix, le prompt, les états STT, la transcription et les boutons défilent
ensemble quand l'espace manque. Avec le clavier logiciel, la consigne, le
champ et le bouton Valider défilent ensemble.
Les cartes suivantes et reportées conservent leurs chemins de clips en cache.

La notation **écrite et orale de grammaire** préserve les formes attendues
par le module, y compris les articles élidés, les terminaisons et les
particules. Le même contrôle s'applique à chaque hypothèse finale de la
course et à l'enregistrement du verdict. Les hypothèses partielles restent
visibles, sans verdict si aucun résultat final n'arrive. La transcription
orale peut ajouter de la ponctuation finale. Le vocabulaire conserve ses
normalisations tolérantes et peut valider une hypothèse partielle. Le pont
PCM préserve le caractère provisoire d'un texte conservé après une erreur
ou un résultat final vide.
En vocabulaire, la phonétique et les élisions françaises s'appliquent
aux réponses attendues en français, à l'écrit et dans les deux voies vocales.
Les réponses de grammaire alimentent la maîtrise de la règle. Le feedback de
vocabulaire annonce l'intervalle renvoyé par la notation FSRS enregistrée
pour cette réponse. Les verdicts s'affichent dès la validation.

## Règles de modification

1. Modifier ces seams, leurs tests et cette note ensemble ; ne pas contourner
   l'orchestrateur depuis un widget.
2. Mesurer sur un corpus enregistré avant de changer la priorité d'un moteur.
3. Toute clé, limite, fonction Edge ou coût de fournisseur se configure hors du
   client et doit être documenté dans un runbook sans jamais inscrire un secret
   dans Git.
4. Toute nouvelle stratégie de course ou de capture doit être validée en arrière
   plan, avec permissions, réseau lent et au moins un appareil réel.

## Politique bêta des fournisseurs (décision 2026-11-22)

Whisper local est conservé. Les services cloud ne sont que des secours : une
limite atteinte ne doit jamais empêcher une session locale avec le moteur du
téléphone ou Whisper.
En mode Course, un décodeur PCM local prêt pour la langue fait utiliser la
capture partagée, y compris lors de la dernière tentative. Sans décodeur PCM
local compatible, le reconnaisseur système peut ouvrir le micro seul en
mode embarqué. Sur Android, il faut un service embarqué détecté par l'API
système (Android 12+) et un reconnaisseur dédié créé dans le pont natif.
Sur iOS, la requête exige la reconnaissance embarquée pour la langue.
Les moteurs réseau servent de secours si aucun moteur local n'est disponible
ou après les tentatives infructueuses du système. Le mode Système utilise
directement le reconnaisseur exclusif configuré par la plateforme, qui peut
utiliser le réseau.
Le cloud n'analyse la capture qu'après la fin de la tentative locale et de
ses segments en attente, sans réponse locale validée. Les demandes cloud
d'un même tour sont sérialisées. Une validation locale n'envoie ni audio ni
réponse attendue au fournisseur.
Si une analyse réseau dépasse le délai du tour, la course abandonne les
envois réseau restants de ce tour. Tant que la requête HTTP Scribe est encore
en cours, le service réserve son emplacement et un tour ultérieur peut
continuer avec les autres moteurs disponibles.

Les routes `/stt-lab` et `/stt-lab/near-miss`, leurs liens, l'enregistrement
de WAV, la persistance des transcriptions du corpus et le journal brut exigent
tous un build de debug lancé avec `--dart-define=STT_DIAGNOSTICS=true`. Hors de
cette configuration, les routes sont absentes et l'enregistreur de corpus
n'accède ni au micro ni à ses fichiers. Le récepteur
Android de corpus est limité au shell de test, au dossier de corpus et aux
captures WAV bornées ; il n'est pas présent dans la livraison.
Sur iOS, le pont prépare les seuls dossiers `Documents/stt_corpus` et
`Documents/stt_logs`. Il pose et relit leur exclusion des sauvegardes avant
de rendre leur chemin aux écrivains Flutter. La vérification s'applique
aussi aux dossiers existants et l'app rétablit leur exclusion au lancement.
Sans confirmation, le laboratoire ne crée ni WAV, ni résultat de corpus,
ni journal persistant.

| Capacité | Plafond authentifié |
| --- | --- |
| Transcription cloud | 300/jour, 80/heure, une requête simultanée ; clip de 30 s maximum |
| Traduction assistée | 200/jour |
| Suggestions de vocabulaire | 25/jour |
| Génération d'exercices | 20/jour |
| Provision audio | 500 nouveaux clips/jour, exclusivement sur un cache miss |

Le budget de la bêta mono-utilisateur est de **20 EUR par mois**. Le tableau
de bord fournisseur alerte à 12 EUR, les fonctions cloud sont restreintes à
16 EUR et désactivées à 20 EUR. Ces seuils sont des garde-fous d'exploitation
à configurer chez les fournisseurs ; le dépôt applique les limites par
utilisateur avant chaque appel. Les coûts réels restent vérifiés dans les
tableaux de bord des fournisseurs, qui font foi.

Whisper local est désormais intégré via `packages/ponderin_whisper`, un pont
minimal détenu par Ponderin qui appelle le sous-module MIT `whisper.cpp`. Le
wrapper GPL historique n'est plus distribué. Le modèle `ggml-base.bin` est
téléchargé depuis une révision figée et vérifié par SHA-256 ; les avis MIT et
les références exactes sont dans `packages/ponderin_whisper/THIRD_PARTY_NOTICES.md`.
Le téléchargement du modèle (147 951 465 octets) est partagé entre demandes
concurrentes et contrôlé avant installation. Le chargement et l'inférence
native s'exécutent dans un isolate de travail ; le contexte natif reste en
cache et protégé par un verrou. Le fichier de capture n'est nettoyé qu'après
la fin de l'inférence, succès comme échec.
Le pont Android utilise le NDK `28.2.13676358`, aligné sur Flutter 3.44.9 et
le module application ; les builds CI ne doivent pas installer un ancien NDK
distinct pour le plugin.
Whisper local iOS n'est pas livré : le pont reste explicitement limité à
Android jusqu'à une intégration Xcode et un test physique séparés. L'application
possède un `Podfile` versionné ; cela ne fournit pas le pont natif Whisper iOS.
Aucune diffusion externe ne doit
prétendre offrir Whisper local sur iOS avant cette validation.

Le corpus de travail `tool/stt_corpus/` et ses résultats restent privés,
ignorés par Git et interdits par le garde de PR. Les anciennes captures ont
été retirées des deux historiques de branches publiques avec sauvegarde locale.
Le reliquat des anciens objets GitHub a été explicitement accepté pour cette
intégration ; voir [la décision de conservation historique](reviews/2026-11-27-integration.md#purge-et-décision-de-conservation-historique).

## Décisions encore ouvertes

- Quel jeu de modèles Whisper distribuer/télécharger par défaut, pour quelles
  langues, avec quelle taille et quel fallback UX ?
- Quels seuils de latence, exactitude, consommation et coût rendent un moteur
  acceptable pour le lancement bêta ?
- Quelle configuration de monitoring et de révision de budget rend ces seuils
  bêta adaptés lors de l'ouverture à plusieurs utilisateurs ?
