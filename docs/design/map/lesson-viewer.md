# Visionneuse de leçon (grammaire)

**Statut : 🟢 principes décidés · 🟠 détails proposés · contenu 🔴** ·
écran S4 · spec : `../v2-ux-architecture.md §6.4` · `../../grammar-lessons-redesign.md`

## Décidé (utilisateur, 2026-07-22)
- Leçon en plusieurs écrans, jamais un bloc de texte
- Alterner explication → exemple(s) → explication…
- Navigation manuelle libre (avant/arrière)
- Pas trop long
- Mots colorés pour surligner l'important
- Lecture TTS multi-voix : une voix pour la règle, une autre pour les
  exemples, plusieurs si besoin (dialogues)

## Proposé — pas encore vetté (Claude)
- 3-6 pages pour une petite règle (6-10 avant les groupes), ≤2-3 phrases/page
- Markup de surlignage `[[clay]]` / `((teal))`, parseur Dart pur
- Types de pages : explication, exemple (audio par ligne), quick-check
  (QCM non noté toutes les 3-4 pages), dialogue (2 voix, bulles colorées)
- Registre de rôles de voix → ElevenLabs par langue ; TTS système en free
- Points de pagination + reprise où on s'est arrêté ; relecture libre
  depuis la fiche de groupe

## À trancher 🔴
- **LE CONTENU des leçons** (signalé 2026-08-07) : qui écrit quoi, ton,
  langue d'explication (français ? langue UI ?), gabarit par type de
  règle, validation pédagogique — rien n'existe encore
- Fréquence exacte des quick-checks ; place du dialogue dans une petite
  leçon vs au Mélange

Liens : [[grammar-flow]] · [[grammar-drills]] · [[multi-language]]
