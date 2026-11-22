---
status: accepted
date: 2026-11-22
owners:
  - Thomas
supersedes: []
---

# Décision — convergence des relecteurs de PR

## Contexte

Les validations déterministes ne suffisent pas à détecter toutes les
régressions de comportement, d'expérience, de sécurité ou d'alignement avec la
documentation. Des relecteurs agents indépendants sont donc ajoutés au flux de
PR. Leur analyse est cependant non déterministe : un verdict propre isolé ne
constitue pas une preuve suffisante de convergence.

## Décision

Une PR est revue par quatre profils en lecture seule : contrat/documentation,
correction/tests, sécurité/livraison, et expérience/contenu. Ils examinent tous
le même commit avant toute correction. Tous les constats bloquants et
importants sont traités ensemble avant une nouvelle itération.

Chaque profil peut participer à vingt itérations au maximum. La convergence
requiert deux verdicts consécutifs sans constat bloquant ni important pour
chacun des quatre profils, sur le même commit final, par des instances d'agents
fraîches. Aucun correctif n'est créé entre ces deux itérations propres. Tout
nouveau commit remet les compteurs de validation à zéro. À vingt itérations
sans convergence, la fusion reste bloquée et une décision humaine est requise.

## Conséquences

- Une itération de revue ne peut pas masquer une observation tardive d'un autre
  profil : les quatre verdicts sont collectés avant toute correction.
- Une PR propre nécessite volontairement deux relectures indépendantes du même
  code, afin de réduire l'effet du caractère non déterministe des agents.
- Les suggestions ne bloquent pas ; les contrôles CI et l'approbation humaine
  restent obligatoires avant fusion.
- Le futur orchestrateur doit conserver les verdicts, le SHA examiné et le
  compteur de chaque profil.

## Références

- [Spécification de validation des PR](../pr-validation.md)
- [Documentation et commits](../runbooks/documentation-et-commits.md)
