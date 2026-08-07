# Navigation & onglets

**Statut : 🟠 proposé — à vetter** · spec : `../v2-ux-architecture.md §3`

## Décidé (utilisateur)
- (2026-08-07) Un header GÉNÉRAL et un menu footer GÉNÉRAL, composants
  partagés qu'on ajoute aux écrans — pas de chrome sur mesure par écran
- (2026-08-07) Header + footer MASQUÉS pendant les sessions actives
  (quiz/leçon/drill/test) et célébrations — les sessions gardent leur
  propre chrome minimal (progression + quitter)
- (le remaniement des 5 slots attend toujours un veto)

## Proposé — pas encore vetté (Claude, 2026-08)
- 5 slots repensés : Parcours · Bibliothèque · FAB Pratiquer · Progrès · Amis
- Profil/Paramètres/Paywall derrière l'avatar (haut droite Parcours & Progrès)
- La cloche notifications disparaît de l'accueil
- Feuille de mode (Voix/Mains libres/Écrit/Cartes) conservée, ouverte depuis
  les étapes de S18 et Pratiquer
- Contenus du shell (spec §6.0 + `../diagrams/v2-shell.svg`) :
  - header `root` : chip langue (onglets scoped langue) · série 🔥 ·
    avatar ; `sub` : retour · titre · une action contextuelle
  - footer : 5 slots icône+label, actif en clay, FAB Pratiquer central,
    jamais de badge rouge (point discret sur Amis max)
  - chrome de session : ✕ · progression · compteur · pause (voix)
- Footer présent sur tous les écrans de navigation (onglets + détails +
  S18)

## À trancher 🔴
- Rien de plus une fois le modèle vetté ou amendé

Liens : [[parcours-home]] · [[pratique-libre]] · [[bibliotheque]] · [[progres-suivi]]
