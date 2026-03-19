# Task 03: Reporting Projection Schema and Module

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 04

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 02 outputs, and the approved plan before starting implementation.

## Objective
Introduce the reporting-side projection contract for this first PR: the `AurumFinance.Reporting.DailyBalanceSnapshot` schema and the initial `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1` module.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/02_schema_and_factory_alignment.md`
- [ ] Completed outputs from Task 02
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ledger/account.ex`

## Expected Outputs

- [ ] `AurumFinance.Reporting.DailyBalanceSnapshot`
- [ ] `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`

## Acceptance Criteria

- [ ] `DailyBalanceSnapshot` schema matches the approved table shape
- [ ] `DailyBalanceSnapshot.entity_id` is treated as derived reporting data, not caller-trusted external input
- [ ] `projection_version` remains a persisted field on snapshot rows even though the first PR calls `V1` directly
- [ ] No speculative resolver layer is introduced before a second projection version exists
- [ ] Module docs may reference that rebuild semantics are owned by the projection engine and reporting context contracts, not by the schema/module layer
- [ ] Public API/docs remain explicit and auditable

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting/
lib/aurum_finance/reporting/projections/
```

### Constraints
- Do not implement projection rebuild logic here
- Do not implement Oban job logic here
- Do not implement reporting UI here
- Do not make the schema/module layer the owner of rebuild runtime semantics

## Execution Instructions

### For the Agent
1. Read all inputs and Task 02 outputs.
2. Implement the reporting schema and initial `V1` projection module only.
3. Keep the module surface minimal and explicit.
4. Keep module docs focused on schema ownership and the decision to call `V1` directly in this PR.
5. Document any assumptions around schema ownership and future versioning.

### For the Human Reviewer
1. Check that the reporting schema and initial projection module match the approved plan.
2. Verify the first PR avoids speculative resolver infrastructure while preserving `projection_version` on persisted rows.
3. Approve before Task 04 begins.

---

## Execution Summary

### Work Performed
- Added `AurumFinance.Reporting.DailyBalanceSnapshot` with the persisted reporting projection fields, constraints, and schema-level documentation for derived `entity_id`
- Added `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1` as the first explicit projection contract module
- Kept `V1` intentionally minimal by exposing the persisted projection version and a changeset builder that derives `account_id`, `entity_id`, and `projection_version` from the resolved account/module contract
- Added focused ExUnit coverage for the schema contract and the V1-derived field behavior
- Verified the new reporting slice with targeted tests and `mix precommit`

### Outputs Created
- `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
- `test/aurum_finance/reporting/daily_balance_snapshot_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The first PR only needs a stable projection contract, not runtime rebuild behavior | Task 03 explicitly forbids implementing rebuild logic or worker orchestration here |
| `entity_id` should be derived from the resolved account in the projection contract layer | The approved plan treats `entity_id` as denormalized reporting data rather than caller-trusted input |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep `DailyBalanceSnapshot.changeset/2` as the persisted row schema contract | Collapse all row-building into `V1` only | The schema should still describe the stored row shape independently of projection versioning |
| Put derived-field ownership in `V1.changeset/3` | Let callers pass `entity_id` and `projection_version` directly | This keeps the first version auditable and prevents external input from owning derived reporting fields |
| Avoid introducing a resolver/version dispatcher | Add a version resolver before a second version exists | The plan explicitly rejects speculative resolver infrastructure in the first PR |

### Blockers Encountered
- None; Task 02 outputs were already in place and the new reporting contract compiled cleanly

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
