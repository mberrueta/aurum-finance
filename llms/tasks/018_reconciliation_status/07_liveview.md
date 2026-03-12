# Task 07: LiveView and Components Rewrite

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 08

## Assigned Agent
`liveview-frontend-agent` - Phoenix LiveView frontend specialist

## Agent Invocation
```
Act as a LiveView frontend agent following llms/constitution.md.

Execute Task 07 from llms/tasks/018_reconciliation_status/07_liveview.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md (UX States + User Stories + Acceptance Criteria)
- lib/aurum_finance_web/live/reconciliation_live.ex (current mock -- to be fully rewritten)
- lib/aurum_finance_web/components/reconciliation_components.ex (current mock components)
- lib/aurum_finance_web/live/accounts_live.ex (pattern: entity selector, tabs, streams, slideover)
- lib/aurum_finance_web/live/transactions_live.ex (pattern: listing transactions with postings)
- lib/aurum_finance_web/router.ex (existing route)
- lib/aurum_finance/reconciliation.ex (Task 03 output -- context API)
```

## Objective
Replace the mock `ReconciliationLive` and `ReconciliationComponents` with a real data-driven reconciliation workflow. The LiveView should support: session list view, session creation form, session detail with posting list, bulk clear/un-clear actions, balance summary, and finalization.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - UX States, User Stories, Acceptance Criteria
- [ ] `lib/aurum_finance_web/live/reconciliation_live.ex` - Current mock to replace
- [ ] `lib/aurum_finance_web/components/reconciliation_components.ex` - Current mock components
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - Pattern for entity selector, streams, forms
- [ ] `lib/aurum_finance_web/live/accounts_live.html.heex` - HEEx template pattern
- [ ] `lib/aurum_finance/reconciliation.ex` - Task 03 context API
- [ ] `lib/aurum_finance_web/router.ex` - Existing route structure

## Expected Outputs

- [ ] Rewritten `lib/aurum_finance_web/live/reconciliation_live.ex` - Full LiveView with real data
- [ ] Rewritten `lib/aurum_finance_web/components/reconciliation_components.ex` - Updated components for real data structures
- [ ] New HEEx template `lib/aurum_finance_web/live/reconciliation_live.html.heex` (if extracting from inline render)
- [ ] Updated router if new live actions are needed (e.g., `:show` for session detail)

## Acceptance Criteria

### Structure and Patterns
- [ ] Uses `use AurumFinanceWeb, :live_view`
- [ ] Uses `dgettext("reconciliation", ...)` for all UI strings
- [ ] HEEx templates use `{}` interpolation and `:if`/`:for` attributes (NO `<%= %>` blocks)
- [ ] Entity selector follows AccountsLive pattern
- [ ] Data loaded via `Reconciliation` context functions (no direct Repo calls)
- [ ] Entity scope enforced on all queries

### Session List View (US-7)
- [ ] Shows list of sessions for selected entity, filterable by account
- [ ] Active sessions appear at top with distinct badge
- [ ] Completed sessions show completion timestamp
- [ ] Empty state: "No reconciliation sessions yet" with CTA
- [ ] Empty state: "Create an institution account first" when no institution accounts exist

### Session Creation (US-1, US-4)
- [ ] "New Session" button opens form (slideover or modal)
- [ ] Form requires: account selection (institution accounts only), statement_date, statement_balance
- [ ] Inline validation errors displayed
- [ ] On success: navigates to session detail view
- [ ] Error when active session already exists for account

### Session Detail View (US-2, US-3, US-8)
- [ ] Shows postings for the account with reconciliation status derived from overlay
- [ ] Each row: transaction date, description, amount, status badge
- [ ] Checkbox selection for unreconciled postings
- [ ] "Select all" toggle
- [ ] "Mark Cleared" bulk action (enabled when postings selected)
- [ ] "Un-clear" action on individual cleared postings
- [ ] Cleared balance, statement balance, and difference displayed
- [ ] Difference highlighted: green when zero, warning/amber when non-zero

### Finalization (US-5)
- [ ] "Reconcile" button visible in active session
- [ ] If difference is zero: finalize directly
- [ ] If difference is non-zero: show confirmation (JS confirm or modal)
- [ ] On finalization: success flash, session becomes read-only
- [ ] Completed session: no checkboxes, no action buttons

### Completed Session View
- [ ] Read-only: postings displayed without checkboxes or actions
- [ ] Shows completion details (completed_at, final balances)

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance_web/live/reconciliation_live.ex       # To rewrite
lib/aurum_finance_web/components/reconciliation_components.ex  # To rewrite
lib/aurum_finance_web/live/accounts_live.ex             # Pattern: entity selector, tabs, streams
lib/aurum_finance_web/live/accounts_live.html.heex      # HEEx pattern
lib/aurum_finance_web/live/transactions_live.ex         # Pattern: listing with postings
lib/aurum_finance_web/components/ui_components.ex       # Shared components (badge, au_card, etc.)
lib/aurum_finance_web/router.ex                         # Route configuration
```

### Patterns to Follow

**Entity selector (from AccountsLive):**
```elixir
def mount(_params, _session, socket) do
  entities = Entities.list_entities()
  current_entity = List.first(entities)
  # ... load data scoped to entity
end

def handle_event("select_entity", %{"entity_id" => entity_id}, socket) do
  # ... switch entity, reload data
end
```

**Stream-based lists:**
```elixir
socket
|> stream_configure(:postings, dom_id: &"posting-#{&1.id}")
|> stream(:postings, postings, reset: true)
```

**Form handling:**
```elixir
def handle_event("validate_session", %{"reconciliation_session" => params}, socket) do
  changeset = Reconciliation.change_reconciliation_session(%ReconciliationSession{}, params)
  {:noreply, assign(socket, form: to_form(changeset, as: "reconciliation_session"))}
end
```

### LiveView State Shape

Key assigns:
- `entities` - list of entities for selector
- `current_entity` - selected entity
- `sessions` - list of sessions for the entity (stream or assign)
- `selected_session` - currently viewed session (or nil for list view)
- `postings` - postings for the selected session's account (stream)
- `selected_posting_ids` - MapSet of posting IDs selected for bulk action
- `cleared_balance` - derived cleared balance
- `difference` - statement_balance - cleared_balance
- `institution_accounts` - accounts available for session creation
- `form` - changeset form for session creation/edit
- `form_open?` - whether creation form is visible

### Router Decision (Closed — Do Not Reopen)

The router uses two live actions. **This is decided — do not use query params for session navigation.**

```elixir
live "/reconciliation", ReconciliationLive, :index
live "/reconciliation/:session_id", ReconciliationLive, :show
```

- `:index` — session list view, no session loaded
- `:show` — session detail view, `session_id` from params

The LiveView handles both via `handle_params/3`. On `:show`, load the session and its postings. On `:index`, load the session list only.

Navigation after session creation: `push_navigate(socket, to: ~p"/reconciliation/#{session.id}")`.

### Constraints
- All data fetching must go through the `Reconciliation` context (and `Ledger`/`Entities` for accounts/entities)
- No direct Repo calls from the LiveView
- HEEx must use `{}` interpolation, NOT `<%= %>`
- Must use `:if` and `:for` attributes, NOT `<%= if ... %>` blocks
- The existing mock must be fully replaced (not incrementally patched)
- Bulk actions must call context functions that use `Ecto.Multi` (the LiveView does not manage transactions)

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` (required by constitution)
3. Fully rewrite `reconciliation_live.ex` with real data and all views
4. Fully rewrite `reconciliation_components.ex` with components for real data structures
5. Extract HEEx to a separate template file if inline render becomes large
6. Update router if adding new live actions
7. Ensure the module compiles: `mix compile --warnings-as-errors`
8. Manually verify the page loads in browser (if dev server available)
9. Document assumptions and UI decisions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify HEEx compliance (no `<%= %>`, uses `{}` and `:if`/`:for`)
2. Verify entity scope enforcement
3. Verify all UX states from the spec are handled
4. Verify context functions are called (no direct Repo)
5. Verify i18n pattern for all UI strings
6. Test in browser: session list, creation, detail, bulk actions, finalization
7. If approved: mark `[x]` on "Approved" and update plan.md status
8. If rejected: add rejection reason and specific feedback

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
