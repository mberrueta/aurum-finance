# Task 04: Reports Hub Refactor

## Status
- **Status**: COMPLETED
- **Approved**: [X] Human sign-off
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

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/03_reporting_refresh_and_live_freshness_signal.md`
- [x] Approved outputs from Tasks 02-03
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `lib/aurum_finance_web/live/reports_live.ex`
- [x] `lib/aurum_finance_web/live/reports_live.html.heex`
- [x] `lib/aurum_finance_web/router.ex`

## Expected Outputs

- [x] Refactored `/reports` LiveView
- [x] Removal of mock dashboard sections no longer in scope
- [x] Net Worth card wired to the real backend result
- [x] Global refresh action and coarse freshness badge in the hub UI

## Acceptance Criteria

- [x] `/reports` is organized around report types, not historical runs
- [x] The global freshness badge is coarse and operational
- [x] The page no longer presents mock cashflow, mock portfolio, or fake history as if they were real reporting features
- [x] Net Worth card shows name, description, status, as-of date, compact per-currency summary, and open link
- [x] Global refresh action is visible and wired to async reporting refresh
- [x] UI remains minimal, readable, and aligned with existing app conventions

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

### Work Performed
- Replaced the old mock-heavy `/reports` LiveView with a real reporting hub in [reports_live.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/reports_live.ex) and [reports_live.html.heex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/reports_live.html.heex).
- Wired the hub to `AurumFinance.Reporting.net_worth_report/2`, `AurumFinance.Reporting.subscribe_hub_freshness/0`, and `AurumFinance.Reporting.enqueue_hub_refresh/1`.
- Removed the previous fake dashboard content so the page now centers on one global freshness badge, one refresh action, and one Net Worth card.
- Added coarse live freshness updates on reporting invalidation and refresh-complete signals.
- Added/updated report copy in [reports.po](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/gettext/en/LC_MESSAGES/reports.po).
- Replaced the old LiveView test coverage with focused hub tests in [reports_live_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance_web/live/reports_live_test.exs).

### Outputs Created
- Refactored `/reports` hub UI backed by the real Net Worth read model.
- Coarse hub freshness badge with `Up to date` and `Outdated` states.
- Global refresh CTA wired to async reporting refresh enqueue-only behavior.
- Net Worth hub card showing description, status, as-of date, in-scope account count, compact per-currency summary, and open link.
- LiveView tests covering initial render, refresh enqueue behavior, and freshness badge updates after refresh completion.

### Assumptions Made
- The hub should compute its visible `entity_ids` from `Entities.list_entities/0` and pass them explicitly into the reporting APIs.
- The `/reports/net-worth` destination can remain a plain link target string in this task even if the detailed page lands in Task 05.
- The hub should stay coarse and should not surface row-level freshness or job-history details.

### Decisions Made
- Kept the hub intentionally minimal instead of preserving maintenance-oriented mock dashboard sections.
- Derived presentation-ready badge/status assigns in the LiveView so the external HEEx template stays simple and compile-safe.
- Re-read the hub on reporting freshness PubSub messages instead of trying to incrementally patch UI state from event payloads.

### Blockers Encountered
- None in the final implementation. The UI refactor needed a small follow-up to avoid relying on private helper calls directly from the external HEEx template, which was resolved by assigning derived values in the LiveView.

### Questions for Human
- Is the plain `/reports/net-worth` link target acceptable until Task 05 lands the dedicated Net Worth page and route?

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
