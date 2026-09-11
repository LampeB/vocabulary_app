# Carte de l'app — suivi des décisions v2

Open this folder (`docs/design/map/`) as an Obsidian vault, or read it on
GitHub. One note per zone; each note separates **ce qui est décidé** (par
Thomas, avec la date), **ce qui est proposé mais pas encore vetté** (par
Claude), et **ce qui reste ouvert**.

**Règle d'entretien :** toute décision prise en session (ou tout nouveau
choix proposé dans `../v2-ux-architecture.md` / les specs) doit mettre à
jour la note concernée ET son statut dans la table ci-dessous — sinon la
carte ment.

Légende : 🟢 décidé (utilisateur) · 🟠 proposé — à vetter (Claude) ·
🔴 ouvert (personne n'a tranché) · ⚪ établi (v1, inchangé)

## Structure

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Navigation & onglets | [[navigation]] | 🟢 | modèle complet décidé/validé 2026-08-07 |
| Parcours (ex-Étudier) : structure validée | [[parcours-home]] | 🟢 | Q6 seule reste (test de saut sur niveau verrouillé) — nœud=expansion en place, compteurs sans CEFR : décidés 2026-08-21 |
| Écran Chemin du jour (S18) | [[daily-chain]] | 🟢 | détails visuels (base = panneau sombre validée) |
| Porte de préchargement | [[preload-gate]] | 🟢 | (maquetté 2026-08-21) reste : cas retry/hors-ligne, jamais simulés |
| Chemin du jour (mécanique) | [[daily-chain]] | 🟢 | nombres à régler au build (quotas, surplus) |
| Onboarding | [[onboarding]] | 🟠 | rythme, placement |

## Apprendre

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Flux vocabulaire (intro + porte) | [[vocab-flow]] | 🟢🟠 | écho, taille de lot — budget quotidien 5-10 mots/j adaptatif tranché 2026-08-21 |
| Flux leçons (clusters) — ex-grammaire | [[grammar-flow]] | 🟢 | (complet — recette Mélange validée 2026-08-13 : ≥ 4 leçons, quiz ≥ 20 q, sans vocab pur) |
| Niveau 0 (écriture — hangul) | [[niveau-0]] | 🟢 | (structure jamo validée 2026-08-13) |
| Visionneuse de leçon | [[lesson-viewer]] | 🟢🟠 | **gabarits/ton 🔴** — swipe + effet de page + exemple sur la même page que la leçon décidés 2026-08-21 (pacing recalibré, TTMIK/PACE) |
| Exercices (drills) — ex-grammaire | [[grammar-drills]] | 🟢 | (complet — recette Mélange validée, défauts fins posés 2026-08-13) |
| Test de niveau / placement | [[level-test]] | 🟢🟠 | sémantique du placement, seuil |

## Réviser

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Quiz canvas, voix, cloze, leeches | [[quiz-canvas]] | ⚪🟠 | flashcard/écrit confirmés 2026-08-21 ; cloze/voix/leeches jamais maquettés |
| Pratique libre (entrée dans Parcours) | [[pratique-libre]] | 🟢 | (confirmé 2026-08-21 — bottom sheet validé tel quel) |

## Contenu & suivi

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Onglets Vocabulaire & Leçons (ex-Grammaire) | [[bibliotheque]] | 🟢🟠 | entrée Familles (visuel) |
| Familles de mots | [[familles]] | 🟢🟠 | design écran, gratuit vs premium |
| Progrès & bilan hebdo | [[progres-suivi]] | 🟢🟠 | breakdown niveau exact — courbe multi-séries points/lignes (jamais barres) décidée 2026-08-21, plus de % CEFR affiché |
| Défis | [[defis]] | 🟢🟠 | scope après audit M9 |
| Pipeline de contenu (génération) | [[content-pipeline]] | 🟢🟠 | slot des leçons (P3), revue native |

## Système

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Langage d'interaction (plongée, flashcards, popups, scroll) | [[interaction-language]] | 🟢 | décidé 2026-09-11 |
| Multi-langue (règles transverses) | [[multi-language]] | 🟢 | — |
| Menu général (avatar) → Paramètres · abonnement · avatar · déconnexion | — | 🟢⚪ | (maquetté 2026-08-21) carte profil + sections, avatar fondu dans le profil ; écrans v1 dessous non redessinés |

Docs sources : `../v2-ux-architecture.md` (structure + flux) ·
`../app-design-overview.md` (état actuel) · `../../two-flow-daily-plan.md` ·
`../../grammar-lessons-redesign.md` · `../../feature-roadmap.md` ·
`../../implementation-plan-v2.md`.
