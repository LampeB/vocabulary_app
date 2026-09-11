# Porte de préchargement

**Statut : 🟢 décidé** · écran S2 · spec : `../v2-ux-architecture.md §6.2`

## Décidé (utilisateur, 2026-07 puis reconfirmé 2026-08-06)
- Écran dédié AVANT l'accueil, qui ne disparaît que quand le chargement
  est entièrement terminé — l'accueil arrive complet, jamais de listes qui
  se réordonnent sous les yeux

## Proposé — pas encore vetté (Claude)
- Visuel : motif waveform + ligne de statut progressive
  (« Synchronisation… » → « Préparation de ton chemin… »), pas de spinner brut
  — **maquetté 2026-08-21** dans le playground (fond sombre dégradé,
  ondes animées, 3 lignes de statut qui s'enchaînent, transition vers
  l'accueil une fois « chargé »)
- >8 s → bouton réessayer ; hors-ligne → données en cache + bandeau
  *(non maquetté — pas de simulation d'échec/hors-ligne dans la démo)*
- Reprises chaudes : pas de porte

Liens : [[parcours-home]]
