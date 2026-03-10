# Task 10: Materialization Results and Traceability UI

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 06, 07, 08, 09
- **Blocks**: Tasks 11, 12, 13

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements results displays, progress states, and traceability surfaces for data workflows.

## Agent Invocation
Activate `dev-frontend-ui-engineer` with:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 10 from `llms/tasks/017_import_review_queue_materialization/10_materialization_results_and_traceability_ui.md`.
>
> Read the full milestone plan and Tasks 06-09 outputs first. Surface materialization progress, outcomes, and row-to-transaction traceability on the imported-file details page.

## Objective
Show durable materialization outcomes on the imported-file details page, including run summaries, row-level committed/skipped/failed state, and links or identifiers for created transactions where applicable.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 06-09 outputs
- [ ] `llms/constitution.md`
- [ ] `lib/aurum_finance_web/live/import_details_live.ex`
- [ ] `lib/aurum_finance_web/live/import_details_live.html.heex`
- [ ] materialization run/result query outputs from backend tasks

## Expected Outputs

- [ ] Materialization summary UI on the imported-file details page
- [ ] Row-level committed/skipped/failed indicators
- [ ] Transaction traceability links or identifiers where available
- [ ] LiveView tests for progress and final results rendering

## Acceptance Criteria

- [ ] Users can see pending/processing/completed/failed materialization state on the details page
- [ ] Users can see row-level committed/skipped/failed outcomes after a run
- [ ] Created transactions are traceable from the row-level UI when available
- [ ] The page refreshes correctly via PubSub and durable state reloads
- [ ] The UI remains usable for large result sets

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/import_details_live.ex
lib/aurum_finance_web/live/import_details_live.html.heex
test/aurum_finance_web/live/import_details_live_test.exs
lib/aurum_finance_web/router.ex                  # Existing transaction route context if linking
```

### Patterns to Follow
- Reuse the imported-file details page instead of redirecting to a separate result screen
- Treat durable run state as the source of truth
- Preserve the existing summary-card approach from the page

### Constraints
- Do not introduce a polling-only solution
- Do not hide failures inside only flash messages; durable results must remain inspectable

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Add summary/result UI and row-level traceability indicators.
3. Ensure PubSub refreshes rehydrate the correct durable state.
4. Add LiveView tests for progress and final outcomes.
5. Document all assumptions in "Execution Summary".
6. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify results remain understandable after page refresh or reconnect.
3. Check that row-to-transaction traceability is visible enough for debugging.
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
