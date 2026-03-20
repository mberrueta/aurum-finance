# Task 05: Net Worth LiveView Page

## Status
- **Status**: BLOCKED
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

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/04_reports_hub_refactor.md`
- [ ] Approved outputs from Tasks 02-04
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance_web/router.ex`
- [ ] `lib/aurum_finance_web/live/`

## Expected Outputs

- [ ] Route for `/reports/net-worth`
- [ ] LiveView module and HEEx template for the Net Worth page
- [ ] Date selector, summary UI, and accounts table
- [ ] Empty-state and no-history-state handling

## Acceptance Criteria

- [ ] `/reports/net-worth` loads with the current business date default, implemented with `Date.utc_today()` in V1
- [ ] Page renders Assets, Liabilities, and Net Worth summaries per currency
- [ ] Liabilities display as positive owed amounts in rows and summaries
- [ ] Freshness state and refresh suggestion are visible when relevant
- [ ] Table includes Entity, Account, Type, Currency, Balance, Snapshot Used, and Coverage
- [ ] No-history rows are visible and excluded from totals
- [ ] Page shows a clear empty state when no included institution-managed asset/liability accounts are available
- [ ] UI does not introduce charts, drilldown, or export features

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
