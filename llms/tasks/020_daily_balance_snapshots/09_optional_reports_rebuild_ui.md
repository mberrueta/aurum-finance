# Task 09: Optional Reports Rebuild UI

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 08
- **Blocks**: Task 10

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Task 08 outputs, and the approved plan before starting implementation.

## Objective
If scope still remains clean after the backend core is complete, add a minimal authenticated rebuild control to `ReportsLive` for manual snapshot refresh by `account_id` with optional `from_date`.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/08_backend_test_suite.md`
- [ ] Completed outputs from Tasks 01-08
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance_web/live/reports_live.ex`
- [ ] Existing form/component patterns from the web layer

## Expected Outputs

- [ ] Minimal `ReportsLive` rebuild control
- [ ] Form submission path to reporting enqueue API
- [ ] Optional LiveView smoke test if implemented

## Acceptance Criteria

- [ ] UI remains clearly technical/internal, not final reporting product UI
- [ ] User can submit `account_id` and optional `from_date`
- [ ] Submit delegates to reporting enqueue API
- [ ] Success/error feedback is shown
- [ ] No advanced job status or pipeline UI is added
- [ ] No charts, dashboards, or report rendering work is added here

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/reports_live.ex
lib/aurum_finance_web/components/
test/aurum_finance_web/live/
```

### Constraints
- This task is optional scope
- Skip this task if it expands or delays the backend core

## Execution Instructions

### For the Agent
1. Proceed only if the task status is explicitly moved to `IN_PROGRESS` or approved by the human reviewer; otherwise treat this task as skipped.
2. Keep the UI intentionally narrow and technical.
3. Reuse existing LiveView/form patterns.

### For the Human Reviewer
1. Decide whether Task 09 is worth including in this PR.
2. If scope feels noisy, skip Task 09 and proceed directly to Task 10.

---

## Execution Summary
### Work Performed
- Added a narrow technical snapshot rebuild control to `ReportsLive`
- Implemented a schemaless LiveView form for `account_id` plus optional `from_date`
- Wired submit handling to `AurumFinance.Reporting.enqueue_daily_balance_snapshot_refresh/3`
- Added success and validation/error flash feedback without introducing job status UI or report rendering scope
- Added a dedicated LiveView test module covering render, successful enqueue, and invalid input feedback

### Outputs Created
- Updates in `lib/aurum_finance_web/live/reports_live.ex`
- `test/aurum_finance_web/live/reports_live_test.exs`
- Updates in `priv/gettext/reports.pot`
- Updates in `priv/gettext/en/LC_MESSAGES/reports.po`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| A technical UUID-driven form is acceptable for the optional maintenance surface | The task explicitly asks for an internal/manual rebuild control, not a polished report product flow |
| Invalid form input can be treated as user-visible error feedback via flash plus field errors | The task requires feedback to be shown, but does not require a richer validation UX or background job inspection |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep the rebuild control inside `ReportsLive` instead of adding a controller/action | Skip Task 09 entirely or add a separate maintenance route | Reusing the existing authenticated reports surface keeps the optional scope small and aligned with the plan |
| Use a schemaless changeset in the LiveView for validation | Introduce a dedicated rebuild-request module or push raw params directly into `Reporting` | A local changeset keeps the form deterministic, validates `from_date`, and avoids adding another production module for a very small UI |
| Preserve the existing mock report panels around the new maintenance card | Strip the page down to only the rebuild form | The task says the UI should stay internal and narrow, but not that the existing placeholder reports surface must be removed |

### Blockers Encountered
- None

### Questions for Human
1. None

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
- [ ] SKIPPED - Proceed directly to Task 10

### Feedback
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
