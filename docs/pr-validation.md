# Validation des pull requests

Cette spécification définit le sas obligatoire avant une fusion dans `main`.
Les contrôles mécaniques (CI) restent la source de vérité pour ce qui est
déterministe ; les relecteurs agents recherchent les défauts de jugement que
ces contrôles ne peuvent pas exprimer.

## Les quatre relecteurs

Chaque relecteur est lancé sur le diff entre la branche de la PR et `main`.
Il est en lecture seule, repart sans le contexte de l'auteur et rend un rapport
structuré. Il ne modifie jamais la branche.

| Relecteur | Mission | Cherche en particulier |
| --- | --- | --- |
| Produit, contrat et expérience | Vérifier que le changement respecte les décisions, spécifications et état du projet applicables, et qu'il reste cohérent pour l'apprenant. | Contrat produit ou technique contredit, documentation manquante ou devenue factuellement fausse, décision non autorisée, localisation, accessibilité, petits écrans, thèmes, parcours visible et cohérence pédagogique des seeds. |
| Qualité du code, architecture et performance | Relire le code lui-même comme un mainteneur senior, indépendamment des tests. | Duplication d'une capacité existante, mauvaise frontière de couches, API ou abstraction inutile, cycle de vie Flutter incorrect, rebuilds ou I/O évitables, synchronisation coûteuse, dette de lisibilité ou de maintenabilité. |
| Correction et tests | Relire le comportement Flutter/Dart et les tests comme un propriétaire du code. | Régression, cas limite, effet de bord, erreur de persistance/synchronisation, test manquant ou fragile. |
| Sécurité et livraison | Examiner les frontières externes et le chemin de livraison. | Secret, permissions ou workflow CI dangereux, dépendance à risque, artefact généré versionné, régression de configuration ou de build. |

Un relecteur dont la spécialité n'est pas touchée le signale explicitement ;
il vérifie tout de même que le diff ne franchit pas une frontière relevant de
sa mission.

## Format de verdict

Chaque observation porte obligatoirement **un type unique** : `Bloquant`,
`Important` ou `Suggestion`. Aucun autre libellé (`mineur`, `nit`, `à voir`,
etc.) ne remplace ces types. Elle donne aussi la preuve (fichier et ligne ou
scénario reproductible), le risque et la correction attendue.

- **Bloquant** : défaut à corriger avant fusion.
- **Important** : défaut ou absence de validation à corriger avant fusion.
- **Suggestion** : amélioration non bloquante, conservée pour décision humaine.
- **Aucun constat** : aucun bloquant ni important trouvé.

Chaque rapport utilise ce format, même lorsqu'il n'a aucun constat :

```text
Relecteur : <profil>
Commit analysé : <SHA>

- Type : Bloquant | Important | Suggestion
  Emplacement : <fichier:ligne ou scénario>
  Preuve et risque : <constat vérifiable>
  Correction attendue : <action précise>

Verdict final : BLOQUÉ | PROPRE
```

`BLOQUÉ` est obligatoire dès qu'au moins un **Bloquant** ou **Important** est
présent. `PROPRE` signifie strictement qu'il n'y a ni Bloquant ni Important ;
il peut contenir des Suggestions. L'orchestrateur conserve les types à
l'identique lors de la consolidation et ne peut pas rétrograder un Bloquant ou
un Important sans décision humaine documentée.

Les observations de style sans conséquence ne sont pas rapportées : le
formatage et les règles mécaniques appartiennent à la CI.

Le relecteur de qualité du code ne remplace pas le linter : le linter impose
formatage, analyse statique et règles mesurables ; ce relecteur juge la qualité
que ces outils ne peuvent pas inférer du diff.

## Boucle de revue

Une itération est atomique : les quatre relecteurs examinent **le même commit**
et aucun correctif n'est fait avant que leurs quatre verdicts soient réunis.
L'orchestrateur déduplique les observations, puis l'auteur traite tous les
bloquants et importants de l'itération en une seule modification. La PR passe
ensuite à l'itération suivante sur son nouveau commit.

```text
commit de PR
  → quatre verdicts indépendants
  → consolidation de toutes les remontées
  → correction unique de tous les bloquants/importants
  → itération suivante
```

Si les quatre verdicts ne contiennent aucun bloquant ni important, aucun code
n'est modifié : l'itération suivante relit volontairement le **même commit**
avec de nouvelles instances d'agents. Cette seconde lecture indépendante
compense le caractère non déterministe de l'analyse par agent.

La convergence est atteinte seulement lorsque chacun des quatre relecteurs a
obtenu **deux verdicts propres consécutifs** sur le même commit final. Tout
nouveau commit remet ces compteurs à zéro pour les quatre relecteurs : un
correctif local peut avoir un effet de bord hors de sa zone apparente.

Chaque relecteur a au plus **20 itérations**. Si cette limite est atteinte sans
convergence, la boucle s'arrête sans fusion automatique et produit un rapport
de désaccord pour décision humaine.

## Conditions de fusion

La convergence des agents ne remplace jamais les garde-fous mécaniques. La
fusion exige, sur le commit final :

1. deux verdicts propres consécutifs des quatre relecteurs ;
2. toutes les validations CI obligatoires vertes ;
3. les conversations de PR résolues ;
4. l'approbation humaine exigée par la protection de branche.

## Garde-fous exécutables

Le hook local appelle `tool/check-pr-policy.ps1 -Staged`. Pour vérifier une
branche avant publication, utiliser :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/check-pr-policy.ps1 -BaseRef origin/main
```

La CI `Pull request validation` est exécutée sur chaque PR vers `main`. Elle
exige :

- le formatage des seuls fichiers Dart internes modifiés, afin de durcir le
  dépôt progressivement sans reformater du code hors sujet ;
- la politique documentaire et l'interdiction des artefacts générés ou de la
  configuration privée ;
- `flutter analyze`, les tests hôte et le seuil de couverture ;
- une revue des dépendances, un scan de secrets et `actionlint` ;
- un audit `zizmor` de tous les workflows, avec actions épinglées par SHA ;
- une compilation Android intégrant le moteur natif Whisper épinglé ;
- un contrôle de la frontière de licence Whisper et des tests des fonctions
  cloud/quota sur une base PostgreSQL jetable.

La version Flutter de ce check est figée à **3.44.9**, celle qui correspond à
la version validée du projet. Toute montée de SDK est une modification séparée
qui doit rendre la suite verte avant de devenir la nouvelle référence CI.

La revue de dépendances exige que le **Dependency Graph** soit activé dans les
réglages GitHub du dépôt. Tant que cette activation distante n'est pas faite,
le check échoue volontairement plutôt que de donner une validation trompeuse.
L'activation du graphe et des alertes Dependabot a été effectuée le 26 novembre
2026 via l'API GitHub ; la comparaison de dépendances est alors devenue
accessible. Le résultat du check reste à revérifier sur chaque commit final.

Les profils des quatre relecteurs sont versionnés dans `.codex/agents/` et le
skill d'orchestration dans `.agents/skills/pr-validation/`. Ils n'accordent
jamais eux-mêmes une fusion : l'approbation humaine et les checks GitHub
obligatoires restent le verrou effectif.

## Références

- [État actuel](../PROJECT_STATUS.md)
- [Tests et stratégie](../TESTS.md)
- [Documentation et commits](runbooks/documentation-et-commits.md)
- [Décision de convergence](decisions/2026-11-22-pr-validation-convergence.md)
