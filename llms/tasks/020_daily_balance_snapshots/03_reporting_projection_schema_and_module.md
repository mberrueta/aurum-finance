# Task 03: Reporting Projection Schema and Module

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
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
