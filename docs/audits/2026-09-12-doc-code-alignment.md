# Alignement documentation ↔ code — règles produit V0

**Date :** 12 septembre 2026
**Portée :** décisions marquées « décidé » dans les documents de design et
périmètre V0 adopté le 12 septembre. Les éléments « proposés » ne sont pas des
engagements, sauf lorsqu'ils contredisent une décision plus récente.

## Verdict

Le noyau métier est cohérent : les listes restent libres, les prérequis de
leçon existent, et le seuil est bien **80 % pondéré avec 70 % minimum par
liste**. La documentation est
maintenant claire : un quiz de vocabulaire peut démarrer sans parcours.

L'écart principal est structurel. Le dépôt contient le moteur et l'interface
v1, tandis que la documentation décrit le futur parcours V0 et son langage
d'interaction v2. Les écarts ci-dessous doivent donc former les prochains lots
de produit, pas des correctifs isolés.

| État | Sens |
| --- | --- |
| Conforme | Règle appliquée, avec test pertinent. |
| Partiel | Fondation présente, promesse incomplète. |
| À construire | Pas encore de chemin produit complet. |

## Règles métier et pédagogiques

| Règle | État | Preuve dans le code | Suite |
| --- | --- | --- | --- |
| Une liste créée/importée peut être étudiée sans curriculum. | **Conforme** | `getDueCards` ajoute les variantes sans progression ; le setup accepte une source `list`. | Garder cet invariant testé. |
| Découvrir recommande un premier contact, sans bloquer la pratique libre. | **Partiel** | Le quiz direct fonctionne ; les écrans Découvrir/écho n'existent pas. | Ajouter ces étapes seulement au chemin facultatif. |
| Une leçon dépend de listes de vocabulaire préalables. | **Conforme** | `prerequisite_lists`, barres de progression et verrou dans le hub/le setup. | Conserver des prérequis par `seed_id`. |
| Pré-requis à 80 % pondéré, avec au moins 70 % dans chaque liste. | **Conforme** | `arePrerequisitesKnown` pondère par le nombre de mots et impose le plancher par liste ; les tests couvrent le cas 100 % + 60 % verrouillé. | Rien. |
| Une leçon verrouillée dit quoi travailler. | **Conforme** | Le hub montre la progression et les listes ; le setup les nomme. | Réutiliser ce message dans le futur lecteur. |
| Texte de leçon figé et exemples à partir de vocab connu. | **Partiel** | Règles JSON et exemples figés existent ; les drills sélectionnent des mots connus. Pas de schéma/lecteur multi-pages. | Créer le modèle de leçon seedé minimal. |
| Clusters, mélange final et progression par niveau. | **À construire** | Règles et exercices individuels seulement. | Ajouter le modèle de cluster après le lecteur. |

## Langues et contenu V0

| Règle | État | Preuve dans le code | Suite |
| --- | --- | --- | --- |
| UI V0 en français, anglais et coréen. | **Conforme (fondation)** | Les trois locales sont chargées ; les clés récentes d'accueil existent dans les trois fichiers. | Ajouter un test de parité récursif des clés. |
| Paires V0 visibles : FR→KO, EN→KO, KO→FR. | **Partiel** | Le picker de l'accueil limite à ces trois paires et transmet la paire au quiz. La création de liste garde six langues. | Décider : cacher, étiqueter ou assumer les paires hors V0. |
| Un seul chip de paire, avec ajout en deux étapes cible puis base. | **Partiel** | Chip sur l'accueil, mais seulement trois choix ; le dialogue de création a encore son propre sélecteur. | Centraliser la sélection lors de l'UX « démarrer une langue ». |
| KO→FR ne tombe pas sur l'anglais. | **Non conforme — bloqueur contenu** | Les règles FR/KO n'ont que `fr` et `en` ; le resolver retombe sur l'anglais. Pas de leçons en coréen. | Auteuriser et faire relire les explications coréennes avant bêta. |
| Les 18 salutations ont des exemples utiles FR/EN/KO. | **À construire — bloqueur contenu** | La roadmap V0 indique seulement trois exemples coréens. | Compléter et faire valider la première unité. |

## Parcours quotidien et interface

| Règle | État | Preuve dans le code | Suite |
| --- | --- | --- | --- |
| Chemin dédié, généré/figé par jour, avec série par langue. | **Partiel** | Carte d'accueil et décompte d'échéances par paire ; pas de route S18, modèle persistant, gel quotidien ou série par langue. | Construire le shell local, le générateur et les deep-links. |
| Révisions → leçons → drills → renforcer ; réussite quand tout est fait. | **À construire** | Les flux existent séparément, sans orchestration ni complétion. | Ajouter après le shell, sans toucher à la pratique libre. |
| Navigation « plongée » et repli mouvement réduit. | **À construire** | Routes Material par défaut, sans Hero/zoom ni stratégie reduced-motion. | Créer une transition réutilisable et migrer un flux complet. |
| Pile inclinée seulement pour les flashcards qui se dépilent. | **Partiel** | Carte active, flip et FSRS présents ; pas de pile visuelle. Les autres écrans n'en utilisent pas. | Ajouter la pile dans le seul mode Cartes. |
| Exemples de leçon en popup contextuelle accessible. | **À construire** | Modales génériques, mais pas de lecteur ni de popup d'exemple avec reprise focus/position. | Construire le composant avec le lecteur. |
| Scroll rare et annoncé. | **Non conforme** | Plusieurs `ListView`/`SingleChildScrollView` essentiels n'ont pas d'indicateur transverse. | Définir un indicateur réutilisable et l'appliquer au nouveau flux. |
| Footer cinq slots égaux, sans bouton central. | **Non conforme, V0 à préciser** | `AppShell` a quatre onglets et un bouton Étudier central surélevé. | Navigation V2 dans un lot dédié ; social/paiement restent différés V0. |
| Retour vers le vrai point d'entrée. | **Partiel** | `pop` fonctionne sur les routes poussées ; plusieurs CTA font `go`, sans contrat `returnTo`. | Ajouter l'origine pour S18/S4/S5 dès leur création. |

## Écarts documentaires corrigés dans ce changement

`two-flow-daily-plan.md`, `vocab-flow.md` et `pratique-libre.md` contenaient
encore l'ancienne formulation d'une porte globale. Ils indiquent désormais que
Découvrir est une recommandation du parcours et que le quiz depuis une liste
reste libre, conformément à `ProgressRepositoryImpl.getDueCards`.

## Ordre d'exécution recommandé

1. **Contenu KO→FR de la première unité :** explications coréennes, exemples
   complets, puis revue de la professeure.
2. **Chemin du jour minimal et facultatif :** écran dédié, étape de révision
   par paire, entrée Découvrir placeholder vers une liste.
3. **Lecteur de leçon réutilisable :** données seedées, pages courtes, popup
   d'exemple, reprise de position ; c'est là que plongée et scroll s'appliquent.
4. **Finition du flux :** écho non noté, complétion, pile flashcard, tests de
   persistance/hors-ligne et essais appareil des trois paires.

Les amis, l'abonnement, les clusters complets et le nouveau footer restent hors
du chemin critique V0, sauf décision produit contraire.

## Vérification

Le seuil hybride 80 % / 70 % a été contrôlé par analyse ciblée et les tests d'écran de
grammaire/statistiques de listes. Cet audit compare les contrats documentation
et code ; il ne valide ni appareil physique, ni backend déployé, ni qualité
pédagogique des traductions.
