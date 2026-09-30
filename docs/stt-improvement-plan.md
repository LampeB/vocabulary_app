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
| `SttRace` | Coordonne les hypothèses des moteurs, rejette les callbacks périmés et accepte la première réponse validée. |
| `answer_validator.dart` | Compare l'hypothèse au mot attendu et à ses variantes, y compris les normalisations coréennes. |
| Adaptateurs STT | STT système, Whisper local quand disponible et ElevenLabs Scribe selon disponibilité. |
| `SttLabScreen` / `SttCorpusRecorder` | Outils de diagnostic sur appareil : corpus étiqueté et comparaison des moteurs. |

## Flux mains-libres

```text
audio du prompt → signal de fin → remise micro → hypothèses STT
→ validation contrainte → feedback audio → carte suivante
```

`AudioDirector` doit terminer ou annuler l'audio précédent avant l'écoute.
`SttRace` et `VoiceTurnMachine` ignorent les résultats arrivés après la fin du
tour pour empêcher une réponse de contaminer la carte suivante.

## Règles de modification

1. Modifier ces seams, leurs tests et cette note ensemble ; ne pas contourner
   l'orchestrateur depuis un widget.
2. Mesurer sur un corpus enregistré avant de changer la priorité d'un moteur.
3. Toute clé, limite, fonction Edge ou coût de fournisseur se configure hors du
   client et doit être documenté dans un runbook sans jamais inscrire un secret
   dans Git.
4. Toute nouvelle stratégie de course ou de capture doit être validée en arrière
   plan, avec permissions, réseau lent et au moins un appareil réel.

## Décisions encore ouvertes

- Faut-il distribuer/télécharger un modèle Whisper hors ligne, pour quelles
  langues, avec quelle taille et quel fallback UX ?
- Quels seuils de latence, exactitude, consommation et coût rendent un moteur
  acceptable pour le lancement bêta ?
- Quelle configuration déployée Supabase/ElevenLabs (authentification, rate
  limit, quotas et observabilité) garantit ce contrat à l'échelle ?
