# Study redesign — implementation plan

> Branch: `feat/study-redesign` (off `main`). One PR at the end.
> Tracks the Notion **VocabApp — Tasks** redesign tasks. Each numbered step = one
> commit, so the history reads as a clean, reviewable sequence.

## Decisions (locked 2026-06-27)

- **Scope:** full plan, Phases 1–8.
- **Écrire keyboard:** use the **phone's native keyboard** (revised 2026-06-27 —
  custom per-language keyboards don't scale with the generic-language goal; the OS
  keyboard handles every script and follows the system theme).
- **Hands-free wrong answer:** speak/reveal the answer, **hold the orange flood
  ~2.5 s, then auto-advance**. "Pas entendu" auto re-listens up to **2×** before
  requeuing as *à revoir*.
- **Contrast (DESIGN_REVIEW #1, #6):** filled clay ≈ `#A85A30`, filled teal ≈
  `#3E726D` for white-text buttons; darken Faint ≈ `#8A8073`, Muted2 ≈ `#6F695F`
  for text. Keep bright clay/teal for accents, fills, and icons.

## Conventions

- Conventional Commits. One logical step per commit.
- Every commit: compiles, `flutter analyze` clean, relevant `flutter test` green
  (tests use `LD_LIBRARY_PATH="$HOME/.local/lib:…"` for the sqlite3 native lib).
- Co-author trailer on each commit.

## Current state notes

- Theming infra **already exists**: `AppTheme.light/.dark` build brightness-aware
  `ThemeData` from tokens; `themeModeProvider` persists + defaults to
  `ThemeMode.system`; `app.dart` wires `theme`/`darkTheme`/`themeMode`. So the
  theming work is mostly the **per-screen audit** (Phase 7), not the wiring.
- In-progress working-tree diff (a clean partial start — `VkWaveform.flatAtRest`
  + listening-animated quiz waveform) folds into commit 5.
- Only `PROJECT_STATUS.md` was untracked; design specs were committed in
  `21c4ee8`.

## Phases → commits

### Phase 1 — Tokens & theming foundation
1. `fix(theme): WCAG-AA contrast pass on clay/teal CTAs + faint/muted text`
2. `feat(theme): fill light+dark ThemeData gaps + Settings Apparence toggle (Auto/Clair/Sombre)`

### Phase 2 — Study-canvas foundation
3. `refactor(quiz): reusable dark immersive study scaffold (bg + dotted ground + minimal header)`
4. `feat(quiz): word-in-wave centerpiece component`
5. `feat(waveform): VkWaveform per-state speed/amplitude/glow + frozen-mountain rest (+ tests)`
6. `feat(quiz): full-screen feedback overlay (teal/orange flood), generalize _triggerFlash (+ tests)`

### Phases 3–5 — Mode restyles (each builds light + dark)
7. `feat(quiz): restyle Voix onto study canvas (mic + "Voir la réponse"/"Clavier" pills)`
8. `feat(quiz): restyle Cartes (ambient wave, FR/KR flip, teal/orange self-grade)`
9. `feat(quiz): restyle Écrire (word-in-wave + input + native keyboard)`

### Phase 6 — Hands-free
10. `feat(quiz): hands-free word-in-wave screen — state→visual machine, pause, oversized controls`
11. `feat(quiz): hands-free feedback floods + earcons/haptics + "pas entendu" retry loop`

### Phase 7 — App-wide theming completion
12. `refactor(theme): route hard-coded AppColors.* through theme-aware lookups`
13. `feat(theme): dark variants for Home/Lists/Stats/Social/Profile/Settings/Paywall/Onboarding`

### Phase 8 — Start-a-session restructure
14. `refactor(nav): split start-a-session from list management (lists = CRUD only)`
15. `feat(quiz): generalize QuizArgs source (all-due / in-progress / list[s]) + provider queries`
16. `feat(nav): Start-a-session accordion screen + center-nav route + Home quick-start deep link (+ tests)`

## Deferred (tracked, not in this branch)

- **Session-as-activities architecture** epic (open model questions; accordion
  ships Vocabulaire-only with Grammaire disabled).
- **Deep STT rework** (`docs/stt-improvement-plan.md`). Phase 6's "pas entendu"
  loop uses current STT with the retry UI.
