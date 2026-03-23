# Task 04: LiveView Drilldown Tests

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 05

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer.

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to write LiveView tests for the drilldown UI behavior.

## Objective
Write LiveView tests covering the drilldown panel toggle behavior, badge rendering, transaction display, pagination, and non-interactive no-snapshot rows.

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/plan.md` - Acceptance criteria
- [ ] `llms/tasks/022_reporting_net_worth_drilldown/03_liveview_drilldown_ui.md` - Task 03 output
- [ ] `llms/constitution.md` - Test discipline
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `test/aurum_finance_web/live/net_worth_live_test.exs` - Existing LiveView tests
- [ ] `test/support/reporting_test_helpers.ex` - Test helpers
- [ ] `lib/aurum_finance_web/live/net_worth_live.ex` - Updated LiveView

## Expected Outputs

- [ ] New tests in `test/aurum_finance_web/live/net_worth_live_test.exs` covering drilldown behavior
- [ ] All tests pass with `mix test test/aurum_finance_web/live/net_worth_live_test.exs`

## Acceptance Criteria

- [ ] Test: clicking account row with snapshot opens drilldown panel
- [ ] Test: clicking same row again closes drilldown panel
- [ ] Test: opening new row closes previously open row (single expansion)
- [ ] Test: no-snapshot row does NOT have phx-click / is not clickable
- [ ] Test: drilldown panel shows balance and snapshot date
- [ ] Test: drilldown panel shows Outdated badge for refreshable_gap account
- [ ] Test: drilldown panel shows transaction list with Date, Description, Amount
- [ ] Test: pagination controls appear when > 20 transactions
- [ ] Test: changing page within the same drilldown keeps the panel open (expanded_account_id unchanged)
- [ ] Test: opening a different row resets drilldown page to 1
- [ ] Test: account rows show appropriate badges (Outdated for refreshable_gap, No snapshot for no_history)
- [ ] Tests use existing helpers and factory patterns
- [ ] All tests pass, `mix precommit` clean

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance_web/live/net_worth_live_test.exs  # Add tests here
test/support/reporting_test_helpers.ex               # insert_snapshot!, create_transaction!
```

### Patterns to Follow
- Follow existing LiveView test patterns in the file: `conn |> log_in_root() |> live("/reports/net-worth")`
- Use `has_element?/3` for presence checks
- Use `element/2` + `render_click/1` for click interactions
- Use `render/1` to inspect HTML content
- Test drilldown toggle: click row, assert panel visible; click again, assert panel gone

### Constraints
- Tests should be `async: false` (matching existing pattern in the file)
- Need to create enough test data: entity, accounts with/without snapshots, transactions
- For pagination test: create 25+ transactions to verify page 2 exists

## Execution Instructions

### For the Agent
1. Read all inputs, especially Task 03 output and existing test patterns
2. Read `llms/coding_styles/elixir_tests.md` before writing
3. Add new test cases to the existing file
4. Run tests to verify
5. Run `mix format`

### For the Human Reviewer
After agent completes:
1. Verify test coverage matches acceptance criteria
2. Run full test suite
3. If approved: mark `[x]` on "Approved" and update plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
