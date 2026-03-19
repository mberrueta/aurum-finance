# Task 04: Projection Engine

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
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
