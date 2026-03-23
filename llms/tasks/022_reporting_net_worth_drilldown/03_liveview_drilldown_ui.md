# Task 03: LiveView Drilldown UI

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 01, Task 02
- **Blocks**: Task 04

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView.

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to implement the drilldown row expansion in the Net Worth LiveView.

## Objective
Implement the account row drilldown UI: clickable rows, single-expansion panel with balance explanation header and paginated transaction table. Add row-level badges for Outdated and No snapshot states.

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/plan.md` - Full spec (UX/UI Contract section)
- [ ] `llms/tasks/022_reporting_net_worth_drilldown/01_backend_drilldown_query.md` - Backend function API
- [ ] `llms/constitution.md` - HEEx template rules, i18n rules
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance_web/live/net_worth_live.ex` - Current LiveView
- [ ] `lib/aurum_finance_web/live/net_worth_live.html.heex` - Current template
- [ ] `lib/aurum_finance_web/components/transactions_components.ex` - Row expansion pattern reference
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` - Toggle pattern reference (handle_event "toggle_transaction")
- [ ] `lib/aurum_finance_web/components/ui_components.ex` - Badge component, format_money

## Expected Outputs

- [ ] Updated `net_worth_live.ex` with drilldown state management (expanded_account_id, drilldown data, pagination)
- [ ] Updated `net_worth_live.html.heex` with row expansion panel
- [ ] New `net_worth_components.ex` component module (if needed for extraction)
- [ ] Row-level Outdated and No snapshot badges
- [ ] Rows without snapshots are NOT clickable (no cursor-pointer, no phx-click)
- [ ] All new user-facing strings use `dgettext("reports", ...)` with i18n keys

## Acceptance Criteria

- [ ] Clicking an account row with a snapshot opens an inline expansion panel below it
- [ ] Clicking the same row again closes it
- [ ] Opening a new row closes any previously open row (single expansion)
- [ ] No-snapshot rows are visually non-interactive (no cursor-pointer, no phx-click handler)
- [ ] Expansion panel shows: "Balance Explanation" header, "Balance of [Amount] as of [Date]" summary
- [ ] Panel shows Outdated badge when coverage is `:refreshable_gap`
- [ ] Transaction table columns: Date, Description, Amount (with au-mono, debit/credit styling)
- [ ] Transactions paginated at 20 per page with page navigation
- [ ] Account rows show Outdated badge for `:refreshable_gap` coverage
- [ ] Account rows show No snapshot badge for `:no_history` coverage
- [ ] No new per-row badges except Outdated and No snapshot. Existing coverage/status column presentation remains unchanged.
- [ ] All strings internationalized via `dgettext("reports", ...)`
- [ ] Template uses `{}` interpolation and `:if`/`:for` attributes (no `<% %>` blocks)
- [ ] Responsive: drilldown table readable on mobile/tablets

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance_web/live/net_worth_live.ex           # Add state management
lib/aurum_finance_web/live/net_worth_live.html.heex    # Add expansion panel
lib/aurum_finance_web/components/transactions_components.ex  # Row expansion pattern
lib/aurum_finance_web/components/ui_components.ex      # Badge, format_money
```

### Patterns to Follow
- **Row expansion**: Follow `transactions_components.ex` pattern -- `tr :if={@expanded_account_id == row.account_id}` with `colspan` on the `td`
- **Toggle event**: Follow `transactions_live.ex` `handle_event("toggle_transaction", ...)` pattern
- **State**: Add `expanded_account_id` (nil or UUID), `drilldown_data` (nil or map), `drilldown_page` (integer)
- **Badge component**: Use existing `<.badge variant={...}>` from `ui_components.ex`
- **Money formatting**: Use `format_money/2` from `UiComponents`
- **Amount styling**: Use `au-mono` class, and `au-debit`/`au-credit` classes if they exist, otherwise use color classes for positive/negative

### Constraints
- The `expanded_account_id` toggle and drilldown data load should happen in `handle_event`
- Call `Reporting.drilldown_transactions/3` (the facade) passing `snapshot_date_used` from the row as the date parameter
- Pagination: handle_event for page changes, re-fetch drilldown data
- The `build_account_rows/1` helper already produces display rows; add `has_snapshot?` and `snapshot_date_used` fields to support drilldown capability check and query parameter

### I18n Keys to Add
- `drilldown_header` - "Balance Explanation"
- `drilldown_summary` - "Balance of %{amount} as of %{date}"
- `drilldown_outdated_badge` - "Outdated"
- `drilldown_no_snapshot_badge` - "No snapshot"
- `drilldown_table_date` - "Date"
- `drilldown_table_description` - "Description"
- `drilldown_table_amount` - "Amount"
- `drilldown_no_transactions` - "No transactions found"
- `drilldown_page_info` - "Page %{page} of %{total_pages}"
- `drilldown_prev` - "Previous"
- `drilldown_next` - "Next"

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` before editing
3. Study the transactions row expansion pattern in `transactions_components.ex` and `transactions_live.ex`
4. Add drilldown state assigns to `mount/3` and wire up `handle_event("toggle_drilldown", ...)`
5. Update `build_account_rows/1` to include `has_snapshot?` and `snapshot_date_used` in the display row map
6. Add the expansion panel markup to the template
7. Add pagination event handler
8. Add all i18n keys via `dgettext`
9. Run `mix format` and `mix compile --warnings-as-errors`
10. Document assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Visually inspect the drilldown panel by navigating to `/reports/net-worth` in a browser
2. Test: click a row with snapshot -> panel opens with transactions
3. Test: click same row -> panel closes
4. Test: click different row -> first closes, second opens
5. Test: no-snapshot rows are not clickable
6. Test: pagination works
7. Check responsive behavior on mobile viewport
8. Verify all strings use dgettext
9. If approved: mark `[x]` on "Approved" and update plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
