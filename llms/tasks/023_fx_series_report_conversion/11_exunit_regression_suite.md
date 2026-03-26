# Task 11: ExUnit Regression Suite

## Status
- **Status**: COMPLETE
- **Approved**: [x] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 12

## Assigned Agent
`qa-elixir-test-author` - QA-driven ExUnit author for backend, LiveView, and worker coverage

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file, Task 10 scenario outputs, and completed implementation tasks before writing the final regression suite.

## Objective
Add deterministic automated coverage for the FX context, CSV parser/import service, provider sync workers/scheduler behavior, `/fx` LiveView flows, and account-report FX conversion flows.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/10_test_scenarios_and_traceability.md`
- [ ] Completed outputs from Tasks 02-09
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] `test/support/factory.ex`

## Expected Outputs

- [ ] Backend tests for context, lookup, import, and report conversion semantics
- [ ] Worker/Oban tests for provider sync and scheduler behavior
- [ ] LiveView tests for `/fx` and the account-report conversion UI
- [ ] Any required factory/test-support additions

## Acceptance Criteria

- [ ] Tests cover series creation/edit/delete guardrails and list/detail aggregates
- [ ] Tests cover CSV happy path, invalid file rejection, overlap confirmation, and provider-series upload rejection
- [ ] Tests cover manual sync enqueue and global stale-series scan behavior
- [ ] Tests cover direct and inverted lookup plus stale-rate handling
- [ ] Tests cover account-report conversion success, invalid selection, no-compatible-series, and missing-rate-unavailable behavior
- [ ] Tests use stable DOM IDs and outcome-focused assertions
- [ ] Tests are deterministic, DB-sandbox-safe, and avoid timing flakiness
- [ ] `mix test` and `mix precommit` are run before completion

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/aurum_finance_web/live/
test/support/factory.ex
```

### Constraints
- Prefer factories over fixtures
- Keep tests high-signal and aligned to Task 10 scenario mapping
- Avoid raw HTML assertions when stable selectors are available

## Execution Instructions

### For the Agent
1. Follow the approved scenario matrix.
2. Add only the test support truly required by the implemented feature.
3. Run `mix test` and `mix precommit`, then document any remaining gaps.

### For the Human Reviewer
1. Confirm high-signal coverage of the approved feature scope.
2. Confirm quality gates were run cleanly.
3. Approve before Task 12 begins.

---

## Execution Summary
Implemented a compact regression pass aligned to Task 10 without duplicating already-covered behavior.

Added coverage in:

- `test/aurum_finance/fx_test.exs`
  - `delete_fx_series/1` blocks deletion when rows exist
  - `delete_fx_series/1` deletes empty series
  - `lookup_fx_rate/3` direct lookup
  - `lookup_fx_rate/3` inverted lookup
  - `lookup_fx_rate/3` stale-rate miss
  - `enqueue_fx_sync/1` resumes from the day after the latest stored rate
  - `enqueue_fx_sync/1` returns `:already_up_to_date` when coverage is complete
  - `enqueue_fx_sync/1` rejects CSV-backed series

- `test/aurum_finance/fx/csv_import_test.exs`
  - `check_overlap/2` returns overlapping persisted dates deterministically
  - `import/2` rejects provider-backed series

- `test/aurum_finance_web/live/fx_live_test.exs`
  - detail-page `Sync Now` enqueues a provider sync job
  - sidebar create flow persists a CSV series from the LiveView form
  - delete action is hidden for series with stored rows and works for empty series

Existing tests kept as the main coverage for:

- scheduler stale-series scan behavior
- account report conversion success/incompatible/missing-rate behavior
- saved account report CRUD, ordering, and runtime preview states
- reports dashboard and account-report LiveView states

Quality gates run:

- `mix test test/aurum_finance/fx_test.exs test/aurum_finance/fx/csv_import_test.exs test/aurum_finance/fx/global_sync_scheduler_test.exs test/aurum_finance_web/live/fx_live_test.exs test/aurum_finance/reporting/account_report_test.exs test/aurum_finance/reporting/saved_account_reports_test.exs test/aurum_finance_web/live/account_report_live_test.exs test/aurum_finance_web/live/reports_live_test.exs`
- `mix precommit`

Residual gaps intentionally not expanded in this task:

- no new provider HTTP integration tests beyond the existing provider-specific suite
- no browser-level E2E
- no broad rewrite of legacy tests outside the FX/report scope

## Human Review
*[Filled by human reviewer]*
