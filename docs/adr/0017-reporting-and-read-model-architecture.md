# ADR 0017: Reporting and Read Model Architecture

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: Architecture consolidation follow-up (post Steps 1-10 baseline)

## Context

The ledger is optimized for correctness, traceability, and event integrity.
Reporting workloads require fast aggregations, dimensional slicing, and
historical comparisons that are expensive to run directly on raw posting data
for every query.

This ADR defines a reporting architecture based on read models/projections that
are derived from immutable ledger facts while preserving auditability.

### Inputs

- ADR-0002 / ADR-0008: Ledger correctness and posting model.
- ADR-0004: Fact/overlay separation.
- ADR-0006: Retrospective + projection product posture.
- ADR-0011: Classification metadata and explainability.
- ADR-0012: FX lookup semantics for conversion-aware reporting.
- ADR-0014: Canonical financial model.

## Decision Drivers

1. Reporting must not compromise ledger integrity.
2. Interactive analytics require pre-aggregated/optimized read paths.
3. Reports must remain explainable back to source transactions/postings.
4. FX-aware reports require deterministic conversion policy handling.
5. Projection features must clearly separate historical actuals from forecasts.

## Decision

### 1. Read Model Pattern

Reporting uses explicit read models/projections, derived from ledger and
classification data:

- account balance timelines,
- category/month aggregates,
- cashflow summaries,
- net worth snapshots,
- portfolio valuation snapshots.

These are derived artifacts and never become authoritative accounting facts.

### 2. Projection Pipeline

A projection pipeline consumes fact changes and updates read models:

1. detect relevant fact changes,
2. recompute affected aggregates incrementally when possible,
3. fallback to bounded recomputation when needed,
4. stamp projection version/as-of metadata.

Projection lag is acceptable as long as staleness is visible to callers.

Trigger model is **asynchronous jobs** (queue/worker based) as the default
projection update mechanism. Synchronous-on-write projection updates are out of
scope for core reporting paths. Batch rebuild jobs remain supported for
backfills, recovery, and projection-version migrations.

### 3. Query Strategy

Reporting queries read from projection tables/views first. Drilldown paths
retain linkage to underlying transaction/posting identifiers for explainability.

Explainability contract:
- Every report row MUST be traceable to one or more transaction/posting IDs, or
  to a documented derivation rule when the row is aggregate/synthetic.

Direct ledger scans are reserved for:
- audit/verification queries,
- projection rebuild workflows,
- low-frequency administrative diagnostics.

### 4. FX and Multi-entity Semantics

Reporting requests must specify:
- entity scope (single entity or explicit cross-entity set),
- report currency,
- rate type/jurisdiction policy,
- as-of date/time and lookup strategy.

Conversion metadata is included in outputs so users can reproduce results.

### 5. Projection Classes

Two projection classes are defined:

1. **Historical projections** (actuals):
   built only from immutable facts + accepted overlays.
2. **Forecast projections** (forward-looking):
   explicitly tagged as modeled outputs, never mixed silently with actuals.

## Rationale

This architecture gives reporting the performance and dimensional flexibility it
needs while preserving the ledger's role as source of truth.

It also makes stale/missing conversion assumptions explicit, avoiding silent
analytics drift in multi-currency scenarios.

### Architectural Pattern

This architecture follows a CQRS-style separation between the ledger write
model and reporting read models.

The ledger (`transactions`/`postings`) remains optimized for correctness and
auditability, while reporting projections provide optimized read paths for
analytics workloads.

This prevents reporting concerns from leaking into the financial fact model and
allows reporting logic to evolve independently from the accounting core.

### Anti-patterns avoided

This design explicitly avoids:

- **Leaking reporting concerns into ledger facts**, such as storing cached
  balances, reporting buckets, or FX-converted amounts on
  `transactions/postings`.
- **Slow interactive dashboards caused by repeated full-ledger scans** for
  common aggregations (cashflow, net worth, category totals).
- **Inconsistent numbers across screens** caused by each report implementing
  its own ad-hoc query logic.
- **Silent FX drift** where reports use implicit or undocumented conversion
  policies, making results non-reproducible.
- **"Fixing reports by mutating facts"**, which breaks auditability and
  immutable ledger guarantees.

## Consequences

### Positive

- Faster analytics workloads without mutating core facts.
- Clear separation between accounting truth and reporting convenience.
- Explainable report outputs with drilldown traceability.
- Supports future forecasting/anomaly features in a controlled way.

### Negative / Trade-offs

- Additional projection maintenance complexity.
- Potential projection lag/staleness windows.
- Rebuild strategies are needed for schema/logic evolution.

### Mitigations

- Include projection version + computed-at metadata in responses.
- Provide deterministic rebuild tooling from ledger facts.
- Keep report APIs explicit about FX and scope parameters.

## Implementation Notes

- Maintain projection tables/materialized views as derived stores.
- Keep projection update logic idempotent and replay-safe.
- Preserve source identifiers in read models for drilldown.
- Distinguish forecast datasets from historical actuals at schema/API level.
