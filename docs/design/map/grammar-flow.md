# Flux leçons (ex-« grammaire ») : clusters de petites leçons

> **Renommé 2026-08-13** : « grammaire » disparaît de l'UI — on dit
> **LEÇONS**. Le fichier garde son nom historique.

**Statut : 🟢 modèle décidé · 🟠 mécanique proposée** · flux F3 ·
spec : `../v2-ux-architecture.md §5 F3` · `../../grammar-lessons-redesign.md` ·
diagrammes : `../diagrams/v2-grammar-flow.svg`, `../diagrams/grammar-stage-ramp.svg`

## Décidé (utilisateur, 2026-08-07)
- Beaucoup de PETITES règles, organisées en GROUPES (~5 règles)
- On apprend les règles une par une, puis on apprend à les MÉLANGER,
  puis on passe au groupe suivant *(révisé 2026-08-09 : ordre LIBRE à
  l'intérieur du cluster — voir ci-dessous ; le Mélange reste la sortie)*
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

## Décidé (utilisateur, 2026-08-13) — « leçons » typées, pas « grammaire »
- Le mot « grammaire » est TROMPEUR selon la langue (retour enseignante
  ko-fr) : chaque langue a son équilibre propre entre grammaire,
  conjugaison, règles d'ÉCRITURE et règles de PRONONCIATION (sons/mots
  qui changent selon la phrase — liaisons, mutations)
- Les « règles » deviennent des **leçons typées** : grammaire ·
  conjugaison · écriture · prononciation (+ types futurs) — champ
  `type` sur la leçon, l'UI dit juste « leçon »
- Le moteur actuel couvre grammaire/conjugaison ; les types écriture
  et prononciation demandent leurs formats d'exercices (voir À trancher)
- (2026-08-13, suite) La liste des types est OUVERTE — les langues ont
  des SYSTÈMES propres qui méritent leçons + exercices dédiés :
  compteurs coréens (개/명/마리…), les DEUX systèmes de nombres coréens
  et la base 10 000 (만), les genres allemands der/die/das/die, les
  honorifiques…
- Principe de structure : une leçon = texte auteuré + `mechanics`
  PLUGGABLE (comme article/conjugaison aujourd'hui, avec test_vectors).
  Un nouveau système = un nouveau type de mécanique (code) + des
  données — jamais une refonte du schéma. Der/die/das est DÉJÀ couvert
  (mécanique article + tags de genre) ; compteurs et nombres coréens =
  futures mécaniques `counter` et `number`

## Décidé (utilisateur, 2026-08-09) — déverrouillage par CLUSTERS
- Le chemin d'un niveau = une suite de CLUSTERS (~5 leçons liées entre
  elles), débloqués un par un — les « groupes » existants SONT les
  clusters, le déverrouillage se fait à cette granularité
- À l'intérieur d'un cluster ouvert : LIBRE CHOIX de l'ordre des
  leçons (les portes de vocab restent actives sur chaque règle)
- Cluster validé = les ~5 leçons faites + un petit quiz qui mélange
  les 5 concepts → le cluster suivant s'ouvre
- Ce quiz EST le Mélange : le Mélange est l'examen du cluster, pas
  d'examen distinct (tranche la question ci-dessous)
- Les NOMBRES sont explicitement non fixés (leçons par niveau, par
  cluster, nb de clusters) — défaut proposé : 5 leçons/cluster (±1
  pour les restes), nb de clusters dérivé du contenu réel du niveau
- COMPOSITION MIXTE (confirmé 2026-08-09) : un cluster thématique =
  ses listes de VOCABULAIRE + les règles qui s'appuient dessus (ex.
  « Au quotidien » : liste vie quotidienne + présent + négation) —
  le vocab s'intègre au chemin, les listes du cluster nourrissent
  les portes de ses propres règles
- Conséquence : l'échelonnement un-par-un des prérequis latins (U6)
  est obsolète dans sa forme d'origine — l'échelonnement vit au
  niveau du cluster

## Proposé — pas encore vetté (Claude)
- Répartition de la rampe : étapes 1-3 par règle (leçon courte →
  Reconnaître J+1 → Construire J+2, pastilles ●●●) ; étapes 4-5
  (Écrire/Parler) portées par le Mélange — ⚠️ à réexaminer : le
  continuum Construire→Écrire décidé 2026-08-09 ([[grammar-drills]])
  fait arriver la production tapée PAR règle, avec la pratique du groupe
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

## Réglages par défaut (délégué à Claude par l'utilisateur, 2026-08-13 — à ajuster aux données)
- Mot « CONNU » : vu ≥ 4 fois ET ≥ 80 % de bonnes réponses sur les
  6 derniers passages (fenêtré — les échecs du tout début ne plombent
  pas le ratio à vie)
- Cadence par leçon : Reconnaître J+1 · Construire J+2 (la
  proposition existante, adoptée)
- Cluster : **4-6 leçons typées** (≥ 4 — le Mélange en combine au
  moins 4, décidé 2026-08-13) + 1-2 listes de vocab ; nombre de
  clusters par niveau dérivé du contenu réel (~3-4 au lancement)

## Proposé (Claude, 2026-08-13) — fiche de cluster clarifiée (retour utilisateur : illisible)
- UNE seule grammaire d'états, la même que la route : ✓ fait ·
  📖 en cours · ▶ prête · 🔒 verrouillée — fini les libellés mélangés
  (« libre », « à toi », pastilles muettes)
- Chaque leçon porte un sous-libellé : son TYPE + sa prochaine étape
  (« conjugaison · prochaine étape : Reconnaître »)
- La porte de vocab s'affiche SUR la leçon qu'elle bloque (mini-barre
  64 % / 80 %) — plus de carte « Portes » séparée
- Le Mélange = bloc but distinct avec sa progression (« s'ouvre quand
  les 5 leçons sont faites · 2/5 »)
- Le CTA nomme l'action (« Continuer : Le présent — la leçon »,
  « Lancer le Mélange ») au lieu d'un générique
- Implémenté dans le playground — à valider en cliquant

## À trancher 🔴
- (rien — la recette du Mélange est validée 2026-08-13, quiz ≥ 20
  questions sans vocab pur : voir [[grammar-drills]] ; la fiche
  clarifiée ci-dessus attend validation)
- ~~Contenu et flux du Niveau 0~~ → axes décidés 2026-08-13, sa carte :
  [[niveau-0]] (restent : tracé ?, obligatoire ?, romanisation)

Liens : [[lesson-viewer]] · [[grammar-drills]] · [[level-test]] ·
[[vocab-flow]] · [[bibliotheque]]
