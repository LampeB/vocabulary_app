# Navigation & onglets

**Statut : 🟠 proposé — à vetter** · spec : `../v2-ux-architecture.md §3`

## Décidé (utilisateur, 2026-08-07)
- Un header GÉNÉRAL et un menu footer GÉNÉRAL, composants partagés
  qu'on ajoute aux écrans — pas de chrome sur mesure par écran
- Header + footer MASQUÉS pendant les sessions actives et célébrations
  — les sessions gardent leur propre chrome minimal
- **Footer : 5 slots égaux, PAS de gros bouton central** :
  Vocabulaire (listes + CRUD) · Grammaire (lire les leçons) · Étudier
  (branché sur quiz + leçons — nouvel écran, l'actuel est trop
  encombré) · Progrès (toutes les progressions : débloquages grammaire,
  vocab, progression grammaire, CEFR…) · Amis (inviter/retirer, liste,
  progression des amis…)
- **Header : sélecteur de langue · série · avatar** ; l'avatar ouvre le
  MENU GÉNÉRAL (Paramètres, options de paiement, choix d'avatar,
  déconnexion, etc.)

- (validé 2026-08-07) Étudier = onglet d'atterrissage, contient carte
  Chemin du jour + carte progression + parcours + entrée Pratique libre
- (validé 2026-08-07) Familles de mots hébergées sous Vocabulaire ;
  l'onglet Grammaire peut LANCER un drill depuis une fiche

## Proposé — pas encore vetté (Claude)
- Header `sub` (détails + S18) : retour · titre · une action
  contextuelle ; chrome de session : ✕ · progression · compteur · pause
- Actif du footer teinté clay ; jamais de badge rouge (point discret
  sur Amis max) ; cloche notifications disparaît
- Feuille de mode conservée, ouverte depuis les étapes S18 et Pratique
  libre

## À trancher 🔴
- (rien — modèle complet validé)

Liens : [[parcours-home]] · [[pratique-libre]] · [[bibliotheque]] · [[progres-suivi]]
