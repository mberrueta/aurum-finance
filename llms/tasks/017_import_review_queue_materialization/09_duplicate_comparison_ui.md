# Task 09: Duplicate Comparison UI

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 05, 06, 08
- **Blocks**: Tasks 10, 11, 12, 13

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements comparison views, interaction states, and review UX for data-heavy workflows.

## Agent Invocation
Activate `dev-frontend-ui-engineer` with:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 09 from `llms/tasks/017_import_review_queue_materialization/09_duplicate_comparison_ui.md`.
>
> Read the full milestone plan and Tasks 05, 06, and 08 outputs first. Add duplicate-candidate comparison UI to the imported-file details flow, but do not redesign the overall page or create a separate review app.

## Objective
Provide a side-by-side or equivalently clear duplicate-review experience so users can inspect incoming duplicate candidates against the matched existing record before forcing approval.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 05, 06, 08 outputs
- [ ] `llms/constitution.md`
- [ ] `lib/aurum_finance_web/live/import_details_live.ex`
- [ ] `lib/aurum_finance_web/live/import_details_live.html.heex`
- [ ] review/traceability query outputs from backend tasks

## Expected Outputs

- [ ] Duplicate comparison interaction inside the imported-file details flow
- [ ] UI for inspecting incoming row vs matched existing record
- [ ] Controls for explicit force-approval or rejection after inspection
- [ ] LiveView tests for duplicate review flow

## Acceptance Criteria

- [ ] Duplicate rows can be inspected without leaving the imported-file details context
- [ ] The UI makes clear what is existing data vs incoming data
- [ ] Users can explicitly force-approve duplicate rows after inspection
- [ ] Users can reject duplicate rows after inspection
- [ ] The UI remains usable for many rows and does not require loading all details into assigns at once

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/import_details_live.ex
lib/aurum_finance_web/live/import_details_live.html.heex
test/aurum_finance_web/live/import_details_live_test.exs
```

### Patterns to Follow
- Extend the existing page rather than creating a disconnected review flow
- Keep row selection and comparison state minimal in assigns
- Preserve the project's UI language and HEEx conventions

### Constraints
- No inline JS
- No separate route unless unavoidable

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Add duplicate comparison UI and explicit decision controls.
3. Keep the interaction within the existing details flow.
4. Add LiveView coverage for duplicate review behavior.
5. Document all assumptions in "Execution Summary".
6. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify the comparison is understandable and side-by-side enough for safe decisions.
3. Check that the interaction still fits the current page architecture cleanly.
4. If approved: mark `[x]` on "Approved" and update plan.md status.
5. If rejected: add rejection reason and specific feedback.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- 

### Outputs Created
- 

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
|  |  |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
|  |  |  |

### Blockers Encountered
- 

### Questions for Human
1. 

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
- [ ] ✅ APPROVED - Proceed to next task
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# Human-only commands, if any
```
