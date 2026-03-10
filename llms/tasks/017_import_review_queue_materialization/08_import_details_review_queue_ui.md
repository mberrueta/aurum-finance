# Task 08: Import Details Review Queue UI

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 05, 06, 07
- **Blocks**: Tasks 09, 10, 11, 12, 13

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements LiveView pages, stream-based UI, interaction states, and polished interface behavior.

## Agent Invocation
Activate `dev-frontend-ui-engineer` with:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 08 from `llms/tasks/017_import_review_queue_materialization/08_import_details_review_queue_ui.md`.
>
> Read the full milestone plan and Tasks 05-07 outputs first. Extend the existing imported-file details page into the first review queue, but do not build the duplicate comparison detail experience in this step.

## Objective
Turn the current import details page into the primary review queue for one imported file by adding review controls, row segmentation, and a `Materialize` trigger while preserving stream-based rendering for large row sets.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 05-07 outputs
- [ ] `llms/constitution.md`
- [ ] `lib/aurum_finance_web/live/import_details_live.ex`
- [ ] `lib/aurum_finance_web/live/import_details_live.html.heex`
- [ ] `test/aurum_finance_web/live/import_details_live_test.exs`

## Expected Outputs

- [ ] Updated `ImportDetailsLive` and HEEx template with review controls
- [ ] `Materialize` button and disabled/loading/progress states
- [ ] Row filters/tabs or equivalent segmentation for `ready`, `duplicate`, `invalid`
- [ ] LiveView tests for review queue interactions and stream-based behavior

## Acceptance Criteria

- [ ] The imported-file details page remains the main surface for preview plus review
- [ ] A visible `Materialize` button exists on the page
- [ ] The button reflects disabled state when no rows are eligible
- [ ] Users can bulk-approve safe `ready` rows
- [ ] Users can reject rows without leaving the page
- [ ] The row list continues to use LiveView streams rather than regular assigns for large collections
- [ ] The page refreshes from durable state after PubSub notifications

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/import_details_live.ex         # Existing page logic and streams
lib/aurum_finance_web/live/import_details_live.html.heex  # Existing summary and rows table
lib/aurum_finance_web/components/                         # Shared component patterns
test/aurum_finance_web/live/import_details_live_test.exs  # Existing page test coverage
```

### Patterns to Follow
- Preserve the existing imported-row stream pattern
- Keep the details page as the primary page rather than introducing a new route in v1
- Use durable persisted state as the source of truth after events

### Constraints
- No inline scripts in HEEx
- No new standalone review page unless explicitly required later
- Do not implement duplicate side-by-side comparison in this task

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Extend the details page with review controls and materialization trigger states.
3. Preserve stream-based rendering for imported rows.
4. Add LiveView tests for the new interactions.
5. Document all assumptions in "Execution Summary".
6. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify the UI still feels like an extension of the existing details page rather than a separate flow.
3. Check stream usage and large-list friendliness.
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
