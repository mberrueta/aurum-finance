# Task 06: Materialization Worker and Async Orchestrator

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 01, 03, 04, 05
- **Blocks**: Tasks 07, 08, 09, 10, 11, 12, 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, business logic, and Oban-based async workflows.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 06 from `llms/tasks/017_import_review_queue_materialization/06_materialization_worker_and_async_orchestrator.md`.
>
> Read the full milestone plan and Tasks 01, 03, 04, and 05 outputs first. Implement the asynchronous materialization workflow end-to-end, but do not build the final LiveView review UI in this step.

## Objective
Implement the Oban worker and orchestration service that claims materialization runs, evaluates row eligibility, creates balanced native-currency ledger transactions/postings, records row-level outcomes, and finalizes the run state safely under retry.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 01, 03, 04, 05 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ingestion/import_worker.ex`
- [ ] `lib/aurum_finance/ledger.ex`
- [ ] `lib/aurum_finance/ledger/transaction.ex`
- [ ] `lib/aurum_finance/ledger/posting.ex`

## Expected Outputs

- [ ] Dedicated Oban worker for materialization
- [ ] Synchronous orchestration service used by the worker
- [ ] Row-eligibility evaluation and currency-mismatch handling
- [ ] Retry-safe transaction/posting creation and row-level traceability persistence

## Acceptance Criteria

- [ ] Materialization runs asynchronously through Oban
- [ ] Worker transitions run status through `pending -> processing -> complete|failed`
- [ ] Worker creates balanced transactions/postings using the clearing-account strategy
- [ ] Materialization always uses `account.currency_code` as the effective posting currency
- [ ] Rows with conflicting `imported_row.currency` produce a row-level `failed` outcome with reason `currency_mismatch`, and are never converted
- [ ] Worker is retry-safe and does not double-commit imported rows
- [ ] Row-level outcomes are persisted durably for later UI display

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/import_worker.ex     # Existing Oban pattern from imports
lib/aurum_finance/ingestion/                     # New orchestration service likely belongs here
lib/aurum_finance/ledger.ex                      # Transaction creation API
test/aurum_finance/ingestion/                    # Oban/manual drain test patterns
```

### Patterns to Follow
- Mirror issue #15 async orchestration structure where appropriate
- Treat PubSub as a later notification concern, not the state carrier
- Use DB-backed uniqueness plus app checks for idempotency

### Constraints
- Do not build LiveView UI in this task
- Do not implement FX conversion
- Do not bypass `Ledger.create_transaction/2` invariants

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Implement the worker and orchestration pipeline.
3. Apply the native-currency and clearing-account rules strictly.
4. Persist row-level outcomes and top-level run outcomes durably.
5. Document all assumptions in "Execution Summary".
6. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify retry safety and double-commit prevention carefully.
3. Check that ledger creation remains native-currency only.
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
