# Architecture

High-level system architecture for AurumFinance.

## Status

Draft with baseline direction.

## Core architectural slices

- Ledger core: double-entry postings, invariants, and audit trail.
- Ingestion pipeline: import, normalize, deduplicate, and classify.
- Rules subsystem: grouped rule execution with deterministic per-group priority.
- Reconciliation workflow: statement matching, discrepancy tracking, correction history.
- FX and tax layer: named rate series, fiscal residency defaults, immutable tax snapshots.
- Reporting/projection layer: retrospective analytics and forward projections from actuals.

## Rules subsystem constraints

- Multiple independent groups may fire for the same transaction.
- First matching rule wins inside each group.
- Engine output must be explainable at group/rule/field granularity.
- Manual override markers on classification fields must prevent unintended rule rewrites.

## Data integrity constraints

- Imported facts are immutable and preserved as source evidence.
- Classification is mutable and version-traceable.
- Original currency/amount values are immutable in the ledger.
- Converted values are derived on read from selected rate series and dates.
