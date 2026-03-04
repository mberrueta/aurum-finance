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
* **Multi-currency with named FX rate series** — e.g., PTAX, oficial, MEP, CCL — per jurisdiction, not a single hidden conversion
* **Fiscal residency aware** — tax-relevant rates and reporting rules follow your country of residence, not where your accounts are
* **Import-first ingestion** (CSV / OFX/QFX / broker statements) + deduplication
* **Immutable facts, correctable classification** — imported data is never modified; categorization is always editable
* **Grouped rules engine** — independent rule groups (expense type, account origin, investment type, etc.) each apply their own priority-ordered logic; multiple groups can match the same transaction simultaneously
* **Retrospective analysis + automatic projection** — learn patterns from actuals; detect recurring income and expenses automatically; project next month without asking the user to pre-assign anything
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

### The problem is especially acute in LATAM

A common real-world scenario that no existing tool handles well:

> *Living in Brazil, with bank accounts in Argentina and the US, investments
> across brokers in all three countries, and tax obligations to Receita Federal
> (Brazil), AFIP/ARCA (Argentina), and the IRS (US).*

Each jurisdiction has its own rules, currencies, and exchange rate conventions:

| Country | Tax authority | FX reference rate | Complexity |
|---|---|---|---|
| 🇧🇷 Brazil | Receita Federal | PTAX (Banco Central do Brasil) | IOF, GCAP, carnê-leão |
| 🇦🇷 Argentina | AFIP / ARCA | Tipo de cambio oficial | Multiple parallel rates (MEP, CCL, blue) |
| 🇺🇸 USA | IRS | N/A (USD base) | FBAR, FATCA for foreign accounts |

AurumFinance is built first for this complexity — and designed so that
**any user can extend it to their own country and jurisdictional needs**.

The system lets each user configure:
* their **country of fiscal residency** (drives tax-relevant rate defaults and reporting)
* which **exchange rate series** to use per jurisdiction (e.g., PTAX for Brazil, oficial for Argentina)
* accounts and brokers in any country, held in any currency

AurumFinance exists to solve that gap — starting from the hardest cases, not the easiest.

---

## Design principles

1. **The ledger is the source of truth**
2. **Multi-currency is first-class** — N named rate series per pair, not a single conversion
3. **Every financial event is traceable to source evidence**
4. **Imported facts are immutable; classification is always correctable**
5. **Automation first; manual correction always possible**
6. **Privacy and least-privilege by default**
7. **Insights come from actuals, not from spending intentions**
8. **Fiscal residency is explicit** — tax-relevant rates and reporting rules are jurisdiction-aware
9. **Extensible by design** — country rules, rate sources, and tax models are configurable, not hardcoded

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
* a tax filing service (it may track tax-relevant events and estimates)
* an envelope/zero-sum budgeting tool — AurumFinance learns from your actuals, not from spending intentions

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

### Phase 1 — Research & Landscape Analysis

* Comparative analysis: Firefly III, GnuCash, Actual Budget
* Rules-engine and ledger-model validation for AurumFinance direction
* Multi-jurisdiction + FX model research and constraints capture
* Design lessons and architecture implications documentation

### Phase 2 — Import Automation (first implementation feature)

* CSV import
* OFX / QFX import
* Duplicate detection
* Grouped rule-based categorization (triggers → conditions → actions, per group)

### Phase 3 — Core Finance Tracker (MVP)

* Owners/entities (individuals + legal entities)
* Accounts (bank, broker, crypto, cash, credit cards, loans)
* Transactions, postings, categories
* Monthly cash flow report
* Net worth calculation
* Recurring income/expense detection (automatic, from actuals)
* Next-month projection based on historical patterns

### Phase 4 — Investment Tracking

* Positions and price history
* Portfolio value and allocation
* Realized / unrealized P&L

### Phase 5 — Multi-Jurisdiction Tax Awareness

* User-configurable fiscal residency (Brazil / Argentina / USA / extensible)
* Named FX rate series per jurisdiction (PTAX, oficial AFIP/ARCA, MEP, CCL, IRS rates)
* Tax event tracking (dividends, interest, asset sales, capital gains, FX gains)
* Tax-relevant rate snapshots at event time (immutable)
* Yearly summaries and estimates per jurisdiction

### Phase 6 — AI-Assisted Workflows (optional, late-stage)

* AI-assisted transaction categorization
* Anomaly detection
* **Chat over your data** — Q&A on transactions, reports, portfolio, and "why did net worth change?"
* **Research ingestion** — attach URLs, emails, or notes as evidence linked to dates, entities, and assets
* **Market/news linking & impact analysis** — relate external signals to holdings (e.g., oil price moves ↔ energy equities)
  * correlation signals over time (with guardrails: correlation ≠ causation)
  * explainable summaries with citations back to ingested sources

### Phase 7 — MCP / AI Data Access Layer (last feature, optional)

* Controlled AI access via MCP
* Permission scopes + PII redaction rules
* Local models (Ollama) and optional external providers

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

### Key differences

| Capability | Firefly III | GnuCash | Actual Budget | AurumFinance |
|---|---|---|---|---|
| Primary orientation | Self-hosted personal finance manager | Desktop accounting system | Local-first budgeting app | ✅ Personal finance OS for complex multi-country setups |
| Ledger model | Double-entry under the hood | Explicit double-entry | ❌ | ✅ Internal double-entry with simpler user-facing flows |
| Rules/classification | Rules engine | Limited automation | Limited automation | ✅ Grouped rules; multiple groups can classify one transaction |
| Import posture | Importer ecosystem available | Strong file import support | Import supported | ✅ Import-first pipeline (CSV/OFX/QFX/broker statements) |
| Facts vs classification | Mixed in app workflows | Accounting records are authoritative | Budget-category centered | ✅ Explicit split: immutable facts + mutable classification |
| Manual override safety | Depends on workflow | Manual accounting edits | Manual category edits | ✅ User overrides protected from rule re-run overwrite |
| Budgeting philosophy | Personal finance + budgets | Accounting-centric | Envelope / zero-sum | ✅ Retrospective + projection (no pre-assignment required) |
| Multi-currency | Supported | Strong support | ❌ | ✅ First-class with named FX series per pair |
| Multi-jurisdiction tax posture | ❌ | ❌ | ❌ | ✅ Fiscal-residency aware defaults and tax behavior |
| Tax FX snapshots | ❌ | ❌ | ❌ | ✅ Immutable tax-rate snapshot at event time |
| Multi-entity support | Limited | Separate books | Limited | ✅ Planned first-class entities (person/family/company/trust) |
| AI/MCP direction | ❌ | ❌ | ❌ | ✅ Optional final phase with scoped, privacy-safe access |

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
