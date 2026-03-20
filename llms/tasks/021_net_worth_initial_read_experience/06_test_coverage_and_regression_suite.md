# Task 06: Test Coverage and Regression Suite

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: Task 07

## Assigned Agent
`qa-elixir-test-author` - QA-driven ExUnit author for backend, integration, LiveView, and regression coverage

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file, Tasks 01-05 outputs, and the approved plan before writing tests.

## Objective
Add deterministic coverage for the backend Net Worth semantics, hub/page LiveViews, refresh-driven freshness behavior, and primary regressions.

## Inputs Required

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/01_net_worth_query_and_performance_contract.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/04_reports_hub_refactor.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/05_net_worth_liveview_page.md`
- [x] Approved outputs from Tasks 01-05
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `llms/coding_styles/elixir_tests.md`
- [x] `test/support/factory.ex`

## Expected Outputs

- [x] Backend tests for Net Worth read semantics
- [x] Freshness and coverage tests
- [x] LiveView tests for `/reports` and `/reports/net-worth`
- [x] Any required factory or test-support updates

## Acceptance Criteria

- [x] Tests cover included account filtering and archived/category/system-managed exclusion by current model fields
- [x] Tests cover latest snapshot `<= as_of_date`
- [x] Tests cover `exact`, `carried_forward`, `refreshable_gap`, and `no_history`
- [x] Tests cover no-history rows excluded from totals
- [x] Tests cover the empty-report state when no included institution-managed asset/liability accounts exist
- [x] Tests cover liabilities shown as positive owed amounts in report output semantics
- [x] Tests cover multi-currency summaries staying separate
- [x] Tests cover hub rendering, refresh action presence, and Net Worth card content
- [x] Tests cover `/reports/net-worth` date selector, summaries, table, and outdated/refresh suggestion states
- [x] Tests include at least one integration-style stale-data case proving the report still renders while showing a refreshable gap
- [x] Tests are deterministic, sandbox-safe, and avoid timing flakiness

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/reporting/
test/aurum_finance_web/live/
test/support/factory.ex
lib/aurum_finance/reporting/
lib/aurum_finance_web/live/
```

### Constraints
- Prefer factories over fixtures
- Keep tests outcome-focused, not raw-HTML fragile
- Include coverage useful for final PR review, not duplicate low-signal tests

## Execution Instructions

### For the Agent
1. Read all completed implementation-task outputs first.
2. Write backend and LiveView tests covering the agreed semantics only.
3. Document any remaining coverage gaps for human review.

### For the Human Reviewer
1. Confirm high-signal coverage of freshness, coverage, and UI semantics.
2. Check that stale-but-renderable behavior is explicitly tested.
3. Approve before Task 07 begins.

---

## Execution Summary

### Work Performed
- Added backend regression tests in [net_worth_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/reporting/net_worth_test.exs) for empty report state with category/system-managed exclusions and for latest-snapshot selection constrained to `<= as_of_date`.
- Strengthened the `/reports` hub coverage in [reports_live_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance_web/live/reports_live_test.exs) to assert actual Net Worth card content and refresh-action presence rather than only container presence.
- Reused the existing detailed Net Worth page coverage in [net_worth_live_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance_web/live/net_worth_live_test.exs), which already covered default date selection, presets, liabilities as positive owed amounts, visible `no_history` rows, multi-entity rendering, stale refresh suggestion state, and empty scope behavior.
- Added the acceptance-criteria-to-test mapping document in [test_plan.md](/mnt/data4/matt/code/personal_stuffs/aurum-finance/docs/qa/test_plan.md).
- Verified the targeted regression suite and `mix precommit`.

### Outputs Created
- Expanded backend Net Worth regression coverage for scope filtering, empty report behavior, latest snapshot selection, liabilities, multi-currency, freshness, and multi-entity metadata.
- Expanded LiveView regression coverage for `/reports` and `/reports/net-worth`.
- Created `docs/qa/test_plan.md` mapping scenarios `S01-S13` to concrete automated tests and layers.

### Assumptions Made
- Existing tests from Tasks 02-05 were acceptable to keep and extend rather than renaming every test case to a scenario-prefixed naming scheme.
- The current `insert_account/2` factory helper remains sufficient for all scenario setup by overriding management group, account type, and institution fields per test.
- The stale-data regression is best proven at both backend and LiveView layers because the final review needs confidence in renderability as well as domain semantics.

### Decisions Made
- Added only the missing high-signal regressions instead of duplicating already strong LiveView coverage from Tasks 04-05.
- Used explicit timestamps and date literals in snapshot-selection tests to keep the suite deterministic and explainable.
- Documented scenario mapping in `docs/qa/test_plan.md` rather than scattering traceability comments through every test body.

### Blockers Encountered
- A snapshot-selection assertion initially failed due to `DateTime` microsecond representation differences; it was stabilized with `DateTime.compare/2`.

### Questions for Human
- None.

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
