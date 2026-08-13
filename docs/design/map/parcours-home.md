# Accueil : page langue + parcours A1→C2

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

## Proposé — pas encore vetté (Claude)
- Série (flamme) dans l'en-tête — la carte héro sombre v1 meurt
- Sélecteur de langue = chip drapeau + autonyme dans l'en-tête
- Nœuds de 3 types : Vocabulaire · Grammaire (règle) · Mélange
- Niveaux partiellement remplis autorisés (« 13 leçons disponibles »)
- Une « leçon » ne compte que les moments d'apprentissage (jamais les
  révisions FSRS)

## À trancher 🔴
- Ouverture d'un nœud : expansion en place vs bottom sheet (ex-Q5,
  reformulée par la route à nœuds)
- Visibilité du test de saut sur niveau verrouillé (Q6)

Liens : [[daily-chain]] · [[level-test]] · [[grammar-flow]] · [[vocab-flow]]
