# Navigation & onglets

**Statut : 🟠 proposé — à vetter** · spec : `../v2-ux-architecture.md §3`

## Décidé (utilisateur, 2026-08-07)
- Un header GÉNÉRAL et un menu footer GÉNÉRAL, composants partagés
  qu'on ajoute aux écrans — pas de chrome sur mesure par écran
- Header + footer MASQUÉS pendant les sessions actives et célébrations
  — les sessions gardent leur propre chrome minimal
- **Footer : 5 slots égaux, PAS de gros bouton central** :
  Vocabulaire (listes + CRUD) · Grammaire *(renommé « Leçons »
  2026-08-13 — « grammaire » trompeur selon la langue)* · Étudier
  *(renommé « Parcours » 2026-08-13 — « Étudier » ne distinguait pas
  cet onglet des deux autres, qui servent aussi à étudier ; le nom
  colle maintenant à ce que l'écran montre : route à nœuds + chemin du
  jour + position)* (branché sur quiz + leçons — nouvel écran, l'actuel
  est trop encombré) · Progrès (toutes les progressions : débloquages
  grammaire, vocab, progression grammaire, CEFR…) · Amis (inviter/
  retirer, liste, progression des amis…)
- **Header : sélecteur de langue · série · avatar** ; l'avatar ouvre le
  MENU GÉNÉRAL (Paramètres, options de paiement, choix d'avatar,
  déconnexion, etc.)

- (validé 2026-08-07) Étudier = onglet d'atterrissage, contient carte
  Chemin du jour + carte progression + parcours + entrée Pratique libre
- (validé 2026-08-07) Familles de mots hébergées sous Vocabulaire ;
  l'onglet Grammaire peut LANCER un drill depuis une fiche
- **V0 (2026-09-12)** : Amis est reporté. Son slot est temporairement occupé
  par **Profil** ; le footer V0 conserve donc cinq slots égaux :
  Parcours · Vocabulaire · Leçons · Progrès · Profil.

## Proposé — pas encore vetté (Claude)
- Header `sub` (détails + S18) : retour · titre · une action
  contextuelle ; chrome de session : ✕ · progression · compteur · pause
- Actif du footer teinté clay ; jamais de badge rouge (point discret
  sur Amis max) ; cloche notifications disparaît
- Feuille de mode conservée, ouverte depuis les étapes S18 et Pratique
  libre

## Décidé (utilisateur, 2026-08-13) — retour contextuel, jamais un écran fixe
- Le bouton retour (‹/✕) d'un écran atteignable par PLUSIEURS chemins
  (ex. S4 leçon, S5 drills, Mélange — accessibles depuis la fiche de
  cluster ET depuis le chemin du jour) doit revenir au point d'ENTRÉE
  réel, jamais une destination câblée en dur
- Bug relevé sur le playground : le retour ramenait toujours à la
  fiche même en venant du chemin du jour — corrigé (pattern
  `returnTo`, déjà appliqué à S6 résumé via `vOrigin`, généralisé à
  S4/S5/Mélange)
- Principe transverse pour l'implémentation réelle (go_router) : la
  pile de navigation doit refléter le vrai point d'entrée, pas un
  onglet par défaut — probablement la même racine que le ticket Notion
  « Bug: system back exits the app from pushed routes » (routes
  poussées de façon incohérente), à vérifier ensemble côté code

## Décidé (utilisateur, 2026-09-11) — transition de navigation « plonger »
- Ouvrir une destination depuis une tuile, une ligne ou un contrôle donne
  l'impression de **plonger dans l'élément touché** : l'élément source se
  développe vers l'écran qui s'ouvre, puis le retour inverse le mouvement vers
  la source réelle.
- Ce principe s'applique aux listes, niveaux, fiches, réglages et setup de
  quiz. Ces écrans ne sont pas construits comme des cartes empilées ou
  inclinées : la pile est réservée au moment de révision des flashcards.
- Respecter `prefers-reduced-motion` (fondu simple) et ne jamais ralentir la
  navigation au point de la rendre moins directe. Voir [[interaction-language]].

## À trancher 🔴
- (rien — modèle complet validé)

Liens : [[parcours-home]] · [[pratique-libre]] · [[bibliotheque]] · [[progres-suivi]] · [[interaction-language]]
