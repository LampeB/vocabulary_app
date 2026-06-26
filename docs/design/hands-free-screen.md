# Hands-free (Mains libres) — screen spec

*Finalized design. Replaces the earlier "orb" concept. Built around the signature waveform, eyes-free. 26 June 2026.*

## Purpose

Hands-free is the eyes-off study mode: the phone may be on a desk or in a pocket while the learner does something else. Audio auto-plays each prompt, the learner answers by voice, grading is automatic, and the session flows card to card on its own. The screen must be **readable and operable from peripheral vision** — big signals, big targets, no precise aiming.

## Layout — "word in the wave"

Dark immersive background (`#241F1B` deep ink) + dotted ground (white low-alpha).

- **Header**: quit (✕) on the left, counter (e.g. `04 / 12`) centered. Minimal.
- **Center**: the prompt word centered (Space Grotesk ~48, on-dark), with a **wide waveform behind it** at low opacity (~0.3). A mono eyebrow **cue line** sits below (e.g. "Dis-le en coréen"). The whole center area is the **tap-to-pause** zone.
- **Bottom**: two **oversized** buttons side by side — **Répéter** (left) and **Passer** (right), each ~half width and ~104 px tall, icon + label. Corner-anchored so they're hittable by feel.

## States → visuals

The waveform encodes only the **audio I/O state** (idle / reading / listening / processing). Grading feedback is a separate full-screen event.

| State | Waveform | Screen | Word / cue |
|---|---|---|---|
| Préparation (loading next card) | collapsed flat, still, dim (~0.16) | dark | word dim (0.4), no cue |
| **Lecture du mot** (prompt TTS plays) | **frozen** (static, no dance) | **whole screen pulses** — warm breathing glow (~1.9 s) | word full · "Écoute le mot" |
| **À toi (écoute)** (mic open / STT) | **animated** full ripple, brighter (~0.42), faster (~0.7 s), soft glow | dark | word full · "Dis-le en coréen" |
| Analyse (grading) | slow, low-amplitude, dim (~0.24) | dark | word slightly dim · "…" |
| **Juste** (correct) | — | **whole screen floods bright teal** `#2FA98C`, big white check | "Juste !" |
| **À revoir** (wrong) | — | **whole screen floods bright orange** `#E8693C`, big white ✕ | "À revoir" + Korean answer revealed |
| Pas entendu (no speech) | muted slow wobble (~0.26) | dark | "Je n'ai pas entendu — réessaie" |
| Pause | near-dark, still | dark | word dimmed (~0.18) + blurred → sits **behind** a large bright **EN PAUSE** (with pause icon); hint "Touche pour reprendre" |

Key motion semantics: **pulse = "listen" (the app is talking), dance = "your turn" (speak now).** They must be distinguishable peripherally.

## Feedback — must be catchable peripherally

- Correct/wrong is a **full-screen color flood** (teal vs orange), held for the feedback moment — not a subtle tint — so it registers from the corner of the eye with the phone on the side.
- The two feedback colors are **brighter than the base palette** and chosen for maximum separation from each other and from the dark studying state. Orange stays in the warm/clay family (not rose — rose is reserved for destructive actions).
- Pair every outcome with a **distinct earcon + haptic** (correct, wrong, and a listen-start cue), so it's catchable even face-down or in a pocket.
- On **À revoir**, the correct answer is spoken and revealed.

## Pause

Tapping the center pauses. The word recedes (dimmed ~0.18 + soft blur) and a large bright **EN PAUSE** comes to the front, so the word reads as sitting behind the message. Waveform goes near-dark. Tap again to resume.

## Controls

Oversized, corner-anchored, find-by-feel: **Répéter** (replay the prompt and re-listen) and **Passer** (skip / requeue the word). Center = pause. No control requires precise aiming.

## "Pas entendu" recovery (important)

Because STT is the weak link, silence must **not** be a hard wrong. Instead: a distinct muted "Je n'ai pas entendu — réessaie" state, auto re-listen up to **N** times (suggest 2), and only then requeue the word as *à revoir*. This is where the STT-improvement work plugs in.

## Accessibility

- Honor `prefers-reduced-motion`: freeze the bars and the screen pulse; rely entirely on color floods + earcons + haptics.
- Eyes-off: distinct earcons (listen-start, correct, wrong) and haptics carry the state even when the screen isn't seen.
- Large targets throughout; whole-screen pause.

## Open questions

- N silent retries before requeue (suggested 2).
- On a wrong answer, auto-advance after speaking the answer, or hold briefly?
- Confirm the exact feedback teal/orange values against on-device glare.

## Theming — follows the system theme (both modes required)

This screen supports **light and dark**, following the OS theme. Dark mode is the immersive design above; light mode is the paper version (mocked in Cowork). The dark canvas is the *dark theme*, not a fixed mode.

Token map (light ↔ dark):

- Background: paper `#F6F1EA` ↔ deep ink `#241F1B`
- Primary text: ink `#2B2622` ↔ on-dark `#F6F1EA`; muted `#756C62` ↔ `#CFC6BA`; faint `#A99F90` ↔ `#9A9086`
- Line/dividers: `#ECE3D7` ↔ `rgba(255,255,255,0.12)`; dotted ground `rgba(43,38,34,0.10)` ↔ white low-alpha
- Accents (teal/clay) stay, brightening slightly on dark (clay `#FF8A55`, teal `#5FB0A8`)
- **EN PAUSE** label: ink in light ↔ white in dark; the word behind dims/blurs in both
- Reading **pulse glow**: warm clay radial — a touch stronger on light so it reads
- Ambient waveform opacity slightly higher on light so bars don't wash out
- **Full-screen feedback floods are identical in both themes** (teal `#2FA98C` / orange `#E8693C` + white) — a color takeover, theme-independent

## Related

- Builds on the listening-waveform animation already wired in `quiz_screen.dart` / `vk_waveform.dart`.
- Depends on / feeds the STT-improvement plan (`docs/stt-improvement-plan.md`) for the "pas entendu" loop.
- Notion: VocabApp — Tasks → "Hands-free screen — word-in-wave design" (implementation).
