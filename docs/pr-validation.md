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
| Contrat et documentation | Vérifier que le changement respecte les décisions, spécifications et état du projet applicables. | Contrat produit ou technique contredit, documentation manquante ou devenue factuellement fausse, décision non autorisée. |
| Correction et tests | Relire le comportement Flutter/Dart et les tests comme un propriétaire du code. | Régression, cas limite, effet de bord, erreur de persistance/synchronisation, test manquant ou fragile. |
| Sécurité et livraison | Examiner les frontières externes et le chemin de livraison. | Secret, permissions ou workflow CI dangereux, dépendance à risque, artefact généré versionné, régression de configuration ou de build. |
| Expérience et contenu | Contrôler l'expérience réellement proposée à l'apprenant. | Localisation, accessibilité, petits écrans, thèmes, parcours visible et, si le diff touche les seeds, cohérence pédagogique. |

Un relecteur dont la spécialité n'est pas touchée le signale explicitement ;
il vérifie tout de même que le diff ne franchit pas une frontière relevant de
sa mission.

## Format de verdict

Chaque observation donne sa gravité, la preuve (fichier et ligne ou scénario
reproductible), le risque et la correction attendue.

- **Bloquant** : défaut à corriger avant fusion.
- **Important** : défaut ou absence de validation à corriger avant fusion.
- **Suggestion** : amélioration non bloquante, conservée pour décision humaine.
- **Aucun constat** : aucun bloquant ni important trouvé.

Les observations de style sans conséquence ne sont pas rapportées : le
formatage et les règles mécaniques appartiennent à la CI.

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

## Références

- [État actuel](../PROJECT_STATUS.md)
- [Tests et stratégie](../TESTS.md)
- [Documentation et commits](runbooks/documentation-et-commits.md)
- [Décision de convergence](decisions/2026-11-22-pr-validation-convergence.md)
