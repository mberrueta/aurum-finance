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
### Work Performed
- Added direct unit coverage for the ledger PubSub event contract, including deduplicated `account_ids` and the emitted business-date `from_date`
- Extended reporting schema/projection tests to cover the persisted unique `account_id + snapshot_date` constraint and explicit rebuild behavior for a liability account
- Reviewed the existing reporting/worker/bridge/materialization tests against the Task 08 acceptance criteria and kept the already-complete coverage in place rather than duplicating it
- Updated `docs/qa/test_plan.md` with a scenario-to-test mapping for the daily balance snapshot backend scope

### Outputs Created
- `test/aurum_finance/ledger/pubsub_test.exs`
- Updates in `test/aurum_finance/reporting/daily_balance_snapshot_test.exs`
- Updates in `docs/qa/test_plan.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Existing coverage in reporting/worker/bridge tests was already sufficient for most Task 08 semantics | Tasks 03-07 had already introduced deterministic tests for rebuild semantics, Oban enqueue behavior, and ledger trigger integration |
| A liability-account rebuild test is the highest-signal way to make “all accounts regardless of account type” explicit | The suite already covered asset, expense, and income behavior indirectly, so a liability case closes the most meaningful remaining gap |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Add a small direct `Ledger.PubSub` unit test module | Rely only on the integration tests in `ledger_test.exs` and `ledger_event_bridge_test.exs` | A direct contract test makes the event payload shape easier to audit and isolates deduplication semantics from broader integration behavior |
| Extend the existing snapshot test module instead of creating a second reporting engine test file | Split new cases into another test file | The current `daily_balance_snapshot_test.exs` already owns the projection/schema contract and is the clearest home for these additional cases |
| Document Task 08 coverage in `docs/qa/test_plan.md` | Keep coverage undocumented outside the task markdown | The QA agent instructions explicitly ask for a scenario-to-file mapping, and the existing repo already uses that document for prior test planning |

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
