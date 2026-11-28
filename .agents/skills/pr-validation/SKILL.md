---
name: pr-validation
description: Run or coordinate VocabKR pull-request validation when a branch is ready for review, including deterministic checks and four independent read-only reviews. Do not use for ordinary implementation before a reviewable diff exists.
---

# Pull-request validation

Read [the validation specification](../../../docs/pr-validation.md) before
starting. It is the source of truth for reviewer types, finding severities and
the convergence rule.

## Deterministic gate

Run `tool/check-pr-policy.ps1 -BaseRef <base>` before review. The GitHub PR
workflow also runs formatting on changed first-party Dart files, Flutter
analysis, tests with coverage, dependency review, secret scanning and workflow
linting. Do not claim the PR is ready when a mandatory check is red.

## Review round

For one fixed head commit, start one fresh, read-only instance of each project
reviewer:

- `pr_product_contract_reviewer`
- `pr_code_quality_reviewer`
- `pr_correctness_tests_reviewer`
- `pr_security_delivery_reviewer`

Collect every verdict before changing code. Preserve the required finding type:
`Bloquant`, `Important` or `Suggestion`. Deduplicate equivalent findings but
never silently downgrade a Bloquant or Important.

Keep reviewers free to follow unexpected evidence within their broad roles.
Attention points are non-exhaustive and may evolve between rounds. Ask for a
short account of examined areas and limits, not a checklist that implies an
exhaustive review. Freeze instructions during each four-verdict round.

## Correction batch

Assign stable finding IDs and explicit file ownership, then use the
[finding corrector profile](../../../.codex/agents/pr-finding-corrector.toml).
Give correctors the consolidated reports and affected contracts. Require them
to identify the underlying invariant, search sibling cases and shared callers,
and check the effects of their fix before returning the batch. Keep this
investigation proportional to the concrete risk; it does not authorize new
product decisions or unrelated rewrites. Preserve findings, related cases,
fixes, actual validation and remaining limits in the review ledger.

Correct all Bloquants and Importants together, make one new commit, then begin
a new round. If all four reviewers are clean, do not change code: repeat the
round on the same SHA with fresh agents. Count at most twenty rounds per
reviewer in one explicitly numbered cycle. Stop without convergence and ask
for a human decision before starting another cycle. Keep earlier cycles and
their findings visible; do not silently renumber them. A final clean result
requires two consecutive clean rounds in the same cycle for all four reviewers
on the same SHA. The user authorized cycle 2 on 28 November 2026.

## Required convergence status

Publish `PR / Independent agent reviews` on the current PR head SHA using
GitHub commit statuses. Keep it pending until all four reviewers have two
consecutive clean verdicts on that exact SHA. A new commit always starts
pending; never reuse verdicts from a prior SHA or count interrupted runs.
Record the four profiles, iteration counts and final verdicts in the PR body.
Record the cycle as well: version-2 evidence binds its `review_cycle` to each
report's `cycle`, and iterations remain 1–20 within that cycle. Only then
publish success. Required CI and an eligible GitHub approval are
separate gates. The validated-PR GitHub Actions bot may formalize the approval
only after checking the owner-attested convergence evidence and required CI
for the exact current SHA. It performs no extra Copilot code review.
