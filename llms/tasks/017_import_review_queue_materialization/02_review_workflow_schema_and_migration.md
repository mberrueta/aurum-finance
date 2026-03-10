# Task 02: Review Workflow Schema and Migration

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Tasks 03, 05, 07, 09, 10, 11, 12, 13

## Assigned Agent
`dev-db-performance-architect` - Database architect for schema design and performance. Handles indexes, migrations, constraints, and persistence tradeoffs.

## Agent Invocation
Activate `dev-db-performance-architect` with:

> Act as `dev-db-performance-architect` following `llms/constitution.md`.
>
> Execute Task 02 from `llms/tasks/017_import_review_queue_materialization/02_review_workflow_schema_and_migration.md`.
>
> Read the full milestone plan and Task 01 output first. Design the review workflow persistence, constraints, and migration strategy. Do not implement context logic or UI in this step.

## Objective
Design the schema and migration for durable row-review decisions without mutating the imported-row evidence model introduced in issue #15.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Task 01 output
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ingestion/imported_row.ex`
- [ ] `priv/repo/migrations/*create_imported_files_and_rows*.exs`

## Expected Outputs

- [ ] Migration design for review workflow persistence
- [ ] Schema contract for `import_row_reviews` or approved equivalent naming
- [ ] Index/constraint plan for one coherent current decision per row
- [ ] Notes on append-only vs latest-state persistence strategy

## Acceptance Criteria

- [ ] Review decisions are persisted separately from `imported_rows`
- [ ] The schema supports at least `approved`, `rejected`, and `force_approved` decisions
- [ ] The schema supports actor attribution for review actions
- [ ] Constraints prevent ambiguous or conflicting current review state per row
- [ ] The design does not repurpose imported-row evidence status for mutable workflow decisions

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/imported_row.ex      # Existing immutable evidence model
priv/repo/migrations/                            # Existing import persistence patterns
lib/aurum_finance/audit.ex                       # Workflow actions will eventually need audit
```

### Patterns to Follow
- Keep durable workflow overlays separate from immutable evidence
- Prefer database constraints over application-only assumptions
- Follow existing UUID + account-scoped migration conventions

### Constraints
- No implementation outside schema/migration design
- No UI or Oban orchestration in this task

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Propose the review schema, fields, indexes, and constraints.
3. Document tradeoffs for append-only history vs latest-state updates.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify persistence strategy matches desired auditability.
3. Check that the design stays consistent with issue #15 immutability.
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
