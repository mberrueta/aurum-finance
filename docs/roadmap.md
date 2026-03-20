# Roadmap

Implementation roadmap by milestone. Each milestone maps to a GitHub milestone with implementation issues.

## Status

Phase 1 (research) complete. Phase 2/3 (architecture + product definition) in progress.
Implementation backlog (M1–M7) defined in GitHub issues. Reporting now has its
first real user-facing read path via the `/reports` hub and `/reports/net-worth`
page backed by `daily_balance_snapshots`.

## Milestones

### M1 — Core Ledger
Double-entry engine, multi-entity support, accounts, currencies, basic ledger UI.
Includes single-user auth (root password guard — self-hosted, no anonymous access).

### M2 — Import Pipeline
Account-scoped CSV ingestion with `imported_files` / `imported_rows`, async processing via background job, PubSub-driven preview/history UI, and immutable evidence persistence. This milestone is preview-only and does not create ledger transactions, postings, or classification outcomes.

### M3 — Rules Engine
Transaction categorization rules (grouped, prioritized, explainable).
Classification layer is mutable; ledger facts are immutable.

### M4 — Reporting
Delivered in V1:
- real `/reports` hub with coarse freshness and async refresh
- real `/reports/net-worth` page
- native-currency Net Worth read model backed by `daily_balance_snapshots`
- latest-snapshot-on-or-before semantics with `exact`, `carried_forward`,
  `refreshable_gap`, and `no_history` coverage states

Still planned within Reporting follow-up work:
- monthly cashflow
- drilldown to postings
- projection v1 recurring detection and broader report surfaces

### M5 — Investments
Instruments, holdings, position snapshots, portfolio allocation, P&L realized/unrealized.

### M6 — Tax Awareness
Fiscal residency config, FX rate history (immutable snapshots), tax event tracking.

### M7 — AI + MCP (last, optional)
AI categorization, insight generation, MCP data access layer.
**Not before M5/M6 are complete.**

## Cross-milestone non-negotiables

- Preserve ledger correctness and traceability at all times.
- Imports are immutable facts; classification is a mutable overlay — never conflate them.
- Rules are grouped and prioritized; outcomes must be explainable per transaction.
- Product posture is retrospective/projection-based, not envelope budgeting.
- Multi-jurisdiction and multi-rate FX are first-class from early design.
- All historical calculations use stored FX rates — never live rates for past dates.
- AI/MCP is the last implementation wave, after core finance workflows exist.
