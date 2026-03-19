# Task 08: Backend Test Suite

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 07
- **Blocks**: Task 09, Task 10

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer for ExUnit, integration, and Oban coverage

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file, Tasks 01-07 outputs, and the approved plan before writing tests.

## Objective
Add deterministic test coverage for migrations/schema behavior, projection semantics, worker/enqueue behavior, and ledger event/subscriber integration.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/01_migration_foundation.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/02_schema_and_factory_alignment.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/03_reporting_projection_schema_and_module.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/04_projection_engine.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/05_reporting_context_api.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/06_refresh_worker_and_enqueue.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/07_ledger_trigger_integration.md`
- [ ] Completed outputs from Tasks 01-07
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] `test/support/factory.ex`

## Expected Outputs

- [ ] Backend tests for projection semantics
- [ ] Worker/enqueue tests
- [ ] Ledger trigger tests
- [ ] Any required factory/test helper updates

## Acceptance Criteria

- [ ] Tests cover bootstrap from first effective movement date
- [ ] Tests cover gap-day carry-forward and `daily_delta = 0`
- [ ] Tests cover all accounts regardless of account type
- [ ] Tests cover report filtering being outside the base projection
- [ ] Tests cover ledger-consistent void semantics where voided originals and their system reversals net to zero in snapshot rebuilds
- [ ] Tests cover forward-range replacement behavior
- [ ] Tests cover that an account with no effective transactions deletes stale snapshots
- [ ] Tests cover that `from_date > last_effective_date` is a no-op and does not leave inconsistent forward rows
- [ ] Tests cover prior closing balance bootstrap when rebuilding from a mid-range `from_date`
- [ ] Tests cover that `entity_id` in snapshots is derived from the resolved account rather than caller-provided input
- [ ] Tests cover account-based worker uniqueness and oldest-known `from_date` preference
- [ ] Tests cover transaction creation and void event emission with all affected accounts in payload
- [ ] Tests cover reporting subscriber/bridge enqueueing per affected account from emitted ledger events
- [ ] Tests are deterministic and sandbox-safe

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/support/factory.ex
lib/aurum_finance/reporting/
lib/aurum_finance/ledger.ex
```

### Constraints
- Prefer factories over ad hoc fixtures
- Do not add timing-based flaky tests
- UI tests are not part of this task unless Task 09 is explicitly approved

## Execution Instructions

### For the Agent
1. Read all completed core-task outputs first.
2. Write backend tests only for the approved core scope.
3. Document any missing hooks or testability issues discovered.

### For the Human Reviewer
1. Verify the suite covers the approved semantics, not speculative extras.
2. Confirm the tests keep the UI scope optional.
3. Approve before Task 09 or Task 10 begins.

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
