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
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
