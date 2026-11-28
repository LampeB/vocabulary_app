# Niveau 0 : apprendre l'écriture (hangul d'abord)

**Statut : 🟢 décidé — structure validée 2026-08-13** ·
décisions 2026-08-13 · concerne les langues à script nouveau
(coréen d'abord ; cf. [[parcours-home]] — Niveau 0 optionnel par langue)

## Décidé (utilisateur, 2026-08-13)
- Le hangul s'apprend par RECONNAISSANCE, deux ponts :
  **romanisation ↔ hangeul** (les deux sens) et **audio ↔ hangeul**
- Granularité progressive : **lettres simples (jamo) → syllabes →
  mots** — l'objectif est d'entraîner la LECTURE
- À terme : mode **chronométré** (vitesse de lecture)
- **Pas de tracé pour l'instant** (peut-être plus tard) — lecture seule
- Niveau 0 **fortement recommandé mais PAS obligatoire** : on peut
  attaquer le Niveau 1 sans, le placement peut le sauter
- Romanisation : la **révisée (RR)** — et règle générale du projet :
  quand il faut choisir un standard, toujours le plus récent ou le
  plus répandu (voir [[multi-language]])

## Validé (utilisateur, 2026-08-13 — proposition Claude acceptée)
- Structure = le modèle cluster habituel : clusters de jamo (consonnes
  de base · voyelles de base · aspirées/tendues · voyelles composées ·
  받침), ordre libre dedans, quiz de validation par cluster
- Formats sur les canvases existants :
  - Reconnaître : QCM dans les deux sens (romanisation→hangeul,
    hangeul→romanisation, audio→hangeul)
  - Discrimination audio (le format prononciation) : entendre une
    syllabe, choisir entre voisines — 가/카/까, parfait pour
    aspirées vs tendues, réécoute illimitée
  - Construire : ASSEMBLER une syllabe depuis des chips de jamo
    (ㅎ+ㅏ+ㄴ → 한) — la mécanique chips existante, distracteurs de
    jamo voisins (ㅏ/ㅑ, ㄱ/ㅋ)
  - Mots : lire à voix haute (production, pipeline voix existant)
- La romanisation S'ESTOMPE avec la progression (l'échafaudage qui
  tombe, même philosophie que la rampe) : partout au début,
  optionnelle ensuite, absente au Niveau 1
- Sortie : mini test de lecture ; au placement, « Je sais déjà lire »
  saute le Niveau 0 entièrement
- Si l'utilisateur saute le Niveau 0 SANS savoir lire (permis, non
  bloqué) : la romanisation reste affichée au Niveau 1 et l'app
  suggère gentiment le Niveau 0 — l'estompage suit la LECTURE, pas le
  niveau
- Le chrono = mode « sprint de lecture » gamifié, jamais bloquant

## À trancher 🔴
- (rien — placement exact de la romanisation à l'écran = build)

Liens : [[parcours-home]] · [[grammar-flow]] · [[grammar-drills]] ·
[[multi-language]] · [[onboarding]]
