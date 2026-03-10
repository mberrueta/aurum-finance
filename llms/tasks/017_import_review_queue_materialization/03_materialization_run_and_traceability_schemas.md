# Task 03: Materialization Run and Traceability Schemas

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 01, 02
- **Blocks**: Tasks 05, 06, 07, 08, 09, 10, 11, 12, 13

## Assigned Agent
`dev-db-performance-architect` - Database architect for schema design and performance. Handles indexes, migrations, constraints, and persistence tradeoffs.

## Agent Invocation
Activate `dev-db-performance-architect` with:

> Act as `dev-db-performance-architect` following `llms/constitution.md`.
>
> Execute Task 03 from `llms/tasks/017_import_review_queue_materialization/03_materialization_run_and_traceability_schemas.md`.
>
> Read the full milestone plan and Tasks 01-02 outputs first. Design the durable materialization-run and row-to-transaction traceability schemas. Do not implement backend logic or UI in this step.

## Objective
Design the persistence contract for async materialization runs and row-level commit traceability, including idempotency guards that prevent double-commit under retries or concurrent requests.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 01-02 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ledger/transaction.ex`
- [ ] `lib/aurum_finance/ingestion/imported_file.ex`
- [ ] `lib/aurum_finance/ingestion/imported_row.ex`

## Expected Outputs

- [ ] Migration design for `import_materializations`
- [ ] Migration design for row-level materialization linkage/traceability
- [ ] Uniqueness strategy preventing the same imported row from being committed twice
- [ ] Queryability notes for imported-file detail UI and worker retry behavior

## Acceptance Criteria

- [ ] Materialization runs can be tracked independently from imported files
- [ ] Row-level materialization outcomes can be persisted durably
- [ ] There is a durable linkage from imported row to transaction
- [ ] The schema design supports the approved top-level run state model defined in Task 01
- [ ] Database constraints support retry-safe/idempotent materialization

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/imported_file.ex     # Existing async import-run pattern
lib/aurum_finance/ledger/transaction.ex          # Target ledger facts
lib/aurum_finance/ledger/posting.ex              # Target posting facts
priv/repo/migrations/                            # Migration and index patterns
```

### Patterns to Follow
- Mirror the durable run-tracking pattern already used for imports
- Enforce idempotency with DB-backed uniqueness, not only app checks
- Keep row-level traceability queryable from the imported-file detail page

### Constraints
- Do not redesign the ledger schemas themselves
- Do not fold materialization state into `imported_files`

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Propose schemas, indexes, and constraints for run tracking and row-level linkage.
3. Explicitly document the idempotency guarantees.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify that the traceability model is sufficient for debugging and UI needs.
3. Confirm the uniqueness strategy is strict enough for Oban retries.
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
