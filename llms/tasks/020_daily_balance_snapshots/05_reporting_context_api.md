# Task 05: Reporting Context API

## Status
- **Status**: COMPLETE
- **Approved**: [x] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 06

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 04 outputs, and the reporting plan before starting implementation.

## Objective
Create `AurumFinance.Reporting` as the public API surface for snapshot listing and synchronous refresh execution.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/04_projection_engine.md`
- [ ] Completed outputs from Task 04
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] Existing context patterns such as `lib/aurum_finance/ledger.ex` and `lib/aurum_finance/ingestion.ex`

## Expected Outputs

- [ ] New context module `lib/aurum_finance/reporting.ex`
- [ ] Public list/refresh API
- [ ] Internal helper structure matching project conventions

## Acceptance Criteria

- [ ] Exposes `list_daily_balance_snapshots/1`
- [ ] Keeps snapshot query composition internal to the context unless a real external consumer appears
- [ ] Exposes one synchronous refresh entrypoint for worker/manual use
- [ ] Query APIs use `opts` and `filter_query/2` style where appropriate
- [ ] Refresh entrypoint is account-scoped and explicit, taking `%Account{}` instead of reloading by id
- [ ] Public rebuild/refresh APIs define `from_date` explicitly:
- [ ] `nil` means bootstrap from the account’s first effective ledger date
- [ ] dates earlier than `first_effective_date` clamp to `first_effective_date`
- [ ] dates later than `last_effective_date` return a no-op result and do not delete existing snapshots
- [ ] older requested dates expand rebuild scope backward and force forward-range replacement from that earlier effective start date
- [ ] Public functions have `@doc`
- [ ] No report-rendering semantics are embedded in this context

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/ledger.ex
lib/aurum_finance/ingestion.ex
```

### Constraints
- Keep context focused on projection access and rebuild orchestration
- Do not add job uniqueness implementation details beyond what the plan requires
- Do not leave `from_date` behavior implicit in public API contracts

## Execution Instructions

### For the Agent
1. Read Task 04 outputs first.
2. Model the context API after existing `list_*` and scoped helper patterns.
3. Keep the synchronous refresh entrypoint explicit and small.
4. Make the `from_date` contract explicit in `@doc` and return semantics.
5. Leave queue merge and runtime safety behavior to Task 06, but keep the API contract compatible with it.
6. Document any public API tradeoffs in the execution summary.

### For the Human Reviewer
1. Review context naming and public API surface.
2. Confirm no report-layer semantics leaked into the base context.
3. Approve before Task 06 begins.

---

## Execution Summary

### Work Performed
- Added `AurumFinance.Reporting` as the public projection access context
- Implemented `list_daily_balance_snapshots/1` with a private query helper and `opts`-driven filtering for `account_id`, `entity_id`, `date_from`, and `date_to`
- Implemented one explicit synchronous refresh entrypoint that pattern matches on `%Account{}` and delegates rebuild execution to `V1` without reloading the account
- Added explicit helper functions for `earliest_snapshot_date_for_account/1` and `latest_snapshot_date_for_account/1` that also work from `%Account{}`
- Added focused ExUnit coverage for list filtering, refresh behavior, no-op behavior, and earliest/latest snapshot helpers

### Outputs Created
- `lib/aurum_finance/reporting.ex`
- `test/aurum_finance/reporting_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The first public reporting context can call `V1` directly without a version resolver | The approved plan explicitly says the first PR should avoid speculative resolver infrastructure until a second projection version exists |
| Worker/manual callers will already have a resolved `%Account{}` when they invoke the synchronous refresh path | The user asked to avoid redundant account reloads when the account is already in memory |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep only `refresh_daily_balance_snapshots/3` as the synchronous public entrypoint | Also expose a second `rebuild_daily_balance_snapshots/2` alias | A second public function that only forwards the same behavior adds naming noise without adding capability |
| Accept `%Account{}` in the synchronous refresh and snapshot-date helper APIs | Accept only `account_id` and reload the account inside the context | These APIs operate on one already-resolved account, so taking the struct avoids redundant DB reads and keeps ownership explicit via pattern matching |
| Keep the list query builder private to the context | Expose `list_daily_balance_snapshots_query/1` as public API | There is no current external caller that needs query composition, and keeping it private avoids leaking context internals prematurely |
| Keep list/query functions free of report-rendering joins or account-type semantics | Denormalize more reporting fields or preload extra ledger state here | Task 05 explicitly limits the context to projection access and rebuild orchestration, not report rendering |

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
