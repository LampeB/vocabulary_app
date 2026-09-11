# Visionneuse de leçon (grammaire)

**Statut : 🟢 principes + modèle de contenu décidés · 🟠 détails proposés · gabarits/ton 🔴** ·
écran S4 · spec : `../v2-ux-architecture.md §6.4` · `../../grammar-lessons-redesign.md`

## Décidé (utilisateur, 2026-07-22)
- Leçon en plusieurs écrans, jamais un bloc de texte
- Alterner explication → exemple(s) → explication…
- Navigation manuelle libre (avant/arrière)
- Pas trop long
- Mots colorés pour surligner l'important
- Lecture TTS multi-voix : une voix pour la règle, une autre pour les
  exemples, plusieurs si besoin (dialogues)

## Décidé (utilisateur, 2026-08-09) — modèle de contenu
- Le TEXTE des leçons est auteuré et FIGÉ (contenu seed, via le
  pipeline contenu) — pas de génération dynamique du cours lui-même
- Les EXEMPLES des leçons et les phrases d'exercices puisent dans le
  vocabulaire que l'utilisateur CONNAÎT déjà : gabarits de phrases
  auteurés par règle, slots remplis par le moteur avec du vocab connu
  (pas de LLM au runtime) — l'apprenant voit comment appliquer ce
  qu'il vient d'apprendre
- Les phrases composées restent soumises à la règle de style : chaque
  phrase doit être utilisable en voyage / conversation réelle

## Proposé — pas encore vetté (Claude)
- 3-6 pages pour une petite règle (6-10 avant les groupes), ≤2-3 phrases/page
  *(nuance 2026-08-21 : peut monter à ~6 pages pleines quand la règle
  couvre plusieurs personnes/formes — voir pacing ci-dessous)*
- Markup de surlignage `[[clay]]` / `((teal))`, parseur Dart pur
- Types de pages : explication, exemple (audio par ligne), quick-check
  (QCM non noté toutes les 3-4 pages), dialogue (2 voix, bulles colorées)
- Registre de rôles de voix → ElevenLabs par langue ; TTS système en free
- Points de pagination + reprise où on s'est arrêté ; relecture libre
  depuis la fiche de groupe

## Décidé (utilisateur, 2026-08-21) — navigation et pacing du contenu
- **Swipe réel** en plus des zones de tap (geste horizontal, seuil de
  distance) — pas seulement des tap-zones
- **Effet visuel de tournage de page** à chaque changement (la page qui
  part pivote/glisse légèrement, celle qui arrive entre en miroir) —
  pas un cut instantané. Implémenté dans le playground (`rotateY` +
  fondu, respecte `prefers-reduced-motion`)
- **Exemple sur la MÊME page que l'explication**, autant que possible —
  fini les pages "explication seule" puis "exemple seul" qui se
  suivent : chaque page enseigne ET montre en contexte
- **Les quick-checks gardent leur page dédiée** (seule exception à la
  fusion ci-dessus — un test, même informel, mérite son propre temps)
- **Retour utilisateur sur le premier jet** : la leçon « Le présent »
  expliquait « je » puis sautait directement l'exercice sans couvrir
  « tu »/« il » — rythme trop rapide, paradigme incomplet avant de
  tester. Corrigé : la leçon couvre maintenant yo/tú/él AVANT le
  quick-check (qui teste tú, pas seulement yo), + une page dédiée aux
  verbes irréguliers fréquents (ir), + dialogue qui réutilise tout —
  6 pages au lieu de 5, chacune plus dense mais complète

## Décidé (utilisateur, 2026-09-11) — approfondissement contextuel
- La leçon reste une surface de lecture ; elle n'utilise pas une pile de
  cartes. Un exemple, un mot ou une règle peut être cliquable pour ouvrir une
  **carte-popup contextuelle** (détail, variante, traduction, explication,
  audio) au-dessus de la page.
- Fermer la popup restitue exactement la position de lecture. Le composant
  offre une fermeture explicite, Échap et un retour de focus au déclencheur ;
  il ne sert pas à empiler de nouvelles destinations.
- Le scroll reste possible lorsqu'il protège la lisibilité, notamment avec une
  taille de texte augmentée, mais doit être annoncé visuellement. Voir
  [[interaction-language]].

### Recherche de terrain (2026-08-21)
Deux repères utilisés pour recalibrer le pacing :
- **Talk To Me In Korean** — structure quasi systématique : expliquer
  le point avec le POURQUOI (pas juste la règle) → exemples en
  contexte → conjugaison à travers les formes/personnes → irréguliers
  en dernier. Confirme : montrer le paradigme complet avant de passer
  à l'exercice, pas juste un cas.
  [TTMIK review](https://www.alllanguageresources.com/talk-to-me-in-korean/)
- **Modèle PACE** (ACTFL, enseignement inductif de la grammaire) — le
  SENS en contexte avant la FORME isolée. Confirme : exemple sur la
  même page que l'explication, jamais la règle nue en premier.
  [PACE Model](https://wlclassroom.com/2017/04/08/pace-model/)

## À trancher 🔴
- **Gabarits des leçons** (le modèle est tranché 2026-08-09, voir
  Décidé) : reste le ton, la langue d'explication (français ? langue
  UI ?), le gabarit par type de règle, la validation pédagogique, et
  P3 — où vivent les textes (`content-roadmap.md`)
- Fréquence exacte des quick-checks ; place du dialogue dans une petite
  leçon vs au Mélange

Liens : [[grammar-flow]] · [[grammar-drills]] · [[multi-language]] · [[interaction-language]]
