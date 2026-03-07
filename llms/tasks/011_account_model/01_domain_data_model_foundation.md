# Task 01: Domain + Data Model Foundation

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None (Issue #10 Entity Model is complete)
- **Blocks**: Task 02, Task 03, Task 04, Task 05

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate the `dev-backend-elixir-engineer` agent with the following prompt:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 01 from `llms/tasks/011_account_model/01_domain_data_model_foundation.md`.
>
> Read all inputs listed in the task, then implement the Account schema, migration, and Ledger context as specified. Follow the existing Entities context patterns exactly.

## Objective
Introduce the `AurumFinance.Ledger` context and `AurumFinance.Ledger.Account` schema with a database migration for the `accounts` table. This delivers the full backend data model for accounts including entity-scoped CRUD APIs, audit event integration, archive/unarchive lifecycle, and a placeholder balance derivation function.

## Inputs Required

- [ ] `llms/tasks/011_account_model/plan.md` - Master plan with canonical domain decisions, field definitions, and classification model
- [ ] `llms/constitution.md` - Global rules (changeset conventions, filter_query pattern, i18n validation, no secrets)
- [ ] `llms/project_context.md` - Project conventions
- [ ] `llms/tasks/010_entity_model/04_ownership_boundary_contract_output.md` - Entity scoping contract (entity_id FK, no cross-entity leakage)
- [ ] `lib/aurum_finance/entities.ex` - Reference context API pattern (list/get/create/update/archive/unarchive/change, filter_query, audit integration)
- [ ] `lib/aurum_finance/entities/entity.ex` - Reference schema pattern (@required/@optional, changeset, Ecto.Enum, archived_at, UUID PK, timestamps)
- [ ] `lib/aurum_finance/audit.ex` - Audit.with_event/3 API and serializer pattern
- [ ] `lib/aurum_finance/audit/audit_event.ex` - AuditEvent schema shape for reference
- [ ] `priv/repo/migrations/20260306175550_create_entities.exs` - Migration pattern reference
- [ ] `docs/adr/0015-account-model-and-instrument-types.md` - Dual classification model (account_type + operational_subtype)
- [ ] `docs/adr/0008-ledger-schema-design.md` - Ledger schema design reference

## Expected Outputs

- [ ] **Migration file**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_accounts.exs`
  - `accounts` table with all canonical fields from plan.md
  - Indexes: `[:entity_id]` and `[:entity_id, :archived_at]` composite
  - FK constraint to `entities` table
- [ ] **Schema file**: `lib/aurum_finance/ledger/account.ex`
  - `AurumFinance.Ledger.Account` with Ecto.Enum for `account_type` and `operational_subtype`
  - `@required` / `@optional` field lists
  - `changeset/2` with i18n validation messages
  - `normal_balance/1` helper (`:debit` for asset/expense, `:credit` for liability/equity/income)
  - `operational_subtypes_for_type/1` helper
  - Immutability guards for `account_type`, `operational_subtype`, and `currency_code` on updates
- [ ] **Context file**: `lib/aurum_finance/ledger.ex`
  - `AurumFinance.Ledger` context with:
    - `list_accounts/1` (entity-scoped, opts: entity_id, include_archived, account_type, operational_subtype)
    - `get_account!/1`
    - `create_account/2` (attrs, opts) with audit event
    - `update_account/3` (account, attrs, opts) with audit event
    - `archive_account/2` (account, opts) with audit event
    - `unarchive_account/2` (account, opts) with audit event
    - `change_account/2` form helper
    - `get_account_balance/2` placeholder returning `%{}`
  - Private `filter_query/2` multi-clause function
  - Private `account_snapshot/1` serializer for audit events
  - `@audit_redact_fields [:institution_account_ref]`
- [ ] **Gettext entries**: New keys in `errors` domain for account-specific validation messages

## Acceptance Criteria

- [ ] Migration creates `accounts` table with all fields matching plan.md canonical field table
- [ ] `account_type` enum includes exactly: `asset`, `liability`, `equity`, `income`, `expense`
- [ ] `operational_subtype` enum includes exactly: `bank_checking`, `bank_savings`, `cash`, `brokerage_cash`, `brokerage_securities`, `crypto_wallet`, `credit_card`, `loan`, `other_asset`, `other_liability`
- [ ] `currency_code` validated with `validate_length(is: 3)` AND `validate_format(~r/^[A-Z]{3}$/)`
- [ ] `account_type`, `operational_subtype`, and `currency_code` are immutable after creation (changeset guards on update)
- [ ] `operational_subtype` is required for asset/liability accounts, nil for income/expense/equity
- [ ] `list_accounts/1` requires `entity_id` in opts and never returns cross-entity data
- [ ] `list_accounts/1` excludes archived accounts by default; `include_archived: true` includes them
- [ ] All create/update/archive/unarchive operations emit audit events via `Audit.with_event/3`
- [ ] `institution_account_ref` is redacted in audit snapshots
- [ ] `get_account_balance/2` returns `%{}` (empty map)
- [ ] `normal_balance/1` returns `:debit` for `asset`/`expense`, `:credit` for `liability`/`equity`/`income`
- [ ] All validation messages use `dgettext("errors", ...)` i18n pattern
- [ ] No hard-delete function exists in the context
- [ ] `mix test` passes (existing tests still green)
- [ ] `mix precommit` passes with zero warnings/errors

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/entities.ex              # Context API pattern to mirror
lib/aurum_finance/entities/entity.ex       # Schema pattern to mirror
lib/aurum_finance/audit.ex                 # Audit.with_event/3, serializer pattern
lib/aurum_finance/audit/audit_event.ex     # AuditEvent schema shape
lib/aurum_finance/helpers.ex               # humanize_token/1 for UI option labels
priv/repo/migrations/                      # Migration naming pattern
priv/gettext/errors.pot                    # Error message domain
priv/gettext/en/LC_MESSAGES/errors.po      # English error translations
```

### Patterns to Follow

**Context API pattern** (from `AurumFinance.Entities`):
- `@entity_type "account"` module attribute for audit events
- `@default_actor "system"` module attribute
- `@audit_redact_fields [:institution_account_ref]` for audit redaction
- `@type list_opt` and `@type audit_opt` typespecs
- `@spec` annotations on all public functions
- `extract_audit_metadata/1` private helper for audit opts
- `update_account_with_action/4` private helper for update/archive/unarchive (mirrors `update_entity_with_action/4`)
- `account_snapshot/1` private serializer function for audit before/after snapshots
- `filter_query/2` multi-clause recursive pattern matching on opts

**Schema pattern** (from `AurumFinance.Entities.Entity`):
- `@primary_key {:id, :binary_id, autogenerate: true}`
- `@foreign_key_type :binary_id`
- `@type t :: %__MODULE__{}`
- `@required` and `@optional` module attributes
- `timestamps(type: :utc_datetime_usec)`
- Validation messages via `Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_key")`
- `belongs_to :entity, AurumFinance.Entities.Entity` association

**Changeset immutability guard pattern** for `account_type`, `operational_subtype`, `currency_code`:
- On update changesets (when `account.id` is not nil), reject changes to immutable fields
- Use `validate_change/3` or separate `create_changeset/2` vs `update_changeset/2` approach
- The plan specifies these fields are immutable once set

**Operational subtype conditional requirement**:
- `operational_subtype` must be required when `account_type` is `asset` or `liability`
- `operational_subtype` must be nil when `account_type` is `income`, `expense`, or `equity`
- Enforce via custom changeset validation

**Entity scoping in list_accounts/1**:
- `entity_id` is a required filter opt (not optional like entity list)
- The function should raise or return empty when `entity_id` is not provided
- This matches the ownership boundary contract requirement

### Constraints
- No `balance` column on the accounts table
- No pre-emptive scaffolding for transactions/postings tables
- `get_account_balance/2` signature: `get_account_balance(account_id, opts \\ [])` where opts may include `as_of_date` -- returns `%{}` for now
- Do not add `has_many :accounts` to Entity schema in this task (keep schemas decoupled for now)
- `institution_account_ref` must NOT appear in application logger output or flash messages

## Execution Instructions

### For the Agent
1. Read all inputs listed above, especially `plan.md` sections "Canonical Domain Decisions" and "Account fields"
2. Create the migration file following the pattern in `priv/repo/migrations/20260306175550_create_entities.exs`
3. Create `lib/aurum_finance/ledger/account.ex` following `lib/aurum_finance/entities/entity.ex` patterns
4. Create `lib/aurum_finance/ledger.ex` following `lib/aurum_finance/entities.ex` patterns
5. Add Gettext error message keys to `priv/gettext/errors.pot` and `priv/gettext/en/LC_MESSAGES/errors.po`
6. Run `mix test` to verify existing tests still pass
7. Run `mix precommit` to verify formatting, Credo, Dialyzer, Sobelow pass
8. Document all assumptions in "Execution Summary"
9. List any blockers or questions

### For the Human Reviewer
After agent completes:
1. Review migration for correct field types, constraints, and indexes
2. Review schema for correct Ecto.Enum values matching plan.md exactly
3. Verify immutability guards work (account_type, operational_subtype, currency_code cannot change on update)
4. Verify entity scoping is enforced in all query functions
5. Verify audit integration follows the same pattern as entities context
6. Verify `institution_account_ref` is in `@audit_redact_fields`
7. Check that no `balance` column exists on the accounts table
8. Run `mix test` and `mix precommit` locally
9. If approved: mark `[x]` on "Approved" and update plan.md status
10. If rejected: add rejection reason and specific feedback

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
| | |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| | | |

### Blockers Encountered
- [Blocker] - Resolution: [How resolved or "Needs human input"]

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
