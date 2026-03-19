# 020 - Daily Balance Snapshots

**Status**: READY FOR TECH LEAD REVIEW
**Priority**: P1
**Labels**: type:feature, area:reporting, area:ledger, area:oban
**Implementation Intent**: Deliver the reusable reporting projection foundation only. Do not build final net worth UI in this PR.

---

## Scope Decision

This plan implements the agreed Layer 1 reporting projection only:

- a reusable `daily_balance_snapshots` projection in each account's native currency
- async refresh/rebuild orchestration with Oban
- a minimal authenticated in-app rebuild capability
- the schema and precision changes required to support the projection correctly

This artifact is intentionally distinct from the deferred ledger-side `BalanceSnapshot` cache concept described in earlier ADR work. `DailyBalanceSnapshot` is a reporting projection, not a ledger balance cache, so it intentionally does not mirror fields such as `currency_code` or `posting_count`.

Explicitly out of scope for this PR:

- final net worth pages
- charts and dashboards
- PDF/Excel export
- FX-rendered report outputs
- generalized workflow/pipeline registries
- advanced projection health UI

---

## Project Context

### Related Existing Entities

- `AurumFinance.Ledger.Account`
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Relevant fields today: `id`, `entity_id`, `account_type`, `management_group`, `currency_code`
  - Gap to close in this PR: `timezone` does not exist yet, but the design requires it

- `AurumFinance.Ledger.Transaction`
  - Location: `lib/aurum_finance/ledger/transaction.ex`
  - Relevant fields: `id`, `entity_id`, `date`, `source_type`, `voided_at`
  - `transaction.date` is already the canonical business date and should remain the grouping key

- `AurumFinance.Ledger.Posting`
  - Location: `lib/aurum_finance/ledger/posting.ex`
  - Relevant fields: `transaction_id`, `account_id`, `amount`
  - Gap to close in this PR: migration currently uses unconstrained `:decimal`; the design requires `decimal(20, 4)`

- `AurumFinance.Ledger`
  - Location: `lib/aurum_finance/ledger.ex`
  - Relevant behavior: centralized transaction creation, account queries, balance derivation, and transaction voiding
  - This is the primary trigger boundary for emitting final ledger domain events consumed by reporting refresh orchestration

- `AurumFinance.Ingestion.MaterializationRunner`
  - Location: `lib/aurum_finance/ingestion/materialization_runner.ex`
  - Relevant behavior: imported rows become persisted ledger transactions through `Ledger.create_transaction/1`
  - This means import-created ledger facts can reuse the same snapshot refresh trigger path if ledger event emission is centralized at the final persisted write boundary

### Existing Async Pattern

- Oban is already installed and started in `AurumFinance.Application`
- Existing worker examples:
  - `AurumFinance.Ingestion.ImportWorker`
  - `AurumFinance.Ingestion.MaterializationWorker`
- The reporting refresh flow should follow this existing pattern instead of introducing a new orchestration framework

### Existing UI Surface

- `AurumFinanceWeb.ReportsLive`
  - Location: `lib/aurum_finance_web/live/reports_live.ex`
  - Current state: placeholder/mock reporting screen
  - Best optional minimal surface for this PR: add a narrow internal rebuild control here rather than inventing a new admin namespace

### Naming Conventions Observed

- Contexts are flat and explicit: `AurumFinance.Ledger`, `AurumFinance.Ingestion`, `AurumFinance.Reconciliation`, `AurumFinance.Classification`
- Query APIs use `list_*` with `opts` filters and private `filter_query/2`
- Primary keys use normal UUIDs (`:binary_id`)
- Timestamps use `:utc_datetime_usec`
- Business dates use `:date`
- Async jobs are explicit worker modules under the owning context

---

## Architecture Alignment

### Decision 1: New reporting context

Create a dedicated reporting context:

- `AurumFinance.Reporting`

This keeps read/projection concerns separate from ledger write facts while staying aligned with the existing context layout.

### Decision 2: Single-purpose projection table

Create a specific table and schema:

- table: `daily_balance_snapshots`
- schema: `AurumFinance.Reporting.DailyBalanceSnapshot`

Do not introduce a generalized projection registry or shared snapshot super-table in this PR.

### Decision 3: Start with a direct V1 projection module

Use one explicit implementation module in this PR:

- `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`

Each persisted row still stores `projection_version`, but the first PR does not need a separate resolver module. The reporting context can call `V1` directly until a second projection version actually exists.

### Decision 4: Native-currency base projection only

`daily_balance_snapshots` persists daily balances in the account native currency only.

It must not persist:

- report-specific semantics
- FX conversions
- denormalized account type
- denormalized currency code

Those stay in joins or higher-level read models later.

### Decision 5: Ledger-driven refresh

Refresh remains asynchronous and ledger-driven:

- emit generic ledger domain events on final, effective ledger changes only
- let reporting subscribe and enqueue refresh work from those events
- never compute synchronously inside transaction writes
- always recompute cumulatively from the oldest affected date forward for one account

---

## Data Model Plan

### 1. Schema changes required in this PR

#### A. Add `accounts.timezone`

Why:

- the design requires account-local EOD semantics
- the field is currently missing from both migration and schema

Plan:

- add `timezone :string, null: false` to `accounts`
- backfill existing rows to a deterministic default during migration for compatibility only
- update `AurumFinance.Ledger.Account` changeset and factory to require it
- require new accounts to provide a real account timezone explicitly
- do not derive `accounts.timezone` from `entity`

Open implementation note:

- if there is no already-approved default timezone policy elsewhere in the repo, use a temporary explicit default such as `"Etc/UTC"` for existing rows only
- document explicitly that this backfill is a legacy-data compatibility measure, not final business semantics
- document explicitly that new accounts must carry their real timezone and that `"Etc/UTC"` must not be treated as the conceptually correct account timezone unless it is truly the account's real timezone

#### B. Normalize monetary precision

Apply agreed precision to persistence:

- `postings.amount` -> `decimal(20, 4)`
- `daily_balance_snapshots.closing_balance` -> `decimal(20, 4)`
- `daily_balance_snapshots.daily_delta` -> `decimal(20, 4)`

If FX tables are introduced later, they should use `decimal(20, 8)`, but there is no existing FX schema in the repo today.

### 2. New `daily_balance_snapshots` table

Fields:

- `id` - UUID PK
- `account_id` - FK to `accounts`, not null
- `entity_id` - FK to `entities`, not null, derived from the resolved account during rebuild/write logic rather than trusted from external input; this is intentional denormalization to support fast entity-wide snapshot filtering without joining through `accounts`
- `snapshot_date` - `date`, not null
- `closing_balance` - `decimal(20, 4)`, not null
- `daily_delta` - `decimal(20, 4)`, not null
- `computed_at` - `utc_datetime_usec`, not null
- `projection_version` - integer, not null
- `inserted_at` / `updated_at` - `utc_datetime_usec`

Indexes:

- unique `[:account_id, :snapshot_date]`
- index `[:entity_id, :snapshot_date]`
- index `[:snapshot_date]`

Do not add `account_type` or `currency_code` columns.

---

## Projection Semantics

### Included ledger facts

Only final, balance-effective ledger facts feed the projection:

- persisted ledger transactions
- import-created ledger transactions once committed
- correction/replacement transactions through their new valid facts

Excluded:

- drafts
- previews
- pending states

Voided transactions are not filtered out with `transaction.voided_at IS NULL`.
The existing ledger model marks the original transaction as voided and inserts an equal-and-opposite reversal transaction on the same business date. Snapshot derivation should therefore match `Ledger.get_account_balance/2` semantics and sum all persisted postings so the original and reversal net to zero naturally.

### Series rules

For one account:

1. Find the first effective `transaction.date` touching the account.
2. Aggregate posting deltas by `transaction.date`.
3. Generate one row per calendar day from that first date through the last date with data.
4. Carry `closing_balance` forward across gap days.
5. Store `daily_delta = 0` on gap days.
6. Stop at the last effective business date; do not auto-fill to today.

### Query basis

The snapshot builder should derive daily movement from:

- postings joined to transactions and accounts
- `transaction.date` as the grouping key
- all persisted postings, including voided originals and their system reversals, so net-zero void behavior matches ledger balance derivation

No runtime timestamp grouping belongs in this logic.

---

## Proposed Modules

### Core reporting context

- `lib/aurum_finance/reporting.ex`
  - public API for list/get/rebuild/enqueue operations

### Projection schema

- `lib/aurum_finance/reporting/daily_balance_snapshot.ex`

### Versioned implementation

- `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
  - account daily delta aggregation
  - range discovery
  - series generation
  - idempotent replace/upsert strategy for recomputed range

### Refresh orchestrator

- `lib/aurum_finance/reporting/daily_balance_snapshot_refresher.ex`
  - enqueue rules
  - refresh execution entry points
  - oldest-known `from_date` merge logic

### Oban worker

- `lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`
  - unique by `account_id`
  - ~10 minute debounce/schedule window
  - job args include `account_id` and `from_date`

### Optional internal rebuild helper

- `lib/aurum_finance/reporting/daily_balance_snapshot_rebuild_request.ex`

This helper is optional if the rebuild API stays small inside `AurumFinance.Reporting`, but the job-building and request-validation logic should stay out of the LiveView.

---

## Context API Shape

Suggested public API:

- `list_daily_balance_snapshots(opts)`
  - filters: `account_id`, `entity_id`, `date_from`, `date_to`

- `list_daily_balance_snapshots_query(opts)`
  - composable query for later reports

- `enqueue_daily_balance_snapshot_refresh(account_id, from_date, opts \\ [])`
  - enqueues/merges async rebuild request

- `refresh_daily_balance_snapshots(account_id, from_date, opts \\ [])`
  - synchronous internal execution path used by the worker and manual rebuild flow

- `rebuild_daily_balance_snapshots(account_id, opts \\ [])`
  - manual/internal entry point with optional `from_date`

- `earliest_snapshot_date_for_account(account_id)`
  - useful for debugging and rebuild decisions

- `latest_snapshot_date_for_account(account_id)`

Internal helpers should include:

- `effective_movement_query/2`
- `first_effective_date_for_account/1`
- `last_effective_date_for_account/1`
- `replace_snapshot_range/4`

---

## Refresh and Rebuild Design

### Trigger points

Minimum trigger set for this PR:

1. `Ledger.create_transaction/1` emits a post-commit ledger domain event after a successful persisted transaction
2. `Ledger.void_transaction/2` emits a post-commit ledger domain event after a successful void/reversal flow
3. any future correction/replacement path that persists new final ledger transactions through `Ledger` should emit the same family of ledger events

Because import materialization already routes through `Ledger.create_transaction/1`, imports should inherit refresh triggering automatically if ledger event emission is centralized there.

Architecture note:

- do not call `AurumFinance.Reporting` directly from `AurumFinance.Ledger`
- `Ledger` is a lower-tier context and should only emit neutral domain events
- `Reporting` owns the subscriber/bridge that translates those events into refresh enqueue requests
- PubSub is an acceptable transport for this PR; durable delivery is a follow-up concern, not a reason to add an upward context dependency now

### Job behavior

Worker characteristics:

- queue: reporting-specific queue such as `:reporting`
- unique job grouping based on `account_id`
- scheduled/debounced by about 10 minutes
- when another refresh is requested for the same account before execution, preserve the oldest `from_date`

Implementation note:

- the job should receive `account_id` and `from_date`
- the enqueue path should prefer the oldest known `from_date`
- keep the implementation intentionally simple
- implementation may choose a minimal merge approach
- detailed merge/inspection behavior is an implementation choice for this PR and should not introduce a new framework or extra operational state tables

### Refresh algorithm

For a requested `(account_id, from_date)`:

1. Resolve the account and `entity_id`.
2. Resolve the account’s first and last effective dates from ledger facts.
3. If no effective transactions exist, delete any stale snapshots for that account and finish.
4. Compute `effective_from_date = max(first_effective_date, requested_from_date)` only when `requested_from_date` is later than bootstrap start; otherwise rebuild from first effective date.
5. Load effective daily deltas from `effective_from_date` through last effective date.
6. Load the prior closing balance immediately before `effective_from_date` when needed.
7. Regenerate the full day-by-day series through last effective date.
8. Replace the recomputed date range transactionally.

### Replace strategy

This PR intentionally prefers full forward-range replacement over partial diffing.

Use this explicit replacement strategy:

- delete rows for `account_id` where `snapshot_date >= effective_from_date`
- bulk insert regenerated rows for the recomputed range

This is the intended design for this PR because recompute is forward-cumulative per account and this approach keeps the rebuild path simple, durable, and easy to audit.

Do not optimize prematurely with partial in-place diffing in this PR.

---

## Minimal Manual Rebuild Capability

Use the existing authenticated app surface, not a new admin framework.

Recommended minimal scope:

- add a technical rebuild card to `AurumFinanceWeb.ReportsLive`
- allow rebuild by `account_id`
- allow optional `from_date`
- submit by calling `AurumFinance.Reporting.enqueue_daily_balance_snapshot_refresh/3`
- show success/error flash only; no advanced job status UI

This is a useful in-app maintenance surface, but it is secondary to the actual core projection work.

The core of this PR is:

- schema and precision changes
- reporting projection schema and initial V1 module
- snapshot rebuild engine
- async worker/orchestration
- ledger-triggered refresh
- test coverage

The minimal rebuild UI in `ReportsLive` should be included only if it fits cleanly without expanding scope or delaying the core foundation.

If the LiveView budget becomes too wide, the fallback is a thin authenticated POST/controller action. The primary recommendation remains `ReportsLive` because the route already exists and is clearly internal today.

---

## Task Breakdown

### Task 01: Schema foundation migration

- add `accounts.timezone`
- alter `postings.amount` precision to `decimal(20, 4)`
- create `daily_balance_snapshots`
- add required indexes and constraints

### Task 02: Account schema and factories alignment

- update `AurumFinance.Ledger.Account` schema/changeset/docs for `timezone`
- require explicit timezone on new account creation paths
- do not allow timezone defaulting from entity-level data
- update `test/support/factory.ex`
- adjust any account-related tests that assume no timezone

### Task 03: Reporting schema and projection module

- add `AurumFinance.Reporting.DailyBalanceSnapshot`
- add versioned `V1` module skeleton

### Task 04: Snapshot rebuild engine

- implement effective movement query
- implement bootstrap/range discovery
- implement day-by-day carry-forward generation
- implement transactional range replacement

### Task 05: Reporting context API

- add list/query functions
- add rebuild and refresh entry points
- keep APIs account-scoped and composable

### Task 06: Oban refresh worker

- add worker module
- add job builder with account uniqueness and scheduled debounce
- add enqueue path that prefers the oldest known `from_date`

### Task 07: Ledger trigger integration

- emit ledger domain events after successful `create_transaction`
- emit ledger domain events after successful `void_transaction`
- add a reporting-owned subscriber/bridge that converts those events into per-account refresh enqueue requests
- keep event emission outside write-model facts but close enough to remain reliable

### Task 08: Tests and validation

- schema tests
- projection engine tests
- enqueue/worker tests
- trigger integration tests
- if Task 09 is implemented, add a minimal LiveView test for rebuild control

### Task 09: Minimal authenticated rebuild UI

- optional scope: add narrow rebuild form/action on `ReportsLive`
- no charts, no final report rendering
- do this only if it lands cleanly after the core projection foundation is complete

### Task 10: Final verification

- run targeted tests first
- run `mix precommit`
- fix any warnings/issues before handoff

---

## Test Strategy

### Migration and schema coverage

- `accounts.timezone` required in changeset
- existing account factory paths still produce valid records
- `daily_balance_snapshots` uniqueness/index-backed constraints behave as expected

### Projection engine coverage

1. bootstrap from first movement date only
2. generate one row per calendar day through last effective date
3. carry closing balance across gap days
4. compute `daily_delta = 0` on no-movement days
5. projection covers all accounts regardless of account type
6. report-specific filtering belongs in upper reporting layers, not in the base projection
7. preserve ledger-consistent void semantics by summing all persisted postings so voided originals and their reversals net to zero
8. rebuild from an older `from_date` and replace all forward rows
9. delete stale rows when an account no longer has effective transactions

### Precision coverage

- Decimal values persist and read back with expected scale
- no float conversions in projection logic

### Worker/enqueue coverage

- unique job scoping is per `account_id`
- enqueue requests prefer the oldest known `from_date`
- worker executes rebuild and returns clean success/failure semantics

### Trigger coverage

- successful ledger transaction creation emits one ledger event covering all affected accounts
- successful void emits one ledger event covering all affected accounts from the transaction date
- reporting subscriber/bridge enqueues one snapshot refresh per affected account from the emitted event payload

### LiveView coverage

- authenticated rebuild control is present on `/reports`
- submit path enqueues rebuild and shows user feedback

---

## Risks and Design Notes

### Risk 1: Multi-account transactions

One transaction may touch multiple accounts, including different account types. Ledger event payloads and reporting subscriber logic must preserve all affected `account_id` values, not collapse them to one account.

### Risk 2: Forward-cumulative recompute correctness

Because balances are cumulative, any affected older date invalidates all later snapshots for that account. The implementation must always replace the full forward range from `from_date`.

### Risk 3: Timezone semantics vs grouping semantics

`accounts.timezone` is required for future local-EOD meaning, but grouping still uses `transaction.date`. The plan must not accidentally start grouping by UTC timestamps.

### Risk 4: Precision backfill

Altering existing `postings.amount` precision needs a migration that is safe for current data. This should be treated as a deliberate data-shape normalization, not an incidental change.

### Risk 5: Oban uniqueness details

The implementation should preserve the simple agreed behavior of preferring the oldest known `from_date` per account without introducing generalized workflow machinery.

---

## Out of Scope Follow-ups

These should remain follow-up work, not PR scope:

1. Net worth report rendering on top of the projection
2. FX-converted reporting outputs
3. Dashboard widgets and charts using snapshot series
4. Projection health/staleness states beyond `computed_at` and `projection_version`
5. Shared workflow/pipeline tracking framework across imports, classification, and reporting
6. Rich admin UI for projection backfills and job inspection
7. Performance optimizations beyond the simple per-account forward rebuild

---

## Involved Roles

Recommended implementation roles:

- `po-analyst`
  - keep scope boundaries explicit and prevent report-layer creep

- `dev-backend-elixir-engineer`
  - migrations, reporting context, projection engine, worker, ledger event bridge, tests

- `dev-frontend-ui-engineer`
  - minimal rebuild control in `ReportsLive`

- `qa-elixir-test-author`
  - deterministic projection/worker/LiveView coverage review

---

## Summary

This PR should create a narrow but durable reporting foundation:

- one reusable native-currency daily balance projection
- one explicit versioned projection implementation
- one async Oban-driven refresh path with per-account debounce
- one minimal authenticated rebuild control

It should not attempt to deliver the actual report product surface yet. The success criterion is a correct, auditable, reusable base projection that later reporting features can depend on.
