# V3 — Sentier de cartes

**Statut : implémentation partielle, référence active au 29 septembre 2026.**

Cette note est la référence versionnée du design V3. Le code Flutter et cette
note décrivent ce qui est réellement livré ; le prototype HTML du plateau ne
sert qu'à discuter l'intention visuelle.

## Intention

V3 est un environnement calme d'étang : fond vert sombre, ondulations lentes,
surfaces papier, typographie DM Serif Display pour les titres, Space Grotesk
pour le corps, Space Mono pour les libellés et Noto Serif KR pour le coréen.

La métaphore ne doit pas transformer toute l'application en collection de
cartes :

| Intention | Traitement V3 voulu |
| --- | --- |
| Ouvrir une destination | plongée/zoom court depuis l'élément sélectionné |
| Réviser une série de vocabulaire | pile de flashcards fixe, flip puis swipe |
| Approfondir un exemple de leçon | popup contextuelle, sans perdre la lecture |
| Lire beaucoup de contenu | scroll réduit et explicitement annoncé |

La règle détaillée demeure [interaction-language.md](map/interaction-language.md).

## Slice V3 actuellement livrée

| Étape | Écran / code | État |
| --- | --- | --- |
| Préchargement | `SplashScreen` | attend la restauration d'authentification puis le seed local avant de quitter l'écran |
| Entrée | `WelcomeScreen`, `AuthScreen` | V3, clair/sombre |
| Plateau | `V3HomeScreen` via `ParcoursScreen` | paire active, activité du jour, parcours, listes et activité libre |
| Chemin du jour | `DailyPathScreen` | révisions dues, entrée de liste et entrée Leçons ; le chemin reste optionnel |
| Liste/prérequis | `ListDetailScreen` | liste, pratique flashcards, mains-libres et ajout de mot |
| Configuration | `StartSessionScreen` | langue → liste/source → mode → sens → quantité |
| Révision | `QuizScreen` en flashcards ou mains-libres | pile, flip, swipe, mains-libres et bilan |

Les points d'entrée fonctionnels de cette slice sont donc continus. Cela ne
signifie pas que la définition de sortie de la boucle V0 complète est atteinte
(voir `../v0-daily-loop-plan.md`).

### Corrections d'intégration — 27 novembre 2026

- Le détail d'une liste affiche et modifie les deux langues dans leur ordre
  `langA` → `langB`. Les suggestions thématiques utilisent cette même paire
  pour leur contexte, leur requête et l'ajout des variantes.
- Le bouton de pratique d'une leçon transmet sa règle exacte et sa paire au
  configurateur, qui les conserve dans le quiz. Une leçon française ne doit
  jamais basculer dans le curriculum coréen.
- Les flashcards gardent le glissement et proposent aussi deux boutons de
  notation localisés, accessibles au clavier et aux lecteurs d'écran.
- Le plateau distingue mots/listes disponibles et acquis. L'absence de cartes
  dues ne prouve aucune activité terminée : le chemin montre une recommandation
  sans faux compteur de complétion ni estimation de mots inédits.

## Limites connues à corriger avant de qualifier V3 de complète

1. **Localisation.** Les textes du plateau, chemin, accueil/auth et splash,
   ainsi que les commandes de sortie, passent par les traductions FR/EN/KO.
   L'audit des autres flux de révision reste à compléter avant livraison V0.
2. **Thèmes.** Les entrées, la liste et le canvas de révision supportent les
   deux thèmes, mais le plateau, le chemin quotidien et le splash utilisent
   encore volontairement une surface sombre V3. Il faut soit concevoir leur
   variante claire, soit expliciter que le plateau est toujours sombre.
3. **Piles hors quiz.** Les ornements de feuilles/piles du plateau et du chemin
   sont retirés. La pile physique inclinée reste réservée aux flashcards.
4. **Plongée et scroll.** La transition `DiveInPage` couvre le chemin quotidien
   et le lecteur de grammaire, pas toutes les destinations V3. Le plateau et
   le chemin signalent désormais leur scroll. Le chemin utilise des hauteurs
   intrinsèques : les textes agrandis peuvent défiler sans chevauchement.
5. **Leçons.** Le lecteur existe, mais la leçon V0 complète (pages validées,
   popup d'exemple, écho non noté, contenu KO→FR relu) n'est pas terminée.
6. **Tests visuels.** Les tests couvrent les comportements et les routes, pas
   une validation screenshot/golden du rendu V3 sur les deux thèmes et trois
   locales. Un test de régression vérifie néanmoins le chemin à 320 × 568,
   texte doublé, en français, anglais et coréen.

## Sources et code

- Palette partagée : `lib/core/theme/v3_colors.dart`.
- Plateau et ondulations : `lib/presentation/screens/home/v3_home_screen.dart`
  et `lib/presentation/widgets/v3_pond.dart`.
- Révision : `lib/presentation/design/v3/` et
  `lib/presentation/screens/quiz/quiz_screen.dart`.
- Aperçu HTML du plateau : `mockups/v3-home-plateau-preview.html`.

Les écrans non migrés doivent être conçus à partir de ces règles et des
décisions de [map/](map/app-map.md), pas à partir d'anciens prototypes.
