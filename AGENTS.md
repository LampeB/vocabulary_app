# VocabKR — operating instructions for agents

## Documentation is the contract

Before proposing, designing, implementing, or reviewing a change, read the
documentation portal at [`docs/README.md`](docs/README.md), then the documents
linked there that match the change. Read [`PROJECT_STATUS.md`](PROJECT_STATUS.md)
first for delivery status and known gaps.

Treat the repository documentation as the source of truth for product,
pedagogy, design, architecture, audio/voice, data rules, tests, and delivery
scope. Do not silently substitute an assumption, a stale mockup, or a previous
conversation for a documented decision.

If a request needs a material decision that is absent, ambiguous, or conflicts
with the documentation:

1. state the gap and ask the user for the decision;
2. do not invent the answer to unblock yourself;
3. after the answer, update the canonical document and `PROJECT_STATUS.md`
   when it changes current delivery state, in the same commit as the work.

For a clearly mechanical task (formatting, a localized bug fix, a test repair),
consult the relevant contract but do not create artificial documentation churn.
Use the documentation exemption only when no product or technical contract is
affected, and say why in the commit body.

## Documentation before every commit

- A versioned pre-commit guard is installed through
  [`tool/install-git-hooks.ps1`](tool/install-git-hooks.ps1). It rejects staged
  application, content, test, CI, or configuration changes without a staged
  documentation update.
- Run `powershell -ExecutionPolicy Bypass -File tool/install-git-hooks.ps1`
  after cloning the repository, before the first commit.
- The guard also checks local Markdown links in staged docs. Do not bypass it
  for substantive work. `DOCS_EXEMPT=1` is reserved for a genuinely mechanical
  change and its reason belongs in the commit body.
- For a product or architecture decision, update its canonical specification,
  not merely a changelog. Keep historical documents marked as historical.

## Source hierarchy

1. `PROJECT_STATUS.md` — what is actually delivered and next.
2. `docs/README.md` — portal to canonical specifications.
3. The matching active specification (for example V3, V0 loop, audio, or
   content contract).
4. Code and tests — evidence of current behavior, used to correct stale docs.
5. Historical plans/audits/mockups — context only; never authoritative alone.
