# Task 05: Net Worth LiveView Page

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: Task 06

## Assigned Agent
`dev-frontend-ui-engineer` - LiveView UI engineer for routed pages, tables, summary cards, and responsive behavior

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Tasks 02-04 outputs, and the approved plan before building `/reports/net-worth`.

## Objective
Implement `/reports/net-worth` as the canonical first reporting page with:

- default `as_of_date`
- summary cards by currency
- freshness and refresh suggestion
- accounts table with agreed columns
- visible no-history rows

## Inputs Required

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/04_reports_hub_refactor.md`
- [x] Approved outputs from Tasks 02-04
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `lib/aurum_finance_web/router.ex`
- [x] `lib/aurum_finance_web/live/`

## Expected Outputs

- [x] Route for `/reports/net-worth`
- [x] LiveView module and HEEx template for the Net Worth page
- [x] Date selector, summary UI, and accounts table
- [x] Empty-state and no-history-state handling

## Acceptance Criteria

- [x] `/reports/net-worth` loads with the current business date default, implemented with `Date.utc_today()` in V1
- [x] Page renders Assets, Liabilities, and Net Worth summaries per currency
- [x] Liabilities display as positive owed amounts in rows and summaries
- [x] Freshness state and refresh suggestion are visible when relevant
- [x] Table includes Entity, Account, Type, Currency, Balance, Snapshot Used, and Coverage
- [x] No-history rows are visible and excluded from totals
- [x] Page shows a clear empty state when no included institution-managed asset/liability accounts are available
- [x] UI does not introduce charts, drilldown, or export features

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/router.ex
lib/aurum_finance_web/live/
lib/aurum_finance/reporting/
test/aurum_finance_web/live/
```

### Constraints
- HEEx must follow project interpolation rules
- Keep the page explainable and minimal
- Avoid adding ad hoc backend logic inside the LiveView

## Execution Instructions

### For the Agent
1. Add the route and LiveView entrypoint.
2. Consume the backend report contract directly.
3. Keep the UI minimal but clear about freshness and coverage.

### For the Human Reviewer
1. Validate the page against the approved product semantics.
2. Check no-history and liability display carefully.
3. Approve before Task 06 begins.

---

## Execution Summary

### Work Performed
- Added the routed Net Worth page and route entrypoint in [router.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/router.ex), [net_worth_live.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/net_worth_live.ex), and [net_worth_live.html.heex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/net_worth_live.html.heex).
- Wired the page directly to `AurumFinance.Reporting.net_worth_report/2` with `Date.utc_today/0` defaulting, `?as_of_date=` URL state, and report reloading through `handle_params/3`.
- Added the summary cards, freshness badge, refresh suggestion callout, and the canonical accounts table with visible `no_history` rows and snapshot coverage semantics.
- Subscribed the page to the narrow reporting freshness PubSub so the detailed view re-reads on invalidation and refresh-complete events.
- Updated the hub link in [reports_live.html.heex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/reports_live.html.heex) to navigate to the new real route.
- Added detailed page copy in [reports.po](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/gettext/en/LC_MESSAGES/reports.po) and LiveView coverage in [net_worth_live_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance_web/live/net_worth_live_test.exs).
- Verified with targeted LiveView tests and `mix precommit`.

### Outputs Created
- `/reports/net-worth` route inside the authenticated app LiveSession.
- Net Worth LiveView with query-param-driven date selection and derived presentation assigns.
- Summary cards by currency showing Net Worth, Assets, Liabilities, and coverage metadata.
- Accounts table with `Entity`, `Account`, `Type`, `Currency`, `Balance`, `Snapshot Used`, and `Coverage`.
- Empty state for empty scope and row-level `No history` rendering that stays visible while excluded from totals.

### Assumptions Made
- The detailed page should use the same visible-entity scope as the `/reports` hub by resolving `Entities.list_entities/0` in the LiveView.
- `?as_of_date=YYYY-MM-DD` is the minimal V1 URL contract for a shareable/filterable report page.
- The page can reuse the reporting freshness subscription for coarse re-read behavior without introducing progress tracking or report-specific refresh jobs.

### Decisions Made
- Kept the page explainable and table-first rather than adding charts or drilldowns.
- Used `handle_params/3` plus `push_patch/2` for the date selector so the selected `as_of_date` remains explicit in the URL.
- Represented `no_history` with visible rows, unavailable balances, and explicit coverage/snapshot messaging instead of hiding the rows.
- Kept refresh behavior informational on this page by showing freshness and refresh suggestion state rather than adding a second refresh control.

### Blockers Encountered
- A local helper name conflicted with an imported web helper and was renamed during implementation.
- The first pass of `parse_as_of_date/1` had a clause-order bug that caused binary dates to fall through to the default date; this was corrected before final verification.

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
