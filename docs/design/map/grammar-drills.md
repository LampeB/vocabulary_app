# Exercices de grammaire (drills / « grammar quizzes »)

**Statut : 🟢 formats validés comme base (2026-08-09) · 🟠 réglages · Mélange 🔴**

Le flux (quand un drill arrive) est traité dans [[grammar-flow]] ; cette
note couvre le CONTENU des sessions d'exercices elles-mêmes — zone
explicitement signalée non décidée (2026-08-07).

## Décidé (utilisateur)
- v1 existait : drills écrits/parlés jugés trop durs sans leçon (2026-07-22)
- Les exercices ne doivent utiliser que du vocab prérequis maîtrisé
- (2026-08-09) D'où viennent les phrases : banque de GABARITS auteurés
  par règle, slots remplis par le moteur avec le vocab que
  l'utilisateur connaît — pas de génération LLM au runtime (voir
  [[lesson-viewer]] : même modèle pour les exemples de leçon)

## Validé (utilisateur, 2026-08-09 — esquisses acceptées comme base)
- Reconnaître : QCM « choisis la bonne forme », ~8 items, feedback immédiat
- Construire : phrase à assembler par chips, ~6 items — avec
  distracteurs obligatoires (voir ci-dessous)
- Écrire (au Mélange) : production tapée, correction IA, ~5 items
- Parler (au Mélange) : à l'oral via le pipeline voix, ~5 items
- Tous ~2-3 min, sur les canvases existants, thème teal (Réviser)

## Décidé (utilisateur, 2026-08-09) — Construire anti-« logique de position »
- Problème identifié (type Duolingo) : avec exactement les bonnes
  tuiles, l'ordre sujet-verbe + l'élimination suffisent — on répond
  juste sans appliquer la règle de grammaire
- Donc : PLUS de chips que nécessaire, avec trois familles de
  distracteurs :
  1. le même verbe conjugué à d'autres personnes/temps
  2. des variantes morphologiques des autres mots (genre, nombre,
     article, forme fausse délibérée)
  3. des leurres hors sujet sans rapport avec la phrase
- But : prouver que l'utilisateur a activement appliqué la règle et la
  conjugaison, pas déduit par position
- Le moteur peut générer les distracteurs depuis le même gabarit (les
  mécaniques produisent aussi les formes FAUSSES)

## Décidé (utilisateur, 2026-08-13) — exercices des types prononciation & écriture
- Type PRONONCIATION, deux formats :
  1. **Production** — l'utilisateur prononce clairement le mot/la
     phrase ; pipeline voix existant (VoiceTurnMachine / SttRace,
     jamais d'appel audio ad hoc)
  2. **Discrimination** — l'app joue X versions du mot dont UNE seule
     est correctement prononcée ; réécoute ILLIMITÉE de chaque
     proposition, puis l'utilisateur soumet son choix
- Note technique (proposé) : les versions fausses = TTS sur la graphie
  phonétique de la mauvaise prononciation (le hangul étant phonétique,
  on écrit la forme fausse, ex. 학년 lu [학년] au lieu de [항년]) —
  variantes portées par les DONNÉES de la leçon, pattern
  mécanique+données habituel ; X peut suivre la rampe de difficulté
- Type ÉCRITURE : les exercices TAPÉS existants suffisent (validation
  par langue déjà en place — élisions, ligatures, décomposition hangul)
- La difficulté de Construire MONTE avec la pratique :
  1. au début : peu/pas de distracteurs — on applique, on analyse
  2. après quelques passages réussis : de plus en plus de distracteurs
  3. à terme : plus de chips du tout — l'utilisateur TAPE la phrase
     lui-même
- Construire → Écrire est donc un CONTINUUM de difficulté sur la même
  règle, pas deux formats étanches ; conséquence sur la rampe de
  [[grammar-flow]] (Écrire « au Mélange » seulement) à réexaminer
- Déclencheur : COMBINAISON — la rampe avance avec les passages
  réussis sur LA règle, et sa VITESSE est indexée sur la maturité
  globale (nb de règles de grammaire + vocab connus) : un apprenant
  avancé franchit les paliers plus vite, voire démarre plus haut
- Pourquoi : sur les premières leçons on découvre à la fois le vocab,
  le format des leçons et les règles générales de la langue → l'app
  est plus douce ; trop assister un avancé = ennui + infantilisation

## Réglages par défaut (délégué à Claude par l'utilisateur, 2026-08-09 — à ajuster aux données)
- Paliers de Construire (on monte après N passages RÉUSSIS sur la règle) :
  - **P0** chips exacts, zéro distracteur (appliquer, analyser) → P1 après 2
  - **P1** +2-3 distracteurs, pointés sur la règle (conjugaisons
    fausses, 0-1 variante morpho, pas encore de leurre) → P2 après 3
  - **P2** +4-6 distracteurs, les 3 familles, ratio ≈ 2 conjugaisons :
    2 variantes : 1 leurre → P3 après 3
  - **P3** plus de chips : production tapée
- Pourquoi ce ratio : les conjugaisons fausses testent la règle, les
  leurres testent surtout la reconnaissance de vocab — on privilégie
  ce qui force la grammaire
- Vitesse selon maturité (PAR langue étudiée, règles maîtrisées) :
  novice < 5 règles : seuils 2/3/3 · intermédiaire 5-14 : 1/2/2 ·
  avancé ≥ 15 : démarre à P1, seuils 1/2 (ne voit plus jamais P0)
- Échec : 2 échecs consécutifs → on redescend d'UN palier (P3→P2,
  jamais sous P0) ; un échec isolé re-sert le même palier
- Garde-fou UI : ≤ 12 chips affichés par item

## Réglages par défaut fins (délégué à Claude, 2026-08-13 — à ajuster aux données)
- Items : Reconnaître ~8 · Construire ~6 · session mixte du Mélange ~10
- Feedback immédiat partout SAUF aux examens (Mélange, test de niveau)
- Indice : au 1er échec sur un item, re-explication courte de la règle
- Banque de gabarits : ≥ 6 par règle ; jamais deux fois le même gabarit
  dans une session ; ton = la règle de style des exemples (phrases
  utilisables en voyage)
- Écrans : on réutilise les canvases existants (pas de nouveau design)

## Décidé (utilisateur, 2026-08-13) — la recette du Mélange (validée avec ajustements)
- Leçon de combinaison (4-6 pages, visionneuse S4) puis QUIZ d'AU
  MOINS **20 questions** — « être sûr qu'ils ont compris, pas un coup
  de chance »
- La combinaison porte sur **minimum 4 leçons** du cluster
- Items = les leçons **appliquées sur le vocab du cluster** — PAS
  d'items de vocab pur (le vocab se teste via FSRS, pas ici)
- 2-3 items parlés en fin de session · barre 80 % · échec → retenté
  demain avec un mix plus facile (proposition adoptée)
- Conséquence de taille : un cluster porte ≥ 4 leçons typées (+ ses
  listes de vocab) — défaut ajusté dans [[grammar-flow]]

## À trancher 🔴
- (rien — tout est décidé ou en défauts réglables)

Liens : [[grammar-flow]] · [[lesson-viewer]] · [[quiz-canvas]]
