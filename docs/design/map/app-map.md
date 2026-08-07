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
| Accueil (Étudier) : structure validée | [[parcours-home]] | 🟢 | détails designer (Q5-Q7) |
| Écran Chemin du jour (S18) | [[daily-chain]] | 🟢 | détails visuels (base = panneau sombre validée) |
| Porte de préchargement | [[preload-gate]] | 🟢 | visuel seulement |
| Chemin du jour (mécanique) | [[daily-chain]] | 🟢 | nombres à régler au build (quotas, surplus) |
| Onboarding | [[onboarding]] | 🟠 | rythme, placement |

## Apprendre

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Flux vocabulaire (intro + porte) | [[vocab-flow]] | 🟢🟠 | écho, taille de lot, budget |
| Flux grammaire (groupes) | [[grammar-flow]] | 🟢🟠 | exam par groupe ?, seuils, cadence |
| Visionneuse de leçon | [[lesson-viewer]] | 🟢🟠 | **contenu des leçons 🔴** |
| Exercices de grammaire (drills) | [[grammar-drills]] | 🔴 | formats de chaque étape |
| Test de niveau / placement | [[level-test]] | 🟢🟠 | sémantique du placement, seuil |

## Réviser

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Quiz canvas, voix, cloze, leeches | [[quiz-canvas]] | ⚪🟠 | layout cloze, thème teal |
| Pratique libre (entrée dans Étudier) | [[pratique-libre]] | 🟠 | setup 3 choix, visibilité de l'entrée |

## Contenu & suivi

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Onglets Vocabulaire & Grammaire | [[bibliotheque]] | 🟢🟠 | entrée Familles (visuel) |
| Familles de mots | [[familles]] | 🟢🟠 | design écran, gratuit vs premium |
| Progrès, CEFR & bilan hebdo | [[progres-suivi]] | 🟢🟠 | layouts, seuils CEFR |
| Défis | [[defis]] | 🟢🟠 | scope après audit M9 |

## Système

| Zone | Note | Statut | Reste à trancher |
|---|---|---|---|
| Multi-langue (règles transverses) | [[multi-language]] | 🟢 | — |
| Menu général (avatar) → Paramètres · abonnement · avatar · déconnexion | — | 🟢⚪ | design du menu (S15 léger ; écrans v1 conservés dessous) |

Docs sources : `../v2-ux-architecture.md` (structure + flux) ·
`../app-design-overview.md` (état actuel) · `../../two-flow-daily-plan.md` ·
`../../grammar-lessons-redesign.md` · `../../feature-roadmap.md` ·
`../../implementation-plan-v2.md`.
