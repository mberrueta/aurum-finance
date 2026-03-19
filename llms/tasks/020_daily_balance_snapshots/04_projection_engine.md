# Task 04: Projection Engine

## Status
- **Status**: COMPLETE
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 05

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 03 outputs, and the approved plan before starting implementation.

## Objective
Implement the versioned Daily Balance Snapshots rebuild engine in `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`, including range discovery, daily delta aggregation, carry-forward generation, and explicit full forward-range replacement.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/03_reporting_projection_schema_and_module.md`
- [ ] Completed outputs from Task 03
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ledger.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`
- [ ] `lib/aurum_finance/ledger/transaction.ex`
- [ ] `lib/aurum_finance/ledger/posting.ex`

## Expected Outputs

- [ ] `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`
- [ ] Internal helpers for effective movement query and range discovery
- [ ] Transactional replace strategy for forward rebuilds

## Acceptance Criteria

- [ ] Uses `transaction.date` as the business grouping key
- [ ] Matches `Ledger.get_account_balance/2` void semantics by summing all persisted postings so voided originals and their system reversals net to zero
- [ ] Covers all accounts regardless of account type
- [ ] Generates one row per calendar day between first and last effective dates
- [ ] Carries `closing_balance` forward on gap days
- [ ] Writes `daily_delta = 0` on no-movement days
- [ ] Stops at last effective date, not today
- [ ] Derives `entity_id` from the resolved account
- [ ] Uses full forward-range replacement, not partial diffing
- [ ] Persists `computed_at` and `projection_version`
- [ ] `from_date = nil` rebuilds from `first_effective_date`
- [ ] `from_date < first_effective_date` rebuilds from `first_effective_date`
- [ ] `from_date > last_effective_date` is a no-op and must not delete existing snapshots
- [ ] if snapshots already exist and a rebuild is requested with an older date, the engine replaces the full forward range from that older effective start date
- [ ] Public API/docs remain explicit and auditable

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting/projections/
lib/aurum_finance/ledger.ex
lib/aurum_finance/ledger/transaction.ex
lib/aurum_finance/ledger/posting.ex
```

### Constraints
- Do not implement Oban job logic here
- Do not implement reporting UI here
- Keep rebuild semantics forward-cumulative and simple
- Do not invent alternative `from_date` behavior beyond the approved contract above

## Execution Instructions

### For the Agent
1. Read all inputs and Task 03 outputs.
2. Implement the V1 projection module and its private helpers.
3. Keep `replace_snapshot_range` explicit and auditable.
4. Implement the `from_date` contract exactly as approved in the acceptance criteria.
5. Document any assumptions around prior-balance bootstrap and empty-account behavior.

### For the Human Reviewer
1. Check that series semantics match the approved plan.
2. Verify the implementation does not leak report-specific filtering into the base projection.
3. Approve before Task 05 begins.

---

## Execution Summary

### Work Performed
- Implemented the V1 rebuild engine directly in `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`
- Added effective date-range discovery from persisted ledger postings joined to `transaction.date`
- Added grouped daily movement aggregation that sums all persisted postings without filtering out voided originals, so reversal pairs net naturally to zero
- Added forward-cumulative series generation with gap-day carry-forward and `daily_delta = 0` on no-movement days
- Added transactional full forward-range replacement using `delete >= effective_from_date` plus bulk `insert_all`
- Added focused ExUnit coverage for bootstrap semantics, older/later `from_date` handling, gap days, stale cleanup, and void behavior

### Outputs Created
- `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
- `test/aurum_finance/reporting/daily_balance_snapshot_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The rebuild engine may compute prior balance directly from ledger facts instead of relying on existing snapshots | This keeps partial forward rebuilds correct even when no prior snapshot rows exist yet |
| Accounts with no persisted postings should clear stale snapshot rows and finish successfully | The approved refresh algorithm explicitly calls for deleting stale snapshots when an account no longer has effective transactions |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Bootstrap later rebuilds from a ledger-derived prior closing balance | Depend on the previous persisted snapshot row before `effective_from_date` | Ledger-derived bootstrap avoids hidden coupling to snapshot completeness and keeps rebuild correctness explicit |
| Keep range discovery and movement aggregation as private helpers inside `V1` | Move them to the future reporting context in Task 05 | Task 04 explicitly scopes the engine behavior to `V1`, and the context can wrap these semantics later without duplicating logic |
| Return explicit status maps from `rebuild/2` (`:rebuilt`, `:noop`, `:deleted_stale`) | Return only `:ok` | The richer result keeps manual debugging and later context/worker integration auditable without adding separate query APIs yet |

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
