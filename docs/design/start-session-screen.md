# Start a session — screen spec

*New screen. The single front door to studying. Replaces launching a quiz from inside a list. Interaction model: **accordion**. Updated 26 June 2026.*

## Purpose & navigation

Studying is separated from list management:

- **Start a session** is reached from the raised clay **center nav button** (the global "start studying" action).
- Home's **À réviser** card **deep-links straight into a session with smart defaults** (a one-tap path that skips this screen for the common "review what's due" case).
- The **Lists** tab is now pure CRUD: Lists screen = create / rename / recolor / delete lists; List detail = browse + add / edit / delete words.
- **Tapping a list no longer starts a quiz** — it opens the list for management only. The old per-list "Start" bottom bar is removed.

## Layout — accordion

Standard back header ("Nouvelle session") on paper + dotted ground. The body is a vertical stack of **collapsible sections**. A pinned bottom bar holds the clay **Commencer** CTA, which shows the resolved word count (e.g. "Commencer · 20 mots").

Accordion behaviour:

- **Only one section is expanded at a time.** Opening a section collapses the others.
- A **collapsed section shows its label on the left and the currently-selected value on the right** — so the stack reads as a running summary of the session as you build it.
- Selecting an option **auto-advances**: the current section collapses (now showing the chosen value) and the next section opens. Any section can be reopened by tapping its header.
- The expanded section shows its options using the unified filled selection style.

### Sections (in order)

1. **Type de session** — `Vocabulaire` (built) / `Grammaire` (shown with a "Bientôt" tag; a future activity type — see the session-as-activities architecture). When built, Grammaire swaps sections 2–5 for grammar-specific ones.

2. **Liste** (when Vocabulaire) — single select. The user's vocab lists, **plus dynamic/smart lists** at the top:
   - **En cours d'apprentissage** — every word the user has already started (FSRS state ≠ `new`), across all lists.
   - **À réviser maintenant** — everything currently due.
   Real lists show a color ring; dynamic lists show an icon chip. Dynamic lists can span language pairs.

3. **Type de quiz** — `Voix` / `Cartes` / `Écrire` / `Mains libres` (the input mode for the vocab activity).

4. **Sens** — **derived from the selected list's language pair**, never hardcoded. A FR↔KR list yields `FR → KR` / `KR → FR` / `Les deux`; an EN↔ES list yields `EN → ES` / `ES → EN` / `Les deux`. A dynamic list spanning pairs shows a single `Sens mixte`.

5. **Nombre de mots** — `10` / `20` / `50` / `100`.

## Component rules

- **One unified selected state for every control**: a solid **filled** treatment (teal fill, or clay for dynamic-list rows) with white text. Not the quieter "border + check" style — filled reads as selected at a glance.
- Section shells: soft frosted container (radius 16), header row = mono eyebrow label + right-aligned value + chevron. Direction and count options are **pills**; type/list/mode options are cards that switch to the filled style when selected.
- CTA uses the primary clay button (subject to the global contrast-token fix — see the design review).

## Key decisions

- Accordion chosen over a plain cascade, a stepper, a quick-start hero, and an editable "recipe" sentence: it keeps everything on one screen, shows a running summary, and the auto-advance gives a guided feel without extra screens.
- Direction must be derived from content, which is why list selection precedes it.
- Activity type leads, so new activity types (grammar) slot in without redesigning the screen.
- "En cours d'apprentissage" is distinct from "À réviser maintenant": started vs due.
- A one-tap quick-start lives on Home's À réviser card, so daily review doesn't require opening this screen.

## Open questions

- Should fully-reviewed lists (0 due) be selectable to study ahead, or disabled?
- May a single session mix language pairs (via a dynamic list), or should it be restricted to one pair?

## Related

- Notion: VocabApp — Tasks → "Build the Start-a-session screen" (implementation) and "Separate start-a-session from list management" (decisions).
- Notion: session-as-activities architecture task (the model behind "Type de session").
