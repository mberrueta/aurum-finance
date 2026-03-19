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
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

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
