# Task 03: Reconciliation Context API

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 04, Task 06, Task 07

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 03 from llms/tasks/018_reconciliation_status/03_reconciliation_context.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md (Context API Shape section + full spec)
- lib/aurum_finance/ledger.ex (context pattern: list_*, get_*!, create_*, filter_query/2, require_entity_scope!, audit integration)
- lib/aurum_finance/audit.ex (Audit.insert_and_log, Audit.Multi.append_event patterns)
- lib/aurum_finance/audit/multi.ex (Multi-based audit pattern)
- lib/aurum_finance/reconciliation/reconciliation_session.ex (Task 02 output)
- lib/aurum_finance/reconciliation/posting_reconciliation_state.ex (Task 02 output)
- lib/aurum_finance/reconciliation/reconciliation_audit_log.ex (Task 02 output)
```

## Objective
Create the `AurumFinance.Reconciliation` context module (`lib/aurum_finance/reconciliation.ex`) with the full public API for session lifecycle, posting state management, and balance derivation.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - Context API Shape section and State Machine section
- [ ] `lib/aurum_finance/ledger.ex` - Pattern for context module structure, `require_entity_scope!/2`, `filter_query/2`, audit meta helpers
- [ ] `lib/aurum_finance/audit.ex` - `Audit.insert_and_log/2`, `Audit.update_and_log/3` patterns
- [ ] `lib/aurum_finance/audit/multi.ex` - `Audit.Multi.append_event/4` for Multi-based audit
- [ ] Task 02 output: the three schema modules

## Expected Outputs

- [ ] `lib/aurum_finance/reconciliation.ex` - Full context module with all public functions

## Acceptance Criteria

- [ ] Module compiles without warnings
- [ ] All public functions have `@doc` documentation with examples
- [ ] All public functions have `@spec` type specifications
- [ ] `list_*` functions accept `opts` keyword list and use private `filter_query/2`
- [ ] Entity scope is enforced via `require_entity_scope!/2` on all listing/query functions
- [ ] `create_reconciliation_session/2` validates one-active-session-per-account (handles unique constraint error from partial index)
- [ ] `create_reconciliation_session/2` uses `Audit.insert_and_log/2` for audit trail
- [ ] `complete_reconciliation_session/2` atomically transitions all cleared overlay records to reconciled, sets `completed_at`, and creates audit log entries -- all in a single `Ecto.Multi` transaction
- [ ] `mark_postings_cleared/3` bulk-inserts overlay records and audit log entries atomically via `Ecto.Multi`
- [ ] `mark_postings_uncleared/3` deletes overlay records (only `:cleared` status) and creates audit log entries atomically
- [ ] `any_posting_reconciled?/1` returns a boolean given a list of posting IDs
- [ ] `get_cleared_balance/2` derives balance by joining postings to overlay table (cleared + reconciled), excluding voided transactions
- [ ] `list_postings_for_reconciliation/2` returns postings LEFT JOINed with overlay status, entity-scoped, voided excluded
- [ ] State machine enforcement: cannot mark a posting cleared if it already has an overlay record; cannot un-clear a reconciled posting
- [ ] Functions that can fail return `{:ok, data} | {:error, reason}` tuples

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex                           # Context pattern to follow
lib/aurum_finance/audit.ex                            # Audit.insert_and_log/2 pattern
lib/aurum_finance/audit/multi.ex                      # Audit.Multi.append_event/4
lib/aurum_finance/reconciliation/                     # Schema modules (Task 02 output)
```

### Patterns to Follow

**Entity scope enforcement:**
```elixir
defp require_entity_scope!(opts, function_name) do
  case Keyword.fetch(opts, :entity_id) do
    {:ok, entity_id} when not is_nil(entity_id) -> opts
    _ -> raise ArgumentError, "#{function_name} requires :entity_id"
  end
end
```

**Filter query pattern (multi-clause dispatch):**
```elixir
defp filter_query(query, []), do: query
defp filter_query(query, [{:entity_id, entity_id} | rest]) do
  query |> where([s], s.entity_id == ^entity_id) |> filter_query(rest)
end
defp filter_query(query, [{:account_id, account_id} | rest]) do
  query |> where([s], s.account_id == ^account_id) |> filter_query(rest)
end
defp filter_query(query, [_unknown | rest]), do: filter_query(query, rest)
```

**Audit integration for creates:**
```elixir
Audit.insert_and_log(changeset, %{
  actor: actor, channel: channel, entity_type: "reconciliation_session"
})
```

**Ecto.Multi for bulk operations:**
```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert_all(:states, PostingReconciliationState, entries)
|> Ecto.Multi.insert_all(:audit_logs, ReconciliationAuditLog, log_entries)
|> Repo.transaction()
```

### Key API Functions

1. **Session lifecycle:**
   - `list_reconciliation_sessions(opts)` - entity_id required, optional account_id filter
   - `get_reconciliation_session!(entity_id, session_id)` - raises on not found
   - `create_reconciliation_session(attrs, opts)` - with audit, validates active session uniqueness
   - `update_reconciliation_session(session, attrs, opts)` - edit statement_balance before completion
   - `complete_reconciliation_session(session, opts)` - atomic finalization
   - `change_reconciliation_session(session, attrs)` - for form handling

2. **Posting state management:**
   - `list_postings_for_reconciliation(account_id, opts)` - LEFT JOIN overlay, entity-scoped
   - `mark_postings_cleared(posting_ids, session_id, opts)` - bulk insert overlay + audit
   - `mark_postings_uncleared(posting_ids, session_id, opts)` - delete cleared overlays + audit
   - `any_posting_reconciled?(posting_ids)` - boolean check for void guard

3. **Balance derivation:**
   - `get_cleared_balance(account_id, opts)` - SUM postings with cleared/reconciled overlay

### State Machine Rules
- Mark cleared: posting must have NO overlay record (unreconciled). Insert `{status: :cleared}`.
- Un-clear: posting must have overlay with `status: :cleared`. DELETE the record.
- Finalize: all overlay records for session with `status: :cleared` are UPDATED to `status: :reconciled`.
- Reconciled is terminal: no transitions from `:reconciled`.

> **v1 Design Decision**: `posting_reconciliation_states` stores the **current effective overlay row per posting** (one row per posting at most). The transition history is exclusively in `reconciliation_audit_logs`. This means `complete_reconciliation_session/2` does an UPDATE on existing rows (`:cleared` → `:reconciled`) rather than inserting new event rows.
>
> This is an explicit v1 trade-off. Future versions may adopt an append-only event log model for the overlay itself (aligning with the ADRs' direction on event sourcing and session reopen/correction), but that is out of scope for this feature. **Do not model `posting_reconciliation_states` as an event log — it is a current-state table.**

### Constraints
- Do NOT modify the `Posting` schema or any existing schemas
- `list_postings_for_reconciliation` must use LEFT JOIN (not preload) to derive status
- The `get_cleared_balance` query must exclude voided transactions (join to transactions, filter `voided_at IS NULL`)
- Use `Ecto.Multi` for all bulk operations to ensure atomicity
- Handle the unique constraint violation on `posting_reconciliation_states.posting_id` gracefully in `mark_postings_cleared`

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` (required by constitution)
3. Create `lib/aurum_finance/reconciliation.ex`
4. Implement all public functions listed in the API
5. Implement private helpers: `require_entity_scope!/2`, `filter_query/2`, audit meta helpers
6. Ensure the module compiles: `mix compile --warnings-as-errors`
7. Document all design decisions and assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review all public functions against the spec's Context API Shape
2. Verify entity scope enforcement on all query functions
3. Verify state machine rules are correctly enforced
4. Verify `Ecto.Multi` is used for all atomic operations
5. Verify audit integration follows existing patterns
6. Verify `@doc` and `@spec` on all public functions
7. Check LEFT JOIN query logic for `list_postings_for_reconciliation`
8. Check cleared balance derivation query
9. If approved: mark `[x]` on "Approved" and update plan.md status
10. If rejected: add rejection reason and specific feedback

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
