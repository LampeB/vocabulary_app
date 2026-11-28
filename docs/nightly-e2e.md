# Nightly E2E

The nightly dispatcher runs at 22:17 Asia/Seoul (13:17 UTC) from `main`.
After this integration is merged, it dispatches `e2e.yml` on `main`, where the
maintained nine-suite runner and per-scenario reset now live. The dispatcher
must validate the integrated application rather than the retired feature ref.
The dispatch job only runs from `main`; selecting the integration branch does
not dispatch the older runner before the merge.

The child workflow defaults to all suites and serializes runs using the
`supabase-e2e-account` concurrency group. A successful dispatch is not a
successful E2E run: inspect the subsequent **E2E (emulator)** run for results.
Do not run the same scenario locally while CI uses its permanent account.

Before the first run, apply the pending production migrations and enroll the
distinct scenario accounts using [the E2E account runbook](runbooks/e2e-account.md).
The `patrol-e2e` environment limits its `E2E_ACCOUNTS_JSON` secret to `main`.
Each build embeds only the credentials for its selected Patrol target.
`SUPABASE_URL` and `SUPABASE_ANON_KEY` remain repository secrets for Android CI.
The integration itself neither applies hosted migrations nor dispatches a run.
No administrator credential is embedded in the app or this dispatcher.

Public-repository schedules can be disabled after 60 days without repository
activity. The routine provides useful database traffic but cannot guarantee
that Supabase will never pause a Free project.

Sources: [GitHub schedules](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
[Supabase pausing](https://supabase.com/docs/guides/platform/free-project-pausing).
