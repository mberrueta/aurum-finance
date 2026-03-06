# Task 07: Documentation and ADR/README Sync

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06
- **Blocks**: None

## Assigned Agent
`docs-feature-documentation-author` - Updates documentation to match implemented behavior.

## Agent Invocation
Use `llms/agents/docs_feature_documentation_author.md` (`name: docs-feature-documentation-author`) to synchronize docs with canonical #10 decisions and implementation.

## Objective
Update all relevant docs and ADR references so terminology, model semantics, and behavior remain in sync with the delivered implementation.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] Tasks 01-06 outputs
- [ ] `README.md`
- [ ] `docs/domain-model.md`
- [ ] `docs/architecture.md`
- [ ] Applicable ADRs (including `docs/adr/0009-multi-entity-ownership-model.md`)

## Expected Outputs
- [ ] Documentation updates reflecting canonical terms:
  - `:individual`, `:legal_entity`, `:trust`, `:other`
  - `tax_identifier`
  - `archived_at` archive semantics
  - generic `audit_events` model with `actor` as string (single-user rationale documented)
- [ ] Removal/replacement of stale terms (`person/company`, `tax_id`, `is_active` archive language where obsolete)
- [ ] Sync note in task output confirming updated files

## Acceptance Criteria
- [ ] README/docs/ADRs are consistent with actual implementation and plan decisions
- [ ] Ownership boundary is explicitly documented (entity-scoped accounts/holdings)
- [ ] Archive and audit semantics are consistent everywhere
- [ ] No contradictory terminology remains in touched docs

## Technical Notes
### Relevant Code Locations
`README.md`  
`docs/domain-model.md`  
`docs/architecture.md`  
`docs/adr/`

### Patterns to Follow
- Prefer precise domain language over broad prose.
- Keep docs implementation-aligned and versionable.

### Constraints
- No feature-scope expansion.
- Sync only what is impacted by #10.

## Execution Instructions
### For the Agent
1. Find all impacted docs and references.
2. Update terminology and behavioral descriptions.
3. Produce concise change summary by file.
4. List any remaining doc inconsistencies for follow-up.

### For the Human Reviewer
1. Verify terminology and semantics are consistent.
2. Confirm no outdated model references remain.
3. Approve task and close issue workstream when done.

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
