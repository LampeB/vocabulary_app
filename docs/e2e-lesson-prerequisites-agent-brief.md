# Brief agent — E2E des leçons et prérequis vocabulaire

## But

Ajouter une suite Patrol Android qui vérifie le vrai parcours de leçon de grammaire : une leçon reste bloquée tant que **ses propres listes prérequises** ne sont pas suffisamment connues, mène vers la bonne liste, puis devient ouvrable quand les prérequis sont satisfaits.

Ce travail porte sur les tests et les petits `WidgetKeys` nécessaires à des sélecteurs stables. Il ne doit pas modifier la règle produit ni contourner l'accès avec un drapeau de développement.

## Règle produit à préserver

Pour une règle de grammaire donnée :

1. Ne considérer que `rule.prerequisiteLists`. Une liste C sans lien avec la règle A+B ne doit jamais bloquer ni débloquer cette règle.
2. Chaque liste prérequise doit atteindre **70 %** de mots connus au minimum.
3. Le cumul, pondéré par le nombre de mots de chaque liste prérequise, doit atteindre **80 %**.
4. Sans liste correspondante, ou avec une liste sous 70 %, la règle est `locked`.
5. Lorsqu'elle est disponible, la règle est `unlocked`; une leçon déjà terminée est `mastered`.

La source de vérité est `lib/presentation/providers/grammar/grammar_provider.dart` :
`ruleStatusesProvider`, `arePrerequisitesKnown`, `RuleStatus`,
`kPrerequisiteUnlockThreshold`. Ne pas dupliquer ni réinterpréter les calculs dans le test.

## Comportement UI attendu

`lib/presentation/screens/grammar/grammar_screen.dart` affiche :

- une carte par règle avec `WidgetKeys.grammarRuleCard(rule.id)` ;
- pour une règle bloquée, une progression globale et une barre par prérequis ;
- une barre prérequise cliquable seulement lorsqu'elle peut pointer vers une liste
  utilisateur correspondante ;
- pour une règle déverrouillée, le bouton
  `WidgetKeys.grammarRuleOpenLesson(rule.id)` qui ouvre `/grammar/<id>` ;
- le lecteur cible a la clé `WidgetKeys.screenGrammarLesson`.

Les règles sont chargées par `grammarRulesProvider(lang)`. Les prérequis sont
résolus par `seedId` (`<token>:<source>><target>`) puis, en compatibilité, par
nom de liste. Les données de progression se lisent via
`progressRepositoryProvider.getListStats(listId)`.

## Infrastructure existante à réutiliser

- Les tests Patrol sont dans `patrol_test/`.
- Les pas partagés sont dans `patrol_test/helpers/steps.dart` et doivent rester
  des phrases `given / when / then` à responsabilité unique.
- `patrol_test/helpers/test_helpers.dart` lance l'app, signe le compte de test
  et nettoie les listes. Utiliser `addTearDown(() => deleteAllLists($))`.
- `Steps.given.aListWithOneWord(...)` montre le style de préparation autorisé
  pour les données. Il est acceptable de préparer les listes/progrès via les
  providers Riverpod : l'action métier (résolution des prérequis, routage,
  affichage) doit, elle, être observée dans la vraie UI.
- Les sélecteurs doivent venir de `lib/core/widget_keys.dart`, jamais de texte
  traduit. Ajouter une clé seulement si aucune clé stable suffisante n'existe.
- Le compte E2E et les secrets sont injectés par `test.env.json` / CI : ne jamais
  écrire de secret dans un test ou une documentation.
- Commande locale :

```powershell
patrol test --target patrol_test/<nouvelle-suite>.dart `
  --dart-define-from-file=test.free.env.json -d emulator-5554
```

`test.free.env.json` est local et ignoré par Git. Pour accélérer un essai :
`--dart-define=TEST_CARD_LIMIT=10`.

## Scénarios E2E demandés

Créer une suite dédiée, par exemple `patrol_test/lesson_prerequisites_test.dart`.

### 1. Règle bloquée et liste prérequise accessible

Préparer une règle réelle ayant au moins une liste prérequise, et une liste
correspondante avec une maîtrise sous le seuil (idéalement 0 %). Puis :

1. signer l'utilisateur et nettoyer les listes ;
2. créer/amorcer seulement les listes requises par cette règle ;
3. ouvrir le hub des leçons ;
4. constater que la carte de règle est visible, mais pas son bouton d'ouverture ;
5. taper la barre de la liste prérequise ;
6. constater l'ouverture de la bonne `screenListDetail` et le nom de la liste.

Ce test prouve le blocage et l'explication actionnable, pas uniquement un label.

### 2. Une liste étrangère ne compte pas

Préparer les listes A/B d'une règle sous le seuil, et une liste C complètement
connue qui ne fait pas partie de ses prérequis. Vérifier que la règle reste
bloquée. Ce scénario empêche la régression « pourcentage global sur toutes les
listes ».

### 3. Déverrouillage réel et ouverture du lecteur

Préparer **toutes et seulement** les listes prérequises de la règle avec des
statistiques qui respectent les seuils (>= 70 % chacune et >= 80 % pondéré).
Puis ouvrir le hub, taper `grammarRuleOpenLesson(rule.id)` et vérifier
`screenGrammarLesson`.

Si amorcer les statistiques de maîtrise via l'UI est trop lent, préparer les
progrès par le repository Riverpod, mais garder l'assertion de disponibilité et
l'ouverture entièrement via l'UI.

## Ce qu'il faut chercher avant de coder

1. Un vrai `GrammarRule` de catalogue utilisable dans `assets/`, les tests seed,
   ou `grammarRulesProvider`, et ses tokens de prérequis.
2. L'API repository permettant de persister des `VariantProgress` connus sans
   inventer un faux champ. Réutiliser un helper ou une fixture existants si elle
   existe.
3. La forme exacte de `VocabularyList.seedId` attendue par le provider.
4. La disponibilité réelle des barres prérequises comme cibles de tap. Ajouter
   une clé par barre si nécessaire; ne pas utiliser un finder de position.

## Critères d'acceptation

- Les trois scénarios passent sur `emulator-5554` avec Patrol.
- `flutter analyze` sur les fichiers modifiés est vert.
- La suite est ajoutée à `TARGETS` de `.github/workflows/e2e.yml`.
- Le test ne dépend pas d'un ordre d'exécution, nettoie ses listes, et ne laisse
  pas de données du compte de test.
- Aucun secret, aucune URL privée et aucun contournement debug ne sont committés.
- Documentation de tests mise à jour seulement si elle devient inexacte.
- Un commit cohérent est créé et poussé sur la branche actuelle.

## Hors scope

- Modifier l'algorithme de déverrouillage.
- Créer du contenu pédagogique ou modifier les catalogues de règles.
- Tester un achat, les amis, les notifications push réelles ou le STT.
- Refaire le design V3 : ce travail observe le comportement déjà rendu par lui.
