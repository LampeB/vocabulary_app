---
status: accepted
date: 2026-11-23
owners:
  - Thomas
supersedes: []
---

# Décision — Ponderin est le nom de travail

## Contexte

`VocabKR` ne décrit plus la portée multi-langue ni l'univers calme de l'app :
eau, étang et ondulations. Le développement reste entièrement interne ; aucune
diffusion externe n'est en cours. Le nom `Ponderin` est une piste distincte de
Ponder ; il n'a pas fait l'objet d'une recherche de disponibilité de marque,
de domaine ou de store.

## Décision

**Ponderin** devient le nom de travail visible de l'application pendant le
développement. Ce n'est pas encore une marque ou un nom de diffusion validé.

Les identifiants techniques actuels (`vocab_kr`, `com.vocabkr.vocab_kr`,
`vocabkr://`) restent stables tant qu'un nom final et un espace de nommage
contrôlé (notamment un domaine) ne sont pas choisis.

## Conséquences

- Une PR dédiée peut remplacer les textes, assets et documents visibles par
  Ponderin sans migrer la base locale, les liens, Supabase ou les identifiants de
  publication.
- Avant toute bêta externe, la disponibilité de la marque, des stores et du
  domaine doit être vérifiée ; le nom final peut donc encore différer de
  Ponderin.
- Le futur changement d'identifiants fera l'objet d'une migration documentée,
  afin de ne pas rompre les installations, les callbacks d'authentification ni
  les liens de partage.

## Références

- [Carte des décisions produit](../design/map/app-map.md)
- [État du projet](../../PROJECT_STATUS.md)
- [Architecture STT/audio](../stt-improvement-plan.md)
