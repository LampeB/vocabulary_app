# Progrès : dashboard & bilan hebdo

> **Renommé 2026-08-21** : plus de CEFR affiché nulle part dans l'app
> (cohérent avec « Niveau 1-6, jamais A1-C2 », décidé 2026-08-13) — le
> titre et les décisions ci-dessous qui mentionnent CEFR comme LIBELLÉ
> ÉCRAN sont supersédées ; CEFR reste un usage interne possible
> (estimation de données), jamais montré à l'utilisateur

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

## Décidé (utilisateur, 2026-08-13) — historique enrichi + nouvelles stats
- Le dashboard doit montrer une histoire plus LONGUE : une timeline
  du parcours de l'utilisateur (événements clés — niveau commencé,
  cluster validé, série atteinte, test réussi…), pas juste
  l'instantané actuel
- Nouvelles statistiques demandées : temps moyen pour maîtriser une
  liste de vocab · temps moyen pour maîtriser une leçon · temps
  activement passé à étudier chaque jour · nombre de jours actifs par
  semaine · nombre de sessions d'étude nécessaires pour valider un
  niveau
- Maquetté dans le playground (carte « Ton rythme » + carte
  « Ton parcours »), chiffres d'exemple

## Constat code (2026-08-13) — ce qui est déjà là vs ce qu'il manque
- **Bonne surprise** : le ticket Notion « Review-event log — capture
  every answer (foundational for stats) » (High, marqué Todo) est en
  réalité DÉJÀ implémenté — `review_events_table.dart` +
  `review_event_dao.dart` existent, avec `responseTimeMs`,
  `correct`, `rating`, `createdAt` par réponse. Le board Notion est
  désynchronisé du code sur ce point — à corriger dessus dès que
  possible.
- **Déjà calculable** : temps de maîtrise d'une LEÇON (grammar_progress
  a `createdAt` + `masteredAt` par règle) ; temps de maîtrise d'une
  LISTE (variant_progress + review_events, une fois la règle « mot
  connu » posée) ; jours actifs vocab (dates de `quiz_sessions`)
- **Manque réellement** : `review_events.mode` ne couvre que
  flashcard/typing/voice/handsFree — aucun événement horodaté pour les
  drills de leçon (Reconnaître/Construire/Mélange) ni pour le temps
  passé dans la visionneuse de leçon. Donc **temps actif/jour**,
  **jours actifs/semaine** et **sessions pour valider un niveau** ne
  sont complets qu'une fois le suivi de session étendu au côté leçons
  — probablement en élargissant `mode` (ou une table sœur) plutôt
  qu'en touchant `quiz_sessions`. Ticket à créer côté code, distinct
  du contenu.

## Décidé (utilisateur, 2026-08-21) — courbe multi-séries, jamais un histogramme
- Le graphe « cette semaine » devient une **courbe à points/lignes**
  (SVG, aire légère sous la courbe principale), pas des barres — permet
  plusieurs séries superposées lisiblement (ex. mots révisés · leçons
  faites) et une fenêtre PLUS LONGUE qu'une semaine (bascule 7 j / 30 j
  maquettée)
- Remplace aussi le % CEFR de la carte position par les DEUX compteurs
  du Parcours (leçons x/20, nœuds x/4 — voir [[parcours-home]]) ; plus
  de barre de progression générique sur cette carte
- Implémenté dans le playground (carte « Ta courbe »)

## À trancher 🔴
- Comment fusionner position parcours (curriculum) et éventuelle
  estimation de niveau interne (données) si celle-ci reste utile en
  coulisses ; le contenu exact du breakdown
- Contenu exact de la timeline (quels événements comptent comme
  « clés » ?) ; profondeur d'historique affichée

Liens : [[navigation]] · [[parcours-home]] · [[level-test]]
