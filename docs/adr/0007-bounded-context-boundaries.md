# ADR 0007: Bounded Context Boundaries and Elixir Context Structure

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: `llms/tasks/002_architecture_system_design/plan.md` (Step 1, DP-1)

## Context

AurumFinance is a Phoenix/LiveView application whose domain spans ledger
accounting, transaction ingestion, automated classification, FX rate management,
reconciliation, and retrospective reporting. Phase 1 produced five accepted ADRs
(0002-0006) that define the fundamental domain rules. Before any implementation
can begin, the application needs a clear partitioning of these domain concepts
into Elixir contexts — the modules under `lib/aurum_finance/` that own data,
enforce invariants, and expose public APIs.

The goals of this partitioning are:

1. **Cohesion** — entities that share invariants and lifecycle belong together.
2. **Low coupling** — contexts communicate through explicit, narrow APIs; no
   context reaches into another's internals.
3. **Acyclic dependencies** — the dependency graph between contexts has no
   cycles; lower-level contexts never depend on higher-level ones.
4. **Multi-entity scoping** — every context must declare whether its data is
   scoped to an owning entity, or is global/shared.
5. **Alignment with milestones** — context boundaries should map cleanly to
   implementation milestones (M1-M7) so that each milestone can be built
   independently.

### Inputs

- ADR-0002: Internal double-entry ledger with personal-finance UX mapping.
- ADR-0003: Grouped rules engine with per-group priority and explainability.
- ADR-0004: Immutable facts vs mutable classification with manual override protection.
- ADR-0005: Multi-jurisdiction FX with named rate series and immutable tax snapshots.
- ADR-0006: Retrospective + projection posture.
- Product invariants from `llms/project_context.md`.
- Milestone structure from `docs/roadmap.md`.

## Domain Concept Enumeration

Before defining boundaries, every domain concept identified in Phase 1 is listed
with its source ADR or product invariant:

| # | Domain Concept | Source |
|---|---------------|--------|
| 1 | Account (Asset, Liability, Equity, Income, Expense) | ADR-0002 |
| 2 | Account tree / hierarchy | ADR-0002 |
| 3 | Transaction | ADR-0002, ADR-0004 |
| 4 | Posting (debit/credit line) | ADR-0002 |
| 5 | Zero-sum invariant per currency per transaction | ADR-0002 |
| 6 | Currency | ADR-0005 |
| 7 | Immutable transaction facts | ADR-0004 |
| 8 | Mutable classification (category, tags, investment type, notes, splits) | ADR-0004 |
| 9 | Classification provenance (classified_by, manually_overridden) | ADR-0003, ADR-0004 |
| 10 | Rule group | ADR-0003 |
| 11 | Rule (conditions, actions, priority within group) | ADR-0003 |
| 12 | Rule evaluation result / audit log | ADR-0003 |
| 13 | Imported file (uploaded source file + async lifecycle) | ADR-0004, project_context |
| 14 | Imported row (raw parsed line persisted as immutable evidence) | ADR-0004 |
| 15 | Deduplication identity | project_context |
| 16 | FX rate series (currency pair + rate type + jurisdiction) | ADR-0005 |
| 17 | FX rate record (date, value, source) | ADR-0005 |
| 18 | Tax event FX snapshot (immutable) | ADR-0005 |
| 19 | Fiscal residency configuration | ADR-0005 |
| 20 | Reconciliation state (unreconciled, cleared, reconciled) | Phase 1 (GnuCash) |
| 21 | Statement matching / discrepancy | Phase 1 (GnuCash) |
| 22 | Recurring pattern (detected from history) | ADR-0006 |
| 23 | Projection / anomaly detection | ADR-0006 |
| 24 | Entity (legal/fiscal ownership unit) | project_context, roadmap M1 |

## Decision

AurumFinance is partitioned into **seven bounded contexts** organized into three
tiers based on their dependency direction. Each context is an Elixir module
namespace under `lib/aurum_finance/`.

Authentication is **not a context** — it is handled at the edge via a root
password configured through an environment variable. A single plug checks the
secret before any request reaches the domain. There is no users table, no
registration flow, and no session management beyond a signed cookie. Running a
second independent instance (e.g. a second Docker container) is the supported
path for any multi-user scenario.

### Context Overview

```
Tier 0 — Foundation (no domain dependencies)
  AurumFinance.Entities        — Multi-entity ownership model

Tier 1 — Core Domain (depends on Tier 0 only)
  AurumFinance.Ledger          — Accounts, transactions, postings, balances
  AurumFinance.ExchangeRates   — FX rate series, rate records, tax snapshots

Tier 2 — Orchestration (depends on Tier 0 + Tier 1)
  AurumFinance.Classification  — Rules engine, classification layer, audit
  AurumFinance.Ingestion       — Import pipeline, file tracking, deduplication
  AurumFinance.Reconciliation  — Statement matching, reconciliation workflow

Tier 3 — Analytics (depends on Tier 0 + Tier 1 + Tier 2, read-only)
  AurumFinance.Reporting       — Retrospective analysis, projections, anomalies
```

### Dependency Graph

Dependencies flow strictly downward — no context depends on a context in a
higher or same tier (except within the same tier where explicitly noted).

```
                              +----------------+
                              |    Entities     |
                              |    (Tier 0)     |
                              +-------+--------+
                                      |
                    +-----------------+-----------------+
                    |                                   |
           +--------v---------+              +----------v------------+
           |      Ledger      |              |    ExchangeRates      |
           |     (Tier 1)     |              |      (Tier 1)         |
           +--------+---------+              +----------+------------+
                    |                                   |
        +-----------+----------+----------+             |
        |                      |          |             |
+-------v--------+  +---------v------+  +v-------------v--------+
| Classification  |  |   Ingestion    |  |   Reconciliation      |
|    (Tier 2)     |  |    (Tier 2)    |  |      (Tier 2)         |
+-------+---------+  +--------+------+  +----------+------------+
        |                      |                    |
        +----------+-----------+--------------------+
                   |
          +--------v----------+
          |     Reporting     |
          |     (Tier 3)      |
          +-------------------+
```

**Dependency edges (exhaustive list):**

| From (depends on) | To (dependency) | Relationship |
|--------------------|-----------------|--------------|
| Ledger | Entities | Accounts and transactions are entity-scoped |
| ExchangeRates | Entities | Fiscal residency is entity-scoped |
| Classification | Ledger | Rules classify transactions/postings owned by Ledger |
| Classification | Entities | Conditions can reference entity attributes (entity_name, entity_slug, entity_type, entity_country_code) to achieve entity-specific matching; rule groups themselves are global |
| Ingestion | Ledger | Future milestone only: later materialization may create ledger facts from imported evidence |
| Ingestion | Classification | Future milestone only: later review/materialization may invoke classification |
| Ingestion | Entities | Imports target a specific entity |
| Reconciliation | Ledger | Reconciliation operates on postings |
| Reconciliation | Ingestion | Reconciliation matches imported rows to existing postings |
| Reconciliation | Entities | Reconciliation is entity-scoped |
| Reporting | Ledger | Reads postings and balances |
| Reporting | ExchangeRates | Converts amounts using rate series |
| Reporting | Classification | Reads classification data for grouping |
| Reporting | Entities | Reports are entity-scoped (or cross-entity) |

**Note on authentication:** The root password check happens in the Phoenix router
via a plug, before any context is reached. It is not modelled as a context dependency.

**Note on the Ingestion-Classification dependency:** Ingestion depends on
Classification (not the reverse). The pipeline calls Classification APIs to
auto-classify imported data. Classification itself is unaware of import
mechanics — it operates on transactions regardless of how they were created.

### Context Responsibilities and Public API Surface

---

#### `AurumFinance.Entities` (Tier 0)

**Responsibility:** Multi-entity ownership model. An entity represents a
legal/fiscal ownership unit (individual, legal entity, trust, other). Entities are
the tenant boundary for all financial data.

There is no user concept — authentication is a root password check at the edge
(see Authentication section above). A running instance is owned by exactly one
operator. Multiple independent instances (e.g. Docker containers) are the
supported path for physical separation.

**Owns:** Entity (fiscal residency fields are columns on Entity — no separate table)

**Multi-entity scope:** This IS the multi-entity boundary. Entity is the
top-level scoping concept.

**Milestone:** M1

**Conceptual public API:**

```
create_entity(attrs) -> {:ok, Entity} | {:error, changeset}
list_entities() -> [Entity]
get_entity!(id) -> Entity
update_entity(entity, attrs) -> {:ok, Entity} | {:error, changeset}
archive_entity(entity) -> {:ok, Entity}
unarchive_entity(entity) -> {:ok, Entity}
effective_fiscal_residency_country(entity) -> country_code  # fiscal_residency_country_code ?? country_code
```

---

#### `AurumFinance.Ledger` (Tier 1)

**Responsibility:** Core double-entry accounting engine. Owns accounts,
transactions, and postings. Enforces the zero-sum invariant per currency per
transaction. Derives balances from postings. This is the system of record for
all financial positions.

**Owns:** Account, AccountType, Transaction, Posting, Balance (derived)

**Multi-entity scope:** Entity-scoped. Every account and transaction belongs
to exactly one entity. Cross-entity transfers are modeled as two transactions
(one per entity) linked by a correlation ID.

**Milestone:** M1

**Key invariants:**
- Sum of all posting amounts per currency per transaction = 0 (ADR-0002)
- Fact fields on transactions are immutable after creation (ADR-0004)
- Original currency and amount are always preserved (ADR-0005)
- Account types follow the standard hierarchy: Asset, Liability, Equity,
  Income, Expense (ADR-0002)

**Conceptual public API:**

```
# Accounts
create_account(entity, attrs) -> {:ok, Account} | {:error, changeset}
list_accounts(entity, opts) -> [Account]
get_account!(id) -> Account
get_account_tree(entity) -> AccountTree

# Transactions and postings
create_transaction(entity, attrs, posting_lines) -> {:ok, Transaction} | {:error, changeset}
list_transactions(entity, opts) -> [Transaction]
get_transaction!(id) -> Transaction
get_postings_for_transaction(transaction) -> [Posting]
get_postings_for_account(account, opts) -> [Posting]

# Balances
get_account_balance(account, opts) -> Balance
get_net_worth(entity, opts) -> NetWorthSummary
```

---

#### `AurumFinance.ExchangeRates` (Tier 1)

**Responsibility:** FX rate series storage, lookup, and tax event snapshot
management. Owns the concept of named rate series per currency pair per
jurisdiction. Provides rate lookup for a given pair, rate type, and date.
Manages immutable tax event FX snapshots.

**Owns:** RateSeries, RateRecord, TaxRateSnapshot, Currency, FxIngestionBatch

**Multi-entity scope:** Mixed.
- Currencies and rate series definitions are global (shared across entities).
- Rate records (actual rate values) are global.
- Tax rate snapshots are entity-scoped (they reference entity-specific tax events).
- Fiscal residency defaults are resolved via `Entities` context.

**Milestone:** M6 (rate storage), with Currency basics in M1

**Key invariants:**
- Tax rate snapshots are immutable once created (ADR-0005)
- Rate type is a string key, not a hardcoded enum (ADR-0005)
- Rate series support arbitrary jurisdiction/purpose combinations (ADR-0005)

**Conceptual public API:**

```
# Rate series management
create_rate_series(attrs) -> {:ok, RateSeries} | {:error, changeset}
list_rate_series(opts) -> [RateSeries]

# Rate records
insert_rates(rate_series, [rate_attrs]) -> {:ok, count} | {:error, reason}
get_rate(currency_pair, rate_type, date) -> {:ok, RateRecord} | {:error, :not_found}
get_rate_nearest(currency_pair, rate_type, date) -> {:ok, RateRecord} | {:error, :not_found}

# Tax snapshots
create_tax_snapshot(entity, event_ref, rate_attrs) -> {:ok, TaxRateSnapshot} | {:error, changeset}
get_tax_snapshot(event_ref) -> TaxRateSnapshot | nil

# Conversion helper
convert_amount(amount, from_currency, to_currency, rate_type, date) -> {:ok, converted} | {:error, reason}
```

---

#### `AurumFinance.Classification` (Tier 2)

**Responsibility:** Grouped rules engine and mutable classification layer.
Owns rule groups, rules, conditions, and actions. Evaluates rules against
transactions and writes classification fields (category, tags, investment type,
notes, splits). Enforces manual override protection. Records classification
provenance (classified_by, manually_overridden) and audit trail.

**Owns:** RuleGroup, Rule, Condition, Action, ClassificationRecord,
ClassificationAuditLog

**Multi-entity scope:** Mixed. Rule groups and rules are **global** (no
`entity_id` column) — entity-specific matching is achieved through condition
fields (`entity_name`, `entity_slug`, `entity_type`, `entity_country_code`).
Classification records and audit logs are entity-scoped (they are attached to
entity-scoped transactions).

**Milestone:** M3

**Key invariants:**
- Multiple groups can fire for the same transaction (ADR-0003)
- First matching rule wins within a group (ADR-0003)
- Fields with manually_overridden = true are skipped by rule evaluation (ADR-0004)
- Every automated change records group, rule, field, old value, new value (ADR-0003)

**Conceptual public API:**

```
# Rule management
create_rule_group(attrs) -> {:ok, RuleGroup} | {:error, changeset}
list_rule_groups(opts) -> [RuleGroup]
create_rule(rule_group, attrs) -> {:ok, Rule} | {:error, changeset}
reorder_rules(rule_group, ordered_ids) -> :ok | {:error, reason}

# Classification execution
classify_transaction(transaction) -> {:ok, ClassificationResult} | {:error, reason}
classify_transactions(transactions) -> [ClassificationResult]
preview_classification(transactions) -> [ClassificationPreview]

# Classification data
get_classification(transaction) -> Classification | nil
update_classification_manually(transaction, field, value, user) -> {:ok, Classification} | {:error, changeset}
clear_manual_override(transaction, field) -> {:ok, Classification} | {:error, changeset}
get_classification_audit_log(transaction) -> [AuditLogEntry]
```

---

#### `AurumFinance.Ingestion` (Tier 2)

**Responsibility:** Import pipeline from uploaded file to immutable review
evidence. Manages file tracking, CSV parsing, normalization, deduplication,
async processing, and preview/history state. It does not create ledger
transactions or invoke classification in the current milestone.

**Owns:** ImportedFile, ImportedRow, parser boundary, duplicate fingerprints

**Multi-entity scope:** Account-scoped within an entity. Every import targets a
specific account; entity selection is only a UI helper for narrowing accounts.

**Milestone:** M2

**Key invariants:**
- Imported rows are immutable evidence records
- Same file imported twice is allowed; row-level dedupe decides `ready` vs `duplicate`
- The milestone ends at preview/review state, before any ledger materialization

**Conceptual public API:**

```
# File lifecycle
store_imported_file(attrs) -> {:ok, ImportedFile} | {:error, term}
enqueue_import_processing(imported_file) -> {:ok, job} | {:error, term}
parse_imported_file(imported_file) -> {:ok, ParsedImport} | {:error, parse_error}

# History / review
list_imported_files(account_id: account_id) -> [ImportedFile]
get_imported_file!(account_id, imported_file_id) -> ImportedFile
list_imported_rows(account_id: account_id, imported_file_id: imported_file_id) -> [ImportedRow]
```

---

#### `AurumFinance.Reconciliation` (Tier 2)

**Responsibility:** Statement-level reconciliation workflow. Manages
reconciliation state transitions (unreconciled, cleared, reconciled) on
postings. Matches imported rows to existing postings. Tracks discrepancies
and correction history.

**Owns:** ReconciliationState, ReconciliationSession, MatchResult, Discrepancy

**Multi-entity scope:** Entity-scoped. Reconciliation operates on
entity-scoped postings and imports.

**Milestone:** M2

**Key invariants:**
- Reconciliation states follow: unreconciled -> cleared -> reconciled (Phase 1, GnuCash)
- State transitions are audited
- Corrections to reconciled postings reset reconciliation state

**Conceptual public API:**

```
# Reconciliation workflow
start_reconciliation(account, statement_attrs) -> {:ok, ReconciliationSession} | {:error, changeset}
match_postings(session) -> {:ok, [MatchResult]} | {:error, reason}
confirm_match(match_result) -> {:ok, updated_posting} | {:error, reason}
mark_cleared(posting) -> {:ok, Posting} | {:error, reason}
mark_reconciled(session) -> {:ok, ReconciliationSession} | {:error, reason}

# Discrepancy tracking
list_discrepancies(session) -> [Discrepancy]
resolve_discrepancy(discrepancy, resolution) -> {:ok, Discrepancy} | {:error, changeset}

# Reconciliation state queries
get_reconciliation_state(posting) -> ReconciliationState
list_unreconciled_postings(account, opts) -> [Posting]
```

---

#### `AurumFinance.Reporting` (Tier 3)

**Responsibility:** Retrospective analysis, projections, recurring pattern
detection, and anomaly alerts. This is a read-heavy context that queries data
from Ledger, Classification, and ExchangeRates. It does not own any primary
financial data — only derived/computed artifacts like detected recurring
patterns and projection snapshots.

**Owns:** RecurringPattern, Projection, AnomalyAlert

**Multi-entity scope:** Entity-scoped (with optional cross-entity aggregation).

**Milestone:** M4

**Key invariants:**
- Operates entirely on imported and classified data (ADR-0006)
- Projections are always labeled with evidence base (ADR-0006)
- No user configuration required for basic value (ADR-0006)
- Display-currency conversions use ExchangeRates at query time (ADR-0005)

**Conceptual public API:**

```
# Historical analysis
get_cashflow_summary(entity, period, opts) -> CashflowSummary
get_net_worth_history(entity, date_range, opts) -> [NetWorthPoint]
get_category_breakdown(entity, period, opts) -> [CategoryTotal]

# Recurring detection
detect_recurring_patterns(entity) -> [RecurringPattern]
list_recurring_patterns(entity, opts) -> [RecurringPattern]

# Projections
project_next_period(entity, opts) -> Projection
get_expected_vs_actual(entity, period) -> ExpectedVsActual

# Anomalies
detect_anomalies(entity, period) -> [AnomalyAlert]
list_anomalies(entity, opts) -> [AnomalyAlert]
```

---

### Multi-Entity Scoping Summary

| Context | Scoping | Notes |
|---------|---------|-------|
| Entities | N/A (this IS the boundary) | Defines the entity concept itself |
| Ledger | Entity-scoped | Accounts and transactions belong to one entity |
| ExchangeRates | Mixed | Rate series/records are global; tax snapshots are entity-scoped |
| Classification | Mixed | Rule groups and rules are global; classification records and audit logs are entity-scoped |
| Ingestion | Entity-scoped | Imports target a specific entity and account |
| Reconciliation | Entity-scoped | Operates on entity-scoped postings |
| Reporting | Entity-scoped (+ cross-entity) | Per-entity by default; cross-entity aggregation optional |

### Context-to-Milestone Mapping

| Context | Primary Milestone | Notes |
|---------|-------------------|-------|
| Auth (edge plug) | M1 | Root password from env var; no context, no table |
| Entities | M1 | Multi-entity model ships with ledger |
| Ledger | M1 | Core ledger is the foundation |
| ExchangeRates | M1 (Currency basics), M6 (full rates) | Currencies needed from M1; rate series deferred |
| Ingestion | M2 | CSV import with column mapping |
| Classification | M3 | Rules engine |
| Reconciliation | M2 | Reconciliation ships with import |
| Reporting | M4 | Retrospective analysis |

## Rationale

### Why no User/Auth context?

Authentication for a self-hosted single-operator tool does not require a user
model. A root password configured via environment variable — checked at the
Phoenix router edge before any request reaches the domain — is sufficient and
eliminates an entire layer of tables, migrations, and UI flows (registration,
password reset, email confirmation). Anyone needing physical separation runs a
second instance. This keeps the domain model focused entirely on financial data.

### Why seven contexts (not fewer)?

Merging related concepts (e.g., Ingestion + Classification) would create
contexts with mixed responsibilities and tangled invariants. The import pipeline
and the rules engine have different lifecycles, different data ownership, and
different reasons to change. Separating them keeps each context focused on a
single domain responsibility.

### Why seven contexts (not more)?

Further splitting (e.g., separating Currencies from ExchangeRates) would create
contexts too small to be meaningful. A context should own a coherent set of
invariants — splitting below that threshold creates unnecessary API boundaries.

### Why the tier structure?

The tier structure enforces acyclic dependencies by construction. A context in
Tier N can only depend on contexts in Tier 0..N-1. This prevents circular
dependencies without requiring developers to maintain a mental model of the full
dependency graph.

### Why is Classification separate from Ledger?

The ledger owns the double-entry invariants (zero-sum, account types, posting
model). Classification owns the interpretation layer (categories, tags,
investment types). Per ADR-0004, these have fundamentally different mutability
rules — fact fields are immutable; classification fields are mutable. Keeping
them in separate contexts enforces this boundary structurally.

### Why is Reporting a separate context?

Reporting is read-heavy and compute-heavy. It queries multiple contexts but
owns no primary financial data. Separating it prevents reporting concerns
(caching, denormalization, pattern detection algorithms) from leaking into the
core domain contexts.

## Consequences

### Positive

- Each context has a clear, single responsibility with well-defined ownership.
- Dependency direction is explicit and acyclic — no circular dependencies.
- Multi-entity scoping is documented per context; implementors know exactly what
  needs an `entity_id` column.
- Context boundaries align with milestones — M1 builds Tier 0 + Tier 1, M2 adds
  Ingestion + Reconciliation, M3 adds Classification, M4 adds Reporting.
- New features (investments in M5, tax awareness in M6) can be added as new
  contexts or extensions to existing ones without restructuring.

### Negative / Trade-offs

- Seven contexts means seven public API surfaces to maintain.
- Cross-context queries (e.g., Reporting joining Ledger + Classification +
  ExchangeRates) require explicit API composition rather than direct schema joins.
- The multi-entity scoping decision (entity_id column vs schema separation) is
  deferred to ADR-0009 — this ADR only identifies which contexts are entity-scoped.

### Mitigations

- Constitution mandates consistent API patterns (`list_*` with opts, `{:ok, _}`/`{:error, _}` tuples) which reduces the per-context API surface cost.
- Cross-context reads can use shared query composition (e.g., `list_*_query/1`) exposed by lower-tier contexts for upper-tier contexts to join against.
- The tier structure is simple enough to enforce via code review without tooling.

## Implementation Notes

- Authentication lives in `lib/aurum_finance_web/plugs/root_auth.ex` — a single
  plug, no context directory.
- Each context maps to a directory under `lib/aurum_finance/`:
  - `lib/aurum_finance/entities/`
  - `lib/aurum_finance/ledger/`
  - `lib/aurum_finance/exchange_rates/`
  - `lib/aurum_finance/classification/`
  - `lib/aurum_finance/ingestion/`
  - `lib/aurum_finance/reconciliation/`
  - `lib/aurum_finance/reporting/`
- Context modules (e.g., `AurumFinance.Ledger`) serve as the public API facade.
  Internal schemas and helpers are private to the context namespace.
- The web layer (`AurumFinanceWeb`) calls only context-level public APIs, never
  internal schemas or Repo directly (per constitution).
- Cross-context communication uses function calls through the public API — no
  PubSub or message passing is needed at this scale.
- `AurumFinance.Audit` is implemented as a cross-cutting foundation helper used
  by multiple contexts. It is not treated as a standalone bounded context with
  its own product surface.
- Current shipped audit scope is intentionally narrow: entity lifecycle, account
  lifecycle, and transaction void actions. Import/rules/settings/classification
  provenance remains deferred.
