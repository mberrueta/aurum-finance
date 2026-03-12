# Task 05: Test Factories

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 06, Task 08

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 05 from llms/tasks/018_reconciliation_status/05_factories.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir_tests.md
- test/support/factory.ex (existing factory patterns)
- lib/aurum_finance/reconciliation/reconciliation_session.ex (Task 02 output)
- lib/aurum_finance/reconciliation/posting_reconciliation_state.ex (Task 02 output)
- lib/aurum_finance/reconciliation/reconciliation_audit_log.ex (Task 02 output)
```

## Objective
Add ExMachina factories for `ReconciliationSession`, `PostingReconciliationState`, and `ReconciliationAuditLog` to the existing `AurumFinance.Factory` module. Also add convenience helpers following the `insert_entity/1` and `insert_account/2` pattern.

## Inputs Required

- [ ] `test/support/factory.ex` - Existing factory module with patterns to follow
- [ ] Task 02 output: the three schema modules

## Expected Outputs

- [ ] Modified `test/support/factory.ex` with three new factories and convenience helpers

## Acceptance Criteria

- [ ] `reconciliation_session_factory/0` creates a valid session with auto-generated entity and account
- [ ] `posting_reconciliation_state_factory/0` creates a valid overlay record with auto-generated posting and session
- [ ] `reconciliation_audit_log_factory/0` creates a valid audit log entry
- [ ] Convenience helper `insert_reconciliation_session/2` accepts entity and optional attrs, creates via context or direct insert
- [ ] All factories produce records that pass schema changeset validation
- [ ] Factories use `sequence/2` for unique fields where appropriate
- [ ] Factories use the correct association patterns (referencing entity, account, posting)

## Technical Notes

### Relevant Code Locations
```
test/support/factory.ex    # Existing factory module to modify
```

### Patterns to Follow

The existing factory module uses:
- `insert(:entity)` to create parent records inline
- Direct struct construction (not changeset) for factories
- `params_for/2` + context function for convenience helpers
- Explicit `entity_id: entity.id` alongside `entity: entity` for both FK and association

### Factory Shapes

```elixir
def reconciliation_session_factory do
  entity = insert(:entity)
  account = insert(:account, entity: entity, entity_id: entity.id)

  %ReconciliationSession{
    entity: entity,
    entity_id: entity.id,
    account: account,
    account_id: account.id,
    statement_date: Date.utc_today(),
    statement_balance: Decimal.new("1000.00"),
    completed_at: nil
  }
end

def posting_reconciliation_state_factory do
  entity = insert(:entity)
  account = insert(:account, entity: entity, entity_id: entity.id)
  transaction = insert(:transaction, entity: entity, entity_id: entity.id)
  posting = insert(:posting, transaction: transaction, transaction_id: transaction.id,
                             account: account, account_id: account.id)
  session = insert(:reconciliation_session, entity: entity, entity_id: entity.id,
                                            account: account, account_id: account.id)

  %PostingReconciliationState{
    entity: entity,
    entity_id: entity.id,
    posting: posting,
    posting_id: posting.id,
    reconciliation_session: session,
    reconciliation_session_id: session.id,
    status: :cleared,
    reason: nil
  }
end
```

### Constraints
- Do NOT remove or modify existing factories
- Add new aliases for the reconciliation schemas
- Keep factory defaults sensible (e.g., session starts as active with `completed_at: nil`)
- The `posting_reconciliation_state_factory` default status should be `:cleared` (the initial state when a record exists)

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir_tests.md` (required by constitution)
3. Add aliases for the three new schemas at the top of the factory module
4. Add the three factory functions
5. Add convenience helpers if appropriate
6. Ensure the module compiles: `mix compile --warnings-as-errors`
7. Document assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify factories follow existing patterns in the file
2. Verify all required fields are populated with valid defaults
3. Verify associations are correctly linked
4. Verify no existing factories were modified
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
### Git Operations Performed
```bash
```
