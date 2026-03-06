# Task 05: Test Coverage

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 02, 03
- **Blocks**: Task 06

## Assigned Agent
`qa-elixir-test-author` - Designs and implements deterministic ExUnit/LiveView coverage.

## Agent Invocation
Use `llms/agents/qa_elixir_test_author.md` (`name: qa-elixir-test-author`) to implement tests for entity model, CRUD flows, archive behavior, and generic audit events.

## Objective
Provide complete deterministic test coverage for the issue acceptance criteria, including no-hard-delete guarantees and audit traceability.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] Task 01 output
- [ ] Task 02 output
- [ ] Task 03 output
- [ ] Existing test patterns under `test/`

## Expected Outputs
- [ ] Context tests for create/update/archive/list semantics
- [ ] Validation tests for entity changeset and canonical enum/fields
- [ ] Fiscal residency behavior tests for the selected decision:
  - write-time default from `country_code` when `fiscal_residency_country_code` is omitted
- [ ] Audit event tests for create/update/archive
- [ ] LiveView tests for list/new/edit/archive interactions with stable selectors

## Acceptance Criteria
- [ ] Tests assert soft archive via `archived_at` and absence of hard delete flows
- [ ] Tests assert write-time fiscal residency default behavior (`country_code` -> `fiscal_residency_country_code`)
- [ ] Tests assert audit events include required shape fields
- [ ] Tests avoid brittle raw-HTML assertions and use LiveView helpers/selectors
- [ ] `mix test` passes

## Technical Notes
### Relevant Code Locations
`test/aurum_finance/`  
`test/aurum_finance_web/live/`  
`test/support/`

### Patterns to Follow
- `start_supervised!/1` for process lifecycles.
- LiveView tests with `element/2`, `has_element?/2`.
- Deterministic, no sleeps.

### Constraints
- Keep tests scoped to #10 deliverables.
- Do not skip coverage for audit behavior.

## Execution Instructions
### For the Agent
1. Add context/model tests.
2. Add LiveView behavior tests.
3. Validate with `mix test`.
4. Document assumptions and gaps.

### For the Human Reviewer
1. Review coverage vs acceptance criteria.
2. Confirm critical paths (archive/audit) are tested.
3. Confirm tests include non-unique `tax_identifier`, write-time fiscal residency default, and archived-entity edit behavior.
4. Approve before final review/handoff.

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
# human only
```
