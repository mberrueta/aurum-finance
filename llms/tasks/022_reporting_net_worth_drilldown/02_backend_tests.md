# Task 02: Backend Drilldown Query Tests

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer.

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to write ExUnit tests for the drilldown query.

## Objective
Write comprehensive tests for the `drilldown_transactions/3` function added in Task 01, covering happy paths, edge cases, and security boundaries.

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/plan.md` - Feature specification
- [ ] `llms/tasks/022_reporting_net_worth_drilldown/01_backend_drilldown_query.md` - Task 01 output
- [ ] `llms/constitution.md` - Test discipline rules
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `test/aurum_finance/reporting/net_worth_test.exs` - Existing test file to extend
- [ ] `test/support/reporting_test_helpers.ex` - Test helpers (insert_snapshot!, create_transaction!)
- [ ] `test/support/factory.ex` - Factory patterns
- [ ] `lib/aurum_finance/reporting/net_worth.ex` - Implementation to test

## Expected Outputs

- [ ] New `describe "drilldown_transactions/3"` block in `test/aurum_finance/reporting/net_worth_test.exs`
- [ ] All tests pass with `mix test test/aurum_finance/reporting/net_worth_test.exs`

## Acceptance Criteria

- [ ] Test: returns transactions grouped by transaction_id with net_amount summed for the account
- [ ] Test: respects the snapshot date boundary (transactions after snapshot date are excluded)
- [ ] Test: orders by date DESC, inserted_at DESC
- [ ] Test: pagination works (page 1 returns first 20, page 2 returns next batch)
- [ ] Test: returns empty list when account has no transactions
- [ ] Test: returns empty list / error for non-existent account_id
- [ ] **Architectural guardrail test**: Given entity A with account X and entity B with account Y, calling `drilldown_transactions(account_x_id, ...)` never returns entity B's transactions. This is not just a happy-path check — it validates that the query's entity isolation is structural, not accidental. Setup must use two distinct entities with overlapping transaction dates to ensure the boundary is real.
- [ ] Test: handles liability accounts correctly (raw posting amounts, not abs)
- [ ] Test: transaction eligibility matches DailyBalanceSnapshot projection (e.g., if projection excludes voided facts, drilldown must too — derive the assertion from actual projection code, not assumptions)
- [ ] Tests use `insert_snapshot!` and `create_transaction!` helpers from `ReportingTestHelpers`
- [ ] Tests use `async: true` DataCase
- [ ] All tests pass, `mix precommit` clean

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/reporting/net_worth_test.exs   # Add tests here
test/support/reporting_test_helpers.ex             # Existing helpers
test/support/factory.ex                            # Factory for :entity, :account
```

### Patterns to Follow
- Follow existing test structure in `net_worth_test.exs` -- uses `import AurumFinance.ReportingTestHelpers`
- Use `insert(:entity)` and `insert_account/2` for setup
- Use `insert_snapshot!` and `create_transaction!` for data
- Each test should be self-contained with its own entity/account setup
- Assert on the return shape: `{:ok, %{transactions: [...], total_count: _, page: _, ...}}`

### Constraints
- Tests must be deterministic (no timing dependence)
- Use DB sandbox (DataCase, async: true)

## Execution Instructions

### For the Agent
1. Read all inputs, especially Task 01 output to understand the exact function signature and return shape
2. Read `llms/coding_styles/elixir_tests.md` before writing tests
3. Add a new `describe "drilldown_transactions/3"` block to the existing test file
4. Write tests covering all acceptance criteria
5. Run `mix test test/aurum_finance/reporting/net_worth_test.exs` to verify
6. Run `mix format`

### For the Human Reviewer
After agent completes:
1. Verify test coverage is comprehensive (boundary conditions, pagination, isolation)
2. Verify tests are deterministic
3. Run full test suite to check for regressions
4. If approved: mark `[x]` on "Approved" and update plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
