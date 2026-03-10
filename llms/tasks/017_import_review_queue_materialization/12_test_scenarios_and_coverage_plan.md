# Task 12: Test Scenarios and Coverage Plan

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 05, 06, 08, 09, 10, 11
- **Blocks**: Task 13

## Assigned Agent
`qa-test-scenarios` - Test scenario designer. Defines what to test across backend, Oban, and LiveView layers without writing implementation code.

## Agent Invocation
Activate `qa-test-scenarios` with:

> Act as `qa-test-scenarios` following `llms/constitution.md`.
>
> Execute Task 12 from `llms/tasks/017_import_review_queue_materialization/12_test_scenarios_and_coverage_plan.md`.
>
> Read the full milestone plan and Tasks 05-11 outputs first. Produce the definitive scenario matrix for review workflow, materialization, idempotency, native-currency guards, and LiveView progress behavior.

## Objective
Define the final test plan and scenario coverage needed before implementation is considered complete.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 05-11 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] existing import and ledger tests under `test/aurum_finance/` and `test/aurum_finance_web/live/`

## Expected Outputs

- [ ] Backend scenario matrix for review persistence and materialization
- [ ] Oban scenario matrix for async processing and retries
- [ ] LiveView scenario matrix for review queue and results UI
- [ ] Explicit coverage for currency mismatch, duplicate override, idempotency, and failure paths

## Acceptance Criteria

- [ ] Scenarios cover `ready`, `duplicate`, `invalid`, already committed, and currency-mismatch rows
- [ ] Scenarios cover bulk approval, explicit duplicate override, rejection, and materialization trigger flows
- [ ] Scenarios cover retry/idempotency behavior
- [ ] Scenarios cover PubSub-driven page refresh
- [ ] Scenarios cover audit events and traceability outcomes

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/ingestion/
test/aurum_finance_web/live/
test/aurum_finance/
```

### Patterns to Follow
- Favor outcome-oriented assertions over raw HTML snapshots
- Split backend, async, and LiveView concerns clearly
- Include edge cases that can cause silent double-commit or wrong-currency writes

### Constraints
- This task defines scenarios only; it does not implement tests

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Produce a concise but complete scenario matrix for the feature.
3. Highlight the minimum set of tests needed to prove currency and idempotency safety.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Confirm the scenario set is sufficient before test writing begins.
3. Verify native-currency and idempotency edges are explicitly covered.
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
