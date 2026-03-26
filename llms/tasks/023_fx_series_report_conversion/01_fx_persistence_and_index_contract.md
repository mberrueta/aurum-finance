# Task 01: FX Persistence and Index Contract

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02

## Assigned Agent
`dev-db-performance-architect` - Database and schema/query specialist for migrations, indexes, uniqueness, and lookup performance

## Agent Invocation
Invoke the `dev-db-performance-architect` agent with instructions to read this task file, the approved spec, ADR-0012, current reporting/Oban configuration, and current project schema patterns before proposing the concrete persistence and index contract.

## Objective
Define the exact database and query contract for the first FX foundation so backend implementation can proceed with one clear shape for:

- `fx_series` identity, mutability boundaries, and uniqueness
- `fx_rate_records` storage, precision, and upsert semantics
- list/detail aggregation fields (`row_count`, `last_ingested_date`)
- report-time lookup and scheduler-supporting query/index expectations

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `docs/adr/0012-fx-rate-storage-and-lookup.md`
- [ ] `config/config.exs`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- [ ] Existing migration patterns under `priv/repo/migrations/`

## Expected Outputs

- [ ] Recommended migration contract for `fx_series` and `fx_rate_records`
- [ ] Index and constraint guidance for CRUD, upsert, lookup, and scheduler scans
- [ ] Query-shape guidance for list/detail aggregates and report-time latest-on-or-before lookup
- [ ] Recommendation on queue strategy (`:fx` vs `:reporting`) and scheduler wiring concerns

## Acceptance Criteria

- [ ] Recommends one concrete schema/index approach that enforces unique `slug` and unique `(fx_series_id, effective_date)`
- [ ] Confirms decimal/date storage choices are sufficient for `rate_value > 0`, 10+ decimal places, and daily-granularity semantics
- [ ] Covers list-page aggregates without requiring per-row N+1 queries
- [ ] Covers report-time lookup for direct and inverted series with a bounded 4-day staleness window
- [ ] Covers provider-staleness scans for global daily sync
- [ ] Identifies any non-blocking index or queue tradeoffs for later PR review
- [ ] Stays within the approved narrow scope and does not redesign ADR-0012 into a generalized FX platform

## Technical Notes

### Relevant Code Locations
```text
priv/repo/migrations/                         # Migration and index patterns
lib/aurum_finance/reporting.ex               # Existing reporting context boundaries
config/config.exs                            # Current Oban queue/plugin config
docs/adr/0012-fx-rate-storage-and-lookup.md  # FX lookup/storage posture
```

### Constraints
- No implementation in this task
- No broadening into tax snapshots or multi-account FX aggregation
- Prefer query shapes that remain explainable under audit and simple to test
- If `docs/adr/0012-fx-rate-storage-and-lookup.md` is incomplete or ambiguous for this feature, default to the approved `plan.md` and `execution_plan.md` semantics and document the gap instead of extending scope or inventing new FX platform behavior

## Execution Instructions

### For the Agent
1. Read the approved spec, execution plan, ADR, and existing persistence patterns.
2. Recommend the concrete migration/index/query contract for V1 FX storage and lookup.
3. Call out queue/scheduler implications and any N+1 risks.
4. Document the contract the next backend tasks should implement.

### For the Human Reviewer
1. Confirm the persistence and index proposal is narrow and understandable.
2. Confirm the queue/scheduler recommendation is acceptable for V1.
3. Approve before Task 02 begins.

---

## Execution Summary

### 1. Scope and Assumptions

**Scope.** This contract covers the persistence layer, indexes, constraints, and
query-shape guidance for two new tables (`fx_series`, `fx_rate_records`) that
form the V1 FX foundation described in `plan.md`. It also covers queue strategy
and scheduler-supporting query patterns. It does NOT cover Currency entity
(ADR-0012 Section 0), TaxRateSnapshot, FxIngestionBatch, or any schema beyond
the approved V1 feature boundary.

**Assumptions.**

- Single-user, self-hosted deployment. No multi-tenant partitioning needed.
- FX series are global resources (not entity-scoped), per the approved spec.
- Expected cardinality: tens of series, low thousands of rate records per series
  (daily granularity, multi-year history). Total rate records in the low tens of
  thousands.
- Write rate is extremely low: bulk CSV imports (occasional), daily provider
  sync (one batch per series per day), manual CRUD (rare).
- Read patterns are report-time lookups (single-row point reads), list-page
  aggregations (small result sets), and scheduler staleness scans (full table
  scan of a small table).
- The project uses `binary_id` primary keys, `utc_datetime_usec` timestamps,
  `Ecto.Enum` for constrained string fields, and explicit `up/down` migrations
  for DDL that cannot be expressed in `change/0`.
- ADR-0012 describes a broader `ExchangeRates` context with `RateSeries`,
  `RateRecord`, `TaxRateSnapshot`, `FxIngestionBatch`, and a `Currency` entity.
  The approved V1 feature spec intentionally narrows this to `AurumFinance.Fx`
  with `FxSeries` and `FxRateRecord` only. This contract follows the V1 spec.
  Where ADR-0012 fields are not present in the V1 spec (e.g., `rate_type`,
  `jurisdiction_code`, `source_reference`, `fetched_at`, `quality_flag`,
  `ingestion_batch_id`), they are omitted. The ADR remains the long-term
  direction; V1 is a deliberate subset.
- `effective_date` is `:date` (not `:utc_datetime_usec`) because the V1 model
  is daily-granularity only, matching the spec's "one row per day, no
  time-of-day support."

---

### 2. Workload Model

#### Tables

| Table | Expected Rows | Growth Rate | Write Pattern | Read Pattern |
|-------|--------------|-------------|---------------|--------------|
| `fx_series` | 5-50 | Near-static (manual creation) | Single-row inserts/updates | List page (all rows + aggregates), detail page (single row), report-time filter, scheduler scan |
| `fx_rate_records` | 500-50,000 | ~1 row/series/day (provider sync) + bulk CSV | Bulk inserts (CSV upsert), single-row inserts (provider sync) | Report-time point lookup, detail page (latest N rows), list-page aggregate subqueries, scheduler staleness subquery |

#### Critical Queries

1. **List page with aggregates** - All series with `count(*)` and `max(effective_date)` per series. Small table, LEFT JOIN aggregate is fine.
2. **Detail page recent rates** - Latest 30 rate records for one series, ordered by `effective_date DESC`.
3. **Report-time FX lookup** - Single rate record: `WHERE fx_series_id = $1 AND effective_date <= $2 AND effective_date >= $3 ORDER BY effective_date DESC LIMIT 1`.
4. **Series filter for report form** - Series matching a currency pair (direct or inverted) with date range coverage. Small table, sequential scan is acceptable.
5. **Scheduler staleness scan** - All `provider_module` series with their `max(effective_date)`, compared against yesterday. Small table.
6. **CSV upsert** - Bulk `INSERT ... ON CONFLICT (fx_series_id, effective_date) DO UPDATE`.
7. **Delete guard** - `SELECT EXISTS(SELECT 1 FROM fx_rate_records WHERE fx_series_id = $1)`.

---

### 3. Recommendations (Ordered by Impact)

**R1. Use a single migration with both tables, constraints, and indexes.**
At this data scale and as a greenfield addition, there is no lock risk from
creating new tables. A single migration keeps the rollback atomic.

**R2. Store `rate_value` as `decimal` with `precision: 24, scale: 10`.**
The spec requires 10+ decimal places. 24 digits of precision with 10 scale
digits gives 14 integer digits, which handles any realistic exchange rate
(including highly inflated currencies). This matches the intent from the spec's
boundary condition note.

**R3. Store `source_kind` as a Postgres string column backed by Ecto.Enum.**
This follows the project's established pattern (see `imported_file.ex`,
`entity.ex`, `rule_group.ex`). The enum values are `[:csv_upload,
:provider_module]`.

**R4. Enforce slug uniqueness, currency-pair-per-series uniqueness of rate
records, and all NOT NULL constraints at the database level.**
Application-level validation is necessary but not sufficient. DB constraints are
the source of truth.

**R5. Use a dedicated `:fx` Oban queue with concurrency 3.**
Rationale: FX sync/backfill jobs are IO-bound (external API calls) and should
not compete with `:reporting` (CPU-bound snapshot rebuilds) or `:imports`
(file parsing). A separate queue provides independent concurrency control and
makes operational monitoring clearer. The concurrency of 3 is sufficient for the
expected series count and avoids overwhelming external rate APIs.

**R6. Use `Oban.Plugins.Cron` for the daily global sync scheduler.**
The spec requires "runs on app start and daily schedule." Oban Cron satisfies
the daily schedule. For the app-start trigger, a simple `Application` child or
`handle_continue` in a GenServer that enqueues a one-time scan job on boot is
sufficient. The cron entry should schedule a single global scanner job (not
per-series jobs), matching the spec's "global scan approach."

**R7. No partitioning or TimescaleDB hypertables needed.**
The expected data volume (tens of thousands of rows) is well within what a
single Postgres table with proper indexes handles trivially.

---

### 4. Index and Constraint Plan

#### 4.1 `fx_series` Table

```elixir
create table(:fx_series, primary_key: false) do
  add :id, :binary_id, primary_key: true

  add :name, :string, null: false
  add :slug, :string, null: false
  add :description, :text

  add :base_currency_code, :string, null: false
  add :quote_currency_code, :string, null: false

  add :from_date, :date, null: false
  add :to_date, :date

  add :source_kind, :string, null: false
  add :provider_module, :string

  timestamps(type: :utc_datetime_usec)
end

# Unique slug for human-readable identification and URL routing
create unique_index(:fx_series, [:slug])

# Supports report-form series filtering by currency pair + date coverage.
# Also useful for scheduler scans filtered by source_kind.
# At this table size a sequential scan is equally fast, but the index
# documents the intended access path and costs nothing to maintain.
create index(:fx_series, [:base_currency_code, :quote_currency_code])
```

**Constraints enforced at the changeset level (not DB CHECK):**
- `base_currency_code != quote_currency_code` (validated in changeset;
  a CHECK constraint is also acceptable but the project does not use CHECK
  constraints elsewhere, so changeset-only is consistent)
- `to_date >= from_date` when `to_date` is not nil
- `provider_module` required when `source_kind = :provider_module`
- `provider_module` must be nil when `source_kind = :csv_upload`
- `name` length: min 2, max 160
- `description` length: max 500
- `slug` length: max 180 (derived from name via `Helpers.slugify/1`)
- Currency codes: exactly 3 uppercase ASCII letters (format validation)

**Note on CHECK constraints:** The project currently relies on Ecto changeset
validation for business rules rather than Postgres CHECK constraints. This
contract follows that convention. If the reviewer prefers DB-level CHECK for
`base_currency_code != quote_currency_code` or `to_date >= from_date`, those
are safe to add in the same migration as:

```elixir
create constraint(:fx_series, :currencies_must_differ,
  check: "base_currency_code != quote_currency_code")

create constraint(:fx_series, :date_range_valid,
  check: "to_date IS NULL OR to_date >= from_date")
```

#### 4.2 `fx_rate_records` Table

```elixir
create table(:fx_rate_records, primary_key: false) do
  add :id, :binary_id, primary_key: true

  add :fx_series_id,
      references(:fx_series, type: :binary_id, on_delete: :restrict),
      null: false

  add :effective_date, :date, null: false
  add :rate_value, :decimal, precision: 24, scale: 10, null: false

  timestamps(type: :utc_datetime_usec)
end

# Primary access pattern: one rate per series per day.
# Enforces the business uniqueness rule.
# Also serves as the covering index for:
#   - report-time lookup (series_id + effective_date range scan)
#   - detail page (series_id + ORDER BY effective_date DESC LIMIT 30)
#   - CSV upsert conflict target
#   - scheduler staleness subquery (series_id + max effective_date)
#   - delete guard (series_id existence check)
create unique_index(:fx_rate_records, [:fx_series_id, :effective_date])
```

**Key design choice: `on_delete: :restrict`.**
The spec says "if fx_series has records, cannot delete." Using `:restrict`
enforces this at the FK level. The application delete guard (check for existing
records, return error) provides the user-friendly message; the FK constraint is
the safety net.

**Constraints enforced at the changeset level:**
- `rate_value > 0` (strictly positive; `Decimal.compare(rate_value, 0) == :gt`)

**Optional DB CHECK (reviewer's discretion):**

```elixir
create constraint(:fx_rate_records, :rate_value_positive,
  check: "rate_value > 0")
```

#### 4.3 Index Summary

| Table | Index | Type | Purpose |
|-------|-------|------|---------|
| `fx_series` | `fx_series_slug_index` | unique btree | Slug lookup, uniqueness |
| `fx_series` | `fx_series_base_currency_code_quote_currency_code_index` | btree | Report-form series filtering |
| `fx_rate_records` | `fx_rate_records_fx_series_id_effective_date_index` | unique btree | Upsert conflict target, report-time lookup, detail page, staleness scan, delete guard |

**Total: 3 indexes.** This is the minimal set that covers all identified query
patterns. No additional indexes are needed at V1 scale.

---

### 5. Migration Safety Plan

**Risk level: LOW.** Both tables are new (no existing data, no ALTER on existing
tables). The migration creates two tables and three indexes. No locks on
existing tables are acquired.

**Migration file pattern:**

```
priv/repo/migrations/YYYYMMDDHHMMSS_create_fx_series_and_rate_records.exs
```

Use `change/0` since all operations are reversible (`create table`, `create
index`). The `down` path is automatic via Ecto. If CHECK constraints are
added, use `up/down` instead (since `create constraint` in `change` requires
Ecto 3.12+ for auto-reversal; verify project Ecto version).

**Rollout steps:**

1. Run `mix ecto.migrate` in development.
2. Verify tables exist: `\dt fx_series` and `\dt fx_rate_records` in psql.
3. Verify indexes exist: `\di fx_*` in psql.
4. Run the full test suite (`mix test`).
5. Deploy. No backfill needed (empty tables).

**Rollback:** `mix ecto.rollback` drops both tables and all indexes atomically.

---

### 6. Query Notes

#### 6.1 List Page Aggregates (row_count + last_ingested_date)

The list page needs `count(fx_rate_records)` and `max(effective_date)` per
series. Use a LEFT JOIN aggregate or a lateral subquery. At the expected series
count (5-50), either approach is fine. The LEFT JOIN aggregate is simpler:

```sql
SELECT
  s.*,
  COALESCE(agg.row_count, 0) AS row_count,
  agg.last_ingested_date
FROM fx_series s
LEFT JOIN LATERAL (
  SELECT
    COUNT(*) AS row_count,
    MAX(effective_date) AS last_ingested_date
  FROM fx_rate_records r
  WHERE r.fx_series_id = s.id
) agg ON true
ORDER BY s.name ASC;
```

In Ecto, this is cleanest as a subquery join:

```elixir
rate_stats =
  from(r in FxRateRecord,
    group_by: r.fx_series_id,
    select: %{
      fx_series_id: r.fx_series_id,
      row_count: count(r.id),
      last_ingested_date: max(r.effective_date)
    }
  )

from(s in FxSeries,
  left_join: stats in subquery(rate_stats),
  on: stats.fx_series_id == s.id,
  select: {s, stats.row_count, stats.last_ingested_date},
  order_by: [asc: s.name]
)
```

**Verification:** `EXPLAIN (ANALYZE, BUFFERS)` should show the unique index on
`fx_rate_records(fx_series_id, effective_date)` used for the aggregate
subquery. At low row counts, Postgres may choose a sequential scan, which is
equally fast and not a concern.

#### 6.2 Detail Page (Latest N Rates)

```elixir
from(r in FxRateRecord,
  where: r.fx_series_id == ^series_id,
  order_by: [desc: r.effective_date],
  limit: 30
)
```

Uses the unique index backward scan. Efficient even at 10,000+ records per
series.

#### 6.3 Report-Time FX Lookup (Latest On Or Before with 4-Day Staleness)

This is the most performance-critical query in the feature. It must return
exactly one rate or nothing:

```elixir
from(r in FxRateRecord,
  where: r.fx_series_id == ^series_id,
  where: r.effective_date <= ^as_of_date,
  where: r.effective_date >= ^staleness_floor,
  order_by: [desc: r.effective_date],
  limit: 1
)
```

Where `staleness_floor = Date.add(as_of_date, -4)`.

**EXPLAIN expectation:** Index Scan Backward on the unique index
`(fx_series_id, effective_date)` with a range condition. Returns at most 1 row.
This is a point-read-class query.

**Inverted series handling:** The lookup query is the same regardless of
direction. The caller determines whether to use `rate_value` directly or
`Decimal.div(Decimal.new(1), rate_value)` based on whether the series
base/quote matches the account/target currencies directly or inversely. This
logic belongs in the context function, not in SQL.

**Return contract:**
- `{:ok, %FxRateRecord{}}` when a rate is found within the window
- `{:error, :rate_not_found}` when no rate exists in the 4-day window

#### 6.4 Report-Form Series Filtering

Find all series that connect `account_currency` and `target_currency` (direct
or inverted) with date range coverage:

```elixir
from(s in FxSeries,
  where:
    (s.base_currency_code == ^account_currency and
       s.quote_currency_code == ^target_currency) or
      (s.base_currency_code == ^target_currency and
         s.quote_currency_code == ^account_currency),
  where: s.from_date <= ^as_of_date,
  where: is_nil(s.to_date) or s.to_date >= ^as_of_date
)
```

At 5-50 series this is a sequential scan and requires no special index.

#### 6.5 Scheduler Staleness Scan

Find all `provider_module` series that are behind yesterday and still active:

```elixir
yesterday = Date.add(Date.utc_today(), -1)

stale_series_query =
  from(s in FxSeries,
    left_join: r in subquery(
      from(r in FxRateRecord,
        group_by: r.fx_series_id,
        select: %{fx_series_id: r.fx_series_id, max_date: max(r.effective_date)}
      )
    ),
    on: r.fx_series_id == s.id,
    where: s.source_kind == :provider_module,
    where: is_nil(s.to_date) or s.to_date >= ^yesterday,
    where: is_nil(r.max_date) or r.max_date < ^yesterday
  )
```

This runs once daily (or on boot). Performance is irrelevant at this scale.

#### 6.6 CSV Upsert

Bulk upsert using Ecto `Repo.insert_all/3` with `on_conflict` and
`conflict_target`:

```elixir
Repo.insert_all(
  FxRateRecord,
  rate_rows,
  on_conflict: {:replace, [:rate_value, :updated_at]},
  conflict_target: [:fx_series_id, :effective_date]
)
```

The unique index on `(fx_series_id, effective_date)` is the conflict target.
`rate_value` and `updated_at` are replaced on conflict; `id`, `inserted_at`,
`fx_series_id`, and `effective_date` are preserved.

#### 6.7 Delete Guard

```elixir
has_records? =
  FxRateRecord
  |> where([r], r.fx_series_id == ^series_id)
  |> Repo.exists?()
```

Uses the unique index prefix scan on `fx_series_id`. Returns immediately.

---

### 7. Operational Checklist

- **Autovacuum:** Default settings are fine for both tables at V1 scale. No
  high-churn patterns exist (CSV upserts are infrequent, provider syncs insert
  1 row/day/series).
- **Bloat:** Not a concern at this data volume. Standard `pg_stat_user_tables`
  monitoring is sufficient.
- **Slow query log:** Ensure `log_min_duration_statement` captures the
  report-time lookup if it ever exceeds expectations. At this scale, it should
  be sub-millisecond.
- **Index bloat:** The unique index on `fx_rate_records` is append-mostly (new
  dates are always increasing). Minimal bloat expected.
- **Disk growth:** Negligible. 50,000 rate records at ~100 bytes each is ~5MB.
- **Monitoring:** Track Oban job success/failure rates for the `:fx` queue. The
  scheduler staleness scan itself is a monitoring tool (detects stale series).
- **Alerting:** No special alerts needed at V1. Oban's built-in error handling
  and retry semantics cover provider failures.

---

### 8. Out-of-Scope and Follow-ups

**Out of scope for this contract (deferred to later tasks or features):**

1. **Currency entity table** (ADR-0012 Section 0) - Not part of V1. Currency
   codes are stored as plain strings. A `currencies` reference table is a
   future concern.
2. **TaxRateSnapshot and FxIngestionBatch tables** (ADR-0012 Sections 3, 6) -
   Explicitly out of V1 scope.
3. **Rate type and jurisdiction fields** (ADR-0012 Section 1) - V1 uses
   `source_kind` and `provider_module` instead. The broader `rate_type` +
   `jurisdiction_code` model can be added when the tax feature lands.
4. **`source_reference`, `fetched_at`, `quality_flag`** fields on rate records -
   ADR-0012 columns not needed in V1. Can be added as nullable columns later
   without migration risk.
5. **Composite natural key uniqueness on series** (`base_currency_code,
   quote_currency_code, rate_type, jurisdiction_code`) - V1 uses `slug`
   uniqueness instead. Multiple series for the same pair are allowed by design.
6. **Partitioning / TimescaleDB** - Not warranted at V1 volumes.
7. **`CREATE INDEX CONCURRENTLY`** - Not needed since both tables are new and
   empty at migration time.

**Answers to Execution Plan open questions:**

- **Q1 (report route):** This contract does not prescribe the route. The
  report-time lookup query shape works regardless of whether it lives under
  `/reports/account` or extends an existing route. The backend task (Task 07)
  and frontend task (Task 08) should decide based on UX flow.
- **Q2 (queue strategy):** Recommend a dedicated `:fx` queue with concurrency 3.
  See Recommendation R5 above for rationale.

**ADR-0012 gap note:** ADR-0012 defines `effective_at` as a timestamp
(supporting intraday rates). The V1 spec explicitly restricts to daily
granularity with `effective_date` as `:date`. This is a deliberate narrowing,
not a conflict. If intraday support is needed later, the column can be migrated
from `:date` to `:utc_datetime_usec` with a backfill step (set time to
`00:00:00Z` for all existing rows). This is noted here for traceability but is
not a V1 concern.

## Human Review
*[Filled by human reviewer]*
