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
4. une approbation GitHub admissible exigée par la protection de branche.

Décision utilisateur du 27 novembre 2026 : un bot GitHub Actions peut fournir
l'approbation formelle après les quatre profils indépendants et la CI. Il ne
fait pas de nouvelle analyse de code et ne prétend pas être Copilot. Le compte
utilisé n'est actuellement pas éligible à la revue Copilot ; aucune licence
n'est achetée et aucune approbation Copilot n'est simulée. Le bot vérifie le
SHA, la preuve de convergence attestée par le propriétaire et les huit checks
CI avant de publier une review `APPROVED`. Les approbations périmées sont
annulées au push ; le bot ne fusionne pas et ne modifie pas le code.

L'orchestrateur publie le statut requis `PR / Independent agent reviews` sur
le SHA de tête courant. Il reste `pending` pendant les revues/corrections et
ne passe à `success` qu'après deux verdicts propres consécutifs des quatre
profils sur ce même SHA. Les compteurs et rapports sont consignés dans la PR.
Tout nouveau SHA repart en attente. Ce statut s'ajoute aux huit checks CI :
une CI verte et une approbation externe seules ne satisfont pas la convergence.

### Preuve vérifiée par le bot

Le corps de PR contient exactement un commentaire HTML commençant par
`<!-- ponderin-review-evidence` et terminé par `-->`. Son objet JSON possède
exactement `head_sha`, `base_sha` et `reviewers`. Ce dernier associe les quatre
noms de profils `.codex/agents/` à deux rapports : `iteration` (1–20),
`instance_id`, `verdict` (`PROPRE`), `bloquant` (0), `important` (0), et
éventuellement `report_text`. Les deux itérations sont consécutives et communes
aux quatre profils ; les huit identifiants d'instances sont distincts.

Le propriétaire atteste cette preuve avec le statut de convergence dont la
description est `reviews-v1:` suivi du SHA-256 du JSON canonique (clés triées,
séparateurs `,`/`:`, `ensure_ascii=True`, encodage UTF-8). Le bot refuse une
preuve altérée, un statut d'un autre auteur, une CI périmée ou issue d'une
autre application, un fork, un brouillon ou une nouvelle tête/base. Il relie
les sept checks de PR au workflow `.github/workflows/pr-validation.yml`, à
l'événement `pull_request`, au numéro de la PR et aux SHA exacts de tête et de
base. Le check `test` doit provenir d'un `push` sur la même tête dans
`.github/workflows/test.yml`. Le bot vérifie aussi que chaque check provient
de la suite associée à l'exécution GitHub Actions correspondante. Le titre
de l'exécution PR conserve les valeurs de l'événement d'origine, même si
GitHub affiche ensuite les références courantes dans `pull_requests`.

Le workflow manuel [d'approbation](../.github/workflows/approve-validated-pr.yml)
s'exécute sur `main` à la demande du propriétaire et charge le script de ce
même commit.

### Première activation

Avant la première fusion, `approve-validated-pr.yml` est absent de la branche
par défaut. GitHub exige un fichier déjà présent sur cette branche pour recevoir
`workflow_dispatch`. Pour ce premier passage uniquement, utiliser le chemin
du [workflow E2E existant](../.github/workflows/e2e.yml) sur une branche
d'exploitation temporaire. Voir la [condition de déclenchement GitHub](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).

1. Créer `ops/bootstrap-pr-approval` depuis le SHA exact de `main` attesté dans
   la preuve. Ce commit d'exploitation contient uniquement le script
   `tool/approve_validated_pr.py` revu et le remplacement temporaire de
   `.github/workflows/e2e.yml` par le workflow d'approbation revu adapté à cette
   référence. Vérifier le parent, le diff des deux fichiers et le SHA complet
   avant de publier cette branche.
2. Sur cette branche, activer uniquement `workflow_dispatch` avec `pull_number`,
   `expected_head` et `expected_ops_sha`. Reprendre les permissions limitées du
   workflow d'approbation. Restreindre le job à
   `refs/heads/ops/bootstrap-pr-approval`, au propriétaire en tant qu'acteur et
   acteur déclencheur, et à `github.sha == inputs.expected_ops_sha`. Vérifier le
   ref d'exploitation dans le job et charger le script au `github.sha` de ce job
   avec `persist-credentials: false`. Vérifier le SHA du checkout avant de lancer
   le script.
3. Une fois la convergence réelle attestée et la CI verte, le propriétaire
   vérifie que la branche publiée pointe vers le SHA d'exploitation revu et
   déclenche `e2e.yml` avec la branche et les trois valeurs exactes. La preuve,
   le statut de convergence et la CI font l'objet des mêmes contrôles que dans
   le workflow permanent. Après confirmation de l'approbation sur la tête de
   PR attendue, supprimer la branche temporaire.

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
  configuration privée, y compris les chemins accentués et les chemins avec
  retour à la ligne. Le fichier de déploiement local `supabase/.env.deploy`
  est interdit dans l'index et dans les diffs de PR. La CI vérifie aussi que
  Git lance le hook après son installation sous Ubuntu ;
- `flutter analyze`, les tests hôte et le seuil de couverture ;
- les diagnostics STT testés en debug avec et sans opt-in et une sonde Dart
  compilée en mode produit avec l'opt-in actif pour vérifier le refus ;
- une revue des dépendances, un scan de secrets et `actionlint` ;
- un audit `zizmor` de tous les workflows, avec actions épinglées par SHA ;
- une compilation Android intégrant le moteur natif Whisper épinglé ;
- une compilation debug pour le simulateur iOS sur macOS, sans signature, sans
  secrets de projet et sans publication de binaire ;
- un contrôle de la frontière de licence Whisper et des tests des fonctions
  cloud/quota sur une base PostgreSQL jetable.
Ce dernier contrôle applique aussi les migrations de production de sécurité.
Il vérifie que `vocab-audio` reste fermé aux clients entre 007 et 012, puis
exerce les lectures publiques, la confidentialité et l'immuabilité des clips
malgré une règle Storage permissive préexistante. Les tests des outils admin
vérifient le refus de HTTP et des redirections avec des clés factices. Le
prévol Patrol et le reset exigent le contrat `challenge-boundaries-v1` de 019.
Les suites SQL vérifient les vrais refus de reset avec données conservées
jusqu'à 018, puis l'acceptation après 019
et le refus quand un garde d'isolation, de suppression, de référence privée ou
d'écriture est désactivé. Les tests d'isolation E2E couvrent les écritures de
relations et de progression par le rôle authentifié. Deux connexions PostgreSQL vérifient qu'une
demande d'amitié concurrente attend la fin du reset, puis est refusée.

La version Flutter de ce check est figée à **3.44.9**, celle qui correspond à
la version validée du projet. Toute montée de SDK est une modification séparée
qui doit rendre la suite verte avant de devenir la nouvelle référence CI.

Le projet iOS utilise CocoaPods seul tant que des plugins nécessaires ne
gèrent pas Swift Package Manager. Le `ios/Podfile` est versionné et les
configurations Debug, Profile et Release de Runner chargent chacune les
réglages CocoaPods correspondants. Le build Flutter installe les pods avant
de lancer Xcode.

Le check du simulateur utilise le runner `macos-15-intel`. Runner et ses pods
excluent ARM64 pour le seul SDK `iphonesimulator`, car la caméra dépend de
GoogleMLKit BarcodeScanning 6.0. Sur un checkout neuf, Flutter 3.44.9 génère
ses réglages avant l'installation des pods et ne peut pas encore détecter
cette contrainte. Le SDK iPhone conserve sa configuration d'architecture.
[Podspec GoogleMLKit 6.0.0](https://github.com/CocoaPods/Specs/blob/master/Specs/b/e/b/GoogleMLKit/6.0.0/GoogleMLKit.podspec.json).

La revue de dépendances exige que le **Dependency Graph** soit activé dans les
réglages GitHub du dépôt. Tant que cette activation distante n'est pas faite,
le check échoue volontairement plutôt que de donner une validation trompeuse.
L'activation du graphe et des alertes Dependabot a été effectuée le 26 novembre
2026 via l'API GitHub ; la comparaison de dépendances est alors devenue
accessible. Le résultat du check reste à revérifier sur chaque commit final.

Les profils des quatre relecteurs sont versionnés dans `.codex/agents/` et le
skill d'orchestration dans `.agents/skills/pr-validation/`. Ils n'accordent
jamais eux-mêmes une fusion : l'approbation GitHub admissible, la convergence
publiée et les checks obligatoires restent le verrou effectif.

Copilot n'est pas une dépendance du sas. Son éventuelle activation future
nécessitera une licence éligible et les réglages décrits dans la
[configuration officielle](https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-code-review).

## Références

- [État actuel](../PROJECT_STATUS.md)
- [Tests et stratégie](../TESTS.md)
- [Documentation et commits](runbooks/documentation-et-commits.md)
- [Décision de convergence](decisions/2026-11-22-pr-validation-convergence.md)
- [Lot de correction de la revue d'intégration du 27 novembre](reviews/2026-11-27-integration.md)
