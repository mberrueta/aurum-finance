# Task 07: Ledger Event Integration

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 06
- **Blocks**: Task 08

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 06 outputs, and the relevant ledger modules before starting implementation.

## Objective
Emit neutral ledger domain events from final ledger write paths and add a reporting-owned subscriber/bridge so successful persisted transactions and successful void flows trigger per-account refresh from the correct business date without introducing a `Ledger -> Reporting` dependency.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/06_refresh_worker_and_enqueue.md`
- [ ] Completed outputs from Task 06
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ledger.ex`
- [ ] `lib/aurum_finance/ingestion/materialization_runner.ex`
- [ ] Application event/PubSub wiring used elsewhere in the app, if any

## Expected Outputs

- [ ] Ledger write-path integration for create/void domain event emission
- [ ] Reporting-owned subscriber/bridge for snapshot refresh enqueueing
- [ ] Per-account trigger handling for multi-account transactions

## Acceptance Criteria

- [ ] Successful `create_transaction` emits a ledger domain event after commit
- [ ] Successful `void_transaction` emits a ledger domain event after commit
- [ ] Event payload includes the transaction business date used as `from_date`
- [ ] Event payload includes all affected accounts for multi-account transactions
- [ ] Reporting subscriber/bridge enqueues refresh per affected account from the emitted event payload
- [ ] Import-created transactions inherit refresh behavior through centralized ledger paths
- [ ] Failed writes do not emit events or enqueue refresh
- [ ] Ledger does not call `AurumFinance.Reporting` directly
- [ ] Event emission happens only at the final persisted ledger boundary, not in lower-level helper functions that may be reused by previews, validations, or internal construction paths

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ledger.ex
lib/aurum_finance/reporting/
lib/aurum_finance/ingestion/materialization_runner.ex
```

### Constraints
- Do not enqueue from drafts or preview paths
- Keep ledger event emission close to successful write completion
- Do not place event hooks in reusable low-level helpers where they could be triggered by non-final or intermediate flows
- Do not introduce a direct `Ledger -> Reporting` dependency to satisfy refresh orchestration

## Execution Instructions

### For the Agent
1. Read Task 06 outputs first.
2. Add ledger domain event emission only after successful write completion.
3. Add the reporting subscriber/bridge that converts those events into enqueue requests.
4. Ensure account collection is per affected posting account, deduplicated.
5. Keep event emission at the final persisted ledger boundary rather than inside reusable helpers.
6. Document any event-delivery assumptions in the execution summary.

### For the Human Reviewer
1. Verify create/void event coverage is complete.
2. Confirm imports inherit behavior through `Ledger.create_transaction/1`.
3. Confirm `Ledger` does not directly depend on `Reporting`.
4. Approve before Task 08 begins.

---

## Execution Summary
### Work Performed
- Added `AurumFinance.Ledger.PubSub` as the neutral ledger-domain event helper for successful transaction create/void notifications
- Updated `AurumFinance.Ledger.create_transaction/2` and `AurumFinance.Ledger.void_transaction/2` to broadcast only after successful write completion from the public ledger write paths
- Added `AurumFinance.Reporting.LedgerEventBridge` as the reporting-owned subscriber that turns ledger events into per-account snapshot refresh enqueue requests
- Wired the bridge into `AurumFinance.Application` with a test-environment escape hatch so DB sandboxed tests can start bridge instances explicitly
- Added focused test coverage for ledger event emission, non-emission on failed writes, bridge enqueue behavior, and import/materialization inheritance through `Ledger.create_transaction/1`

### Outputs Created
- `lib/aurum_finance/ledger/pubsub.ex`
- `lib/aurum_finance/reporting/ledger_event_bridge.ex`
- `test/aurum_finance/reporting/ledger_event_bridge_test.exs`
- Updates in `lib/aurum_finance/ledger.ex`
- Updates in `lib/aurum_finance/application.ex`
- Updates in `config/test.exs`
- Updates in `test/aurum_finance/ledger_test.exs`
- Updates in `test/aurum_finance/ingestion/materialization_worker_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Ledger write notifications are acceptable as at-least-once delivery signals | Snapshot refresh enqueueing is already idempotent at the Oban layer by account-based uniqueness |
| The bridge should not auto-start in test by default | Async sandboxed tests need to explicitly `start_supervised!` and `Sandbox.allow/3` the bridge process before it can write jobs safely |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Use a single ledger transaction topic with event tuples `:transaction_created` and `:transaction_voided` | Per-account topics or a direct `Ledger -> Reporting` callback | A single neutral topic keeps ledger decoupled from reporting while still carrying all account ids needed for fan-out |
| Broadcast the void event from the original voided transaction payload | Broadcast from the reversal transaction or include both ids | Refreshing from the original business date and affected accounts is the only projection input required, and the original transaction already carries that shape clearly |
| Disable bridge auto-start in test via config and start it explicitly per test | Let the application child run during tests | A globally supervised bridge would hit SQL sandbox ownership errors in async tests whenever it tried to enqueue Oban jobs |

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
