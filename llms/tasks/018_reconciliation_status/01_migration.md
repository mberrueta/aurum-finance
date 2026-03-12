# Task 01: Database Migration

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02, Task 05

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 01 from llms/tasks/018_reconciliation_status/01_migration.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md (the full spec -- read the Schema Design section carefully)
- priv/repo/migrations/20260308120000_harden_audit_events.exs (pattern for append-only triggers)
- priv/repo/migrations/20260307203018_create_transactions_and_postings.exs (pattern for table creation)
```

## Objective
Create a single Ecto migration that adds three new tables (`reconciliation_sessions`, `posting_reconciliation_states`, `reconciliation_audit_logs`) with all required columns, foreign keys, indexes, constraints, and an append-only trigger on `reconciliation_audit_logs`.

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - Schema Design section with full column specs
- [ ] `priv/repo/migrations/20260308120000_harden_audit_events.exs` - Pattern for append-only DB trigger
- [ ] `priv/repo/migrations/20260307203018_create_transactions_and_postings.exs` - Pattern for binary_id PKs and FKs
- [ ] `priv/repo/migrations/20260306175550_create_entities.exs` - Entities table reference
- [ ] `priv/repo/migrations/20260307120000_create_accounts.exs` - Accounts table reference

## Expected Outputs

- [ ] New migration file: `priv/repo/migrations/[timestamp]_create_reconciliation_tables.exs`
- [ ] Migration creates `reconciliation_sessions` table with all columns and indexes
- [ ] Migration creates `posting_reconciliation_states` table with all columns, UNIQUE on `posting_id`, and indexes
- [ ] Migration creates `reconciliation_audit_logs` table with all columns and indexes (no `updated_at`)
- [ ] Partial unique index on `reconciliation_sessions` for one-active-session-per-account constraint
- [ ] Append-only trigger on `reconciliation_audit_logs`
- [ ] DB-level CHECK constraint on `posting_reconciliation_states.status` enforcing `status IN ('cleared', 'reconciled')`, named `posting_reconciliation_states_status_check`
- [ ] DB-level trigger or CHECK constraint preventing status transition FROM `:reconciled` on `posting_reconciliation_states`
- [ ] Reversible `down/0` function that drops triggers, tables, and indexes

## Acceptance Criteria

- [ ] `mix ecto.migrate` runs without errors
- [ ] `mix ecto.rollback` cleanly reverses all changes
- [ ] All three tables exist with correct column types and constraints
- [ ] `posting_reconciliation_states.posting_id` has a named UNIQUE index: `posting_reconciliation_states_posting_id_index`
- [ ] Partial unique index on `(account_id) WHERE completed_at IS NULL` on `reconciliation_sessions`, named `reconciliation_sessions_account_id_active_index`
- [ ] CHECK constraint on `posting_reconciliation_states.status` named `posting_reconciliation_states_status_check`
- [ ] `reconciliation_audit_logs` has an append-only trigger (UPDATE and DELETE blocked)
- [ ] Foreign keys reference the correct parent tables
- [ ] All `id` fields use `binary_id` (UUIDs) matching the existing project pattern
- [ ] Timestamp fields use `utc_datetime_usec` matching existing pattern
- [ ] `reconciliation_audit_logs` has `inserted_at` but NO `updated_at`

## Technical Notes

### Relevant Code Locations
```
priv/repo/migrations/                                    # All existing migrations
priv/repo/migrations/20260308120000_harden_audit_events.exs  # Trigger pattern
priv/repo/migrations/20260307203018_create_transactions_and_postings.exs  # Table creation pattern
```

### Patterns to Follow
- Use `binary_id` for all primary keys and foreign keys (project standard)
- Use `utc_datetime_usec` for all timestamp columns
- Follow the trigger pattern from `harden_audit_events.exs` for the append-only trigger on audit logs
- Use `create unique_index` for the posting_id uniqueness constraint
- Use `create index` with `where:` option for the partial unique index on active sessions

### Constraint & Index Naming Convention

Use explicit names on every constraint and index so that `unique_constraint/3`, `check_constraint/3`, and error messages in the schema modules are unambiguous:

| Object | Name |
|--------|------|
| UNIQUE on `posting_reconciliation_states.posting_id` | `posting_reconciliation_states_posting_id_index` |
| PARTIAL UNIQUE on `reconciliation_sessions(account_id) WHERE completed_at IS NULL` | `reconciliation_sessions_account_id_active_index` |
| CHECK on `posting_reconciliation_states.status` | `posting_reconciliation_states_status_check` |
| Append-only trigger on `reconciliation_audit_logs` | `reconciliation_audit_logs_append_only_trigger` |
| Trigger/CHECK preventing `:reconciled` updates | `posting_reconciliation_states_no_unreconcile_trigger` |

The schema modules (Task 02) will reference these names in `unique_constraint/3` and `check_constraint/3` calls.

### Constraints

- Migration timestamp must be after `20260310214609` (latest existing migration)
- Do NOT modify any existing tables or triggers
- The `postings_append_only_trigger` must NOT be touched
- `statement_balance` should use `:decimal` type (not `:float`)
- The `status` column on `posting_reconciliation_states` stores the Ecto.Enum as a string
- `from_status` and `to_status` on `reconciliation_audit_logs` are plain `:string` (nullable), not enums, since they can be `nil`

### Schema Details (from spec)

**reconciliation_sessions:**
- `id`: binary_id PK
- `account_id`: binary_id FK to accounts, NOT NULL
- `entity_id`: binary_id FK to entities, NOT NULL
- `statement_date`: :date, NOT NULL
- `statement_balance`: :decimal, NOT NULL
- `completed_at`: :utc_datetime_usec, nullable
- timestamps (utc_datetime_usec)

**posting_reconciliation_states:**
- `id`: binary_id PK
- `entity_id`: binary_id FK to entities, NOT NULL
- `posting_id`: binary_id FK to postings, NOT NULL, UNIQUE
- `reconciliation_session_id`: binary_id FK to reconciliation_sessions, nullable
- `status`: :string, NOT NULL (stores "cleared" or "reconciled")
- `reason`: :string, nullable
- timestamps (utc_datetime_usec)

**reconciliation_audit_logs:**
- `id`: binary_id PK
- `posting_reconciliation_state_id`: binary_id FK to posting_reconciliation_states, nullable
- `reconciliation_session_id`: binary_id FK to reconciliation_sessions, NOT NULL
- `posting_id`: binary_id FK to postings, NOT NULL
- `from_status`: :string, nullable
- `to_status`: :string, nullable
- `actor`: :string, NOT NULL
- `channel`: :string, NOT NULL
- `occurred_at`: :utc_datetime_usec, NOT NULL
- `metadata`: :map, nullable
- `inserted_at`: :utc_datetime_usec, NOT NULL (NO updated_at)

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` (required by constitution)
3. Generate the migration timestamp as `20260311120000` (or similar, after the latest existing)
4. Create the migration file with `up/0` and `down/0` functions
5. In `up/0`: create all three tables, then indexes, then triggers
6. In `down/0`: drop triggers first, then tables (reverse order)
7. Add the append-only trigger for `reconciliation_audit_logs` using the same pattern as `audit_events_append_only_trigger`
8. Add a DB trigger or CHECK constraint on `posting_reconciliation_states` that prevents changing status FROM 'reconciled' to any other value (prevents UPDATE of reconciled records)
9. Run `mix ecto.migrate` to verify it applies cleanly
10. Run `mix ecto.rollback` to verify it reverses cleanly
11. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review the migration file for correctness against the spec's Schema Design section
2. Verify all foreign keys, indexes, and constraints are present
3. Verify the append-only trigger matches the existing pattern
4. Verify the reconciled-status protection constraint/trigger is correct
5. Run `mix ecto.migrate` and `mix ecto.rollback` to verify
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

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
