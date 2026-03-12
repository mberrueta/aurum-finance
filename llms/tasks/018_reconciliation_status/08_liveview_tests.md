# Task 08: LiveView Integration Tests

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05, Task 07
- **Blocks**: Task 09

## Assigned Agent
`liveview-frontend-agent` - Phoenix LiveView frontend specialist

## Agent Invocation
```
Act as a LiveView frontend agent following llms/constitution.md.

Execute Task 08 from llms/tasks/018_reconciliation_status/08_liveview_tests.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir_tests.md
- llms/tasks/018_reconciliation_status/plan.md (UX States + Acceptance Criteria)
- lib/aurum_finance_web/live/reconciliation_live.ex (Task 07 output)
- lib/aurum_finance_web/components/reconciliation_components.ex (Task 07 output)
- test/aurum_finance_web/live/accounts_live_test.exs (LiveView test pattern)
- test/aurum_finance_web/live/transactions_live_test.exs (LiveView test pattern)
- test/support/factory.ex (Task 05 output -- reconciliation factories)
```

## Objective
Write LiveView integration tests for the `ReconciliationLive` module covering all user stories, UX states, and edge cases.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - UX States, User Stories, Acceptance Criteria
- [ ] `lib/aurum_finance_web/live/reconciliation_live.ex` - Task 07 output
- [ ] `test/aurum_finance_web/live/accounts_live_test.exs` - LiveView test pattern
- [ ] `test/support/factory.ex` - Task 05 output (factories)

## Expected Outputs

- [ ] `test/aurum_finance_web/live/reconciliation_live_test.exs` - Comprehensive LiveView tests

## Acceptance Criteria

- [ ] All tests pass: `mix test test/aurum_finance_web/live/reconciliation_live_test.exs`
- [ ] Uses `AurumFinance.ConnCase` with `:logged_in` tag (or whatever auth pattern exists)
- [ ] Tests use factories for data setup

### Page Load and Empty States
- [ ] Page renders successfully for authenticated user
- [ ] Shows "No reconciliation sessions yet" when no sessions exist
- [ ] Shows "Create an institution account first" when no institution accounts exist

### Session Creation (US-1)
- [ ] "New Session" button is visible
- [ ] Session creation form shows institution accounts only
- [ ] Creating a session succeeds and navigates to session detail
- [ ] Creating a session with invalid data shows inline errors
- [ ] Creating a session when active session exists shows error

### Session Detail (US-2, US-3, US-4)
- [ ] Session detail shows postings for the account
- [ ] Postings show date, description, amount, status badge
- [ ] Statement balance, cleared balance, and difference are displayed
- [ ] Selecting postings and clicking "Mark Cleared" updates the view
- [ ] Cleared balance updates after marking postings cleared

### Un-clear (US-8)
- [ ] "Un-clear" button visible on cleared postings
- [ ] Clicking "Un-clear" removes the overlay and updates balances

### Finalization (US-5)
- [ ] "Reconcile" button is visible in active session
- [ ] Finalization succeeds and shows success message
- [ ] Completed session becomes read-only (no action buttons)

### Session History (US-7)
- [ ] Past sessions appear in the session list
- [ ] Active sessions show at top with distinct badge
- [ ] Completed sessions show completion timestamp

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance_web/live/accounts_live_test.exs    # LiveView test pattern
test/aurum_finance_web/live/transactions_live_test.exs # LiveView test pattern
test/aurum_finance_web/live/auth_protection_test.exs   # Auth test pattern
```

### Patterns to Follow

From existing LiveView tests:
```elixir
defmodule AurumFinanceWeb.ReconciliationLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import AurumFinance.Factory

  # ... setup with logged_in user, entity, accounts, transactions

  describe ":index — session list" do
    test "renders reconciliation page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/reconciliation")
      assert html =~ "Reconciliation"
    end
  end

  describe ":show — session detail" do
    test "loads session detail via /reconciliation/:session_id", %{conn: conn, session: session} do
      {:ok, _view, html} = live(conn, "/reconciliation/#{session.id}")
      assert html =~ session.statement_date |> to_string()
    end

    test "unknown session_id returns 404 or redirects", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, "/reconciliation/00000000-0000-0000-0000-000000000000")
    end
  end

  describe "session creation" do
    test "creates session and navigates to :show", %{conn: conn, entity: entity, account: account} do
      {:ok, view, _html} = live(conn, "/reconciliation")

      view
      |> element("button", "New Session")
      |> render_click()

      # Fill form and submit — expect push_navigate to /reconciliation/:session_id
    end
  end
end
```

### Test Setup

Most tests will need:
- A logged-in user (via ConnCase setup)
- An entity
- An institution account with postings (transactions)
- Sometimes: an existing reconciliation session

### Constraints
- Tests MUST be deterministic
- Tests MUST use the DB sandbox
- Tests MUST use factories
- LiveView tests use `live/2`, `render_click/2`, `render_submit/2`, etc.
- Assert on rendered HTML content for UI verification
- **Router is `:index` + `:show` — do NOT use query params for session navigation.** Tests for session detail must use `live(conn, "/reconciliation/#{session.id}")`, never `/reconciliation?session_id=...`

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir_tests.md` (required by constitution)
3. Study existing LiveView test patterns in the project
4. Create `test/aurum_finance_web/live/reconciliation_live_test.exs`
5. Write tests for all user stories and UX states
6. Run tests: `mix test test/aurum_finance_web/live/reconciliation_live_test.exs`
7. Fix any failures
8. Document assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify all acceptance criteria test cases exist
2. Verify tests follow project patterns
3. Run `mix test` to verify all pass
4. Check that key user flows are exercised
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
