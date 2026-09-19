# Prompt à copier-coller — agent E2E prérequis de leçons

Tu travailles dans le dépôt Flutter `vocab_kr`. Lis d'abord intégralement
`docs/e2e-lesson-prerequisites-agent-brief.md`, puis implémente exactement le
lot décrit. Ne traite pas ce brief comme une simple suggestion : ses règles de
déverrouillage et ses critères d'acceptation sont obligatoires.

Commence par inspecter les providers, repositories, fixtures et données seed
existants afin d'utiliser une vraie règle de grammaire et de vraies données de
maîtrise. Préfère les clés dans `lib/core/widget_keys.dart` et les pas partagés
dans `patrol_test/helpers/steps.dart`; n'utilise pas du texte traduit ni des
finders positionnels pour piloter l'UI.

Le résultat attendu est une nouvelle suite Patrol qui vérifie :

1. une règle bloquée avec navigation vers la liste prérequise ;
2. qu'une liste non prérequise, même totalement connue, ne déverrouille pas la
   règle ;
3. une règle réellement déverrouillée, suivie de l'ouverture du lecteur de
   leçon.

Les données peuvent être amorcées par la couche Riverpod/repository pour rendre
le test rapide, mais l'état bloqué/déverrouillé et la navigation doivent être
constatés dans l'application réelle sur Android. Ne modifie pas l'algorithme
produit, n'utilise pas d'override debug, ne commite aucun secret.

Exécute au minimum `flutter analyze` sur les fichiers touchés et la nouvelle
suite Patrol sur `emulator-5554` avec `test.free.env.json`. Ajoute la suite à la
CI `.github/workflows/e2e.yml`, mets à jour la doc seulement si nécessaire,
crée un commit cohérent puis pousse la branche courante. À la fin, donne le hash
du commit, les commandes exécutées et les résultats de test.
