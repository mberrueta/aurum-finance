# Task 06: Refresh Worker and Enqueue Path

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: Task 07

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 05 outputs, and the approved plan before starting implementation.

## Objective
Implement the Oban worker and enqueue path for asynchronous snapshot refresh, keeping the behavior intentionally simple: job args are `account_id + from_date`, uniqueness is account-based, and enqueueing prefers the oldest known `from_date` without extra state tables.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/05_reporting_context_api.md`
- [ ] Completed outputs from Task 05
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/application.ex`
- [ ] `lib/aurum_finance/ingestion/import_worker.ex`
- [ ] `lib/aurum_finance/ingestion/materialization_worker.ex`

## Expected Outputs

- [ ] `AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker`
- [ ] Enqueue path in reporting context/orchestrator
- [ ] Oban configuration updated to include the `:reporting` queue
- [ ] Simple account-based debounce behavior

## Acceptance Criteria

- [ ] Worker receives `account_id` and `from_date`
- [ ] Worker queue and scheduling follow existing Oban house style
- [ ] Oban configuration includes the `:reporting` queue required by the worker
- [ ] Uniqueness groups jobs by `account_id`
- [ ] Enqueue path prefers the oldest known `from_date`
- [ ] The enqueue path must preserve the oldest requested `from_date` for a pending refresh of the same account
- [ ] A minimal implementation may inspect and update an existing queued or scheduled job, or use another equally simple approach consistent with current Oban house style
- [ ] The worker does not rely on extra state tables or generalized workflow machinery to preserve the oldest date
- [ ] `from_date = nil` is normalized before enqueueing to the semantic “rebuild from first effective date”, and the execution path still applies the approved clamp/no-op rules
- [ ] The execution path, not queue state alone, remains responsible for the final `first_effective_date` / `last_effective_date` clamp rules
- [ ] Correctness beats enqueue dedupe convenience: if pending-job arg merge is not fully reliable with the chosen Oban approach, the execution path must defensively recompute from the earliest safe date visible at runtime for that account
- [ ] It is not acceptable for account-based uniqueness to silently lose an older requested rebuild date for the same account
- [ ] Implementation stays simple and does not add extra state tables or workflow registries
- [ ] Worker delegates synchronous rebuild to reporting context/rebuild layer
- [ ] Invalid or stale job conditions fail safely

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/application.ex
lib/aurum_finance/ingestion/import_worker.ex
lib/aurum_finance/ingestion/materialization_worker.ex
lib/aurum_finance/reporting/
```

### Constraints
- Keep fine-grained merge semantics intentionally minimal
- Do not introduce generalized operational pipeline state
- Do not use best-effort-only debounce semantics that can lose an older requested rebuild date for the same account
- If enqueue-time merge is imperfect, correctness must be recovered in the execution path rather than accepted as eventual loss

## Execution Instructions

### For the Agent
1. Read Task 05 outputs first.
2. Implement the worker and the enqueue helper together.
3. Preserve the oldest requested `from_date` for pending refreshes of the same account using a minimal approach consistent with current Oban house style.
4. Keep the `from_date` merge strategy minimal and documented.
5. Add a defensive runtime fallback so execution still rebuilds from the earliest safe date if queue-time merge semantics are not fully trustworthy.
6. Record any assumptions about Oban uniqueness behavior in the execution summary.

### For the Human Reviewer
1. Check that the enqueue path still matches the simple agreed behavior.
2. Confirm the required `:reporting` queue was added to Oban configuration.
3. Reject any hidden operational framework creep.
4. Approve before Task 07 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
