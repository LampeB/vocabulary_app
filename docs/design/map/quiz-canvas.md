# Quiz canvas, voix, cloze & mots difficiles

**Statut : ⚪ canvas établi (v1) · 🟠 ajouts proposés** · écran S5 ·
spec : `../v2-ux-architecture.md §6.5` · mémoire : refactor voix COMPLET
(VoiceTurnMachine/AudioDirector/SttRace — tout changement voix passe par
ces seams)

## Décidé (utilisateur)
- Le canvas v1 (barre de progression, gros mot, waveform, modes
  Voix/Mains libres/Écrit/Cartes) fonctionne — conservé
- Features retenues (2026-07-22) : cloze (#3) et leeches (#4)
- (2026-08-08) Mode Cartes : après le flip, **swipe droite/gauche** =
  « je savais / je ne savais pas », persisté en FSRS (good/again) —
  les cartes ne sont plus une impasse SRS (avant : rien n'était noté)

## Proposé — pas encore vetté (Claude)
- Layout carte cloze : phrase à trou (chip ou saisie) sur le même canvas
- Chip « Famille » sur la révélation de réponse (entrée vers [[familles]])
- Théming teal des surfaces Réviser (vs clay Apprendre)
- Leeches : lapses ≥3 ou précision <50 % sur 10 → source « Mots
  difficiles » + étapes Renforcer
- Résumé de session : bloc « et ensuite » vers le chemin

## Confirmé (utilisateur, 2026-08-21)
- Ce qui EST maquetté (flashcard avec flip + swipe, écrit) est bon tel
  quel — pas de retouche demandée en repassant sur l'écran

## Décidé (utilisateur, 2026-09-11) — la pile est une métaphore de révision
- Les quiz et révisions de vocabulaire sont le **seul** contexte qui utilise
  une pile de flashcards légèrement inclinées : les cartes visibles derrière
  montrent le travail restant, puis la carte active est dépilée après la
  réponse.
- La pile ne se propage pas aux écrans de setup, de sélection de mode ou de
  navigation vers le quiz ; ceux-ci suivent la transition de plongée définie
  dans [[interaction-language]].

## À trancher 🔴
- Cloze, mode voix et leeches n'ont jamais été réellement maquettés
  (seuls flashcard/écrit le sont) — le layout cloze précis ; d'où
  viennent les phrases avant que les leçons existent ; la définition
  leech (seuils) à valider

Liens : [[daily-chain]] · [[pratique-libre]] · [[grammar-drills]] · [[interaction-language]]
