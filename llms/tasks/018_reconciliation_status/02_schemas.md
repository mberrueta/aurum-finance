# Task 02: Ecto Schemas

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03, Task 05

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 02 from llms/tasks/018_reconciliation_status/02_schemas.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md (Schema Design and Context API sections)
- lib/aurum_finance/ledger/account.ex (schema pattern: @required/@optional, changeset, Ecto.Enum)
- lib/aurum_finance/ledger/posting.ex (immutable schema pattern, timestamps without updated_at)
- lib/aurum_finance/audit/audit_event.ex (append-only schema pattern, timestamps without updated_at)
```

## Objective
Create three Ecto schema modules under `lib/aurum_finance/reconciliation/`:
1. `ReconciliationSession` - session header
2. `PostingReconciliationState` - overlay table for posting reconciliation status
3. `ReconciliationAuditLog` - transition audit trail (append-only)

## Inputs Required

- [ ] `llms/tasks/018_reconciliation_status/plan.md` - Schema Design section
- [ ] `lib/aurum_finance/ledger/account.ex` - Pattern for schemas with @required/@optional, Ecto.Enum, changeset
- [ ] `lib/aurum_finance/ledger/posting.ex` - Pattern for append-only schemas (no updated_at)
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Pattern for audit schema with map fields
- [ ] `lib/aurum_finance/entities/entity.ex` - Entity association pattern

## Expected Outputs

- [ ] `lib/aurum_finance/reconciliation/reconciliation_session.ex` - ReconciliationSession schema
- [ ] `lib/aurum_finance/reconciliation/posting_reconciliation_state.ex` - PostingReconciliationState schema
- [ ] `lib/aurum_finance/reconciliation/reconciliation_audit_log.ex` - ReconciliationAuditLog schema

## Acceptance Criteria

- [ ] All three schemas compile without warnings
- [ ] Each schema declares `@required` and `@optional` field lists per constitution
- [ ] Each schema has a `changeset/2` function with `cast` and `validate_required`
- [ ] All validation messages use `dgettext("errors", "error_...")` pattern
- [ ] `ReconciliationSession` has `belongs_to :account` and `belongs_to :entity`
- [ ] `PostingReconciliationState` has `belongs_to :posting`, `belongs_to :entity`, `belongs_to :reconciliation_session` (optional)
- [ ] `PostingReconciliationState.status` uses `Ecto.Enum, values: [:cleared, :reconciled]`
- [ ] `ReconciliationAuditLog` uses `timestamps(type: :utc_datetime_usec, updated_at: false)`
- [ ] All schemas use `@primary_key {:id, :binary_id, autogenerate: true}` and `@foreign_key_type :binary_id`
- [ ] Each schema has a `@type t :: %__MODULE__{}` type declaration
- [ ] Each schema has a `@moduledoc` and `@doc` on `changeset/2` with examples
- [ ] `ReconciliationSession.changeset/2` validates `statement_balance` is present and is a valid decimal
- [ ] `PostingReconciliationState.changeset/2` includes `unique_constraint(:posting_id, name: :posting_reconciliation_states_posting_id_index)` and `foreign_key_constraint(:posting_id)`
- [ ] `PostingReconciliationState.changeset/2` includes `check_constraint(:status, name: :posting_reconciliation_states_status_check)`
- [ ] `ReconciliationSession.changeset/2` includes `unique_constraint(:account_id, name: :reconciliation_sessions_account_id_active_index, message: dgettext("errors", "error_active_session_exists"))`

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger/account.ex           # Full schema pattern to follow
lib/aurum_finance/ledger/posting.ex           # Append-only timestamps pattern
lib/aurum_finance/audit/audit_event.ex        # Append-only with map field pattern
lib/aurum_finance/entities/entity.ex          # Entity association pattern
```

### Patterns to Follow
- `@primary_key {:id, :binary_id, autogenerate: true}` on every schema
- `@foreign_key_type :binary_id` on every schema
- `@required` and `@optional` module attributes listing field atoms
- `changeset/2` uses `cast(attrs, @required ++ @optional)` then `validate_required(@required, message: dgettext(...))`
- Ecto.Enum with module attribute: `@statuses [:cleared, :reconciled]` then `field :status, Ecto.Enum, values: @statuses`
- Associations use `belongs_to` referencing the related schema module
- Foreign key constraints declared in changeset: `foreign_key_constraint(:account_id)` etc.

### Constraints
- Do NOT modify any existing schemas
- `ReconciliationAuditLog` must use `timestamps(type: :utc_datetime_usec, updated_at: false)` since the table has no `updated_at` column
- `PostingReconciliationState` and `ReconciliationSession` use standard `timestamps(type: :utc_datetime_usec)`
- The `from_status` and `to_status` fields on `ReconciliationAuditLog` are plain `:string` (not Ecto.Enum) since they can be `nil`
- The `channel` field on `ReconciliationAuditLog` is a plain `:string` (not the Ecto.Enum used in AuditEvent), keeping the audit log schema simple

### Schema Field Details

**ReconciliationSession:**
- Required: `[:account_id, :entity_id, :statement_date, :statement_balance]`
- Optional: `[:completed_at]`
- Associations: `belongs_to :account, Account`, `belongs_to :entity, Entity`

**PostingReconciliationState:**
- Required: `[:entity_id, :posting_id, :status]`
- Optional: `[:reconciliation_session_id, :reason]`
- Associations: `belongs_to :posting, Posting`, `belongs_to :entity, Entity`, `belongs_to :reconciliation_session, ReconciliationSession`

**ReconciliationAuditLog:**
- Required: `[:reconciliation_session_id, :posting_id, :actor, :channel, :occurred_at]`
- Optional: `[:posting_reconciliation_state_id, :from_status, :to_status, :metadata]`
- Associations: `belongs_to :posting_reconciliation_state, PostingReconciliationState`, `belongs_to :reconciliation_session, ReconciliationSession`, `belongs_to :posting, Posting`
- NOTE: `Posting` is referenced via alias `AurumFinance.Ledger.Posting`

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `llms/coding_styles/elixir.md` (required by constitution)
3. Create the `lib/aurum_finance/reconciliation/` directory if it doesn't exist
4. Create all three schema files following the patterns identified above
5. Ensure each module compiles cleanly: `mix compile --warnings-as-errors`
6. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify all three schema files exist and compile without warnings
2. Verify field lists match the spec's Schema Design section
3. Verify changeset validations are appropriate (required fields, constraints)
4. Verify i18n pattern is used for all validation messages
5. Verify associations are correctly declared
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
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
