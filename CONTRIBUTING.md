# Contributing to AurumFinance

Thanks for your interest in contributing to **AurumFinance** — an open-source, self-hosted personal finance operating system focused on **correctness**, **auditability**, and **privacy-first data ownership**.

Because this project handles sensitive financial data, contributions should prioritize **clarity, determinism, and security** over speed.

---

## Quick links

* Code of Conduct: `CODE_OF_CONDUCT.md`
* Security reporting: `SECURITY.md`
* ADRs: `docs/adr/`
* Project context: `llms/project_context.md`
* Contributor + agent guidelines: `AGENTS.md`
* Baseline LLM governance: `llms/constitution.md`
* Elixir/Phoenix guidelines: `llms/elixir.md`
* Testing guidelines: `llms/elixir_tests.md`

---

## Before you start

### 1) Discuss first for non-trivial changes

For anything beyond a small fix, please **open an issue first** to align on:

* scope and design direction
* security/privacy implications
* ledger/accounting correctness
* data model and migration strategy

### 2) Use ADRs for architectural decisions

If a change affects architecture, domain modeling, data invariants, or long-term direction, write an ADR.

* Location: `docs/adr/`
* Naming: use zero-padded sequence + short slug, e.g. `docs/adr/0003-import-pipeline.md`

An ADR should include:

* context / problem
* decision
* alternatives considered
* trade-offs
* consequences / follow-ups

---

## What contributions are most valuable

### Domain modeling & ledger correctness

* double-entry invariants
* reconciliation workflows
* multi-currency handling (explicit FX, no hidden conversions)
* multi-entity support (individuals, couples, companies)

### Ingestion & automation

* CSV import formats and normalization
* OFX/QFX parsing
* deduplication strategies
* deterministic categorization rules

### Security & privacy

* threat modeling
* safe defaults for self-hosting
* PII boundaries and redaction strategies (especially for future AI/MCP)

### Tests & reliability

* regression tests for financial edge cases
* deterministic test fixtures
* LiveView interaction tests

### Documentation

* architecture docs
* deployment and ops guidance
* import format research

---

## Development setup

### Prerequisites

* Elixir/Erlang (recommended via ASDF)
* PostgreSQL
* Node.js (for assets)

### Local setup

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

Open: [http://localhost:4000](http://localhost:4000)

### Docker

```bash
docker compose up --build
```

Open: [http://localhost:4000](http://localhost:4000)

---

## Coding standards

Please follow the repository conventions:

* **Elixir/Phoenix/LiveView**: `llms/elixir.md`
* **Testing**: `llms/elixir_tests.md`
* **Project-wide rules** (including security/config hygiene): `llms/constitution.md`

Key expectations:

* Prefer small, explicit, readable functions.
* Treat imports as **evidence**; keep pipelines **idempotent** and reproducible.
* Do not introduce hidden financial transformations.
* Keep boundaries clean: web layer calls contexts; contexts encapsulate DB/side effects.
* Never hardcode secrets/keys; document required env vars for new config.

---

## Quality gates

Before opening a PR, run:

```bash
mix format
mix test
mix credo --strict
```

When you’re done with a set of changes, run the full gate:

```bash
mix precommit
```

PRs should keep `main` releasable and CI-green.

---

## Tests

* All executable logic should come with ExUnit tests.
* Keep tests deterministic (no sleeps / timing assumptions).
* Use the SQL sandbox patterns from `llms/elixir_tests.md`.

---

## Pull request process

1. Fork the repo

2. Create a branch:

   * `fix/<short-description>`
   * `feat/<short-description>`
   * `docs/<short-description>`

3. Make focused changes (small PRs are easier to review)

4. Add/update tests

5. Ensure quality gates pass

6. Open a PR

### PR checklist

Include in the PR description:

* What changed and why
* How to test (commands + expected outcomes)
* Any migrations and how to roll back (if applicable)
* Security/privacy notes (PII, secrets, access patterns)
* Links to issue/ADR (if relevant)

---

## Security

* **Do not** report vulnerabilities via public issues.
* Follow `SECURITY.md` for responsible disclosure.

---

## AI / agent-assisted contributions (optional)

If you use AI agents (Codex/Claude/Gemini), please ensure outputs comply with:

* `llms/constitution.md` (baseline rules)
* `AGENTS.md` (agent workflow and repo-specific constraints)

When in doubt, prefer smaller diffs and explicit reasoning in the PR.

---

## License

By contributing, you agree that your contributions will be licensed under the project’s license (Apache 2.0).
