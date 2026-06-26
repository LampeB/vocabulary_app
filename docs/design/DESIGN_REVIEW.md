# VocabKR — Design Review

*Critique of the 8 screen boards in `docs/design/screenshots/`, checked against the documented design system. 26 June 2026.*

The design has a strong, coherent identity — the warm paper palette, the dotted ground, and the waveform motif give it a calm, distinctive feel that fits an "encouraging coach, never exam-like" tone. The issues below are mostly gaps and inconsistencies, not a rethink. They're ordered by impact.

---

## 🔴 Critical

### 1. The primary button color fails color contrast — everywhere

White text on the clay CTA (`#D08358`) measures **2.97:1**, which fails WCAG AA for both normal *and* large text (needs 4.5:1 / 3:1). This is the most-used button in the app — *Commencer*, *Continuer*, *Ajouter un mot*, *Créer la liste*, *Essayer 7 jours*. The teal CTA (`#4C8C86`) with white is **3.89:1**, which also fails normal-text AA.

The design system even names a "Clay deep `#C4703F` — AA contrast" token, but white on it is only **3.66:1** — still failing. So the documented "accessible" clay isn't actually accessible against white.

**Fix:** darken the filled-button clay to roughly `#A85A30` (≈4.5:1 with white) and the filled teal to about `#3E726D`. Keep the brighter clay/teal for accents, fills, and icons where they're not carrying white text. This is one token change that fixes every screen at once.

### 2. Voice study screen has no manual "tap to talk" / retry control

On the canonical Study · Voice screen (`study-f1`), the only bottom actions are *Je ne sais plus* and *Écrire*. The listening state is communicated by the text "J'ÉCOUTE…" alone — there's no mic button to re-trigger listening, and no visible way to recover when recognition fails. Given that speech recognition is the known weak point of the app, the UI currently gives the user no way to *retry the recording* without abandoning the word.

**Fix:** add the clay mic affordance as a tappable element with three clear states (idle → listening pulse → processing), so a learner can re-record on demand. This pairs directly with the planned STT rework.

---

## 🟡 Moderate

### 3. Clay means too many things at once

Clay (`#D08358`) is assigned to: the primary CTA, the "live/recording" state, streak energy, *and* the "à revoir" (incorrect) feedback screen. Using the same warm color for "primary action / go" and for "you got it wrong" sends mixed signals. Rose is reserved strictly for destructive actions, so "incorrect" has no color of its own and borrows the action color.

**Fix:** give "à revoir" its own neutral-but-distinct treatment (e.g., a muted amber/stone tint or simply the ink-on-line card with a clay accent bar), so warm-clay can stay "the active/primary" color without doubling as the error state.

### 4. "Continuer" switches color between flows

In onboarding, *Continuer* is clay. In the quiz feedback screens, *Continuer* is teal (and *Valider* is teal). The same forward/commit action shouldn't change color by context — it teaches the user nothing consistent.

**Fix:** pick one rule. The system text suggests teal = "commit/continue," so make all *Continuer/Valider* buttons teal and reserve clay for the *starting* action (Commencer, start a session). Then apply it everywhere.

### 5. Annual price is ambiguous on the paywall

The paywall shows "Mensuel 7,99 €" next to "Annuel 4,75 €" at equal size. Read quickly, the annual plan looks like it costs €4.75 total — cheaper than one month — when 4,75 € is the *per-month, billed-annually* rate. This is the screen where clarity matters most.

**Fix:** show "4,75 €/mois" inline on the annual card (not just in fine print), and consider a secondary line with the actual annual total (e.g., "57 € facturé par an").

### 6. Several text tokens fail contrast on paper

Beyond the buttons: the "Faint" token (`#A99F90`) used for captions and inactive nav is **2.32:1** (well below AA), "Muted 2" eyebrow labels (`#8A857C`) are **3.26:1**, and clay-deep text on paper is **3.26:1** — all failing normal-text AA. Eyebrows are small uppercase mono, which is the *hardest* text to read, so this compounds.

**Fix:** darken Faint to about `#8A8073` and Muted 2 to about `#6F695F` for any text use; keep the lighter values only for non-text elements like dividers and the dotted ground.

---

## 🟢 Minor

### 7. Home hierarchy leads with the streak, not the task

The huge "12 jours de suite" streak number is the largest thing on Home and grabs the eye first, above the "23 mots à réviser → Commencer" card, which is the screen's actual primary job. The vanity metric outranks the action.

**Fix:** either shrink the streak number slightly or lift the "À réviser" card visually (it's already dark, which helps) so the start-reviewing action wins the first glance.

### 8. Edit-list rows place a tiny delete next to a tiny edit

In *Modifier la liste*, each word row has a small teal pencil and a small rose bin immediately adjacent. Two small, neighboring targets — one of them destructive — invite mis-taps. (The delete does have a confirmation dialog, which is good.)

**Fix:** increase spacing between the two icons and confirm each is a 44px target including padding, or move delete behind a swipe / overflow so it's harder to hit by accident.

### 9. Dark theme is still undefined for most screens

The design system maps dark tokens but notes a full dark theme of every screen is "not yet designed." Dark currently appears only on a few hero screens, so a user who picks "Sombre" in Settings will hit undesigned screens.

**Fix:** design the dark variants for the high-traffic screens first (Home, Lists, List detail, Quiz modes, Settings), then the rest.

---

## What works well

- The waveform motif is a genuinely strong, ownable signature that ties audio, study, streaks, and empty states together.
- Clear, consistent French ↔ Korean color coding (teal = FR, clay = KR) is smart and used coherently in vocab rows and audio previews.
- Good empty states and confirmation dialogs already exist — the flows are complete, not skeletal.
- Restraint with color (accents only, paper kept quiet) gives the calm tone the brief asked for.

---

## Suggested order of fixes

1. **Contrast token pass (#1, #6)** — one set of token edits, fixes accessibility across every screen. Highest impact, lowest effort.
2. **Voice screen mic/retry control (#2)** — pairs with the STT rework you already planned.
3. **Color semantics cleanup (#3, #4)** — resolve clay overloading and the Continuer inconsistency.
4. **Paywall clarity (#5)** — small change, protects revenue and trust.
5. **Polish (#7, #8)** and **dark theme (#9)** as follow-ups.
