# Nightly E2E

The nightly dispatcher runs at 22:17 Asia/Seoul (13:17 UTC) from `main`.
It dispatches `e2e.yml` on `feat/multi-language-learning`, where the maintained
nine-suite test runner and per-scenario reset live. This keeps development
changes separate from `main`. Update the ref when the maintained branch changes.

The child workflow defaults to all suites and serializes runs using the
`supabase-e2e-account` concurrency group. A successful dispatch is not a
successful E2E run: inspect the subsequent **E2E (emulator)** run for results.
Avoid manually running the old E2E implementation on `main`; it does not share
this isolation contract. Do not run local E2E tests while CI uses the account.

Before the first run, apply migration `008_e2e_reset.sql` from the maintained
branch and enroll the dedicated account in `e2e_private.accounts` using that
branch's `docs/runbooks/e2e-account.md`. Existing repository secrets are used:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TEST_EMAIL`, `TEST_PASSWORD`.
No administrator credential is embedded in the app or this dispatcher.

Public-repository schedules can be disabled after 60 days without repository
activity. The routine provides useful database traffic but cannot guarantee
that Supabase will never pause a Free project.

Sources: [GitHub schedules](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
[Supabase pausing](https://supabase.com/docs/guides/platform/free-project-pausing).
