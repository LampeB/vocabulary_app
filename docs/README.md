# Documentation VocabKR

Ce dossier sépare volontairement l'état **actuel** des plans, maquettes et
audits historiques. Ne déduisez jamais qu'une décision est livrée parce qu'un
ancien document la décrit comme souhaitable.

## Commencer ici

1. [État actuel du projet](../PROJECT_STATUS.md) — périmètre livré, écarts
   connus et prochaines étapes, mis à jour après chaque lot significatif.
2. [V3 — Sentier de cartes](design/v3-sentier-de-cartes.md) — référence
   d'implémentation de la slice V3 et de ses limites actuelles.
3. [Carte des décisions](design/map/app-map.md) — les décisions produit
   validées, proposées ou encore ouvertes.
4. [Tests](../TESTS.md) et [guide d'écriture](writing-tests.md) — inventaire,
   commandes et règles de test.

## Spécifications actives

| Sujet | Document |
| --- | --- |
| Boucle V0 complète et critères de sortie | [v0-daily-loop-plan.md](v0-daily-loop-plan.md) |
| Interaction : plongée, flashcards, popups, scroll | [interaction-language.md](design/map/interaction-language.md) |
| Prérequis de leçons | [audit d'alignement V0](audits/2026-09-12-doc-code-alignment.md) |
| Contenu et génération | [content-roadmap.md](content-roadmap.md) · [seed-content-authoring.md](seed-content-authoring.md) |
| Architecture voix/audio | [stt-improvement-plan.md](stt-improvement-plan.md) · [refactor-voice-orchestration.md](refactor-voice-orchestration.md) |

## Historique et matériel de référence

- `audits/` contient des constats datés ; ils ne remplacent pas l'état actuel.
- `design/app-design-overview.md`, `design/v2-ux-architecture.md`, les
  maquettes et les captures v1/v2 restent des références historiques ou des
  propositions. Leur statut est indiqué dans chaque fichier.
- `feature-coverage.md` et `test-coverage-roadmap.md` expliquent la stratégie
  et l'historique de couverture ; l'inventaire exécutable est `TESTS.md` et la
  CI dans `.github/workflows/`.

## Règle d'entretien

Un changement qui modifie une règle produit, une route de la slice V3, une
source de vérité design, une architecture voix/audio ou la CI doit mettre à
jour au minimum `PROJECT_STATUS.md` et le document canonique concerné, dans le
même commit.
