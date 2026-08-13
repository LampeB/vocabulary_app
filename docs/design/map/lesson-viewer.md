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
- Markup de surlignage `[[clay]]` / `((teal))`, parseur Dart pur
- Types de pages : explication, exemple (audio par ligne), quick-check
  (QCM non noté toutes les 3-4 pages), dialogue (2 voix, bulles colorées)
- Registre de rôles de voix → ElevenLabs par langue ; TTS système en free
- Points de pagination + reprise où on s'est arrêté ; relecture libre
  depuis la fiche de groupe

## À trancher 🔴
- **Gabarits des leçons** (le modèle est tranché 2026-08-09, voir
  Décidé) : reste le ton, la langue d'explication (français ? langue
  UI ?), le gabarit par type de règle, la validation pédagogique, et
  P3 — où vivent les textes (`content-roadmap.md`)
- Fréquence exacte des quick-checks ; place du dialogue dans une petite
  leçon vs au Mélange

Liens : [[grammar-flow]] · [[grammar-drills]] · [[multi-language]]
