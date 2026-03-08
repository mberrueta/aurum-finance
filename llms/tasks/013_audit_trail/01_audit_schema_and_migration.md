# Task 01: Audit Schema and Migration Hardening

## Status
- **Status**: PENDING
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
- llms/tasks/013_audit_trail/plan.md (full spec context)
- This task file in full
```

## Objective
Harden the existing `AuditEvent` schema and `audit_events` table for production use by: (1) adding the `metadata :map` column, (2) removing `updated_at` from the schema, and (3) adding a Postgres trigger that enforces append-only semantics at the database level. This corresponds to plan tasks 1-3.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Full spec and design decisions (especially D6, D7, D8)
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Current schema (line 29: `timestamps(type: :utc_datetime_usec)` generates both `inserted_at` and `updated_at`)
- [ ] `priv/repo/migrations/20260306190830_create_audit_events.exs` - Original migration (line 16: `timestamps(type: :utc_datetime_usec)` creates both timestamp columns)
- [ ] `llms/constitution.md` - Schema changeset conventions, migration conventions

## Expected Outputs

- [ ] **Migration file**: `priv/repo/migrations/<timestamp>_harden_audit_events.exs` containing:
  1. `add :metadata, :map` (nullable) to `audit_events`
  2. `remove :updated_at` column from `audit_events`
  3. A Postgres trigger `audit_events_append_only` that raises an exception on UPDATE or DELETE operations against `audit_events`
- [ ] **Schema update**: `lib/aurum_finance/audit/audit_event.ex` modified to:
  1. Add `field :metadata, :map` to the schema block
  2. Change `timestamps(type: :utc_datetime_usec)` to `timestamps(type: :utc_datetime_usec, updated_at: false)`
  3. Add `:metadata` to the `@optional` list
  4. Update `changeset/2` to cast `:metadata`

## Acceptance Criteria

- [ ] The migration runs cleanly (`mix ecto.migrate`) and is reversible (`mix ecto.rollback`)
- [ ] `AuditEvent` schema declares `field :metadata, :map`
- [ ] `AuditEvent` schema uses `timestamps(type: :utc_datetime_usec, updated_at: false)` -- no `updated_at` field
- [ ] `@optional` includes `:metadata` alongside `:before` and `:after`
- [ ] `changeset/2` casts `:metadata`
- [ ] The Postgres trigger prevents UPDATE on `audit_events` rows (verified by attempting a raw SQL UPDATE in a test or migration verification)
- [ ] The Postgres trigger prevents DELETE on `audit_events` rows
- [ ] The trigger uses `RAISE EXCEPTION` with a clear message (e.g., `'audit_events is append-only: UPDATE and DELETE are prohibited'`)
- [ ] Existing tests continue to pass (no regressions from schema change)
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/audit/audit_event.ex          # Schema to modify
priv/repo/migrations/                            # New migration location
test/aurum_finance/entities_test.exs             # Tests that create audit events indirectly
test/aurum_finance/ledger_test.exs               # Tests that create audit events indirectly
```

### Patterns to Follow
- Migration naming: `<timestamp>_harden_audit_events.exs`
- The migration should use `execute/2` for the trigger (forward SQL and rollback SQL) since Ecto does not have native trigger support
- The trigger function and trigger should be created in the `up` direction and dropped in the `down` direction
- Follow the existing `@required` / `@optional` pattern in the schema (line 14-15 of `audit_event.ex`)

### Migration Structure for the Trigger

The trigger should follow this pattern:
```sql
-- Up
CREATE OR REPLACE FUNCTION audit_events_append_only_trigger()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only: UPDATE and DELETE are prohibited';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_events_append_only
  BEFORE UPDATE OR DELETE ON audit_events
  FOR EACH ROW
  EXECUTE FUNCTION audit_events_append_only_trigger();

-- Down
DROP TRIGGER IF EXISTS audit_events_append_only ON audit_events;
DROP FUNCTION IF EXISTS audit_events_append_only_trigger();
```

### Constraints
- The `updated_at` column removal is a breaking change for any code that reads `updated_at` from `AuditEvent`. Grep for `updated_at` references in audit-related code before removing.
- The trigger must not interfere with INSERT operations -- only UPDATE and DELETE.
- The migration must be reversible for development workflow (rollback adds `updated_at` back and drops the trigger).

### Design Decision References
- **D7**: Append-only enforcement at database level via Postgres trigger (not privilege revocation)
- **D8**: `metadata` field for extensibility -- nullable map, no validation beyond casting
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
