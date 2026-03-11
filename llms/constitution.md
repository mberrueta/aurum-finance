# AurumFinance Constitution

## Core Principles

### Agent Tooling Restrictions (NON-NEGOTIABLE)

- Agents MUST NOT use git commands that modify the repository state (`git add`, `git commit`, `git stash`, `git revert`, `git push`).
- Agents MUST only propose changes via file edits and leave version control actions to the user.

### Test Discipline & Quality Gates (NON-NEGOTIABLE)

- All changes that touch executable logic MUST include ExUnit tests.
- `mix test` and `mix precommit` MUST pass with zero warnings/errors before merge.
- Tests MUST run under the DB sandbox and be deterministic (no timing or ordering
  dependence).
- For substantive changes, a coverage report via `mix coveralls.html` MUST be
  generated and linked in the PR.
- Debug prints and log noise MUST NOT be committed.

Rationale: Strong testing and zero-warning gating keep the monolith reliable,
enable safe refactoring, and ensure CI readiness.

### Context APIs & Query Patterns

- Context `list_*` functions MUST accept an `opts` keyword list for filtering.
- Core filtering MUST live in a private, multi-clause `filter_query/2` that
  pattern matches on filter keys.
- Complex retrievals SHOULD expose a reusable `list_*_query/1` for composition.
- Functions that can fail MUST return `{:ok, data}` or `{:error, reason}` tuples.
- Web layers MUST call through contexts, not schemas or repos directly.
- Public functions that define important backend or shared-module behavior MUST
  have `@doc` documentation.
- Important public backend/shared functions SHOULD include executable examples in
  their `@doc` blocks when the behavior is non-trivial or reused across
  contexts, so the docs also serve as doctest-style usage guidance.

Rationale: Consistent, composable APIs and queries improve readability,
maintainability, and testability across contexts.

### Coding Style Baselines For Elixir Work

- Any agent changing Elixir production code MUST read
  `llms/coding_styles/elixir.md` before editing.
- Any agent changing Elixir tests MUST read
  `llms/coding_styles/elixir_tests.md` before editing.
- Agents MUST prefer pattern matching in function heads and small helpers over
  simple `if`/`case` branching whenever that keeps the flow flatter.
- Agents SHOULD prefer `with` for linear happy-path flows instead of nested
  `case` chains.
- Tests MUST use factories as the default test-data mechanism and MUST NOT
  introduce fixture-style helpers or `*_fixture` naming.
- Public backend functions added or materially changed MUST include `@doc`
  documentation with executable-style examples when the behavior is non-trivial.

Rationale: Explicit style baselines reduce repeated review churn and keep agent
output aligned with the project's expected Elixir and test conventions.

### Schema Changesets & I18n Validation

- Schemas MUST declare `@required` and `@optional` field lists.
- `changeset/2` MUST `cast(attrs, @required ++ @optional)` and validate with
  those lists.
- All validation messages MUST be internationalized using
  `dgettext("errors", "some_key_no_text")`.
- HEEx templates MUST use `{}` interpolation and `:if`/`:for` attributes and
  MUST NOT use `<% %>` or `<%= %>` blocks.

Rationale: Declarative changesets and localized messages ensure consistent,
translatable validation and predictable UI behavior.

### Security & Configuration Hygiene

- Secrets, salts, keys, and credentials MUST NEVER be hardcoded in source code.
  This includes signing salts, encryption salts, API keys, tokens, and any
  cryptographic material. All such values MUST come from environment variables
  (via `runtime.exs` or direnv), with dev/test defaults clearly labelled
  (e.g., `"dev_only_signing_salt"`). Agents MUST NOT generate random secrets
  and embed them in source files.
- `mix sobelow --config .sobelow-conf` MUST run clean (or with documented
  waivers) prior to merge for security-impacting changes.
- Required external keys (S3/Google/Mailer) MUST be present in appropriate
  environments before enabling related features.
- Data access MUST use Ecto with parameterized queries; logging MUST avoid
  sensitive data.
- PRs that add configuration MUST document required env vars.

Rationale: Protecting secrets and enforcing secure defaults mitigate risk and
accelerate compliant deployments.

### Build Parity & Operational Readiness

- The repo MUST be bootstrappable via `mix setup` and runnable locally via
  `mix phx.server` at http://localhost:4000.
- Assets MUST be built with `mix assets.build` (or `mix assets.deploy`) using
  the appropriate profiles (`admin`, `doctor`, `user`).
- All PRs MUST pass `mix precommit` (format, Credo, Dialyzer, Sobelow, docs).
- Migrations MUST live under `priv/repo/**` with seeds/fixtures placed in the
  documented directories.
- Tests MUST use the provided DB sandbox configuration.

Rationale: Reproducible builds and consistent runbooks reduce onboarding time
and ensure CI/CD parity.

## Project Structure & Tooling

- Source in `lib/`: contexts under `lib/aurum_finance/**`, web layer under
  `lib/aurum_finance_web/**`.
- Tests in `test/**`; mirror source paths.
- Config in `config/*.exs`; secrets via direnv.
- Assets in `assets/` (Tailwind/Esbuild); compiled/static in `priv/static`.
- Data/DB in `priv/repo/**` (migrations, seeds); fixtures in `priv/fixtures`.
- Utilities in `scripts/`; deployment in `flyio/`; container in `Dockerfile`.

Stack and tools

- Elixir/Erlang via ASDF; PostgreSQL 14+; Node.js for assets.
- ExUnit, Mox, ExMachina, ExCoveralls; Sobelow for security; Credo/Dialyzer.

## Development Workflow & Quality Gates

- Development
  - `mix setup` to bootstrap; `mix phx.server` to run locally.
  - Follow Elixir style: 2-space indent; snake_case functions/files; PascalCase
    modules; avoid grouped aliases.
  - HEEx-only templating rules (see Principles).
- Testing
  - Use ExUnit with DB sandbox; group tests with `describe` blocks.
  - Use `Test.Factories.Factory` (e.g., `insert(:user)`).
  - Assert changeset errors via `errors_on(changeset)`.
- Reviews & PRs
  - Commits: small, imperative subject; logically scoped.
  - PRs MUST include summary, linked issues, screenshots (UI), migration notes,
    and a test plan; run `mix precommit` before pushing.
  - Security validation via Sobelow is required for security-impacting changes.
  - Coverage report via `mix coveralls.html` for substantive changes.

## Governance

Authority

- This constitution supersedes other practice documents in case of conflict.

Amendments

- Amendments MUST be proposed via PR updating this file and any affected
  templates. Each amendment MUST include:
  - Rationale, scope, and migration/transition guidance.
  - Version bump per policy below.
  - List of updated artifacts (templates, scripts, docs).
- Approval by maintainers is required; major changes SHOULD be announced to the
  team with an adoption plan.

Compliance & Review

- All PRs MUST state how the change satisfies the relevant MUST rules.
- Exceptions REQUIRE a written waiver in the PR with an expiration date.
- Non-compliant merges MAY be reverted immediately.
- This constitution SHOULD be reviewed at least quarterly.
