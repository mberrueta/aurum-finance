# Task 06: Refresh Worker and Enqueue Path

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: None
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

### Work Performed
- Added `AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker` as the Oban worker for asynchronous snapshot refreshes
- Added `AurumFinance.Reporting.enqueue_daily_balance_snapshot_refresh/3` as the reporting-owned enqueue path
- Added the `:reporting` queue to Oban configuration
- Implemented account-based uniqueness on the worker and used the uniqueness conflict row as the enqueue-time merge point
- Normalized `from_date = nil` into a persisted sentinel meaning “rebuild from first effective date”
- Added a runtime fallback in the worker that inspects sibling pending refresh jobs for the same account and reuses the oldest visible `from_date`
- Added focused ExUnit coverage for job building, enqueue merge behavior, nil normalization, invalid/stale job handling, and end-to-end queue draining

### Outputs Created
- `lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`
- `test/aurum_finance/reporting/daily_balance_snapshot_refresh_worker_test.exs`
- `config/config.exs`
- `lib/aurum_finance/reporting.ex`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Oban uniqueness conflict returns the existing job row for the same account | This makes it possible to keep the merge logic simple by updating the conflicted row instead of introducing a side table or generalized orchestration state |
| Queue-time merge may still be imperfect under race conditions, so the worker should inspect sibling pending jobs at runtime | Task 06 explicitly requires correctness to beat dedupe convenience and asks for a defensive runtime fallback |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Use a persisted sentinel string for `from_date = nil` | Leave `from_date` absent from args | The task explicitly requires nil to be normalized before enqueueing while preserving the semantic “rebuild from first effective date” |
| Merge on the uniqueness conflict job row returned by `Oban.insert/1` | Pre-query pending jobs and then insert/update separately | Letting Oban hand back the conflicted row is simpler and more reliable than a separate best-effort lookup before insert |
| Keep runtime fallback scoped to sibling pending jobs for the same account | Add extra state tables to track the earliest requested date | The plan explicitly forbids extra state tables and workflow machinery for this first version |

### Blockers Encountered
- None

### Questions for Human
1. None

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
