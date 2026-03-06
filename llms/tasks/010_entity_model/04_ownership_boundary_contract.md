# Task 04: Ownership Boundary Contract for Downstream Contexts

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 06

## Assigned Agent
`tl-architect` - Defines architectural contracts, boundaries, and sequencing guardrails.

## Agent Invocation
Use `llms/agents/tl_architect.md` (`name: tl-architect`) to produce ownership-boundary contract output for downstream account/holding work.

## Objective
Document and formalize the ownership contract: entity is the tenant boundary; accounts and holdings are entity-scoped; downstream context APIs must enforce scope-by-entity.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] `llms/tasks/010_entity_model/01_domain_data_model_foundation.md`
- [ ] `docs/domain-model.md`
- [ ] `docs/architecture.md`
- [ ] `docs/adr/0009-multi-entity-ownership-model.md`
- [ ] `llms/project_context.md`

## Expected Outputs
- [ ] Ownership contract note for #11/#27 integration
- [ ] Explicit invariants for entity scoping in account/holding models
- [ ] Guardrail recommendations to avoid cross-entity leakage
- [ ] Input checklist for upcoming implementation tasks

## Acceptance Criteria
- [ ] Clearly states Entity as ownership boundary
- [ ] Clearly states Accounts are entity-scoped
- [ ] Clearly states Holdings are entity-scoped
- [ ] Defines how this issue unblocks downstream work
- [ ] No implementation code changes outside planning artifacts

## Technical Notes
### Relevant Code Locations
`docs/domain-model.md`  
`docs/architecture.md`  
`docs/adr/0009-multi-entity-ownership-model.md`

### Patterns to Follow
- Keep contracts precise and implementation-oriented.
- Maintain ADR-consistent language.

### Constraints
- This is architecture guidance; no runtime behavior changes in this task.

## Execution Instructions
### For the Agent
1. Synthesize ownership semantics from ADR/domain docs.
2. Produce explicit downstream integration contract.
3. List assumptions and unresolved risks.

### For the Human Reviewer
1. Validate ownership contract completeness.
2. Confirm downstream issues can implement directly from this output.
3. Approve before handoff/review tasks continue.

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
