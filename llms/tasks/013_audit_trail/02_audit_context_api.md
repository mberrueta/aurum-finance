# Task 02: Audit Context API — New Helpers and Caller Migration

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03, Task 04

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
```
Act as a Senior Backend Elixir Engineer following llms/constitution.md.

Read and implement Task 02 from llms/tasks/013_audit_trail/02_audit_context_api.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec — especially "API / Context Design" and "Transaction / Atomicity Strategy" sections)
- llms/tasks/013_audit_trail/01_audit_schema_and_migration.md (Task 01 output for context)
- This task file in full
```

## Objective
Replace the existing `Audit.with_event/3` and `Audit.log_event/1` API with the new atomic helper API: `Audit.insert_and_log/2`, `Audit.update_and_log/3`, `Audit.archive_and_log/3`, and `Audit.Multi.append_event/4`. Migrate ALL existing callers in `Entities` and `Ledger` contexts to the new API. Remove the old functions entirely. This is a breaking change with no backward compatibility shim. Corresponds to plan tasks 4-6.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Full spec, especially sections: "API / Context Design", "Transaction / Atomicity Strategy", "Redaction enforcement"
- [ ] `lib/aurum_finance/audit.ex` - Current context with `with_event/3`, `log_event/1`, `create_audit_event/1`, redaction logic, snapshot helpers
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Schema (after Task 01 modifications: includes `metadata`, no `updated_at`)
- [ ] `lib/aurum_finance/entities.ex` - Caller of `Audit.with_event/3` at lines 64, 151. Functions: `create_entity/2`, `update_entity/3`, `archive_entity/2`, `unarchive_entity/2`
- [ ] `lib/aurum_finance/ledger.ex` - Caller of `Audit.with_event/3` at lines 220, 470. Caller of `Audit.log_event/1` at lines 923, 935. Functions: `create_account/2`, `update_account/3`, `archive_account/2`, `unarchive_account/2`, `create_transaction/2`, `void_transaction/2`
- [ ] `llms/constitution.md` - Context API conventions, error tuple conventions

## Expected Outputs

### New functions in `lib/aurum_finance/audit.ex`

- [ ] **`Audit.insert_and_log(changeset, meta)`** - Wraps `Repo.insert(changeset)` + audit event append in a single `Repo.transaction`. `meta` must contain: `actor`, `channel`, `entity_type`, `redact_fields` (optional), `metadata` (optional). Action is inferred as `"created"`. `before` is always `nil`. Returns `{:ok, struct}` or `{:error, changeset}` or `{:error, {:audit_failed, reason}}`.

- [ ] **`Audit.update_and_log(struct, changeset, meta)`** - Wraps `Repo.update(changeset)` + audit event append in a single `Repo.transaction`. `struct` is the pre-update state used for the `before` snapshot. Returns same tuple shapes.

- [ ] **`Audit.archive_and_log(struct, changeset, meta)`** - Identical to `update_and_log` but infers action as `"archived"`. Provided as a semantic alias for clarity at call sites.

### New module `lib/aurum_finance/audit/multi.ex`

- [ ] **`Audit.Multi.append_event(multi, step_name, before_snapshot, meta)`** - Appends a named step to an existing `Ecto.Multi` that inserts an audit event. The `after` snapshot is derived from the result of the named Multi step (identified by `step_name`). `meta` must contain: `actor`, `channel`, `entity_type`, `entity_id`, `action`, `redact_fields` (optional), `metadata` (optional), and a `serializer` function to convert the result struct to a snapshot map.

### Migrated callers in `lib/aurum_finance/entities.ex`

- [ ] `create_entity/2` - Replace `Audit.with_event/3` with `Audit.insert_and_log/2`
- [ ] `update_entity/3` (via `update_entity_with_action/4`) - Replace with `Audit.update_and_log/3`
- [ ] `archive_entity/2` - Replace with `Audit.archive_and_log/3`
- [ ] `unarchive_entity/2` - Replace with `Audit.update_and_log/3` (action `"unarchived"`)
- [ ] Remove `entity_snapshot/1` private function - snapshot serialization moves into `meta` or the Audit helpers
- [ ] Remove `extract_audit_metadata/1` and `normalize_actor/1` - normalization is handled by Audit helpers

### Migrated callers in `lib/aurum_finance/ledger.ex`

- [ ] `create_account/2` - Replace `Audit.with_event/3` with `Audit.insert_and_log/2`
- [ ] `update_account/3` (via `update_account_with_action/4`) - Replace with `Audit.update_and_log/3`
- [ ] `archive_account/2` - Replace with `Audit.archive_and_log/3`
- [ ] `unarchive_account/2` - Replace with `Audit.update_and_log/3` (action `"unarchived"`)
- [ ] `create_transaction/2` (via `persist_transaction/3`) - Replace `Repo.transaction` + `log_event` pattern with `Audit.Multi.append_event/4`
- [ ] `void_transaction/2` (via `persist_void_transaction/2`) - Replace `Repo.transaction` + `log_event` pattern with `Audit.Multi.append_event/4` (two audit events: one for the void, one for the reversal creation)
- [ ] Remove `log_transaction_created/2`, `log_transaction_voided/3`, `maybe_log_transaction_created/2` private functions
- [ ] Remove `account_snapshot/1`, `transaction_snapshot/1` private functions -- move to `meta` serializer or keep as private but pass to Audit
- [ ] Remove `extract_audit_metadata/1` and `normalize_actor/1`

### Removed from `lib/aurum_finance/audit.ex`

- [ ] `with_event/3` - Deleted entirely (including `@type with_event_meta`, `build_event_attrs/4`, `ensure_audit_logged/2`)
- [ ] `log_event/1` - Deleted as a public function. The internal insert logic may be retained as a private helper used by the new functions.

## Acceptance Criteria

- [ ] `Audit.with_event/3` no longer exists in the codebase (not just deprecated -- fully removed)
- [ ] `Audit.log_event/1` no longer exists as a public function
- [ ] `Audit.insert_and_log/2` exists and wraps insert + audit in a single DB transaction
- [ ] `Audit.update_and_log/3` exists and wraps update + audit in a single DB transaction
- [ ] `Audit.archive_and_log/3` exists and wraps archive update + audit in a single DB transaction
- [ ] `Audit.Multi.append_event/4` exists and appends an audit step to an `Ecto.Multi`
- [ ] All `Entities.*` functions produce audit events atomically (verified by existing tests passing)
- [ ] All `Ledger.*` functions produce audit events atomically (verified by existing tests passing)
- [ ] Redaction is applied inside the Audit helpers, not in the callers
- [ ] Snapshot serialization is passed via `meta` (as a `:serializer` function) or handled by default snapshot logic in Audit
- [ ] Error tuples follow constitution conventions: `{:ok, struct}` or `{:error, changeset}` or `{:error, {:audit_failed, reason}}`
- [ ] No references to `with_event` or direct `log_event` calls remain in `Entities` or `Ledger`
- [ ] All existing tests pass without modification (the API change is internal; public context APIs remain the same)
- [ ] `mix precommit` passes

## Technical Notes

### Known Call Sites to Migrate

| File | Line(s) | Current API | Target API |
|------|---------|-------------|------------|
| `lib/aurum_finance/entities.ex` | 64-76 | `Audit.with_event/3` in `create_entity/2` | `Audit.insert_and_log/2` |
| `lib/aurum_finance/entities.ex` | 148-163 | `Audit.with_event/3` in `update_entity_with_action/4` | `Audit.update_and_log/3` or `Audit.archive_and_log/3` |
| `lib/aurum_finance/ledger.ex` | 220-232 | `Audit.with_event/3` in `create_account/2` | `Audit.insert_and_log/2` |
| `lib/aurum_finance/ledger.ex` | 467-482 | `Audit.with_event/3` in `update_account_with_action/4` | `Audit.update_and_log/3` or `Audit.archive_and_log/3` |
| `lib/aurum_finance/ledger.ex` | 839-846 | `Repo.transaction` + `log_event` in `persist_transaction/3` | `Ecto.Multi` + `Audit.Multi.append_event/4` |
| `lib/aurum_finance/ledger.ex` | 888-902 | `Repo.transaction` + `log_event` in `persist_void_transaction/2` | `Ecto.Multi` + `Audit.Multi.append_event/4` |
| `lib/aurum_finance/ledger.ex` | 922-944 | `log_transaction_created/2`, `log_transaction_voided/3` | Removed -- replaced by Multi pattern |
| `lib/aurum_finance/ledger.ex` | 970-986 | `maybe_log_transaction_created/2`, `maybe_finish_void_transaction/3` | Removed -- replaced by Multi pattern |

### Snapshot Serializer Strategy

The current code has `entity_snapshot/1`, `account_snapshot/1`, and `transaction_snapshot/1` as private functions in the caller contexts. Two options:

**Option A**: Keep snapshot functions in the caller contexts and pass them via `meta[:serializer]`. The Audit helpers call the serializer to build before/after snapshots.

**Option B**: Move snapshot functions into the Audit context or a shared module.

**Recommendation**: Option A. Each domain context knows its own schema shape best. The snapshot functions stay as private functions in `Entities` and `Ledger`, passed to Audit via `meta[:serializer]`. This matches the current pattern (the `serializer` option already exists in `with_event/3`).

### Transaction Refactoring for Ledger

The `persist_transaction/3` function currently uses a manual `Repo.transaction` with nested function calls. This must be refactored to use `Ecto.Multi`:

1. Build the Multi pipeline: insert transaction -> insert postings -> append audit event
2. Run the entire Multi via `Repo.transaction/1`
3. The `Audit.Multi.append_event/4` step reads the transaction result from a prior named step

Similarly, `persist_void_transaction/2` must be refactored from its current nested callback pattern to a flat `Ecto.Multi` pipeline.

### The `meta` Map Structure

```elixir
%{
  actor: "person",           # required
  channel: :web,             # required
  entity_type: "entity",     # required
  action: "created",         # optional (inferred by helper)
  redact_fields: [:tax_id],  # optional, default []
  metadata: %{},             # optional, default nil
  serializer: &my_snapshot/1 # optional, default: Audit default snapshot
}
```

### Constraints
- This is a **breaking internal change**. All callers must be migrated in this single task. No partial migration.
- The public API of `Entities` and `Ledger` contexts must NOT change. The functions still accept the same arguments and return the same tuple shapes.
- The `create_audit_event/1` and `change_audit_event/2` functions in `Audit` should be preserved (they are independent of the event logging pipeline).
- Existing redaction logic (`redact_snapshot/2`, `do_redact/2`) must be preserved and reused by the new helpers.
- Existing snapshot helpers (`default_snapshot/1`, `stringify_keys/1`, `stringify_value/1`) must be preserved.

### Design Decision References
- **D9**: Atomic domain write + audit append via Ecto.Multi
- Plan section "API / Context Design" for the full helper specifications
- Plan section "Transaction / Atomicity Strategy" for the current-vs-target state table
- Plan section "Failure semantics" for error return conventions

## Execution Instructions

### For the Agent
1. Read ALL inputs listed above thoroughly -- especially the plan's API design section
2. Implement `Audit.insert_and_log/2`, `Audit.update_and_log/3`, `Audit.archive_and_log/3` in `audit.ex`
3. Create `lib/aurum_finance/audit/multi.ex` with `Audit.Multi.append_event/4`
4. Migrate `Entities` context: replace all `with_event/3` calls with new helpers
5. Migrate `Ledger` context: replace `with_event/3` calls for accounts, refactor transaction/void paths to use Multi
6. Remove `with_event/3`, `log_event/1`, and all dead private helpers from `audit.ex`
7. Remove dead private helpers from `entities.ex` and `ledger.ex`
8. Grep the entire codebase for `with_event` and `log_event` to confirm no references remain
9. Run `mix test` -- all existing tests must pass
10. Run `mix precommit`
11. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify `with_event/3` and `log_event/1` are fully removed (grep confirmation)
2. Review each new Audit helper for correct transaction wrapping and error handling
3. Review `Audit.Multi.append_event/4` for correct step dependency resolution
4. Verify redaction is applied inside Audit helpers, not callers
5. Verify the public API of `Entities` and `Ledger` is unchanged
6. Check that the Ledger transaction/void refactoring preserves all business logic (zero-sum validation, reversal creation, etc.)
7. Run `mix test` to confirm all tests pass
8. If approved: mark `[x]` on "Approved" and update plan.md status
9. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files/artifacts created]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [Assumption 1] | [Why this was assumed] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [Decision 1] | [Options] | [Why chosen] |

### Blockers Encountered
- [Blocker 1] - Resolution: [How resolved or "Needs human input"]

### Questions for Human
1. [Question needing human input]

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
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
