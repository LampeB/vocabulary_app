---
status: accepted
date: 2026-11-26
owners:
  - Thomas
---

# Décision — Whisper local sans le wrapper GPL

## Contexte

Le moteur local reste une capacité voulue. Le wrapper `whisper_flutter_new`
était sous GPL et représentait l'essentiel des lignes ajoutées par la branche
d'intégration. Le développement est encore privé et local ; la diffusion
externe est préparée pour plus tard.

## Décision

Retirer ce wrapper et écrire un pont Flutter/C minimal propre au projet vers
`ggml-org/whisper.cpp`, sous MIT. Conserver le moteur tiers en sous-module Git
épinglé à un commit et vérifier le modèle par taille et empreinte SHA-256.
Le choix a été accepté par l'utilisateur dans la conversation d'intégration.

Le pont ne reprend pas le code du wrapper GPL. Son périmètre livré est Android
et les hypothèses de performance et de précision doivent encore être mesurées
sur appareil. L'intégration iOS reste à réaliser séparément.

## Conséquences

- Préserver les notices des dépendances et contrôler les changements de licence.
- Construire le code natif en CI et initialiser les sous-modules lors du clone.
- Conserver les archives Git historiques ; retirer le code de la version
  distribuée ne supprime pas son historique.
- La licence du code propre à l'application demeure une décision indépendante.

Voir [l'architecture audio](../stt-improvement-plan.md) et
[le runbook de distribution](../runbooks/whisper-gpl-distribution.md).
