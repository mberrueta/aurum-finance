# Task 02: Generic Audit Events Foundation

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 05

## Assigned Agent
`dev-backend-elixir-engineer` - Implements reusable backend data models and integration points.

## Agent Invocation
Use `llms/agents/dev_backend_elixir_engineer.md` (`name: dev-backend-elixir-engineer`) to implement a generic `audit_events` foundation and integrate it into entity mutations.

## Objective
Create a generic audit model from the start and wire entity create/update/archive operations to emit audit events with full traceability metadata.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] `llms/tasks/010_entity_model/01_domain_data_model_foundation.md`
- [ ] `docs/domain-model.md` - Traceability expectations
- [ ] `docs/architecture.md` - Cross-context design expectations
- [ ] `llms/project_context.md`

## Expected Outputs
- [ ] Migration + schema for `audit_events`
- [ ] Audit event shape includes:
  - `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`
- [ ] `actor` format is defined and implemented as structured map (not string)
  - minimum keys for root-auth flows: `type`, `id`
- [ ] Channel semantics support at least:
  - `web`, `system`, `mcp`, `ai_assistant`
- [ ] Entity context integration that logs create/update/archive events transactionally

## Acceptance Criteria
- [ ] No entity-specific one-off audit structure introduced
- [ ] `occurred_at` used explicitly (not generic `timestamp` naming)
- [ ] `before`/`after` capture old/new values for explainability
- [ ] `actor` is persisted/handled as structured map (not plain string)
- [ ] Audit logging executes for all entity changes in scope
- [ ] `mix compile` succeeds

## Technical Notes
### Relevant Code Locations
`priv/repo/migrations/`  
`lib/aurum_finance/` (audit model/context placement)
`lib/aurum_finance/entities.ex`

### Patterns to Follow
- Generic model reusable across domains.
- Keep writes atomic with domain mutation operations.

### Constraints
- Do not defer audit to a later milestone.
- Avoid logging sensitive payloads beyond needed before/after traceability.

## Execution Instructions
### For the Agent
1. Implement `audit_events` migration and schema.
2. Integrate writes in entity create/update/archive flows.
3. Keep model generic and reusable.
4. Document assumptions and unresolved questions.

### For the Human Reviewer
1. Validate event shape and generic nature.
2. Verify entity actions are all audited.
3. Approve before UI/testing tasks proceed.

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
