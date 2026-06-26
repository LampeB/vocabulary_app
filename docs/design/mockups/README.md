# Interactive mockups

Self-contained HTML maquettes of the redesigned screens. Open any file in a browser — each is interactive (switch modes, step through states, flip cards, etc.). These are design references, not production code; the specs live one level up in `docs/design/`.

| File | Screen | Theme |
|------|--------|-------|
| `quiz-setup-accordion-light.html` | Start-a-session (accordion) | Light |
| `handsfree-dark.html` | Hands-free — all states | Dark |
| `handsfree-light.html` | Hands-free — all states | Light |
| `quiz-modes-dark.html` | Voix / Cartes / Écrire | Dark |
| `quiz-modes-light.html` | Voix / Cartes / Écrire | Light |

Notes:
- Icons load from the Tabler webfont CDN; fonts from Google Fonts — both need an internet connection.
- The dark study screens and their light counterparts both exist because all screens follow the system theme (see `../quiz-modes.md` and `../hands-free-screen.md`).
