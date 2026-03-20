# Task 02: Net Worth Backend Read Model

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03

## Assigned Agent
`dev-backend-elixir-engineer` - Senior Elixir/Phoenix backend engineer for read models, queries, and business semantics

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 01 output, the approved plan, and existing reporting modules before implementing the report-shaped backend contract.

## Objective
Implement the Net Worth V1 backend read model on top of `daily_balance_snapshots`, including:

- included account selection
- latest snapshot `<= as_of_date` semantics
- coverage classification
- per-currency totals
- liability presentation semantics
- page-level freshness result

## Inputs Required

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/01_net_worth_query_and_performance_contract.md`
- [x] Approved Task 01 output
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `llms/coding_styles/elixir.md`
- [x] `lib/aurum_finance/reporting.ex`
- [x] `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- [x] `lib/aurum_finance/ledger/account.ex`
- [x] `lib/aurum_finance/ledger.ex`

## Expected Outputs

- [x] Report-specific backend module for Net Worth
- [x] Public `AurumFinance.Reporting` API entrypoint for Net Worth reads
- [x] Structured result contract for the Net Worth page and hub card
- [x] `@doc`, `@spec`, and executable examples for non-trivial public functions

## Acceptance Criteria

- [x] Uses only `daily_balance_snapshots` plus ledger/account facts already in scope
- [x] Applies the canonical account scope: `account_type in [:asset, :liability]`, `management_group == :institution`, `archived_at is nil`
- [x] Uses latest snapshot `<= as_of_date` per included account
- [x] Returns `exact`, `carried_forward`, `refreshable_gap`, and `no_history`
- [x] Excludes no-history rows from totals while keeping them visible in the result
- [x] Returns per-currency summaries only, with no FX or consolidated global total
- [x] Returns entity display metadata for each row so the UI can deterministically show or hide the Entity column without additional queries
- [x] Preserves internal ledger sign semantics while presenting liabilities as positive owed amounts in report-shaped output
- [x] Treats current business date default as `Date.utc_today()` in V1
- [x] Keeps web shaping thin by returning a report-ready result object/map

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/reporting/
lib/aurum_finance/ledger/account.ex
lib/aurum_finance/ledger.ex
test/aurum_finance/reporting/
```

### Constraints
- Web layers must call through `AurumFinance.Reporting`
- No implicit recomputation on read
- No generic freshness framework beyond immediate need

## Execution Instructions

### For the Agent
1. Read Task 01 output before writing code.
2. Implement the smallest backend contract that satisfies the approved plan.
3. Keep query logic isolated and explainable.
4. Document assumptions, especially around freshness and liability presentation.

### For the Human Reviewer
1. Confirm the returned data contract is stable enough for UI tasks.
2. Check that freshness semantics match the approved plan.
3. Approve before Task 03 begins.

---

## Execution Summary

### Work Performed
- Implemented the report-specific backend module [net_worth.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting/net_worth.ex).
- Extended the public Reporting context in [reporting.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting.ex) with the Net Worth entrypoint.
- Added backend coverage in [net_worth_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/reporting/net_worth_test.exs) for scope filtering, per-currency summaries, liability presentation, refreshable gaps, and multi-entity metadata.
- Verified the implementation with targeted tests, the reporting test slice, and `mix precommit`.

### Outputs Created
- Public API: `AurumFinance.Reporting.net_worth_report/2`
- Backend read-model module: `AurumFinance.Reporting.NetWorth`
- Report-shaped result with:
  - `as_of_date`
  - `freshness_status`
  - `refresh_suggested?`
  - `empty?`
  - `included_account_count`
  - `entity_count`
  - `show_entity_column?`
  - `coverage_counts`
  - `currency_summaries`
  - `account_rows`
- Row-level output includes entity display metadata, snapshot metadata, `coverage`, raw `ledger_balance`, presented `balance`, and `contributes_to_totals?`.

### Assumptions Made
- The reporting caller provides explicit `entity_ids`; the backend does not silently widen scope to all entities.
- `daily_balance_snapshots.computed_at` is the per-row freshness watermark for detecting later-inserted relevant ledger facts.
- A report is `:outdated` only when at least one included row is `:refreshable_gap`; `:no_history` alone is not stale.

### Decisions Made
- Implemented latest-snapshot selection with `LEFT LATERAL JOIN` to preserve `no_history` rows and keep the query explainable.
- Kept freshness report-specific and derived from `transaction.date <= as_of_date` plus `transaction.inserted_at > snapshot.computed_at`.
- Returned liability balances as positive owed amounts in `balance` while preserving raw signed ledger values in `ledger_balance`.
- Kept the backend contract UI-ready so later LiveView tasks do not need per-row Repo calls or extra entity lookups.

### Blockers Encountered
- None in the code. The local test environment emitted transient Postgres `too_many_connections` logs, but the affected test runs completed successfully.

### Questions for Human
- Are we comfortable standardizing the explicit entity-scope requirement for reporting reads at the API level, or do you want a later convenience wrapper that resolves “all current entities” in the Reporting context?

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
