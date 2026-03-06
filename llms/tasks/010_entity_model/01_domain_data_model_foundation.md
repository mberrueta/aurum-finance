# Task 01: Domain + Data Model Foundation

## Status
- **Status**: 🔄 IN_PROGRESS
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Tasks 02, 03, 04

## Assigned Agent
`dev-backend-elixir-engineer` - Implements schemas, contexts, queries, and backend invariants.

## Agent Invocation
Use `llms/agents/dev_backend_elixir_engineer.md` (`name: dev-backend-elixir-engineer`) to deliver the canonical Entities foundation for issue #10.

## Objective
Create the `Entity` schema and context APIs aligned with ADR/domain definitions, including canonical enum and soft archive via `archived_at`, with no hard delete path.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md` - Master execution plan
- [ ] `https://github.com/mberrueta/aurum-finance/issues/10` - Source requirements
- [ ] `docs/domain-model.md` - Multi-entity and ownership definitions
- [ ] `docs/architecture.md` - Context and boundary model
- [ ] `docs/adr/0009-multi-entity-ownership-model.md` - Canonical entity semantics
- [ ] `llms/project_context.md` - Project conventions

## Expected Outputs
- [ ] Entity migration with canonical fields:
  - `id`, `name`, `type`, `tax_identifier`, `country_code`, `fiscal_residency_country_code`, `default_tax_rate_type`, `notes`, `archived_at`, timestamps
- [ ] `AurumFinance.Entities.Entity` schema with enum values:
  - `:individual`, `:legal_entity`, `:trust`, `:other`
- [ ] `AurumFinance.Entities` context public API:
  - `list_entities/1`, `get_entity!/1`, `create_entity/1`, `update_entity/2`, `archive_entity/1`, `change_entity/2`
- [ ] No hard-delete public API

## Acceptance Criteria
- [ ] `tax_identifier` naming is used everywhere (no `tax_id`)
- [ ] `tax_identifier` has no unique restriction
- [ ] `fiscal_residency_country_code` defaults from `country_code` at write time when omitted
- [ ] Archive is implemented through `archived_at` (not `is_active` as primary mechanism)
- [ ] Archived entities remain editable through update flow
- [ ] Context follows project conventions (`list_*` opts, private `filter_query/2`)
- [ ] Public context methods have docs and doctests where relevant
- [ ] `mix compile` succeeds

## Technical Notes
### Relevant Code Locations
`priv/repo/migrations/`  
`lib/aurum_finance/entities/`  
`lib/aurum_finance/entities.ex`

### Patterns to Follow
- Context API and filtering conventions from `llms/constitution.md`.
- Ecto schema required/optional field declaration.
- I18n validation messages via `dgettext("errors", ...)`.

### Constraints
- No hard delete behavior.
- No unrelated domain expansion beyond Entity foundation.

## Execution Instructions
### For the Agent
1. Implement migration and schema fields exactly as defined in plan.
2. Implement context APIs and filtering semantics.
3. Ensure public methods include docs/doctests where relevant.
4. Validate compile and document assumptions.
5. Prepare clear handoff for Task 02/03/04.

### For the Human Reviewer
1. Verify canonical enum and field naming.
2. Confirm archive behavior uses `archived_at`.
3. Confirm no hard-delete API exists.
4. Approve before Task 02 starts.

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
