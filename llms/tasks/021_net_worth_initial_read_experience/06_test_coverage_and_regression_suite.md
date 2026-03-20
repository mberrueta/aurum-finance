# Task 06: Test Coverage and Regression Suite

## Status
- **Status**: BLOCKED
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

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/01_net_worth_query_and_performance_contract.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/04_reports_hub_refactor.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/05_net_worth_liveview_page.md`
- [ ] Approved outputs from Tasks 01-05
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] `test/support/factory.ex`

## Expected Outputs

- [ ] Backend tests for Net Worth read semantics
- [ ] Freshness and coverage tests
- [ ] LiveView tests for `/reports` and `/reports/net-worth`
- [ ] Any required factory or test-support updates

## Acceptance Criteria

- [ ] Tests cover included account filtering and archived/category/system-managed exclusion by current model fields
- [ ] Tests cover latest snapshot `<= as_of_date`
- [ ] Tests cover `exact`, `carried_forward`, `refreshable_gap`, and `no_history`
- [ ] Tests cover no-history rows excluded from totals
- [ ] Tests cover the empty-report state when no included institution-managed asset/liability accounts exist
- [ ] Tests cover liabilities shown as positive owed amounts in report output semantics
- [ ] Tests cover multi-currency summaries staying separate
- [ ] Tests cover hub rendering, refresh action presence, and Net Worth card content
- [ ] Tests cover `/reports/net-worth` date selector, summaries, table, and outdated/refresh suggestion states
- [ ] Tests include at least one integration-style stale-data case proving the report still renders while showing a refreshable gap
- [ ] Tests are deterministic, sandbox-safe, and avoid timing flakiness

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
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
### Decisions Made
### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
