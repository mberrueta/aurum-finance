<p align="center">
  <img src="priv/static/images/logo.png" alt="AurumFinance Logo" width="200" height="200" />
</p>

# AurumFinance

![Status](https://img.shields.io/badge/status-early--stage-orange)
![Elixir](https://img.shields.io/badge/elixir-1.19%2B-blueviolet)
![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![CI](https://github.com/mberrueta/aurum-finance/actions/workflows/elixir.yml/badge.svg)
![Open Issues](https://img.shields.io/github/issues/mberrueta/aurum-finance)
![Open PRs](https://img.shields.io/github/issues-pr/mberrueta/aurum-finance)

**AurumFinance** is an open-source, self-hosted personal finance operating system for people with complex financial lives.

> One system for all your accounts, entities, currencies, and investments — on your own hardware.

> Not Mint, not YNAB, not a SaaS. AurumFinance is infrastructure for your financial data.

**Project status:** Early-stage. Bootstrapping docs, ADRs, CI, and the first Phoenix app skeleton.

---

## What AurumFinance is for

* **Double-entry ledger** with auditable, traceable financial events
* **Multi-entity support** (individuals, couples/families, companies/LLCs, trusts)
* **Multi-currency** with explicit FX handling (no hidden conversions)
* **Import-first ingestion** (CSV / OFX/QFX / broker statements) + deduplication
* **Rules-first categorization** (deterministic baseline), **AI-assisted** as an optional enhancement
* **Local-first AI** (Ollama planned), external OpenAI-compatible APIs optional
* **Explainable insights** — every number ties back to postings and source evidence
* **Privacy by design** — self-hosted, explicit PII boundaries, scoped access

---

## Why it exists

Most personal finance tools assume: one country, one currency, one person, one bank.

That breaks down if you:

* operate across multiple jurisdictions
* manage finances for multiple people/profiles (self, spouse, dependents)
* have personal + business finances
* invest across brokers, assets, and currencies
* require data ownership, privacy, and auditability

AurumFinance exists to solve that gap.

---

## Design principles

1. **The ledger is the source of truth**
2. **Multi-currency is first-class**
3. **Every financial event is traceable to source evidence**
4. **Automation first; manual correction always possible**
5. **Privacy and least-privilege by default**
6. **Insights must be explainable and reproducible**

---

## Reconciliation philosophy

AurumFinance treats **imports as evidence**, not unquestionable truth:

* **Statements and broker reports** are the authoritative source documents
* The **ledger enforces invariants** — balanced postings, traceability, auditability
* Reconciliation is a first-class workflow: detect differences, explain them, and record corrections without losing the original source

---

## Non-goals

AurumFinance is **not**:

* a trading platform
* a bank aggregation SaaS
* a multi-tenant hosted product
* a tax filing service (it may track tax-relevant events)

---

## Architecture (high level)

> _Architecture and domain model diagrams coming in Phase 1._

Planned core components:

* **Ledger** — double-entry postings, invariants, audit trail
* **Entities & ownership** — individuals + legal entities as first-class domain objects
* **Ingestion pipeline** — imports, normalization, dedup, rule engine
* **Reporting** — cashflow, net worth, allocations, realized/unrealized P&L
* **AI layer (optional)** — categorization, anomaly detection, natural-language queries
* **MCP data access layer (optional)** — scoped permissions, redaction, safe querying

---

## Screenshots

> _Screenshots and demo coming in Phase 1._

---

## Roadmap

### Phase 0 — Bootstrap (now)

* Phoenix project skeleton + core deps
* ADR system + initial architecture docs
* CI pipeline (format / test / lint)
* Minimal Docker Compose for Postgres + app
* Repo hygiene: license, code of conduct, contributing, security policy

### Phase 1 — Core Finance Tracker (MVP)

* Owners/entities (individuals + legal entities)
* Accounts (bank, broker, crypto, cash, credit cards, loans)
* Transactions, postings, categories
* Monthly cash flow report
* Net worth calculation

### Phase 2 — Import Automation

* CSV import
* OFX / QFX import
* Duplicate detection
* Rule-based categorization

### Phase 3 — Investment Tracking

* Positions and price history
* Portfolio value and allocation
* Realized / unrealized P&L

### Phase 4 — AI-Assisted Workflows (optional)

* AI-assisted transaction categorization
* Anomaly detection
* **Chat over your data** — Q&A on transactions, reports, portfolio, and "why did net worth change?"
* **Research ingestion** — attach URLs, emails, or notes as evidence linked to dates, entities, and assets
* **Market/news linking & impact analysis** — relate external signals to holdings (e.g., oil price moves ↔ energy equities)
  * correlation signals over time (with guardrails: correlation ≠ causation)
  * explainable summaries with citations back to ingested sources

### Phase 5 — MCP / AI Data Access Layer (optional)

* Controlled AI access via MCP
* Permission scopes + PII redaction rules
* Local models (Ollama) and optional external providers

### Phase 6 — Tax Awareness

* Tax event tracking (dividends, interest, asset sales, capital gains)
* Yearly summaries and estimates

---

## Tech stack

| Layer | Technology |
|---|---|
| Language | Elixir 1.17+ |
| Web framework | Phoenix + LiveView |
| Database | PostgreSQL |
| Infrastructure | Docker / Docker Compose |
| AI (local) | Ollama (planned / preferred) |
| AI (external) | OpenAI-compatible APIs (optional) |

---

## Quick start

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

Open: [http://localhost:4000](http://localhost:4000)

### Environment setup (`direnv`)

```bash
direnv allow
cp .envrc.custom.example .envrc.custom
```

Use `.envrc.custom` (or `.envrc_custom`) for machine-local overrides.

`tmux_proj.sh` uses `DIR` from your environment when set. If `DIR` is not set, it falls back to the script directory automatically.

Default open-source ports in `.envrc`:
- `MIX_PORT=4000`
- `TIDEWAVE_PORT=4001`
- `LIVE_DEBUGGER_PORT=4002`

Your local `.envrc_custom` can override them with machine-specific values.

### Docker

```bash
docker compose up --build
```

Open: [http://localhost:4000](http://localhost:4000)

---

## CI / quality gates

Automated checks on every push, keeping `main` always releasable:

* `mix format --check-formatted`
* `mix test`
* `mix credo --strict`
* `mix dialyzer` (later)

---

## Data portability & backups

* Structured exports (CSV/JSON) planned for all core entities
* Database migrations are versioned and reversible where possible
* Backups are the user's responsibility by default; recommended strategies will be documented

---

## Documentation layout

```text
/docs
  /adr               # Architecture Decision Records
  architecture.md
  deployment.md
  domain-model.md
  research.md
  roadmap.md
  security.md
  privacy.md
```

---

## Inspirations (not clones)

* [Firefly III](https://github.com/firefly-iii/firefly-iii) — self-hosted personal finance manager
* [GnuCash](https://gnucash.org/) — double-entry accounting system
* [Actual Budget](https://github.com/actualbudget/actual) — local-first budgeting

AurumFinance borrows lessons, not UI or product direction.

---

## Contributing

Before feature PRs, the highest-value contributions are:

* domain modeling and ledger invariants review
* security/privacy threat-model feedback
* import format research (CSV / OFX / QFX / broker statements)
* test fixtures and reconciliation workflows

Planned repo standards:

* `CONTRIBUTING.md` — contribution workflow and dev setup
* `CODE_OF_CONDUCT.md` — community guidelines
* `SECURITY.md` — vulnerability reporting and security posture

---

## Security & privacy

AurumFinance handles highly sensitive data. Core goals:

* self-hosted, local-first operation
* explicit PII boundaries and redaction rules (especially for AI/MCP)
* auditable changes + reconciliation workflows
* secure secret management practices

See `docs/security.md` and `docs/privacy.md` (planned).

---

## License

Apache 2.0 — see [LICENSE](LICENSE).
