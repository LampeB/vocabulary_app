# Interactive mockups

Self-contained HTML maquettes of the redesigned screens. Open any file in a browser — each is interactive (switch modes, step through states, flip cards, etc.). These are design references, not production code; the specs live one level up in `docs/design/`.

| File | Screen | Theme |
|------|--------|-------|
| `quiz-setup-accordion-light.html` | Start-a-session (accordion) | Light |
| `handsfree-dark.html` | Hands-free — all states | Dark |
| `handsfree-light.html` | Hands-free — all states | Light |
| `quiz-modes-dark.html` | Voix / Cartes / Écrire | Dark |
| `quiz-modes-light.html` | Voix / Cartes / Écrire | Light |
| `grammar-lesson-flow.html` | Flux complet d'une leçon de grammaire (S9 → S4 → drills → Mélange), annoté décidé/proposé | Both (page) · Light (écrans) |
| `grammar-lesson-flow-interactive.html` | Le même flux, NAVIGABLE : un téléphone tappable — fiche cluster → leçon paginée → drills (rampe P0-P3 jouable) → Mélange | Both (page) · Light (écran) |
| `vocabapp-playground.html` | L'APP ENTIÈRE navigable (v2) : porte de préchargement S2, shell 5 onglets, chemin du jour S18, sessions, clusters, test de niveau, menu général S15 — dataset minimal 1 langue, bloc CONFIG réglable. Seul S16 (onboarding) manque encore. | Both (page) · Light (écran) |
| `vocabapp-mobile-test.html` | Même app, sans le chrome de démo (pas d'en-tête/jump-bar/footer) — l'écran occupe 100 % de la fenêtre : à ouvrir directement sur un téléphone pour juger la taille réelle des éléments | Light (écran) |

Notes:
- Icons load from the Tabler webfont CDN; fonts from Google Fonts — both need an internet connection.
- The dark study screens and their light counterparts both exist because all screens follow the system theme (see `../quiz-modes.md` and `../hands-free-screen.md`).
