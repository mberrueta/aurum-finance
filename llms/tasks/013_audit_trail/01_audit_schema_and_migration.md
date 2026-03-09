# Task 01: Ledger and Audit Immutability — Schema and Migration Hardening

## Status
- **Status**: ✅ COMPLETE (migration written, schema updated — awaiting human `mix ecto.migrate` verification)
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02, Task 03, Task 04

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
```
Act as a Senior Backend Elixir Engineer following llms/constitution.md.

Read and implement Task 01 from llms/tasks/013_audit_trail/01_audit_schema_and_migration.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec context — especially D7)
- This task file in full
```

## Objective
Enforce database-level immutability across all financial fact tables in a single migration. Three tables are in scope:

1. **`audit_events`** — fully append-only (no UPDATE, no DELETE). Also adds `metadata :map` and removes `updated_at`.
2. **`postings`** — fully append-only (no UPDATE, no DELETE). Postings are immutable ledger facts.
3. **`transactions`** — protected facts. DELETE is blocked. UPDATE is restricted to lifecycle fields (`voided_at`, `correlation_id`) only; fact fields (`entity_id`, `date`, `description`, `source_type`, `inserted_at`) are immutable. `voided_at` is set-once (NULL → non-NULL; can never be reversed or changed once set).

**Schema note:** `transactions` has no `status` column. Void state is represented entirely by `voided_at`. The set-once trigger is the DB-level consistency rule replacing what would otherwise be a status/voided_at CHECK constraint.

**Scope note:** these protections exist for ledger correctness and tamper resistance. They do not require normal `transaction` or `posting` creation to emit `audit_events` in v1.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` — Full spec and design decisions (especially D7)
- [ ] `lib/aurum_finance/audit/audit_event.ex` — AuditEvent schema
- [ ] `lib/aurum_finance/ledger/transaction.ex` — Transaction schema (confirms: no `status`, no `updated_at`, immutable fields are `entity_id`, `date`, `description`, `source_type`)
- [ ] `lib/aurum_finance/ledger/posting.ex` — Posting schema (confirms: fully append-only)
- [ ] `priv/repo/migrations/20260306190830_create_audit_events.exs` — Original audit_events migration
- [ ] `llms/constitution.md` — Migration conventions

## Expected Outputs

- [x] **Migration file**: `priv/repo/migrations/20260308120000_harden_audit_events.exs` (module renamed to `HardenImmutability`) containing:
  1. `add :metadata, :map` (nullable) + `remove :updated_at` on `audit_events`
  2. Append-only trigger function + trigger on `audit_events`
  3. Append-only trigger function + trigger on `postings`
  4. Restricted-update + delete-protection trigger function + trigger on `transactions`
  5. Fully reversible `down/0` that drops all triggers/functions and reverts `audit_events` schema changes
- [x] **Schema update**: `lib/aurum_finance/audit/audit_event.ex`:
  1. `field :metadata, :map` added
  2. `timestamps(type: :utc_datetime_usec, updated_at: false)` — no `updated_at`
  3. `:metadata` in `@optional`

## Acceptance Criteria

- [ ] `mix ecto.migrate` runs cleanly
- [ ] `mix ecto.rollback` + `mix ecto.migrate` cycle completes cleanly (reversibility confirmed)
- [ ] `AuditEvent` schema: `field :metadata, :map` present; `updated_at: false` in timestamps
- [ ] `@optional` includes `:metadata`
- [ ] Trigger blocks UPDATE on `audit_events` — raw SQL `UPDATE audit_events SET ...` raises
- [ ] Trigger blocks DELETE on `audit_events` — raw SQL `DELETE FROM audit_events ...` raises
- [ ] Trigger blocks UPDATE on `postings` — raw SQL `UPDATE postings SET ...` raises
- [ ] Trigger blocks DELETE on `postings` — raw SQL `DELETE FROM postings ...` raises
- [ ] Trigger blocks DELETE on `transactions` — raw SQL `DELETE FROM transactions ...` raises
- [ ] Trigger blocks UPDATE of fact fields on `transactions` (e.g. changing `description`) — raises
- [ ] Trigger allows UPDATE of `voided_at` (NULL → non-NULL) on `transactions` — succeeds
- [ ] Trigger blocks re-setting `voided_at` once non-NULL — raises
- [ ] Existing tests pass — no regressions
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
priv/repo/migrations/20260308120000_harden_audit_events.exs  # Migration (already written)
lib/aurum_finance/audit/audit_event.ex                        # Schema (already updated)
lib/aurum_finance/ledger/transaction.ex                       # Reference: immutable fields, void_changeset
lib/aurum_finance/ledger/posting.ex                           # Reference: append-only
test/aurum_finance/entities_test.exs                          # Tests using audit events indirectly
test/aurum_finance/ledger_test.exs                            # Tests using transactions/postings
```

### Schema facts confirmed before migration was written
- `transactions`: no `status` column; `voided_at` (nullable utc_datetime_usec) represents void state; no `updated_at`; immutable fact fields are `entity_id`, `date`, `description`, `source_type`, `inserted_at`
- `postings`: `amount`, `transaction_id`, `account_id`, `inserted_at` only; fully immutable
- `audit_events`: had `updated_at` (now removed); added `metadata :map`

### Trigger design
- `audit_events_append_only_trigger`: blocks UPDATE and DELETE unconditionally
- `postings_append_only_trigger`: blocks UPDATE and DELETE unconditionally
- `transactions_immutability_trigger`: blocks DELETE; on UPDATE rejects changes to fact fields; enforces `voided_at` set-once (OLD.voided_at IS NOT NULL AND changing → raises)
- All use `BEFORE UPDATE OR DELETE ... FOR EACH ROW` — INSERT is unaffected

### Design Decision References
- **D7**: Database-level immutability via Postgres triggers — `audit_events`, `postings`, `transactions`
- **D8**: `metadata` field on `audit_events` — nullable map, no validation beyond casting
- Plan section "Proposed Data Model" for the full field list

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Grep the codebase for any references to `AuditEvent` + `updated_at` to ensure nothing depends on it
3. Create the migration file with three operations: add `metadata`, remove `updated_at`, create append-only trigger
4. Update `audit_event.ex`: add `metadata` field, change timestamps macro, update `@optional` and `changeset/2`
5. Run `mix ecto.migrate` and `mix ecto.rollback` to verify reversibility
6. Run `mix test` to verify no regressions
7. Run `mix precommit`
8. Document all assumptions in "Execution Summary"
9. List any blockers or questions

### For the Human Reviewer
After agent completes:
1. Review the migration SQL for correctness (trigger syntax, column types)
2. Verify the trigger fires correctly by mentally tracing an UPDATE/DELETE attempt
3. Confirm `updated_at` is fully removed from schema and no code references it
4. Verify `metadata` is properly cast but not required
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- Grepped codebase for any references to `AuditEvent` + `updated_at` in application and test code. No dependencies found -- all references are in task/plan documentation only.
- Created migration `priv/repo/migrations/20260308120000_harden_audit_events.exs` with three operations: add `metadata :map` column, remove `updated_at` column, create append-only Postgres trigger.
- Updated `lib/aurum_finance/audit/audit_event.ex`: added `field :metadata, :map`, changed `timestamps/1` to `timestamps(type: :utc_datetime_usec, updated_at: false)`, added `:metadata` to `@optional`.
- No changeset function modification needed: `changeset/2` already casts `@required ++ @optional`, so adding `:metadata` to `@optional` is sufficient.

### Outputs Created
- `priv/repo/migrations/20260308120000_harden_audit_events.exs` -- migration with `up/0` and `down/0` (not `change/0`) for full reversibility of trigger DDL
- `lib/aurum_finance/audit/audit_event.ex` -- updated schema (metadata field, updated_at: false)

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Timestamp `20260308120000` is safe for the migration filename | It is after the latest existing migration (`20260307203018`) and before any future work |
| `metadata` column does not need a DB-level default | The plan specifies nullable, and the schema treats it as optional with `nil` default |
| The trigger uses `BEFORE UPDATE OR DELETE` (not `AFTER`) | `BEFORE` allows raising before the operation executes, which is the standard pattern for prohibition triggers |
| No `NOT NULL` backfill needed for `metadata` | Column is nullable by design (plan D8) |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Used `up/0` + `down/0` instead of `change/0` | `change/0` with `execute/2` | `up/down` is clearer for migrations mixing `alter table` with raw SQL `execute` statements, and avoids any ambiguity about rollback behavior |
| Trigger function uses `CREATE OR REPLACE FUNCTION` | `CREATE FUNCTION` | `CREATE OR REPLACE` is idempotent and safer if the migration is re-run or the function already exists from a failed partial migration |

### Blockers Encountered
- None

### Questions for Human
- None

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
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
