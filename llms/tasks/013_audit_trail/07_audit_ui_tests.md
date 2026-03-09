# Task 07: Audit Log LiveView Tests

## Status
- **Status**: ✅ COMPLETE
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 08

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer. Converts scenarios into ExUnit tests with proper test layers (unit, integration, LiveView, Oban), minimal fixtures, and actionable failures.

## Agent Invocation
```
Act as a QA-driven Elixir Test Author following llms/constitution.md.

Read and implement Task 07 from llms/tasks/013_audit_trail/07_audit_ui_tests.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (user stories US-1 through US-5, UX States)
- llms/tasks/013_audit_trail/06_audit_log_liveview.md (LiveView implementation details)
- This task file in full
```

## Objective
Write comprehensive LiveView tests for `AuditLogLive` covering mount, filter interactions, URL-driven state, pagination, empty states, expandable rows, and the read-only invariant. This corresponds to plan task 17.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - User stories US-1 to US-5, UX States, edge cases
- [ ] `lib/aurum_finance_web/live/audit_log_live.ex` - Implementation to test (from Task 06)
- [ ] `test/aurum_finance_web/live/transactions_live_test.exs` - Reference pattern for LiveView tests (filter tests, URL hydration, read-only invariant)
- [ ] `test/support/conn_case.ex` - `log_in_root/1` helper, imported fixtures
- [ ] `test/support/fixtures.ex` - `entity_fixture/1`, `account_fixture/2`
- [ ] `lib/aurum_finance/audit.ex` - `list_audit_events/1`, `distinct_entity_types/0`

## Expected Outputs

- [ ] **`test/aurum_finance_web/live/audit_log_live_test.exs`** - Comprehensive LiveView test file

## Acceptance Criteria

### Mount Tests
- [ ] Authenticated user can access `/audit-log` and sees the audit log page
- [ ] Unauthenticated user is redirected to login (covered by existing auth protection tests, but verify the route is included)
- [ ] Page renders with default filters (no filters applied, showing most recent events)
- [ ] Page title is set correctly

### Filter Tests
- [ ] Selecting an entity type filter updates the URL and filters the displayed events
- [ ] Selecting an action filter updates the URL and filters the displayed events
- [ ] Selecting a channel filter updates the URL and filters the displayed events
- [ ] Selecting an entity filter updates the URL and filters to events owned by that entity
- [ ] Date preset buttons filter events by date range
- [ ] Combining multiple filters works correctly
- [ ] Clearing filters (selecting "All" for each) returns to the unfiltered view

### URL Hydration Tests
- [ ] Navigating directly to `/audit-log?q=type:account&action:created` hydrates filters from the URL
- [ ] Filters form reflects the URL state on mount
- [ ] Invalid filter values in the URL are handled gracefully (ignored or defaulted)

### Pagination Tests
- [ ] First page shows up to 50 events
- [ ] Next button navigates to page 2
- [ ] Previous button navigates back to page 1
- [ ] Previous button is disabled/absent on page 1
- [ ] Next button is disabled/absent on the last page (fewer results than page size)

### Expandable Row Tests
- [ ] Clicking an event row expands it to show before/after snapshots
- [ ] Clicking an expanded row collapses it
- [ ] Before/after snapshots are displayed as formatted JSON
- [ ] Events with `nil` before (inserts) show appropriate placeholder

### Empty State Tests
- [ ] No audit events: shows "No audit events recorded yet."
- [ ] Filters return no results: shows "No events match the selected filters." with clear-filters link
- [ ] Clicking clear-filters link resets to unfiltered view

### Read-Only Invariant
- [ ] No mutation buttons exist in the rendered HTML (no "Edit", "Delete", "Void", "Replay", "Undo")
- [ ] No `phx-submit` forms that perform write operations
- [ ] No `phx-click` handlers for mutation actions

### General
- [ ] Tests use `async: true`
- [ ] Tests use `log_in_root(conn)` for authentication
- [ ] Tests create audit events via domain context calls (e.g., `Entities.create_entity/2`) rather than directly inserting audit records
- [ ] No debug prints or log noise
- [ ] `mix test` passes with zero warnings
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
test/aurum_finance_web/live/                           # LiveView test directory
test/aurum_finance_web/live/transactions_live_test.exs # Reference pattern
test/support/conn_case.ex                              # log_in_root/1
test/support/fixtures.ex                               # entity_fixture, account_fixture
```

### Patterns to Follow (from TransactionsLiveTest)

**Basic mount test pattern:**
```elixir
test "renders the audit log page", %{conn: conn} do
  {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")
  assert has_element?(view, "#audit-log-page")
end
```

**Filter test pattern (from transactions_live_test.exs lines 67-142):**
```elixir
test "filters by entity type", %{conn: conn} do
  entity = entity_fixture(name: "Filter Test Entity")
  # Create some domain records to generate audit events
  {:ok, _account} = Ledger.create_account(%{...})

  {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

  # Apply filter
  view
  |> form("#audit-log-filter-form", filters: %{"entity_type" => "account"})
  |> render_change()

  assert_patch(view, "/audit-log?q=type:account")
  # Verify only account events are shown
end
```

**URL hydration pattern (from transactions_live_test.exs lines 144-196):**
```elixir
test "hydrates filters from query string", %{conn: conn} do
  path = "/audit-log?q=type:entity&action:created"
  {:ok, view, _html} = conn |> log_in_root() |> live(path)
  # Verify filters are applied
end
```

**Read-only invariant pattern (from transactions_live_test.exs lines 297-310):**
```elixir
test "does not render mutation buttons", %{conn: conn} do
  {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")
  html = render(view)
  refute html =~ "Delete"
  refute html =~ "Edit"
  refute html =~ ~s(phx-submit="delete")
end
```

### Creating Audit Events for Tests

Do NOT insert audit events directly. Instead, call domain context functions that produce audit events as a side effect:

```elixir
# Creates an entity AND its audit event
entity = entity_fixture(name: "Audit Test Entity")

# Creates an account AND its audit event
account = account_fixture(entity, %{name: "Audit Test Account"})

# Creates a transaction but, in v1, does NOT create a default audit event
{:ok, transaction} = Ledger.create_transaction(%{
  entity_id: entity.id,
  date: ~D[2026-03-07],
  description: "Test transaction",
  source_type: :manual,
  postings: [...]
})

# Creates an account AND its audit event
account = account_fixture(entity, %{name: "Audit Test Account"})
```

### Constraints
- Do not test the Audit context API here -- that is covered in Task 04
- Focus on LiveView behavior: rendering, interactions, URL state
- Use `has_element?/2` and `render/1` for assertions (not raw HTML string matching where avoidable)
- Element IDs should match what Task 06 implemented -- coordinate with the LiveView implementation

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read the actual `audit_log_live.ex` implementation to understand element IDs, event names, and form structures
3. Create `test/aurum_finance_web/live/audit_log_live_test.exs` with describe blocks:
   - `describe "mount"` - Page load, authentication, defaults
   - `describe "filtering"` - Each filter type, combined filters, URL updates
   - `describe "url hydration"` - Direct URL navigation with filters
   - `describe "pagination"` - Page navigation, boundary conditions
   - `describe "expandable rows"` - Expand/collapse, snapshot display
   - `describe "empty states"` - No events, no matching events
   - `describe "read-only invariant"` - No mutation actions
4. Run `mix test test/aurum_finance_web/live/audit_log_live_test.exs`
5. Run `mix precommit`
6. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify test coverage against acceptance criteria checklist
2. Check that tests create audit events via domain contexts (not direct inserts)
3. Verify URL hydration tests use the correct query string format
4. Confirm read-only invariant test is comprehensive
5. Run `mix test` to verify all tests pass
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
Task completed against the current Task 06 implementation, including the reduced v1 audit scope and the user-facing `Entity` selector instead of a raw `Entity ID` input.

### Work Performed
- Recreated `test/aurum_finance_web/live/audit_log_live_test.exs` as a comprehensive async LiveView suite covering mount, filtering, URL hydration, pagination, expandable rows, empty states, and the read-only invariant.
- Added `/audit-log` to `test/aurum_finance_web/live/auth_protection_test.exs` so route protection is asserted by the shared auth suite.
- Updated `docs/qa/test_plan.md` to map scenarios S35-S48 to the new audit log LiveView coverage.
- Verified the full repo with `mix test` and `mix precommit`.

### Outputs Created
- `test/aurum_finance_web/live/audit_log_live_test.exs`
- Updated `test/aurum_finance_web/live/auth_protection_test.exs`
- Updated `docs/qa/test_plan.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Date-preset UI tests should assert URL state and rendered behavior, not historical exclusion across arbitrary dates | Domain context helpers create audit events at `DateTime.utc_now/0`, and immutable audit rows cannot be backdated inside this suite without bypassing the intended task constraints |
| Using domain contexts to create events and the `Audit` read API only to locate generated event row IDs is acceptable in a LiveView test | The task forbids direct audit inserts, but row-level visibility assertions still need stable DOM targets tied to real audit events |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Reuse the existing auth protection test for `/audit-log` | Duplicate the unauthenticated assertion only inside `audit_log_live_test.exs` | The task explicitly asked to verify the route is included in the shared auth protection coverage |
| Model the filter as owner-entity selection in the tests | Keep the older raw `entity_id` free-input expectations | Task 06 already moved the UI to a user-facing entity selector while preserving compact UUID filtering in the URL |
| Keep the suite async | Convert to sync for simpler ordering assumptions | Each scenario creates its own isolated data, and async execution matches the task acceptance criteria |

### Blockers Encountered
- The original task text still referred to entering a raw `Entity ID` in the filter. Resolution: aligned the task wording and tests with the implemented entity selector UX while preserving `entity:<uuid>` in the compact URL.

### Questions for Human
1. None.

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
