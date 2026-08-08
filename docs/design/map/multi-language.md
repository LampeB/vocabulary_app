# Multi-langue (règles transverses)

**Statut : 🟢 décidé** · spec : `../v2-ux-architecture.md §7` ·
`../../feature-roadmap.md` § multi-language

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

## Proposé — pas encore vetté (Claude)
- Tagging systématique par paire (drapeaux) sur toute donnée scopée
- Scripts via le resolver existant (Hangul → Noto Sans KR, à étendre)

## À trancher 🔴
- Rien de structurel — la vigilance est dans l'exécution (chaque nouvelle
  note de cette carte doit dire sa story multi-langue)

Liens : [[parcours-home]] · [[lesson-viewer]] · [[familles]]
