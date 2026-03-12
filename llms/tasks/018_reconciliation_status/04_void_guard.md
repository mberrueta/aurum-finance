# Task 04: Ledger Void Guard Integration

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 06

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 04 from llms/tasks/018_reconciliation_status/04_void_guard.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md (US-6 acceptance criteria)
- lib/aurum_finance/ledger.ex (void_transaction/2 and persist_void_transaction/2)
- lib/aurum_finance/reconciliation.ex (Task 03 output -- any_posting_reconciled?/1)
```

## Objective
Modify `AurumFinance.Ledger.void_transaction/2` to check for reconciled postings before proceeding with the void. If any posting on the transaction has a `PostingReconciliationState` with `status: :reconciled`, the void must be rejected. If postings have `:cleared` overlay records, those records must be deleted (un-cleared) as part of the void operation.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - US-6 acceptance criteria
- [ ] `lib/aurum_finance/ledger.ex` - Current `void_transaction/2` implementation
- [ ] `lib/aurum_finance/reconciliation.ex` - Task 03 output (provides `any_posting_reconciled?/1`)

## Expected Outputs

- [ ] Modified `lib/aurum_finance/ledger.ex` - `void_transaction/2` with reconciled-posting guard and cleared-posting cleanup

## Acceptance Criteria

- [ ] `void_transaction/2` calls `Reconciliation.any_posting_reconciled?/1` before proceeding
- [ ] If any posting is reconciled, returns `{:error, :reconciled_postings}` (or similar clear error tuple)
- [ ] If postings have `:cleared` overlay records but none are `:reconciled`, the void proceeds AND the cleared overlay records are deleted within the same transaction
- [ ] If no postings have any overlay records, void proceeds unchanged (backward compatible)
- [ ] The check happens at the context level, not just the UI
- [ ] Existing void tests still pass (backward compatibility)
- [ ] No changes to the `Posting` schema

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex              # void_transaction/2, persist_void_transaction/2
lib/aurum_finance/reconciliation.ex      # any_posting_reconciled?/1 (Task 03)
```

### Implementation Approach

The modification to `void_transaction/2` should:

1. After preloading postings (existing code), extract posting IDs
2. Call `Reconciliation.any_posting_reconciled?(posting_ids)` -- if `true`, return error
3. If no reconciled postings, check for cleared postings and include their cleanup in the Multi
4. The cleared-posting cleanup should be an `Ecto.Multi.delete_all` step added to `persist_void_transaction/2`

**Suggested code flow in `void_transaction/2`:**
```elixir
def void_transaction(%Transaction{} = transaction, opts \\ []) do
  transaction = Repo.preload(transaction, :postings)
  posting_ids = Enum.map(transaction.postings, & &1.id)

  cond do
    transaction.voided_at ->
      # existing: already voided
      {:error, Transaction.void_changeset(transaction, %{voided_at: ...})}

    Reconciliation.any_posting_reconciled?(posting_ids) ->
      {:error, :reconciled_postings}

    true ->
      persist_void_transaction(transaction, audit_metadata, posting_ids)
  end
end
```

**In `persist_void_transaction`, add a cleanup step:**
```elixir
|> Ecto.Multi.delete_all(:cleanup_cleared_overlays,
  from(prs in PostingReconciliationState,
    where: prs.posting_id in ^posting_ids and prs.status == :cleared
  )
)
```

### Constraints
- Do NOT modify the `Posting` schema
- Do NOT change the return type for existing success cases
- The reconciled check must happen BEFORE the Multi transaction begins (fail fast)
- The cleared cleanup must happen WITHIN the Multi transaction (atomic with void)
- Import or alias `AurumFinance.Reconciliation` at the top of the module
- Keep the function signatures backward compatible

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` (required by constitution)
3. Modify `void_transaction/2` to add the reconciled-posting guard
4. Modify `persist_void_transaction/2` to clean up cleared overlay records
5. Add the `Reconciliation` alias to the module
6. Ensure the module compiles: `mix compile --warnings-as-errors`
7. Run existing void tests to verify backward compatibility: `mix test test/aurum_finance/ledger_test.exs`
8. Document changes and assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review the guard logic in `void_transaction/2`
2. Verify the cleared-overlay cleanup is within the Multi transaction
3. Verify the error return for reconciled postings is clear and user-facing
4. Run `mix test` to verify no regressions
5. Verify the `Posting` schema was NOT modified
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

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
