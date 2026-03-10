# Task 07: PubSub Notifications for Review and Materialization

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 05, 06
- **Blocks**: Tasks 08, 10, 11, 12, 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements backend event wiring and state-notification patterns.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 07 from `llms/tasks/017_import_review_queue_materialization/07_pubsub_notifications_for_review_and_materialization.md`.
>
> Read the full milestone plan and Tasks 05-06 outputs first. Implement PubSub notifications for review and materialization lifecycle changes, but do not build the LiveView UI in this step.

## Objective
Extend the existing import PubSub pattern to cover review changes and materialization-run status changes, while preserving the rule that PubSub is notification-only and LiveViews must reload durable state.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 05-06 outputs
- [ ] `llms/constitution.md`
- [ ] `lib/aurum_finance/ingestion/pubsub.ex`
- [ ] `lib/aurum_finance_web/live/import_details_live.ex`

## Expected Outputs

- [ ] PubSub topic/event additions for materialization lifecycle
- [ ] Any helper API additions required by LiveViews
- [ ] Notification payload contract documentation
- [ ] Backend tests for broadcast behavior if needed

## Acceptance Criteria

- [ ] Materialization lifecycle changes can notify the imported-file details page
- [ ] Optional review-decision updates can notify the details page if counts/state change
- [ ] PubSub remains notification-only; durable state remains the source of truth
- [ ] Topic scoping remains account/imported-file aware rather than global

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/pubsub.ex           # Existing import PubSub helper pattern
lib/aurum_finance_web/live/import_details_live.ex # Current subscriber and reload behavior
test/aurum_finance_web/live/                    # LiveView refresh test patterns
```

### Patterns to Follow
- Reuse the imported-file detail topic when possible
- Broadcast compact payloads and let the UI reload
- Keep account-scoped and imported-file-scoped subscriptions explicit

### Constraints
- No UI rendering changes in this task
- Do not introduce PubSub-only state

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Extend PubSub helpers for materialization lifecycle and any review-state refresh needs.
3. Keep payloads minimal and durable-state-friendly.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify topic scoping is correct and non-global.
3. Check that PubSub still acts only as a notification layer.
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
