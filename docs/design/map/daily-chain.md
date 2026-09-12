# Chemin du jour (les étapes quotidiennes)

**Statut : 🟢 principe décidé · 🟠 mécanique proposée** · flux F0 ·
spec : `../v2-ux-architecture.md §1, §5 F0` · `../../two-flow-daily-plan.md` ·
schéma : `../diagrams/v2-daily-chain.svg` (sources → générateur → étapes)

## Décidé (utilisateur, 2026-07-22)
- Deux flux : Apprendre (nouveau, jamais noté au 1er contact) / Réviser
  (connu, FSRS) — composés en un plan quotidien
- Navigation « chemin/plan du jour » retenue parmi les options

## Décidé (utilisateur, 2026-08-07)
- Le chemin du jour a son ÉCRAN DÉDIÉ (S18), ouvert par une carte
  « Chemin du jour » sur l'accueil
- Base de design validée « pour l'instant » : le panneau sombre à étapes
  des diagrammes (`../diagrams/v2-daily-chain.svg`, panneau de droite)

## Implémenté (V0, 2026-09-12)

- La carte d'accueil ouvre désormais S18 (`/daily-path`) : une entrée dédiée,
  contextualisée par la paire active.
- Cette première tranche relie uniquement les capacités déjà réelles : révision
  des échéances par paire (avec choix du mode), hub Leçons et Pratique libre.
  Elle ne crée ni série ni complétion fictive.
- Le chemin reste explicitement optionnel : les listes et leurs quiz directs ne
  sont jamais bloqués par cet écran.

## Décidé (utilisateur, 2026-08-08 — mécanique tranchée)
- **Ordre : Réviser d'abord** (échauffement sur du connu) → leçons du
  parcours → drills grammaire → Renforcer en dernier
- **Figé à la génération** : généré au premier lancement du jour ; les
  échéances qui tombent ensuite attendent demain
- **Journée réussie = TOUTES les étapes** du chemin (célébration à la
  dernière)
- **Chemin ET série PAR LANGUE** : chaque langue a son chemin et sa
  propre flamme 🔥 (le header affiche celle de la langue courante)

## Proposé (utilisateur, 2026-08-08)
- Renommer « Chemin du jour » en « **Tâches du jour** » (daily tasks) —
  libellé plus clair pour répondre à « qu'est-ce que je fais
  aujourd'hui ? »

## Proposé — pas encore vetté (Claude, réglages de build)
- Quotas : 2-5 étapes/jour, 1-2 grammaire ; budget de nouveaux mots
  **tranché 2026-08-21** : 5-10/jour, adaptatif par semaine (voir
  [[vocab-flow]]) ; étapes de 2-5 min ; grosse journée d'échéances →
  max ~20 mots par étape Réviser, le surplus en 2ᵉ étape ou vers
  Pratique libre
- Hier disparaît sans culpabilisation ; étape sautée reste disponible
- Résumé de session avec bloc « et ensuite » (Continuer le chemin)

## À trancher 🔴
- (rien de structurel — les nombres ci-dessus se règlent au build)

Liens : [[parcours-home]] · [[vocab-flow]] · [[grammar-flow]]
