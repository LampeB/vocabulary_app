# Onglets Vocabulaire & Leçons (ex-Grammaire)

**Statut : 🟢 deux onglets séparés décidés · 🟠 détails** ·
écrans S7/S8/S9 · spec : `../v2-ux-architecture.md §6.7, §6.8`

## Décidé (utilisateur, 2026-08-06/07)
- Les utilisateurs créent des listes de VOCABULAIRE, jamais de grammaire
  (curriculum intégré, lecture seule)
- (2026-08-07) DEUX ONGLETS distincts — la fusion « Bibliothèque » est
  abandonnée : **Vocabulaire** = voir les listes + CRUD ; **Grammaire**
  = lire les leçons

## Proposé — pas encore vetté (Claude)
- Vocabulaire : v1 Mes listes conservé (cartes, détail, ajout de mot) +
  index des Familles (M8) hébergé ici
- Grammaire : « livre de cours » — cartes de groupe x/5 + Mélange +
  barres de prérequis quand verrouillé ; détail de groupe : lignes de
  règles ●●●, « Relire la leçon », « S'entraîner maintenant »
- Chips de filtre par paire persistants en haut des deux onglets

## Décidé aussi (validé 2026-08-07)
- Familles sous Vocabulaire ; l'onglet Grammaire peut lancer un drill
  depuis une fiche (« S'entraîner maintenant »)

## Proposé — pas encore vetté (Claude, 2026-08-13) — vue d'ensemble Vocabulaire
- Cartes de liste (pas des lignes plates) : pastille couleur, tag
  **PARCOURS** vs **PERSO** (distingue les listes du curriculum des
  listes créées par l'utilisateur — cohérent avec la décision
  2026-08-06 « les listes perso ne comptent pas dans x/20 »), nombre
  de mots, badge « X à réviser » (tire sur les dues FSRS — donne vie
  à la liste au-delà du % statique), % de maîtrise + mini-barre
- Tri (pastille « ⇅ Récent/Maîtrise/A→Z », cycle au tap) — répond au
  proposé historique « chips de filtre par paire persistants »
  (implémenté ici pour la paire ; le tri est un ajout)
- **Familles de mots** : traitement résolu — carte à part, dégradé
  chaud distinct des cartes de liste, glyphe 🌳 — visuellement pas une
  liste de plus (répond au 🔴 historique « traitement visuel de
  l'entrée Familles »)
- Implémenté dans le playground — à valider en cliquant

## Décidé (utilisateur, 2026-08-13) — CRUD visible sur les listes
- Boutons CRUD demandés explicitement : chaque carte + l'en-tête du
  détail de liste (S8) porte un bouton « ⋯ » ouvrant Renommer /
  Ajouter des mots / Supprimer ; « + Nouvelle liste » crée réellement
  une liste (plus un simple stub)
- Conséquence de conception (Claude, à valider) : le CRUD n'est actif
  QUE sur les listes **PERSO** — les listes **PARCOURS** sont du
  contenu de curriculum (comme la grammaire), donc en lecture seule ;
  leur bouton « ⋯ » affiche « géré par le niveau, pas modifiable ici »
  au lieu des actions. Cohérent avec la distinction PARCOURS/PERSO
  posée le même jour dans la vue d'ensemble.
- Implémenté et fonctionnel dans le playground (renommer, ajouter/
  retirer un mot, supprimer une liste perso, créer une liste)

## À trancher 🔴
- (rien — proposition de vue d'ensemble + CRUD parcours/perso en
  attente de validation)

Liens : [[navigation]] · [[grammar-flow]] · [[familles]] · [[vocab-flow]]
