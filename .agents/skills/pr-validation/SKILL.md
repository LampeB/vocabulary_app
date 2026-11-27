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

Correct all Bloquants and Importants together, make one new commit, then begin
a new round. If all four reviewers are clean, do not change code: repeat the
round on the same SHA with fresh agents. Stop after twenty rounds without
convergence and ask for a human decision. A final clean result requires two
consecutive clean rounds for all four reviewers on the same SHA.

## Required convergence status

Publish `PR / Independent agent reviews` on the current PR head SHA using
GitHub commit statuses. Keep it pending until all four reviewers have two
consecutive clean verdicts on that exact SHA. A new commit always starts
pending; never reuse verdicts from a prior SHA or count interrupted runs.
Record the four profiles, iteration counts and final verdicts in the PR body.
Only then publish success. Required CI and an eligible GitHub approval are
separate gates. The validated-PR GitHub Actions bot may formalize the approval
only after checking the owner-attested convergence evidence and required CI
for the exact current SHA. It performs no extra Copilot code review.
