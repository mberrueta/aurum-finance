# Roadmap

Implementation roadmap by milestone. Each milestone maps to a GitHub milestone with implementation issues.

## Status

Phase 1 (research) complete. Phase 2/3 (architecture + product definition) in progress.
Implementation backlog (M1–M7) defined in GitHub issues.

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
Net worth, monthly cashflow, drilldown to postings, projection v1 (recurring detection).

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
