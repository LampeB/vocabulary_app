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

## Proposé — pas encore vetté (Claude)
- Tagging systématique par paire (drapeaux) sur toute donnée scopée
- Curriculum par langue livré progressivement (coréen d'abord) ; page
  langue sans curriculum → placeholder + listes utilisables quand même
- Scripts via le resolver existant (Hangul → Noto Sans KR, à étendre)

## À trancher 🔴
- Rien de structurel — la vigilance est dans l'exécution (chaque nouvelle
  note de cette carte doit dire sa story multi-langue)

Liens : [[parcours-home]] · [[lesson-viewer]] · [[familles]]
