# Flux vocabulaire : introduction + porte

**Statut : 🟢 modèle décidé · 🟠 détails proposés** · écran S3 · flux F2 ·
spec : `../v2-ux-architecture.md §6.3` · `../../two-flow-daily-plan.md` ·
diagramme : `../diagrams/word-lifecycle-gate.svg`

## Décidé (utilisateur, 2026-07-22, précisé le 2026-09-12)
- Le parcours guidé introduit les nouveaux mots par lots avant leur pratique
  notée : la découverte et l'écho restent les premiers contacts recommandés.
- Cette porte n'est **pas globale** : depuis n'importe quelle liste créée ou
  importée, l'utilisateur peut lancer immédiatement un quiz de vocabulaire,
  même pour des mots encore jamais vus. Le parcours propose un ordre ; il ne
  doit jamais enfermer l'utilisateur qui veut uniquement réviser une liste.
- Les listes de vocab restent créables par l'utilisateur (2026-08-06) —
  contrairement à la grammaire.

## Proposé — pas encore vetté (Claude)
- Deck d'intro : un mot/page (mot, trad, audio auto + replay, exemple
  surligné), lot de 5-10, swipe libre
- Pratique « écho » : QCM non noté dans les deux sens juste après le lot
- Écran de fin : chips du lot + « ils arriveront dans tes révisions »
- Unités de vocab du parcours = lots thématiques tagués par niveau ; les
  listes perso peuvent être proposées à Découvrir sans compter dans x/20
- Pratique libre sur liste non étudiée → quiz immédiat possible ; Découvrir
  reste une recommandation, jamais un blocage

## Décidé (utilisateur, 2026-08-21) — budget quotidien de nouveaux mots
- **5 à 10 nouveaux mots par jour** — plage retenue pour tenir sur la
  durée : 35-70/semaine, 150-300/mois, un rythme soutenable sans
  s'épuiser (raisonnement de l'utilisateur, pas juste un chiffre
  arbitraire)
- **Adaptatif, réévalué CHAQUE SEMAINE** : à la fin de la semaine, le
  système regarde si l'utilisateur a suivi le rythme donné (mots
  introduits vs mots réellement absorbés/révisés à temps) et ajuste le
  budget de la semaine suivante à l'intérieur de la plage 5-10 — descend
  si ça déborde, remonte si c'est trop facile
- Défaut de démarrage proposé (Claude, à valider) : 6/jour, jusqu'à la
  première réévaluation hebdomadaire
- Tranche le 🔴 historique (« budget quotidien par défaut ~8 ? ») —
  remplacé par une plage + mécanique adaptative plutôt qu'un chiffre fixe

## À trancher 🔴
- Taille du lot d'introduction en une session (5-10 mots par LOT reste
  ouvert — différent du budget JOURNALIER ci-dessus, qui peut se
  répartir sur plusieurs étapes Découvrir) ; la forme exacte de l'écho
  (QCM suffit-il ?) ; la formule précise de réévaluation hebdomadaire
  (quel seuil de suivi déclenche une baisse/hausse, de combien)

Liens : [[daily-chain]] · [[parcours-home]] · [[grammar-flow]] (prérequis)
