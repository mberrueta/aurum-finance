# Task 01: Domain + Data Model Foundation (Transaction, Posting, Migration)

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None (Issues #10 and #11 are complete)
- **Blocks**: Tasks 02, 03

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate the `dev-backend-elixir-engineer` agent with the following prompt:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 01 from `llms/tasks/012_ledger_primitives/01_domain_data_model_foundation.md`.
>
> Read all inputs listed in the task, then implement the Transaction and Posting schemas, migrations (including the zero-sum database trigger), and the Ledger context API additions as specified. Follow the existing Account model patterns exactly. Do NOT modify `plan.md`.

## Objective
Introduce the `AurumFinance.Ledger.Transaction` and `AurumFinance.Ledger.Posting` schemas with database migrations, a database-level zero-sum constraint trigger, and the core `Ledger` context API additions. Replace the placeholder `Ledger.get_account_balance/2` with a real posting-backed implementation. Add ExMachina factories, fixture helpers, and realistic seed data (6 scenarios) for development and demo use.

This delivers the complete double-entry write model for AurumFinance. Key design constraints: no `updated_at` on either table, no `memo` on transactions, no `status` enum — `voided_at` is the void marker.

## Inputs Required

- [ ] `llms/tasks/012_ledger_primitives/plan.md` - Master plan with canonical domain decisions, field definitions, invariants, user stories, acceptance criteria, and edge cases
- [ ] `llms/constitution.md` - Global rules (changeset conventions, filter_query pattern, i18n validation, no secrets)
- [ ] `llms/project_context.md` - Project conventions (ledger-first, entity scoping, dual classification)
- [ ] `lib/aurum_finance/ledger.ex` - Existing Ledger context with account APIs (extend, do not rewrite)
- [ ] `lib/aurum_finance/ledger/account.ex` - Account schema (reference for patterns, association target)
- [ ] `lib/aurum_finance/entities/entity.ex` - Entity schema (association target for transactions)
- [ ] `lib/aurum_finance/entities.ex` - Reference context API pattern (filter_query, audit integration)
- [ ] `lib/aurum_finance/audit.ex` - `Audit.with_event/3` API and serializer pattern
- [ ] `lib/aurum_finance/audit/audit_event.ex` - AuditEvent schema shape
- [ ] `priv/repo/migrations/20260307120000_create_accounts.exs` - Migration pattern reference
- [ ] `test/support/factory.ex` - ExMachina factory pattern (entity_factory, account_factory)
- [ ] `test/support/fixtures.ex` - Fixture helper pattern (entity_fixture, account_fixture)
- [ ] `docs/adr/0008-ledger-schema-design.md` - Ledger schema design reference
- [ ] `docs/adr/0002-ledger-as-internal-double-entry-model.md` - Double-entry model ADR

## Expected Outputs

- [ ] **Migration file**: `priv/repo/migrations/YYYYMMDDHHMMSS_create_transactions_and_postings.exs`
  - `transactions` table with all fields from plan.md:
    - `id` (UUID PK), `entity_id` (UUID FK to entities, NOT NULL), `date` (date, NOT NULL), `description` (string, NOT NULL), `source_type` (string, NOT NULL), `correlation_id` (UUID, nullable), `voided_at` (utc_datetime_usec, nullable), `inserted_at` (utc_datetime_usec)
    - **No `memo` column. No `status` column. No `updated_at` column.**
  - Indexes: `[:entity_id]`, `[:entity_id, :date]`, `[:correlation_id]`
  - FK constraint to `entities` table
  - `postings` table with all fields from plan.md:
    - `id` (UUID PK), `transaction_id` (UUID FK to transactions, NOT NULL, `on_delete: :restrict`), `account_id` (UUID FK to accounts, NOT NULL), `amount` (numeric, NOT NULL), `inserted_at` (utc_datetime_usec)
    - **No `currency_code` column. No `entity_id` column. No `updated_at` column.**
  - Indexes: `[:transaction_id]`, `[:account_id]`
  - Database-level zero-sum constraint trigger:
    - `DEFERRABLE INITIALLY DEFERRED` — fires at commit time, not per-row
    - Fires after insert on postings
    - Joins `accounts` via `account_id` to get effective currency
    - Groups by `account.currency_code` for the transaction
    - Raises if any group sum is not zero
    - Handles batch inserts correctly (fires at commit time, not per-row)

- [ ] **Schema file**: `lib/aurum_finance/ledger/transaction.ex`
  - `AurumFinance.Ledger.Transaction` with:
    - `Ecto.Enum` for `source_type` only (`:manual`, `:import`, `:system`) — no `status` enum
    - `@required [:entity_id, :date, :description, :source_type]`
    - `@optional [:correlation_id, :voided_at]`
    - `changeset/2` — for creation; validates required fields, description max 500 chars
    - `void_changeset/1` — accepts only `voided_at`; used exclusively by the void workflow
    - `has_many :postings, Posting`
    - `belongs_to :entity, Entity`
    - Immutability guards for `entity_id`, `date`, `description`, `source_type` on updates
    - `timestamps(type: :utc_datetime_usec, updated_at: false)` — no `updated_at`
    - **No `memo` field. No `status` field. No `archived_at` field.**

- [ ] **Schema file**: `lib/aurum_finance/ledger/posting.ex`
  - `AurumFinance.Ledger.Posting` with:
    - `@required [:transaction_id, :account_id, :amount]`
    - `@optional []`
    - `changeset/2` with i18n validation messages
    - `belongs_to :transaction, Transaction`
    - `belongs_to :account, Account`
    - `amount` validation: required, non-nil
    - `timestamps(type: :utc_datetime_usec, updated_at: false)` -- no `updated_at`
    - No `currency_code` field
    - No `entity_id` field

- [ ] **Context additions**: `lib/aurum_finance/ledger.ex` (extend existing file)
  - New module attributes: `@transaction_entity_type "transaction"` (separate from existing `@entity_type "account"`)
  - New public functions:
    - `create_transaction(attrs, opts \\ [])` -- Creates a transaction with nested postings atomically. Validation order: (a) structural checks, (b) load all accounts in one query, (c) validate entity isolation (`account.entity_id == transaction.entity_id` for ALL), (d) validate zero-sum per currency group. Returns `{:ok, transaction}` with postings preloaded, or `{:error, changeset}`. Emits audit event.
    - `get_transaction!(entity_id, transaction_id)` -- Entity-scoped retrieval with postings preloaded. Raises `Ecto.NoResultsError`.
    - `list_transactions(opts)` -- Entity-scoped listing. Requires `entity_id`. Filters: `source_type`, `account_id`, `date_from`, `date_to`, `include_voided` (default `false`, excludes rows where `voided_at IS NOT NULL`). Preloads postings. Ordered by `date` desc, then `inserted_at` desc.
    - `void_transaction(transaction, opts \\ [])` -- Void workflow: sets `voided_at` on original (via `void_changeset/1`), creates reversing transaction with negated amounts, links both via a new `correlation_id`. Guards against double-void: rejects if `transaction.voided_at` is already non-nil. Returns `{:ok, %{voided: tx, reversal: tx}}`. Emits two audit events.
  - Replace `get_account_balance/2` placeholder:
    - Joins postings to accounts (for `currency_code`) and transactions (for `date` filtering)
    - Returns `%{String.t() => Decimal.t()}` -- map of currency_code to balance
    - Supports `as_of_date` option filtering by `transaction.date <= as_of_date`
    - Returns `%{}` for accounts with no postings (backward compatible)
  - New private helpers:
    - `validate_zero_sum/3` -- Loads accounts, groups by `account.currency_code`, validates SUM = 0 per group
    - `validate_entity_isolation/3` -- Validates `account.entity_id == transaction.entity_id` for all accounts
    - `validate_minimum_postings/1` -- At least 2 postings required
    - `transaction_snapshot/1` -- Serializes transaction + posting summary for audit events
    - `filter_query/2` clauses for new transaction filters (`source_type`, `account_id`, `date_from`, `date_to`, `include_voided`)

- [ ] **Factory additions**: `test/support/factory.ex`
  - `transaction_factory` -- Creates a valid transaction with `voided_at: nil`, `source_type: :manual`
  - `posting_factory` -- Creates a valid posting with a decimal amount

- [ ] **Fixture additions**: `test/support/fixtures.ex`
  - `transaction_fixture/2` -- Creates a balanced transaction with at least 2 postings via the context API

- [ ] **Gettext entries**: New keys in `errors` domain for transaction/posting validation messages

- [ ] **Seed data additions**: `priv/repo/seeds.exs`
  - 6 realistic transaction scenarios, each calling `Ledger.create_transaction/2`:
    1. Simple expense: `{checking, -45.00}`, `{groceries, +45.00}` — a direct purchase from checking to an expense account
    2. Transfer between two accounts: `{checking, -1000.00}`, `{savings, +1000.00}` — both asset accounts, same entity
    3. Credit card purchase: `{dining_expense, +85.00}`, `{credit_card, -85.00}` — debit expense, credit the credit card liability
    4. Credit card payment: `{credit_card, +500.00}`, `{checking, -500.00}` — pay down the credit card from checking
    5. Split transaction: `{checking, -150.00}`, `{groceries, +80.00}`, `{household, +70.00}` — a single payment across multiple expense accounts (3 postings)
    6. Voided transaction: post a simple expense, then call `Ledger.void_transaction/2` — produces a void-and-reversal pair with shared `correlation_id`; `voided_at` is set on the original
    6. System transaction: `source_type: :system`, a synthetic entry (e.g., opening balance) — `{equity, -1000.00}`, `{checking, +1000.00}`
  - Seed transactions must use accounts already created in `seeds.exs` (reuse existing account seed fixtures)
  - Seeds are idempotent: guard with `if Repo.aggregate(Transaction, :count) == 0 do ... end`

## Acceptance Criteria

### Schema and Migration
- [ ] `transactions` table created with all fields matching plan.md canonical field table
- [ ] `transactions` table has NO `memo` column, NO `status` column, NO `updated_at` column
- [ ] `transactions` table has `voided_at` (utc_datetime_usec, nullable)
- [ ] `postings` table created with all fields matching plan.md, NO `currency_code` column, NO `entity_id` column, NO `updated_at` column
- [ ] `source_type` enum includes exactly: `manual`, `import`, `system`
- [ ] `postings.amount` uses PostgreSQL `numeric` type (arbitrary precision)
- [ ] `postings.transaction_id` FK has `on_delete: :restrict`
- [ ] Database zero-sum trigger exists and fires at commit time (DEFERRABLE INITIALLY DEFERRED)
- [ ] All required indexes exist: `[:entity_id]`, `[:entity_id, :date]`, `[:correlation_id]`, `[:transaction_id]`, `[:account_id]`

### Context API
- [ ] `create_transaction/2` validates zero-sum per currency group (via account join), NOT globally
- [ ] `create_transaction/2` rejects postings that reference accounts from a different entity
- [ ] `create_transaction/2` rejects fewer than 2 postings
- [ ] `create_transaction/2` returns `{:ok, transaction}` with postings preloaded on success
- [ ] `create_transaction/2` emits audit event with `entity_type: "transaction"`, `action: "created"`
- [ ] `create_transaction/2` runs entire operation inside `Repo.transaction/1` (atomic)
- [ ] `create_transaction/2` loads all referenced accounts in a single query (no N+1)
- [ ] `get_transaction!/2` takes `(entity_id, transaction_id)` and raises on wrong entity
- [ ] `list_transactions/1` requires `entity_id` (raises `ArgumentError` if missing)
- [ ] `list_transactions/1` excludes voided transactions (`voided_at IS NOT NULL`) by default; `include_voided: true` includes them
- [ ] `list_transactions/1` supports filters: `source_type`, `account_id`, `date_from`, `date_to`
- [ ] `list_transactions/1` preloads postings, ordered by `date` desc then `inserted_at` desc
- [ ] `void_transaction/2` sets `voided_at` on original to current UTC datetime (via `void_changeset/1`)
- [ ] `void_transaction/2` creates reversing transaction with negated amounts and same `account_id` values
- [ ] `void_transaction/2` links both via `correlation_id` (new UUID generated at void time)
- [ ] `void_transaction/2` reversal has `source_type: :system`, `voided_at: nil`
- [ ] `void_transaction/2` emits two audit events: `"voided"` on original, `"created"` on reversal
- [ ] `void_transaction/2` returns `{:error, changeset}` if transaction `voided_at` is already non-nil

### Balance Derivation
- [ ] `get_account_balance/2` replaced -- no longer returns hardcoded `%{}`
- [ ] Balance computed from postings via account join: `SELECT a.currency_code, SUM(p.amount) FROM postings p JOIN accounts a ON ...`
- [ ] Returns `%{currency_code => Decimal.t()}` -- exactly one key for a given account
- [ ] Returns `%{}` for accounts with no postings (backward compatible)
- [ ] `as_of_date` filters by `transaction.date <= as_of_date`
- [ ] No FX conversion performed

### Immutability and Integrity
- [ ] Transaction immutable fields (`entity_id`, `date`, `description`, `source_type`) have changeset guards
- [ ] No update API for postings (no update function exposed)
- [ ] No delete API for transactions or postings
- [ ] `void_changeset/1` is the only changeset that sets `voided_at`; it rejects all other field changes
- [ ] `void_transaction/2` guards against double-void: rejects if `transaction.voided_at` is already set
- [ ] Amount of zero in a posting is allowed
- [ ] Neither `transactions` nor `postings` tables have `updated_at` columns

### Audit
- [ ] Transaction creation emits audit event with `entity_type: "transaction"`, `action: "created"`
- [ ] Void emits `"voided"` on original and `"created"` on reversal
- [ ] Audit snapshots include transaction fields + posting summary `[%{account_id: uuid, amount: decimal}]`
- [ ] `@audit_redact_fields` for transactions is `[]` (no sensitive fields)

### Quality Gates
- [ ] `mix test` passes (all existing tests still green)
- [ ] `mix precommit` passes with zero warnings/errors
- [ ] All validation messages use `dgettext("errors", ...)` i18n pattern

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex                            # Extend with transaction APIs
lib/aurum_finance/ledger/account.ex                    # Reference schema pattern, association target
lib/aurum_finance/entities/entity.ex                   # Entity schema, association target
lib/aurum_finance/entities.ex                          # Context API pattern (filter_query, audit, require_entity_scope!)
lib/aurum_finance/audit.ex                             # Audit.with_event/3 API
lib/aurum_finance/audit/audit_event.ex                 # AuditEvent schema shape
priv/repo/migrations/20260307120000_create_accounts.exs  # Migration pattern
test/support/factory.ex                                # ExMachina factory pattern
test/support/fixtures.ex                               # Fixture helper pattern
priv/gettext/errors.pot                                # Error message domain
priv/gettext/en/LC_MESSAGES/errors.po                  # English error translations
```

### Patterns to Follow

**Context API pattern** (from existing `AurumFinance.Ledger`):
- Use a separate `@transaction_entity_type "transaction"` for transaction audit events (keep `@entity_type "account"` for existing account audit events)
- Reuse existing `@default_actor`, `extract_audit_metadata/1`, `normalize_actor/1`
- Add `require_entity_scope!/1` error message variant for transactions (or make it generic)
- `filter_query/2` multi-clause recursive pattern matching on opts for transaction filters
- Catch-all clause `filter_query(query, [_unknown | rest])` to skip unknown filters

**Schema pattern** (from `AurumFinance.Ledger.Account`):
- `@primary_key {:id, :binary_id, autogenerate: true}`
- `@foreign_key_type :binary_id`
- `@type t :: %__MODULE__{}`
- `@required` and `@optional` module attributes
- `timestamps(type: :utc_datetime_usec, updated_at: false)` for **both** Transaction and Posting — neither has `updated_at`
- Validation messages via `Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_key")`
- Immutability guards pattern from Account: check `data.id` is not nil, then reject changes to immutable fields
- Transaction has two changesets: `changeset/2` (creation) and `void_changeset/1` (sets `voided_at` only)

**Zero-sum validation approach** in `create_transaction/2`:
1. Extract `entity_id` and `postings` attrs from the input map
2. Run structural changeset validation on transaction + each posting
3. Load all referenced `account_id` values in a single query: `Repo.all(from a in Account, where: a.id in ^account_ids, select: {a.id, a.entity_id, a.currency_code})`
4. Validate entity isolation: every `account.entity_id` must equal `transaction.entity_id`
5. Group postings by `account.currency_code` (looked up from the account map)
6. For each currency group: `Decimal.eq?(SUM(amounts), Decimal.new("0"))` must be true
7. If all validations pass, insert transaction + postings inside `Repo.transaction/1`
8. Return `{:ok, transaction}` with postings preloaded

**Void workflow approach**:
1. Verify `transaction.voided_at == nil` (reject with error if already voided)
2. Generate a new `correlation_id` UUID
3. Inside `Repo.transaction/1`:
   a. Update original: apply `void_changeset(original, %{voided_at: DateTime.utc_now(), correlation_id: correlation_id})` then `Repo.update/1`
   b. Create reversal: copy `entity_id`, `date`, `description` from original; set `source_type: :system`, `voided_at: nil`, `correlation_id: correlation_id`
   c. Create reversed postings: same `account_id` values, negated amounts
   d. Emit audit event `"voided"` on original
   e. Emit audit event `"created"` on reversal
4. Return `{:ok, %{voided: updated_original, reversal: new_reversal}}`

Note: the reversal is a fresh normal transaction (not pre-voided). Its `description` may be "Reversal of {original.description}" — no memo field is used.

**Database trigger** (PostgreSQL):
- Use `CREATE CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` so it fires at commit time, not per-row
- The trigger function joins `postings` to `accounts` for the given `transaction_id`
- Groups by `currency_code`, sums amounts, raises if any sum != 0
- Write in `execute/1` within the migration

### Constraints
- Do NOT add `has_many :transactions` to Entity schema (keep schemas decoupled)
- Do NOT add `has_many :postings` to Account schema (keep schemas decoupled)
- The `account_id` filter in `list_transactions/1` returns transactions that have at least one posting targeting that account (use a subquery or join)
- Posting references to archived accounts are allowed (archival is a UI concern, not a ledger constraint)
- No artificial limit on number of postings per transaction
- `description` max 500 chars
- **No `memo` field anywhere** — not in schema, changesets, seeds, or tests
- **No `status` field anywhere** — use `voided_at IS NULL/NOT NULL` for void state; no enum
- **No `updated_at` on either table** — both use `timestamps(type: :utc_datetime_usec, updated_at: false)`
- Do NOT call `Repo.update` on transactions except in `void_transaction/2` (via `void_changeset/1`)
- Import/ingestion integration is NOT implemented — `source_type: :import` is a valid enum value only; no file parsing, CSV, or ImportBatch integration in this task

## Execution Instructions

### For the Agent
1. Read all inputs listed above, especially the plan.md sections "Canonical Domain Decisions", "Domain Invariants", and "Schema and Design Assumptions"
2. Create the migration file with both tables, indexes, FK constraints, and the zero-sum trigger
3. Create `lib/aurum_finance/ledger/transaction.ex` following the Account schema pattern
4. Create `lib/aurum_finance/ledger/posting.ex` following the Account schema pattern (with `updated_at: false`)
5. Extend `lib/aurum_finance/ledger.ex` with the new transaction/posting APIs (do not rewrite existing account APIs)
6. Add `transaction_factory` and `posting_factory` to `test/support/factory.ex`
7. Add `transaction_fixture/2` to `test/support/fixtures.ex`
8. Add Gettext error message keys to `priv/gettext/errors.pot` and `priv/gettext/en/LC_MESSAGES/errors.po`
9. Add 6 seed transaction scenarios to `priv/repo/seeds.exs` (idempotent guard required)
10. Run `mix test` to verify existing tests still pass
11. Run `mix precommit` to verify formatting, Credo, Dialyzer, Sobelow pass
12. Document all assumptions in "Execution Summary"
13. List any blockers or questions

### For the Human Reviewer
After agent completes:
1. Review migration — verify: no `memo`, no `status`, no `updated_at` on transactions; `voided_at` nullable; no `currency_code`/`entity_id`/`updated_at` on postings
2. Review zero-sum trigger: must join accounts, group by currency_code, fire at commit time (`DEFERRABLE INITIALLY DEFERRED`)
3. Review `create_transaction/2` validation order: structural, load accounts, entity isolation, zero-sum
4. Verify `void_transaction/2` sets `voided_at` via `void_changeset/1`; no status enum involved
5. Verify entity scoping is enforced in all query functions
6. Verify audit integration for transaction lifecycle events
7. Verify `get_account_balance/2` is no longer a placeholder
8. Verify seed data covers all 6 scenarios including a void-and-reversal pair
9. Run `mix test` and `mix precommit` locally
10. If approved: mark `[x]` on "Approved" and update plan.md status
11. If rejected: add rejection reason and specific feedback

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
