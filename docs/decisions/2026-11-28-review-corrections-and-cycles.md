---
status: accepted
date: 2026-11-28
owners:
  - Thomas
supersedes:
  - 2026-11-22-pr-validation-convergence.md
---

# Décision — relectures ouvertes, corrections renforcées et nouveau cycle

## Contexte

Les vingt passes du premier cycle n'ont pas convergé. Leur rétrospective
montre des familles de défauts examinées trop localement et des effets de
correction découverts lors d'une passe ultérieure. Une grille exhaustive
imposée aux relecteurs limiterait leur exploration sans prouver la couverture.

## Décision utilisateur du 28 novembre 2026

Conserver les quatre relecteurs vierges et leurs missions larges. Ils peuvent
suivre des pistes inattendues et signaler des défauts hors des points
d'attention suggérés. Un bref compte rendu des zones examinées et limites
rend leur travail lisible, sans liste exhaustive à cocher pour être propre.

Renforcer surtout les correcteurs et l'orchestration : identifiants de
constats, recherche de cause et d'invariant, cas voisins, consommateurs
partagés, effets de bord et preuves adaptées au comportement réel. Ce travail
reste dans le périmètre des constats et des contrats acceptés.

Autoriser un nouveau cycle de **vingt passes au maximum par profil**, nommé
cycle 2. Ses passes 1–20 sont les relectures cumulées 21–40 ; les vingt
premières ne sont pas effacées. Un cycle supplémentaire exige une nouvelle
décision explicite. Le bot lie chaque rapport à son cycle dans la preuve
attestée et refuse le mélange de cycles.

Cette décision remplace la portée du plafond et précise le traitement des
corrections de la décision du 22 novembre. Les autres garanties restent
applicables : quatre verdicts sur le même SHA avant correction, tous les
Bloquant/Important traités ensemble, deux passes propres consécutives sur
le même commit dans un même cycle, CI obligatoire, approbation admissible
et protections normales de `main`. La branche d'intégration reste unique.

## Références

- [Spécification de validation](../pr-validation.md)
- [Décision initiale](2026-11-22-pr-validation-convergence.md)
- [Registre du premier cycle](../reviews/2026-11-27-integration.md)
