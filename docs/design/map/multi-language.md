# Multi-langue (règles transverses)

**Statut : 🟢 décidé** · spec : `../v2-ux-architecture.md §7` ·
`../../feature-roadmap.md` § multi-language

## Décidé (utilisateur, 2026-08-13) — le sélecteur d'en-tête montre la PAIRE
- Le chip d'en-tête doit afficher la paire (« FR ↔ ES »), jamais la
  langue cible seule (« Espagnol ») — la langue de base varie d'une
  langue étudiée à l'autre pour un même utilisateur (ex. il apprend
  l'espagnol depuis le français mais le coréen depuis l'anglais),
  l'afficher évite de supposer une base fixe
- (2026-08-13, suite) Le chip d'en-tête EST le seul sélecteur de
  langue — les chips de filtre par paire proposés pour l'onglet
  Vocabulaire sont abandonnés (redondants). Tap sur le chip → feuille
  « Tes langues » : switch entre langues déjà démarrées (série et
  niveau par langue, cohérent avec [[daily-chain]]) **et** démarrer
  une nouvelle langue depuis la même feuille
- (2026-08-13, suite) Démarrer une langue = DEUX étapes explicites,
  jamais une base supposée : 1) choisir la langue à ÉTUDIER (cible),
  2) choisir depuis quelle langue on l'apprend (base — langue des
  explications/leçons). Renforce la décision ci-dessus (pas de base
  fixe) au moment précis où elle compte le plus : la création

## Décidé (utilisateur, 2026-07-22, livré en partie)
- Toute feature doit marcher pour TOUTES les paires étudiables — rien de
  coréen-only par accident
- Chaque langue affichée dans sa propre langue (autonymes) dans les
  sélecteurs
- Paires en/it/de/es livrées (v1.1) : listes par paire, voix par langue,
  validation de réponse par langue (élisions françaises, ligatures…)

## Décidé (utilisateur, 2026-08-08) — contenu par défaut multi-langue
- Catalogue de seed en N-par-langue, PAS N×M par paire :
  `assets/seed/vocab/registry.json` (listes + concepts, agnostique) +
  une couche par langue (`vocab/lang/<code>.json` : mots, exemples, notes,
  tags de genre). Toute paire ordonnée est composée au seeding
  (StarterSeeder, dédup par `seed_id`, jamais par nom)
- Vocabulaire par défaut livré pour les 6 langues (fr/en/it/de/es/ko) ;
  contenu en/it/de/es généré par LLM, revue native à planifier
  (`docs/seed-content-authoring.md`)
- Grammaire : curricula pour les 6 langues (choix utilisateur — pas
  seulement le coréen) ; format par langue cible
  (`assets/seed/grammar/<lang>/rules.json`), textes en cartes de locales
  (fr+en minimum), moteur générique (mécaniques article / conjugaison par
  personne / négation par patron / pluriel + modules par langue,
  vérifiés par test_vectors). Pilote espagnol validé puis it/fr/en/de
- Page grammaire d'une langue sans curriculum → placeholder
  `grammar.no_curriculum` (les listes marchent quand même)

## Décidé (utilisateur, 2026-08-13) — complexité par langue
- **Niveau 0** optionnel par langue : cours d'écriture avant le vocab
  (coréen : hangul) — absent pour les langues latines
- L'équilibre des TYPES de leçons varie par langue (grammaire ·
  conjugaison · écriture · prononciation) : le coréen aura beaucoup de
  prononciation (sons qui mutent selon la phrase), l'espagnol beaucoup
  de conjugaison — le curriculum de chaque langue choisit son mix,
  l'UI dit juste « leçons »
- RÈGLE DES STANDARDS (2026-08-13) : quand un choix de standard
  s'impose (romanisation, translittération, format…), on prend
  toujours **le plus récent ou le plus largement répandu** — pour le
  coréen : la romanisation révisée (RR)
- Les SYSTÈMES propres à une langue sont des leçons comme les autres :
  compteurs et double système de nombres coréens (base 10 000),
  genres allemands… — portés par des mécaniques pluggables du moteur
  (voir [[grammar-flow]])

## Proposé — pas encore vetté (Claude)
- Tagging systématique par paire (drapeaux) sur toute donnée scopée
- Scripts via le resolver existant (Hangul → Noto Sans KR, à étendre)

## À trancher 🔴
- Rien de structurel — la vigilance est dans l'exécution (chaque nouvelle
  note de cette carte doit dire sa story multi-langue)

Liens : [[parcours-home]] · [[lesson-viewer]] · [[familles]]
