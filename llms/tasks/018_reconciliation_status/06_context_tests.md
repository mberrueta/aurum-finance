# Task 06: Context-Level Tests

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03, Task 04, Task 05
- **Blocks**: Task 09

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 06 from llms/tasks/018_reconciliation_status/06_context_tests.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir_tests.md
- llms/tasks/018_reconciliation_status/plan.md (acceptance criteria for all user stories)
- lib/aurum_finance/reconciliation.ex (Task 03 output)
- lib/aurum_finance/ledger.ex (Task 04 output -- void guard)
- test/support/factory.ex (Task 05 output -- reconciliation factories)
- test/aurum_finance/ledger_test.exs (existing test patterns)
```

## Objective
Write comprehensive ExUnit tests for the `AurumFinance.Reconciliation` context and the void guard in `AurumFinance.Ledger.void_transaction/2`. Tests must cover the full state machine, session lifecycle, balance derivation, and all edge cases from the spec.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - All user stories and acceptance criteria
- [ ] `lib/aurum_finance/reconciliation.ex` - Task 03 output (context to test)
- [ ] `lib/aurum_finance/ledger.ex` - Task 04 output (void guard to test)
- [ ] `test/support/factory.ex` - Task 05 output (reconciliation factories)
- [ ] `test/aurum_finance/ledger_test.exs` - Existing test patterns

## Expected Outputs

- [ ] `test/aurum_finance/reconciliation_test.exs` - Comprehensive context tests
- [ ] Additional void guard tests in `test/aurum_finance/ledger_test.exs` (or a new describe block)

## Acceptance Criteria

- [ ] All tests pass: `mix test test/aurum_finance/reconciliation_test.exs`
- [ ] Tests use `AurumFinance.DataCase, async: true`
- [ ] Tests use factories (not fixtures) per constitution
- [ ] Tests use `describe` blocks grouped by function

### Session Lifecycle Tests
- [ ] `create_reconciliation_session/2` happy path: creates session with `completed_at: nil`
- [ ] `create_reconciliation_session/2` rejects when active session exists for account
- [ ] `create_reconciliation_session/2` allows new session when existing session is completed
- [ ] `create_reconciliation_session/2` emits audit event
- [ ] `list_reconciliation_sessions/1` filters by entity_id (required)
- [ ] `list_reconciliation_sessions/1` filters by account_id (optional)
- [ ] `get_reconciliation_session!/2` returns session for valid entity/id
- [ ] `get_reconciliation_session!/2` raises for wrong entity
- [ ] `update_reconciliation_session/3` edits statement_balance before completion
- [ ] `update_reconciliation_session/3` rejects edit after completion
- [ ] `complete_reconciliation_session/2` atomically transitions all cleared to reconciled
- [ ] `complete_reconciliation_session/2` sets completed_at
- [ ] `complete_reconciliation_session/2` creates audit log entries for each transition
- [ ] `complete_reconciliation_session/2` emits session-level audit event

### Posting State Management Tests
- [ ] `mark_postings_cleared/3` inserts overlay records for unreconciled postings
- [ ] `mark_postings_cleared/3` creates audit log entries
- [ ] `mark_postings_cleared/3` rejects if posting already has overlay record
- [ ] `mark_postings_cleared/3` is atomic (all or nothing)
- [ ] `mark_postings_uncleared/3` deletes cleared overlay records
- [ ] `mark_postings_uncleared/3` creates audit log entries
- [ ] `mark_postings_uncleared/3` rejects if posting is reconciled (not cleared)
- [ ] `any_posting_reconciled?/1` returns true when reconciled posting exists
- [ ] `any_posting_reconciled?/1` returns false when only cleared postings exist
- [ ] `any_posting_reconciled?/1` returns false when no overlay records exist
- [ ] `list_postings_for_reconciliation/2` returns postings with derived status
- [ ] `list_postings_for_reconciliation/2` excludes voided transactions
- [ ] `list_postings_for_reconciliation/2` is entity-scoped

### Balance Derivation Tests
- [ ] `get_cleared_balance/2` returns sum of cleared + reconciled amounts
- [ ] `get_cleared_balance/2` excludes voided transactions
- [ ] `get_cleared_balance/2` returns zero/nil when no cleared postings exist

### Void Guard Tests (in ledger_test.exs)
- [ ] `void_transaction/2` succeeds when no overlay records exist (backward compatible)
- [ ] `void_transaction/2` succeeds when postings have only `:cleared` overlay records (and cleans them up)
- [ ] `void_transaction/2` fails with error when any posting is `:reconciled`
- [ ] `void_transaction/2` cleans up cleared overlay records during successful void

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance/ledger_test.exs       # Existing test patterns + void guard tests
test/aurum_finance/reconciliation_test.exs  # New file
test/support/factory.ex                  # Factories
```

### Patterns to Follow

From `ledger_test.exs`:
```elixir
defmodule AurumFinance.ReconciliationTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Reconciliation
  # ... aliases

  describe "create_reconciliation_session/2" do
    test "creates session with required fields" do
      entity = Factory.insert_entity()
      account = Factory.insert_account(entity)

      assert {:ok, session} =
        Reconciliation.create_reconciliation_session(%{
          entity_id: entity.id,
          account_id: account.id,
          statement_date: ~D[2026-03-01],
          statement_balance: Decimal.new("5000.00")
        })

      assert session.completed_at == nil
    end
  end
end
```

### Test Setup Helpers

Many tests will need a common setup: entity + account + transaction with postings. Consider using a setup block:

```elixir
setup do
  entity = Factory.insert_entity()
  account = Factory.insert_account(entity, %{management_group: :institution, account_type: :asset, operational_subtype: :bank_checking})
  category = Factory.insert_account(entity, %{management_group: :category, account_type: :expense, name: "Groceries"})

  {:ok, transaction} = Ledger.create_transaction(%{
    entity_id: entity.id,
    date: ~D[2026-03-01],
    description: "Test",
    source_type: :manual,
    postings: [
      %{account_id: account.id, amount: Decimal.new("-50.00")},
      %{account_id: category.id, amount: Decimal.new("50.00")}
    ]
  })

  %{entity: entity, account: account, transaction: transaction}
end
```

### Constraints
- Tests MUST be deterministic (no timing dependence)
- Tests MUST use the DB sandbox
- Tests MUST use factories, not fixtures
- Tests MUST assert on changeset errors using `errors_on/1` helper
- Each test should be self-contained (use setup blocks for common setup)

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir_tests.md` (required by constitution)
3. Create `test/aurum_finance/reconciliation_test.exs` with all test cases
4. Add void guard tests to `test/aurum_finance/ledger_test.exs` (new describe block)
5. Run all tests: `mix test test/aurum_finance/reconciliation_test.exs test/aurum_finance/ledger_test.exs`
6. Fix any failures
7. Document assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify all acceptance criteria test cases exist
2. Verify tests follow project patterns (DataCase, factories, describe blocks)
3. Run `mix test` to verify all pass
4. Check that state machine edge cases are covered
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

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
### Git Operations Performed
```bash
```
