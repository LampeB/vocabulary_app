# Progrès : dashboard, CEFR & bilan hebdo

**Statut : 🟢 features décidées · 🟠 layouts proposés** · écrans S12/S13 ·
flux F6/F9 · spec : `../v2-ux-architecture.md §6.11, §6.12` ·
`../../feature-roadmap.md` #6/#9 · M2/M7

## Décidé (utilisateur, 2026-07-22)
- Dashboard détaillé : progression à plusieurs échelles + niveaux
  A1/A2/B1… (estimation CEFR)
- Bilan hebdo retenu (feature #6)
- (2026-08-06) le parcours ancre la notion de niveau — l'estimation CEFR
  et la position parcours doivent raconter la même histoire

## Proposé — pas encore vetté (Claude)
- Onglet Progrès dédié (remplace Stats sous Profil) — lié au pari
  navigation
- Ordre : chips de paire → carte CEFR (breakdown tappable) → échelles
  Jour/Semaine/Mois/Tout → graphes (révisions, précision, mots connus) →
  sessions récentes → bilans passés
- Bilan hebdo : plein écran célébratoire, screenshot-friendly, variantes
  « grosse semaine » et « semaine calme », CTA unique
- Seuils CEFR v1 par taille de vocab (A1≈500 … C1≈8000) + poids grammaire ;
  tags CEFR par mot en v2

## À trancher 🔴
- Comment fusionner estimation CEFR (données) et position parcours
  (curriculum) sur la carte de niveau ; les seuils ; le contenu exact du
  breakdown

Liens : [[navigation]] · [[parcours-home]] · [[level-test]]
