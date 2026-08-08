# Flux grammaire : groupes de petites règles

**Statut : 🟢 modèle décidé · 🟠 mécanique proposée** · flux F3 ·
spec : `../v2-ux-architecture.md §5 F3` · `../../grammar-lessons-redesign.md` ·
diagrammes : `../diagrams/v2-grammar-flow.svg`, `../diagrams/grammar-stage-ramp.svg`

## Décidé (utilisateur, 2026-08-07)
- Beaucoup de PETITES règles, organisées en GROUPES (~5 règles)
- On apprend les règles une par une, puis on apprend à les MÉLANGER,
  puis on passe au groupe suivant
- Prérequis de vocabulaire : des listes doivent être MAÎTRISÉES pour
  comprendre les exercices — listes différentes possibles par
  niveau/groupe
- Examen de maîtrise en fin de palier
- Rappel (2026-08-06) : la grammaire est un curriculum de l'app, les
  utilisateurs n'en créent pas
- Rappel (2026-07-22) : rampe progressive, « moins un quiz, plus une leçon »

## Décidé (utilisateur, 2026-08-08) — multi-langue
- Curricula grammaire pour les 6 langues (es/it/fr/en/de rejoignent ko) :
  5 règles A1 par langue latine (articles, présent, négation, pluriel),
  ids préfixés par langue (`es-…`), contenus en cartes de locales, chaque
  règle porte ses test_vectors passés au module dans le CI
- Moteur : mécaniques génériques (article/genre via tags m·f·n des mots,
  conjugaison par personnes p1sg-p3sg, négation par patron `{verb}`,
  pluriel) ; morphologie par langue dans `latin_grammar_modules.dart`,
  exceptions lexicales dans le contenu — même partage code/données que
  le module coréen
- Prérequis par `seed_id` de liste du catalogue (plus jamais par nom)

## Décidé (utilisateur, 2026-08-08) — porte de vocabulaire GLOBALE
- La porte d'une règle se calcule sur l'ENSEMBLE de ses listes
  prérequises : mots connus / mots totaux ≥ **80 %** (ex. liste A à
  100 % + liste B à 70 % → 85 % global → ouvert)
- Remplace le seuil par liste à 90 % (mur à leeches : 2 mots
  récalcitrants sur 18 bloquaient l'ouverture indéfiniment)

## Proposé — pas encore vetté (Claude)
- Répartition de la rampe : étapes 1-3 par règle (leçon courte →
  Reconnaître J+1 → Construire J+2, pastilles ●●●) ; étapes 4-5
  (Écrire/Parler) portées par le Mélange du groupe
- Mélange = leçon de combinaison + exercices mixtes (Écrire, Parler,
  cloze combinés) ; réussi → groupe ✓
- UN groupe actif par langue ; ≥80 % passe un drill, sinon retenté
  demain avec un mix plus facile ; sans micro → « maîtrisé (écrit) »
- Porte réelle : groupe atteint mais vocab pas maîtrisé → le chemin sert
  ces révisions jusqu'à l'ouverture (barres par liste visibles)
- Après le groupe : entretien via cloze/dialogues dans les révisions

## Proposé (utilisateur, 2026-08-08 — à valider techniquement)
- « Mot connu » basé sur la PRÉCISION plutôt que l'état FSRS seul :
  `times_shown`/`times_correct` existent déjà en base ; graduation =
  vu ≥ N fois ET ratio de bonnes réponses ≥ X %. Réglage à prévoir :
  fenêtrer sur les derniers passages (sinon les échecs du tout début
  plombent le ratio à vie)

## À trancher 🔴
- Mélange = seul « exam » du groupe, ou un exam de groupe distinct ?
- Seuils restants : N vues / X % précision pour « connu » ;
  espacement J+1/J+2 (la porte de liste est tranchée : 80 % global)
- Taille de groupe : 5 fixe ou variable ; combien de groupes par niveau

Liens : [[lesson-viewer]] · [[grammar-drills]] · [[level-test]] ·
[[vocab-flow]] · [[bibliotheque]]
