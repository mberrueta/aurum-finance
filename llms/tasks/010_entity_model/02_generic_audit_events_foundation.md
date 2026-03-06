# Task 02: Generic Audit Events Foundation

## Status
- **Status**: ✅ COMPLETED
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
- [ ] `actor` format is defined and implemented as string (`"system"`, `"person"`, `"scheduler"`, etc.)
  - rationale documented: single-user app, actor ID map does not add meaningful value now
- [ ] Channel semantics support at least:
  - `web`, `system`, `mcp`, `ai_assistant`
- [ ] Entity context integration that logs create/update/archive events synchronously via `Audit.with_event/3`

## Acceptance Criteria
- [ ] No entity-specific one-off audit structure introduced
- [ ] `occurred_at` used explicitly (not generic `timestamp` naming)
- [ ] `before`/`after` capture old/new values for explainability
- [ ] `actor` is persisted/handled as plain string
- [ ] Audit logging executes for all entity changes in scope
- [ ] `mix compile` succeeds

## Technical Notes
### Relevant Code Locations
`priv/repo/migrations/`  
`lib/aurum_finance/` (audit model/context placement)
`lib/aurum_finance/entities.ex`

### Patterns to Follow
- Generic model reusable across domains.
- Centralize audit orchestration in `Audit.with_event/3` (avoid per-context duplication).

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
- Added generic `audit_events` persistence model (migration + schema + context).
- Implemented `Audit.with_event/3` as centralized wrapper for sync audit logging.
- Integrated entity `create/update/archive` flows through `Audit.with_event/3`.
- Implemented canonical audit shape including `occurred_at`, `before`, `after`, string `actor`, and typed `channel`.
- Added snapshot redaction support (`redact_fields`) to avoid leaking sensitive fields in audit payloads.
- Aligned Task 01 model decisions while integrating Task 02:
  - write-time default from `country_code` to `fiscal_residency_country_code`
  - no unique restriction for `tax_identifier`
  - archived entities remain editable by normal update flow.

### Outputs Created
- `priv/repo/migrations/20260306190830_create_audit_events.exs`
- `lib/aurum_finance/audit/audit_event.ex`
- `lib/aurum_finance/audit.ex`
- `lib/aurum_finance/entities.ex` (updated with audit integration)
- `lib/aurum_finance/entities/entity.ex` (updated with fiscal residency write-time default)

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| `audit_events.entity_id` can be `:binary_id` in this phase | Current domain IDs are UUID-based and this keeps type safety in queries |
| Default actor for system-triggered events can be `"system"` | Guarantees audit completeness when caller does not pass metadata |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| `actor` stored as plain string | structured actor map | Single-user system does not benefit from actor IDs; simpler schema/API with clear audit semantics |
| Audit orchestration centralized in `Audit.with_event/3` | context-specific `handle_audit_result` helpers | Avoids duplication and keeps audit policy consistent across contexts |
| Sync audit logging without wrapping the domain write in one DB transaction | fully transactional `Ecto.Multi` | Matches product preference for simpler flow while still surfacing audit failures explicitly |
| `channel` modeled as enum-like constrained atom (`Ecto.Enum`) | free-form string | Keeps values bounded to agreed channels (`web/system/mcp/ai_assistant`) |

### Blockers Encountered
- Initial migration generation required escalated execution due sandbox restrictions (`Mix.PubSub` socket).

### Questions for Human
1. Approve Task 02 so Task 03 and Task 05 can proceed against the final audit contract (`with_event`, string actor, redaction support).

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

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
