# V3 — Sentier de cartes

**Statut : implémentation partielle, référence active au 29 septembre 2026.**

Cette note est la référence versionnée du design V3. Les fichiers d'origine
fournis pour V3 et les maquettes HTML restent des références visuelles ; le
code Flutter et cette note décrivent ce qui est réellement livré.

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

## Limites connues à corriger avant de qualifier V3 de complète

1. **Localisation.** Plusieurs libellés V3 sont encore français en dur ; ils
   doivent passer par les traductions FR/EN/KO avant livraison V0.
2. **Thèmes.** Les entrées, la liste et le canvas de révision supportent les
   deux thèmes, mais le plateau, le chemin quotidien et le splash utilisent
   encore volontairement une surface sombre V3. Il faut soit concevoir leur
   variante claire, soit expliciter que le plateau est toujours sombre.
3. **Piles hors quiz.** Le plateau et le chemin utilisent encore des effets de
   feuilles/piles décoratives. La décision produit réserve la pile physique et
   inclinée aux flashcards : ces ornements doivent être aplatis ou redessinés.
4. **Plongée et scroll.** La transition `DiveInPage` couvre le chemin quotidien
   et le lecteur de grammaire, pas toutes les destinations V3. Le plateau est
   scrollable sans indicateur explicite. Ces deux écarts sont visibles.
5. **Leçons.** Le lecteur existe, mais la leçon V0 complète (pages validées,
   popup d'exemple, écho non noté, contenu KO→FR relu) n'est pas terminée.
6. **Tests visuels.** Les tests couvrent les comportements et les routes, pas
   une validation screenshot/golden du rendu V3 sur les deux thèmes et trois
   locales.

## Sources et code

- Palette partagée : `lib/core/theme/v3_colors.dart`.
- Plateau et ondulations : `lib/presentation/screens/home/v3_home_screen.dart`
  et `lib/presentation/widgets/v3_pond.dart`.
- Révision : `lib/presentation/design/v3/` et
  `lib/presentation/screens/quiz/quiz_screen.dart`.
- Aperçu HTML du plateau : `mockups/v3-home-plateau-preview.html`.

Les anciennes maquettes v1/v2 restent utiles pour les écrans non migrés, mais
ne sont pas la source de vérité du rendu V3.
