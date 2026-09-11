# Parcours (ex-« Étudier ») : page langue + parcours A1→C2

> **Onglet renommé 2026-08-13** : « Étudier » → **« Parcours »** —
> Vocabulaire et Leçons servent aussi à étudier, le nom ne distinguait
> pas cet onglet ; « Parcours » colle à ce qu'il montre (route à
> nœuds + chemin du jour + position). Voir [[navigation]].

**Statut : 🟢 modèle décidé · 🟠 détails proposés** · écran S1 · flux F0/F10 ·
spec : `../v2-ux-architecture.md §6.1` · wireframe : `../diagrams/v2-home-parcours.svg`

## Décidé (utilisateur, 2026-08-06)
- L'accueil montre la langue courante (la dernière étudiée si plusieurs)
- Carte d'aperçu de la progression en tête
- Parcours A1→C2 : cartes de niveau extensibles, progression x/20 leçons
- Carte étendue = liste scrollable des leçons, fenêtrée autour de la
  courante (ex. à la 7ᵉ : 5-6-7-8-9, 5 et 6 cochées)
- Démarrer un niveau supérieur exige de réussir un test prouvant la
  maîtrise des niveaux précédents
- (2026-08-07) L'accueil porte une carte « Chemin du jour » qui OUVRE
  l'écran dédié S18 — le jour ne vit plus dans une carte aperçu
- (2026-08-07) L'onglet « Étudier » est branché sur les quiz et les
  leçons de grammaire — nouvel écran requis (l'actuel setup est trop
  encombré) ; 🟠 supposé : cet onglet EST l'accueil et porte chemin +
  progression + parcours

## Décidé (utilisateur, 2026-08-13) — niveaux « Niveau 1-6 », plus de CEFR à l'écran
- Les niveaux s'affichent « Niveau 1 … Niveau 6 » — JAMAIS A1-C2 :
  les libellés CEFR sonnent comme un engagement de certification
  (risque légal/marketing, retour enseignante ko-fr)
- Le CEFR reste la CIBLE INTERNE (tags de contenu, objectifs
  pédagogiques, tests) — mapping Niveau N ↔ A1…C2 dans les données,
  invisible pour l'utilisateur
- **Niveau 0** optionnel par langue : apprendre l'écriture avant le
  vocabulaire (coréen : hangul ; plus tard japonais, etc.) — absent
  pour les langues à alphabet latin

## Décidé (utilisateur, 2026-08-13) — le parcours est une ROUTE à nœuds
- Le parcours se voit comme un vrai CHEMIN : une route dont chaque
  nœud est un cluster — révise la décision « cartes » du 2026-08-08
  (environnement visuel « cosy », on voit où on en est d'un coup d'œil)
- États d'un nœud : **?** dans un cercle (pas encore connu) · **livre
  ouvert** (en cours d'étude) · **✓** (validé)
- Clic sur un nœud → il s'EXPANSE (ou ouvre un bottom sheet) et
  montre son contenu — les leçons du cluster
- (2026-08-13) Le nœud EN COURS affiche un résumé chiffré directement
  sur la route : « X/5 leçons · Y/2 listes maîtrisées » — pas
  seulement un état ✓/📖/? muet ; même résumé en tête de la fiche de
  cluster (cohérence des deux vues)
- Absorbe Q7 (résolu : nœud = cluster) ; Q5 devient « expansion en
  place vs bottom sheet » (à trancher)

## Décidé (utilisateur, 2026-08-09) — le chemin est une suite de CLUSTERS
- Chaque étape du parcours = un cluster MIXTE de ~5 leçons liées
  (listes de vocab + règles qui s'appuient dessus), ordre libre à
  l'intérieur, validé par le Mélange → cluster suivant
- Voir [[grammar-flow]] pour la mécanique complète

## Validé (utilisateur, 2026-08-08 — wireframe accepté comme base)
- Structure de l'écran Étudier : en-tête (chip langue · série · avatar)
  → carte Chemin du jour (pastilles, prochaine étape, chip Continuer,
  chevron) → carte progression (position CEFR + barre) → parcours en
  cartes de niveau (pas de sentier Duolingo — Q1 tranchée : cartes)
  *(révisé 2026-08-13 : le parcours redevient une ROUTE à nœuds)*
- Bilan hebdo se glisse au-dessus le dimanche

## Décidé (utilisateur, 2026-08-13, retour : « bland and messy ») — refonte de l'écran
- Le chemin du jour redevient une VRAIE carte héro (sombre, icônes des
  4 étapes du jour, CTA intégré) au lieu d'une carte teaser identique
  aux autres — c'est la chose principale à faire aujourd'hui, elle
  doit se voir
- La carte « Progression » (CEFR + barre) redevient une ligne fine
  sous le héro plutôt qu'une carte pleine — l'info reste (décidée
  2026-08-08), la présentation s'allège
- La carte Bilan hebdo redevient une bannière fine, visible seulement
  le dimanche (déjà décidé 2026-07-22 : « se glisse au-dessus le
  dimanche » — non respecté dans le premier jet du playground, corrigé)
- Pratique libre redescend en simple pastille, poids visuel mineur
- Implémenté dans le playground — à valider en cliquant

## Proposé — pas encore vetté (Claude)
- Série (flamme) dans l'en-tête — la carte héro sombre v1 meurt
  *(nuance 2026-08-13 : la carte héro sombre revient, mais SEULEMENT
  pour le chemin du jour dans le corps de page — pas comme carte
  d'accueil pleine largeur en v1 ; la flamme reste aussi dans l'en-tête)*
- Sélecteur de langue = chip drapeau + autonyme dans l'en-tête
- Nœuds de 3 types : Vocabulaire · Grammaire (règle) · Mélange
- Niveaux partiellement remplis autorisés (« 13 leçons disponibles »)
- Une « leçon » ne compte que les moments d'apprentissage (jamais les
  révisions FSRS)

## Décidé (utilisateur, 2026-08-21) — nœud = expansion EN PLACE (tranche ex-Q5)
- Taper un nœud du Parcours le déplie SUR PLACE dans la route (accordéon,
  un seul nœud ouvert à la fois) — jamais une navigation vers un autre
  écran. Le nœud « Au quotidien » déplié montre la fiche complète
  (leçons + Mélange) ; les autres nœuds montrent un résumé court +
  action si pertinente (relire, passer le test…)
- La fiche PLEIN ÉCRAN (S9 → onglet Leçons) reste distincte et
  inchangée : le Parcours garde le flux dans la route, l'onglet Leçons
  reste le « livre de cours » navigable en profondeur — deux entrées,
  deux usages, pas une régression de l'une vers l'autre
- Implémenté dans le playground (route accordéon)

## Décidé (utilisateur, 2026-08-21) — plus de CEFR affiché, compteurs à la place
- La ligne de position sous le chemin du jour n'affiche JAMAIS de
  pourcentage type CEFR (déjà tranché : « Niveau 1-6 », jamais A1-C2)
  — remplacée par DEUX compteurs chiffrés x/objectif :
  **leçons faites** (x/20, le chiffre déjà décidé pour le parcours) et
  **nœuds (clusters) franchis** (x/4 par niveau)
- Le Parcours affiché est TOUJOURS celui de la langue actuellement
  sélectionnée en en-tête (cohérent avec le sélecteur de langue
  2026-08-13) — jamais un parcours composite toutes langues confondues
- Implémenté dans le playground (posline à deux compteurs)

## À trancher 🔴
- Visibilité du test de saut sur niveau verrouillé (Q6)

Liens : [[daily-chain]] · [[level-test]] · [[grammar-flow]] · [[vocab-flow]]
