# Quiz study modes — unified design

*Voix, Cartes, and Écrire now share one dark, immersive study canvas (the same language as Hands-free). Approved 26 June 2026.*

## Shared canvas (all study modes)

- **Dark immersive background** (`#241F1B`) + dotted ground — "study mode = focus mode," deliberately distinct from the light paper of Home / Lists / Start-a-session.
- The prompt **word centered inside a wide low-opacity waveform** ("word in the wave").
- **Minimal header**: ✕ (quit) · thin progress bar · counter.
- **Full-screen color feedback**, identical across every mode: correct = bright teal flood `#2FA98C` + big white check + "Juste !"; wrong = bright orange flood `#E8693C` + big white ✕ + "À revoir" (with the answer revealed/spoken). Held for the moment, not a tint — catchable peripherally.
- Big, find-by-feel targets.

## Waveform role per mode

- **Active** — dances on the user's turn — in **Voix**.
- **Ambient** — low-opacity, calm/frozen brand texture, not a meter — in **Cartes** and **Écrire**.

## Voix (voice)

- Word-in-wave; tap the big clay **mic** to talk → bars animate + cue "Dis-le en coréen" → auto-grade → full-screen feedback.
- Two **escape pills** under the mic: **Voir la réponse** (give up / reveal → requeue as à revoir) and **Clavier** (switch to typing for this word).
- Note: these were previously bare labels "Je ne sais plus" + "Écrire", which ran together as "je ne sais plus écrire." Now separated as icon pills and "Écrire" renamed to "Clavier" so no two labels form a sentence.

## Cartes (flashcards)

- Ambient frozen wave. **Front** = French (eyebrow "Français" + word); tap to flip → **back** = Korean (한국어 + word + romaji). Never both faces at once.
- Self-grade with **À revoir** / **Je savais**, styled with the same orange/teal as the auto-graded feedback so grading reads consistently across modes.

## Écrire (typing)

- Word-in-wave up top + underlined text input (clay caret) + **Valider** (teal) → full-screen feedback. Ambient wave behind.
- Hangul keyboard at the bottom.
- ⚠ **Open question**: a dark immersive screen paired with the **OS keyboard** (system-themed, usually light) can clash. Decide between the app's own in-screen dark Hangul keyboard (as mocked) or relaxing Écrire to a lighter treatment. Until resolved, Écrire is the one mode that may diverge from full dark-immersive.

## Relation to Hands-free

Hands-free is the same canvas with no manual mic (auto-listen), the screen-pulse-while-reading behaviour, and oversized corner controls. See `hands-free-screen.md`.

## Open decisions

- Dark-immersive committed for Voix and Cartes; Écrire pending the keyboard question above.
- Whether the wrong-answer flood auto-advances or holds briefly (shared with hands-free).

## Theming — follows the system theme (both modes required)

Every study mode supports **light and dark**, following the OS theme. Dark mode is the immersive dark canvas; light mode is the paper version (both mocked in Cowork). The dark canvas is the *dark theme*, not a fixed "focus mode."

Token map (light ↔ dark):

- Background: paper `#F6F1EA` ↔ deep ink `#241F1B`
- Card/surface: `#FFFFFF` ↔ `~#2E2823`
- Primary text: ink `#2B2622` ↔ on-dark `#F6F1EA`; muted `#756C62` ↔ `#CFC6BA`; faint `#A99F90` ↔ `#9A9086`
- Line: `#ECE3D7` ↔ `rgba(255,255,255,0.12)`; dotted ground `rgba(43,38,34,0.10)` ↔ white low-alpha
- Accents (teal/clay) stay, brightening slightly on dark (clay `#FF8A55`, teal `#5FB0A8`)
- Active cue text uses **clay deep `#C4703F`** on light ↔ clay light `#E0A079` on dark
- Écrire keyboard: light tray `#D8D2C8` + white keys ↔ dark keys on `rgba(255,255,255,0.06)`
- Ambient waveform opacity slightly higher on light so bars don't wash out
- **Full-screen feedback floods are identical in both themes** (teal `#2FA98C` / orange `#E8693C` + white) — a color takeover, theme-independent

## Related

- `docs/design/hands-free-screen.md` (same canvas, eyes-off variant).
- Notion: VocabApp — Tasks → quiz-mode restyle tasks (foundation + Voix / Cartes / Écrire).
