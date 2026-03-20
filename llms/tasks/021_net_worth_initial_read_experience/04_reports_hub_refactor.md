# Task 04: Reports Hub Refactor

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 05

## Assigned Agent
`dev-frontend-ui-engineer` - Phoenix LiveView UI engineer for reporting screens, Tailwind, and interaction design

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Task 02 and Task 03 outputs, and the approved plan before refactoring `/reports`.

## Objective
Replace the current mock-heavy `/reports` page with a real reporting hub centered on:

- a global freshness badge
- one global refresh action
- one Net Worth report card

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [ ] Approved outputs from Tasks 02-03
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance_web/live/reports_live.ex`
- [ ] `lib/aurum_finance_web/live/reports_live.html.heex`
- [ ] `lib/aurum_finance_web/router.ex`

## Expected Outputs

- [ ] Refactored `/reports` LiveView
- [ ] Removal of mock dashboard sections no longer in scope
- [ ] Net Worth card wired to the real backend result
- [ ] Global refresh action and coarse freshness badge in the hub UI

## Acceptance Criteria

- [ ] `/reports` is organized around report types, not historical runs
- [ ] The global freshness badge is coarse and operational
- [ ] The page no longer presents mock cashflow, mock portfolio, or fake history as if they were real reporting features
- [ ] Net Worth card shows name, description, status, as-of date, compact per-currency summary, and open link
- [ ] Global refresh action is visible and wired to async reporting refresh
- [ ] UI remains minimal, readable, and aligned with existing app conventions

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/reports_live.ex
lib/aurum_finance_web/live/reports_live.html.heex
lib/aurum_finance_web/router.ex
assets/css/
test/aurum_finance_web/live/
```

### Constraints
- Do not overload the hub with detailed freshness semantics
- Preserve the app layout conventions and LiveView patterns already in use
- Keep maintenance-only controls secondary if they remain at all

## Execution Instructions

### For the Agent
1. Remove the mock reporting content first.
2. Build the hub around the real Net Worth card and global refresh action.
3. Keep copy and layout honest about current feature scope.

### For the Human Reviewer
1. Validate that `/reports` now reads as a hub, not a fake dashboard.
2. Confirm the card content and coarse freshness semantics feel correct.
3. Approve before Task 05 begins.

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

