# Task 11: Audit Event Integration

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 05, 06, 07, 10
- **Blocks**: Tasks 12, 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements workflow-level audit integration using the existing audit model.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 11 from `llms/tasks/017_import_review_queue_materialization/11_audit_event_integration.md`.
>
> Read the full milestone plan and Tasks 05-10 outputs first. Add workflow-level audit events for review/materialization actions, but do not introduce noisy per-transaction import audit.

## Objective
Wire the review and materialization workflow into the existing generic audit system at the batch/workflow boundary.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 05-10 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/audit.ex`
- [ ] `lib/aurum_finance/audit/multi.ex`
- [ ] `lib/aurum_finance/ingestion.ex`

## Expected Outputs

- [ ] Audit integration for materialization requested/completed/failed
- [ ] Audit integration for review actions or durable batch-review actions
- [ ] Safe metadata shape aligned with current audit constraints
- [ ] Tests verifying audit events exist for workflow transitions

## Acceptance Criteria

- [ ] Review/materialization actions emit generic audit events through the existing audit model
- [ ] Audit metadata remains non-sensitive and aligned with current audit constraints
- [ ] The implementation does not emit noisy per-transaction audit for normal import materialization
- [ ] Audit events are durable and test-covered

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/audit.ex
lib/aurum_finance/audit/multi.ex
lib/aurum_finance/ingestion.ex
test/aurum_finance/audit_test.exs
```

### Patterns to Follow
- Use the current generic audit entrypoints rather than creating a parallel audit system
- Keep metadata non-sensitive
- Favor workflow-level events over low-signal transaction-level noise

### Constraints
- Do not broaden audit scope beyond this workflow
- Do not store secrets or sensitive raw row payloads in audit metadata

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Integrate workflow-level audit events into review and materialization transitions.
3. Keep metadata safe and compact.
4. Add or update tests as needed.
5. Document all assumptions in "Execution Summary".
6. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify metadata safety and audit scope.
3. Check that workflow-level audit exists without transaction-level noise.
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
