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

Une PR est revue par quatre profils en lecture seule : produit/contrat/
expérience, qualité du code/architecture/performance, correction/tests, et
sécurité/livraison. Ils examinent tous le même commit avant toute correction.
Tous les constats bloquants et importants sont traités ensemble avant une
nouvelle itération.

Chaque constat est typé obligatoirement `Bloquant`, `Important` ou
`Suggestion`. Un verdict n'est propre que s'il ne contient aucun Bloquant ni
Important.

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
- Les suggestions ne bloquent pas ; les contrôles CI et une approbation GitHub
  admissible restent obligatoires avant fusion. La précision du 27 novembre
  ci-dessous remplace l'exigence d'un approbateur nécessairement humain.
- Le futur orchestrateur doit conserver les verdicts, le SHA examiné et le
  compteur de chaque profil.

## Précision utilisateur du 27 novembre 2026

Après le refus d'éligibilité Copilot par GitHub, l'utilisateur a choisi un bot
GitHub Actions pour l'approbation formelle. Ce bot vérifie la CI et une preuve
des deux passes propres des quatre profils, sur le SHA courant ; il n'effectue
pas de relecture Copilot supplémentaire. Le statut requis
`PR / Independent agent reviews` matérialise cette convergence. Le bot publie
une review `APPROVED` admissible mais ne fusionne pas et ne modifie pas le code.

## Références

- [Spécification de validation des PR](../pr-validation.md)
- [Documentation et commits](../runbooks/documentation-et-commits.md)
