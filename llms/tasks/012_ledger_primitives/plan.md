# Execution Plan: Issue #12 — Ledger Primitives (Transactions, Postings, Balance Invariants)

## Metadata

- **Issue**: `https://github.com/mberrueta/aurum-finance/issues/12`
- **Created**: 2026-03-07
- **Updated**: 2026-03-07
- **Status**: PLANNED
- **Current Task**: None started
- **Depends on**: Issue #10 (Entity Model) — COMPLETED, Issue #11 (Account Model) — COMPLETED

---

## Context

Issues #10 and #11 established entity ownership and the account model. This issue delivers the write model that makes AurumFinance a real ledger: **Transaction** and **Posting** schemas, the zero-sum balance invariant, and the context API that enforces these rules.

A Transaction is the header record for a balanced financial event. A Posting is a single debit or credit leg targeting one account. Together they form a double-entry ledger entry.

This issue also replaces the placeholder `Ledger.get_account_balance/2` with a real posting-backed implementation that derives balances from the postings table.

This plan is aligned with:

- **ADR-0002**: Double-entry internal model with personal-finance UX mapping
- **ADR-0008**: Ledger schema design (transactions, postings, zero-sum invariant, balance derivation)
- **ADR-0004**: Immutable facts vs. mutable classification (postings are immutable facts)
- **Issue #11 plan**: Established `AurumFinance.Ledger` context and `Account` schema

**Scope boundary**: This issue delivers the domain and data layer, test coverage, seed data, and a read-only Transactions LiveView. No write UI, no create/edit/import forms, no import pipeline integration.

---

## Objective

Implement the Transaction and Posting schemas with their enforced invariants. Establish the double-entry write model as the canonical source of financial truth for all downstream reporting, reconciliation, and classification work.

---

## Scope

- Introduce `AurumFinance.Ledger.Transaction` and `AurumFinance.Ledger.Posting` schemas.
- Implement the zero-sum balance invariant, enforced at both application and database levels.
- Implement entity-scoped transaction context APIs.
- Implement the void-and-reverse workflow for transaction correction.
- Replace the placeholder `Ledger.get_account_balance/2` with a real posting-backed implementation.
- Emit audit events for all transaction lifecycle events.
- Deliver full test coverage including the balance invariant and entity/account scoping.
- Seed realistic transaction data (6 scenarios) for development and demo use.
- Replace the hardcoded `TransactionsLive` placeholder with a read-only Transactions page that loads from the database with filtering (entity, account, date range, source type). No create, edit, import, or void UI.

---

## Domain Invariants

The following invariants must hold throughout the system and are enforced by this issue.

1. **Ledger-first.** The ledger is the source of financial truth. Reporting, summaries, and normalized views are downstream read models. No reporting-driven shortcut or denormalized field belongs in the transaction or posting write model.

2. **Entity ownership is mandatory on transactions.** Every transaction carries a required, immutable `entity_id`. This is the ownership boundary of the financial event. Cross-entity transaction access is a critical defect. Postings do not carry `entity_id` directly — entity scope is derived through the parent transaction via join.

3. **All accounts referenced by a transaction's postings must belong to the same entity as the transaction.** `transaction.entity_id` must equal `account.entity_id` for every account referenced by its postings. This is enforced at the application layer in `create_transaction/2` when loading accounts for zero-sum validation. A posting that references an account from a different entity is rejected. This invariant closes the cross-entity isolation boundary at the write model level.

4. **Every posting references exactly one account, and the account's currency is the posting's currency.** There is no `currency_code` column on postings. The currency of a posting is always `account.currency_code` — derived at read time by joining the account. This is not a validation rule; it is a structural invariant enforced by schema design.

4. **Zero-sum invariant.** Within any transaction, the sum of posting amounts grouped by the effective currency (i.e., `account.currency_code` via join) must equal zero for every currency present. This is enforced at both the application layer (before persistence) and the database layer (trigger).

5. **An account balance is always in exactly one currency.** Because every posting's effective currency is the referenced account's `currency_code`, and every account has exactly one `currency_code`, `get_account_balance/2` for a single account always returns a map with exactly one key — or an empty map if no postings exist. There is no multi-currency account balance.

6. **Postings are fully immutable.** There is no update or delete path for postings. Corrections are handled by voiding the parent transaction and creating a new one.

7. **Transactions use void-and-reverse, not delete.** The only mutation of a posted transaction is transitioning to `:voided` via the void workflow, which creates an equal-and-opposite reversing transaction. Voided transactions' postings remain in the posting history; the reversing postings cancel them out.

8. **No FX conversion in the ledger.** The ledger stores original monetary facts in account-native currencies. Currency normalization to a presentation currency belongs to reporting/read models and is explicitly out of scope for this issue and all future issues that extend the core ledger write model.

9. **Facts vs. overlays.** Immutable financial facts live in the ledger (transactions, postings, amounts, dates). Classification, categorization, reconciliation state, and reporting overlays belong in separate contexts and must not leak into core ledger fact storage.

10. **Transactions are immutable ledger facts — no `updated_at`.** Transactions carry no `updated_at` timestamp because the only supported mutation is `voided_at`, which is set once and never changed. `voided_at` is a nullable `utc_datetime_usec` field: `NULL` means posted; a non-null timestamp means voided and records when the void occurred. This replaces the `status` enum and aligns with the fact that a ledger transaction, once voided, is voided permanently. Postings also carry no `updated_at` — they are fully immutable after creation.

11. **Import boundary: imports do not create ledger facts directly.** File imports and CSV ingestion first stage rows into an `ImportBatch`/`ImportRow` model for review and approval. Only after explicit approval does the ingestion pipeline call `Ledger.create_transaction/2`. Raw file parsing, CSV handling, and import staging are explicitly out of scope for this issue.

---

## Out of Scope

The following are explicitly excluded from this issue and must not be implemented here:

1. **Write/CRUD UI for transactions.** No create, edit, import, or delete forms. The Transactions LiveView added in this issue is read-only: it displays ledger data with filters but provides no mutation paths.

2. **Transaction annotations and memo field.** The `transactions` table has no `memo` or free-text annotation field. Factual notes, classification labels, and user-facing annotations belong in a future overlay model (separate context, separate table, references a transaction by ID). Deferred to a future issue.

3. **FX conversion and reporting normalization.** The ledger stores facts in original account currencies. Converting balances to a presentation currency (e.g., USD net worth across BRL and USD accounts) is the responsibility of reporting and read models. No FX rate lookup, conversion, or normalization is introduced in `AurumFinance.Ledger`.

4. **Automated trading/bridge account creation.** Cross-currency movements that require bridge accounts (e.g., FX buy/sell workflows) are a future milestone. When supported, they will use explicit bridge-account patterns — each posting still references an account whose currency it uses — not by introducing a free-form currency field on postings.

5. **End-user FX workflow abstraction.** This issue establishes the baseline ledger primitive model. It does not implement a complete or safe end-user experience for cross-currency transactions. That belongs to a higher-level builder milestone.

6. **BalanceSnapshot caching.** Performance optimization deferred per ADR-0008.

7. **Parent/child account tree.** `parent_account_id` deferred per Issue #11 plan.

8. **Classification layer.** Category, tags, investment type on transactions belong to `AurumFinance.Classification` (ADR-0007).

9. **Import/ingestion integration.** The ingestion pipeline will call `create_transaction/2`, but that integration is a separate issue. File parsing, CSV processing, import batch/row models, and the staging-to-approval workflow are explicitly out of scope for this issue and all tasks within it.

10. **Reconciliation.** Reconciliation workflows operate on postings but belong to a separate context.

---

## Project Context

### Related Entities

- `AurumFinance.Entities.Entity` (`lib/aurum_finance/entities/entity.ex`)
  - Ownership boundary. Transactions are entity-scoped via `entity_id`.
- `AurumFinance.Ledger.Account` (`lib/aurum_finance/ledger/account.ex`)
  - Target of each posting. Postings reference `account_id`.
  - Has `currency_code` (immutable, ISO 4217) — the authoritative currency for any posting to this account.
  - Has `account_type` enum: `asset`, `liability`, `equity`, `income`, `expense`.
  - Provides `normal_balance/1` helper (`:debit` or `:credit`).
- `AurumFinance.Audit.AuditEvent` (`lib/aurum_finance/audit/audit_event.ex`)
  - Generic audit infrastructure. Transaction lifecycle events (create, void) emit audit events.
- `AurumFinance.Audit` (`lib/aurum_finance/audit.ex`)
  - `Audit.with_event/3` for transactional audit emission.

### Related Features

- **Account CRUD** (`lib/aurum_finance/ledger.ex`, `lib/aurum_finance/ledger/account.ex`)
  - The `Ledger` context exists with account APIs.
  - Transaction and Posting schemas are added to this same context.
  - `get_account_balance/2` currently returns `%{}` — this issue replaces it.
- **Entities context** (`lib/aurum_finance/entities.ex`)
  - Pattern to follow for context API shape, `filter_query/2`, audit integration.

### Naming Conventions

- Contexts: `AurumFinance.Ledger` (already exists)
- Schemas: `AurumFinance.Ledger.Transaction`, `AurumFinance.Ledger.Posting`
- Context functions: `list_*`, `get_*!`, `create_*`, `void_*`, `change_*`
- Filter pattern: Private `filter_query/2` multi-clause recursive function
- Audit pattern: `@entity_type`, `@default_actor`, `@audit_redact_fields`, `Audit.with_event/3`
- Schema pattern: `@primary_key {:id, :binary_id, autogenerate: true}`, `@required`/`@optional`, `timestamps(type: :utc_datetime_usec)`
- Validation: `dgettext(AurumFinanceWeb.Gettext, "errors", "error_key")`
- Factory: `ExMachina.Ecto` in `test/support/factory.ex`
- Fixtures: Context-based helpers in `test/support/fixtures.ex`

---

## Canonical Domain Decisions

### Transaction schema

| Field | Type | Required | Mutability | Notes |
|---|---|---|---|---|
| `id` | UUID | Yes | Immutable | PK |
| `entity_id` | UUID (FK → entities) | Yes | Immutable | NOT NULL, indexed; ownership boundary |
| `date` | `:date` | Yes | Immutable | User-facing transaction date; immutable fact per ADR-0004 |
| `description` | `:string` | Yes | Immutable | Original description from source; immutable fact |
| `source_type` | Ecto.Enum | Yes | Immutable | `manual`, `import`, `system` |
| `correlation_id` | UUID | No | Immutable | Links related transactions (void + reversal pairs) |
| `voided_at` | `:utc_datetime_usec` | No | Set-once | NULL = posted; non-null = voided; set once at void time, never changed |
| `inserted_at` | `:utc_datetime_usec` | — | Immutable | |

**Field decisions:**

- **No `status` enum.** A transaction's void state is tracked by `voided_at`: `NULL` means active/posted; a non-null timestamp means voided and records when. This is analogous to the `archived_at` pattern on `Account`. There is no `updated_at` on transactions — once created, the only allowed mutation is setting `voided_at` once via the void workflow.
- `source_type`: `:manual` for user-created, `:import` for ingestion pipeline output (after staging approval), `:system` for auto-generated (void reversals, opening balances, bridge entries).
- `correlation_id` is nullable. When present, it groups related transactions (void + reversal pairs). Set at void time.
- `description` is required and immutable — the original source description per ADR-0004's immutable facts principle.
- **No `memo` field.** Factual annotations do not belong in the ledger write model. User notes, labels, and classifications belong in a future overlay context (separate table referencing `transaction_id`). Deferred.

### Posting schema

| Field | Type | Required | Mutability | Notes |
|---|---|---|---|---|
| `id` | UUID | Yes | Immutable | PK |
| `transaction_id` | UUID (FK → transactions) | Yes | Immutable | NOT NULL |
| `account_id` | UUID (FK → accounts) | Yes | Immutable | NOT NULL; determines posting currency via `account.currency_code` |
| `amount` | `:decimal` | Yes | Immutable | Signed: positive = debit, negative = credit |
| `inserted_at` | `:utc_datetime_usec` | — | Immutable | |

**Field decisions:**

- `amount` uses the sign convention from ADR-0008: positive = debit, negative = credit. Internal convention only.
- **There is no `currency_code` column on postings.** A posting's currency is always `account.currency_code`, derived by joining the account. This is a structural invariant, not a runtime validation. The account FK is the single source of truth for posting currency.
- Postings have no `updated_at` — they are fully immutable after creation. `timestamps(updated_at: false)` is used in the schema.
- Postings do not carry `entity_id` — entity scope is derived through the parent transaction.

### Zero-sum invariant

**The invariant**: Within a transaction, the sum of posting amounts grouped by effective currency must equal zero for every currency present.

**Effective currency** is `account.currency_code` — determined by joining the `accounts` table via `posting.account_id`. There is no `currency_code` field on postings to group by directly.

Application-level validation in `create_transaction/2`:

```
For each posting: load account (currency_code + entity_id)
Validate: account.entity_id == transaction.entity_id for ALL accounts
Group postings by account.currency_code
For each group: SUM(amount) must = Decimal.new("0")
```

**Enforcement strategy (two levels):**

1. **Application level (primary)**: `Ledger.create_transaction/2` loads each posting's account, groups by `account.currency_code`, and validates the zero-sum condition per group before any insert. The entire operation runs inside a `Repo.transaction/1` — if validation fails, nothing is written.

2. **Database level (safety net)**: A trigger on the `postings` table verifies the zero-sum property after insert by joining accounts. This prevents direct database manipulation from creating invalid state. The trigger is a safety net for application bugs, not the primary enforcement path.

**Decimal precision**: All amount comparisons use `Decimal.eq?/2` against `Decimal.new("0")`. The `amount` column uses PostgreSQL `numeric` type (arbitrary precision, no fixed scale) to support all currency denominations.

### Balance derivation (replaces placeholder)

`Ledger.get_account_balance/2` currently returns `%{}`. This issue replaces it:

```sql
SELECT a.currency_code, SUM(p.amount)
FROM postings p
JOIN accounts a ON p.account_id = a.id
JOIN transactions t ON p.transaction_id = t.id
WHERE p.account_id = $account_id
  AND ($as_of_date IS NULL OR t.date <= $as_of_date)
GROUP BY a.currency_code
```

Returns `%{String.t() => Decimal.t()}` — a map of currency code to balance.

Because every account has exactly one `currency_code`, this query will always produce at most one row for a given `account_id`. The return type is a map for structural consistency with future aggregate queries. Returns `%{}` when no postings exist (backward compatible).

**No FX conversion is performed.** The balance is always in the account's own currency. Reporting layers that need multi-currency normalization (e.g., USD net worth) must apply FX rates externally.

The `as_of_date` option filters by `transaction.date`. When omitted, all postings are included (current balance).

**BalanceSnapshot**: Deferred to a future performance optimization issue per ADR-0008.

### Void workflow

A void cancels a transaction by:

1. Setting `voided_at` on the original transaction to the current UTC datetime (the only allowed mutation on a transaction).
2. Creating a new reversing transaction with equal-and-opposite postings (amounts negated).
3. Linking both via a shared `correlation_id` generated at void time.

The reversing transaction has `source_type: :system` and `voided_at: nil` (it is an active posted transaction).

**Balance semantics**: Voided transactions' postings remain in the posting history. The reversing postings net the effect to zero. `voided_at` is an audit/UI flag only — it does not filter postings from the balance derivation query. `list_transactions/1` excludes voided transactions (where `voided_at IS NOT NULL`) by default; `include_voided: true` includes them.

**Immutability note**: `voided_at` is set once and never changed. There is no "un-void". A voided transaction's `voided_at` is as immutable as its `inserted_at`. The only field mutation ever performed on a `transactions` row is setting `voided_at` at void time.

### Context API additions to `AurumFinance.Ledger`

New public functions:

- `create_transaction(attrs, opts \\ [])` — Creates a transaction with nested postings atomically. Validates zero-sum invariant. Emits audit event.
  - `attrs` must include `:entity_id`, `:date`, `:description`, `:source_type`, and `:postings` (list of posting attrs).
  - Each posting attr requires only `:account_id` and `:amount`. Currency and entity scope are derived from the account.
  - All accounts referenced must belong to `transaction.entity_id`. Cross-entity posting is rejected.
  - Returns `{:ok, transaction}` with postings preloaded, or `{:error, changeset}`.
- `get_transaction!(entity_id, transaction_id)` — Entity-scoped retrieval with postings preloaded. Raises `Ecto.NoResultsError`.
- `list_transactions(opts)` — Entity-scoped listing. Requires `entity_id` in opts.
  - Filters: `entity_id` (required), `source_type`, `account_id`, `date_from`, `date_to`, `include_voided` (default `false`, excludes rows where `voided_at IS NOT NULL`).
  - Preloads postings. Ordered by `date` desc, then `inserted_at` desc.
- `void_transaction(transaction, opts \\ [])` — Void workflow. Sets `voided_at` on original, creates reversal. Returns `{:ok, %{voided: tx, reversal: tx}}`.
- `get_account_balance(account_id, opts \\ [])` — Replaces the placeholder. Returns `%{currency_code => Decimal.t()}`.

**Functions NOT added in this issue:**

- `update_transaction/3` — Transactions are immutable facts. Corrections use void-and-recreate. Deferred.
- `delete_transaction/1` — No hard delete. Void is the only removal path.

### Audit events

- Transaction creation emits an audit event with `entity_type: "transaction"`, `action: "created"`.
- Void emits two audit events: `action: "voided"` on the original, `action: "created"` on the reversal.
- `@audit_redact_fields` for transactions: `[]` (no sensitive fields).
- Audit snapshots include transaction fields and a posting summary (account_id, amount per posting). Currency is derivable from the account.

### Archive/delete posture

- Transactions are **never archived or deleted**. There is no `archived_at` on transactions.
- The void workflow is the only mechanism to cancel a transaction.
- Postings are fully immutable — no update, no archive, no delete.

---

## Terminology Alignment

| External / ADR Term | Canonical Term | Reason |
|---|---|---|
| "split" | Transaction with >2 postings | ADR-0008: splits are multi-posting transactions, no separate entity |
| "debit" / "credit" | Positive / negative `amount` | Sign convention per ADR-0008 section 2 |
| "balance" column | Derived from postings | ADR-0008 section 4: no denormalized balance field |
| "direction" (from issue text) | `amount` sign (positive=debit, negative=credit) | ADR-0008 uses signed amounts, not a direction field |
| "state" (from issue text) | `voided_at` (nullable timestamp) | Void state is tracked by `voided_at IS NOT NULL`; no separate `status` enum on transactions |
| `posting.currency_code` | Does not exist | Posting currency is structural: always `account.currency_code` via join |
| `posting.entity_id` | Does not exist | Posting entity scope is derived via `transaction.entity_id`; account entity scope is derived via `account.entity_id`; both must match and are enforced at transaction creation |

---

## User Stories

### US-1: Create a balanced transaction

As a **system operator**, I want to create a transaction with multiple postings that sum to zero per effective currency, so that the ledger maintains double-entry correctness at all times.

### US-2: Reject unbalanced transactions

As a **system operator**, I want the system to reject any transaction where postings do not sum to zero per effective currency, so that balance integrity is guaranteed and ledger drift is impossible.

### US-3: Derive account balance from postings

As a **system operator**, I want to query an account's balance derived from its postings in the account's natural currency, so that balances are always consistent with the posting history and never stale.

### US-4: Derive account balance as of a specific date

As a **system operator**, I want to query an account's balance as of a specific date, so that I can see historical positions without manual calculation.

### US-5: List transactions for an entity

As a **system operator**, I want to list all transactions for a given entity with filtering by status, date range, and account, so that I can review the ledger history.

### US-6: Void a transaction

As a **system operator**, I want to void a transaction, which creates a reversing entry and sets the original to voided status, so that corrections preserve a full audit trail without destroying history.

### US-7: Entity-scoped transaction isolation

As a **system operator**, I want transactions to be strictly scoped to their owning entity, so that no cross-entity data leakage can occur.

### US-8: Audit trail for transaction lifecycle

As a **system operator**, I want every transaction creation and void to emit audit events with before/after snapshots, so that all ledger changes are fully traceable.

### US-9: Split transactions (multiple postings)

As a **system operator**, I want to create transactions with more than two postings, so that a single real-world event can distribute its amount across multiple accounts.

### US-10: Transactions spanning accounts in multiple currencies

As a **system operator**, I want to create transactions that span accounts with different currencies, where the zero-sum invariant is enforced per currency group via account join, so that multi-currency ledger facts are stored correctly in each account's natural currency.

---

## Acceptance Criteria

### US-1: Create a balanced transaction

**Scenario: Simple two-posting transaction**
- **Given** an entity with two accounts: `checking` (asset, `currency_code: "USD"`) and `groceries` (expense, `currency_code: "USD"`)
- **When** I call:
  ```elixir
  Ledger.create_transaction(%{
    entity_id: entity.id,
    date: ~D[2026-03-07],
    description: "Coffee",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-5.00")},
      %{account_id: groceries.id, amount: Decimal.new("5.00")}
    ]
  })
  ```
- **Then** the function returns `{:ok, transaction}` with `voided_at: nil` (active/posted)
- **And** the transaction has exactly 2 postings loaded
- **And** the sum of posting amounts is `Decimal.new("0")`

**Criteria Checklist:**
- [ ] Transaction is persisted with all required fields
- [ ] Postings are persisted with correct `transaction_id` FK
- [ ] Transaction `voided_at` is `nil` on creation
- [ ] Returned transaction has postings preloaded
- [ ] An audit event is emitted with `entity_type: "transaction"`, `action: "created"`

### US-2: Reject unbalanced transactions

**Scenario: Postings do not sum to zero**
- **Given** an entity with two accounts
- **When** I call `Ledger.create_transaction` with postings summing to `+5.00` (not zero)
- **Then** the function returns `{:error, changeset}`
- **And** the changeset has an error on `:postings` indicating the balance is not zero
- **And** no transaction or posting rows are persisted

**Scenario: Empty postings list**
- **Given** valid transaction attrs but `postings: []`
- **When** I call `Ledger.create_transaction`
- **Then** the function returns `{:error, changeset}` with error indicating at least 2 postings are required

**Scenario: Single posting**
- **Given** valid transaction attrs but only 1 posting
- **When** I call `Ledger.create_transaction`
- **Then** the function returns `{:error, changeset}` with error indicating at least 2 postings are required

**Criteria Checklist:**
- [ ] Unbalanced postings are rejected with a clear error message
- [ ] Fewer than 2 postings are rejected
- [ ] No partial writes occur (entire operation is atomic)
- [ ] Application-level validation catches the imbalance before hitting DB

### US-3: Derive account balance from postings

**Scenario: Account with postings**
- **Given** a USD checking account with 3 transactions resulting in net `+500.00`
- **When** I call `Ledger.get_account_balance(account.id)`
- **Then** the result is `%{"USD" => Decimal.new("500.00")}`

**Scenario: Account with no postings**
- **Given** an account with no postings
- **When** I call `Ledger.get_account_balance(account.id)`
- **Then** the result is `%{}`

**Criteria Checklist:**
- [ ] Balance is computed from postings via account join, not from a stored field
- [ ] Returns `%{account.currency_code => Decimal.t()}` — always exactly one key for a given account
- [ ] Returns `%{}` for accounts with no postings (backward compatible)
- [ ] No FX conversion is performed

### US-4: Derive account balance as of a specific date

**Scenario: Balance at a historical date**
- **Given** an account with postings on 2026-03-01 (`+100`), 2026-03-05 (`+200`), 2026-03-10 (`+300`)
- **When** I call `Ledger.get_account_balance(account.id, as_of_date: ~D[2026-03-05])`
- **Then** the result is `%{"USD" => Decimal.new("300.00")}` (sum of first two only)

**Criteria Checklist:**
- [ ] `as_of_date` filters by `transaction.date <= as_of_date`
- [ ] Omitting `as_of_date` returns the full balance (all postings)

### US-5: List transactions for an entity

**Scenario: Basic listing**
- **Given** two entities, each with transactions
- **When** I call `Ledger.list_transactions(entity_id: entity_a.id)`
- **Then** only entity A's transactions are returned, with postings preloaded, ordered by date desc

**Scenario: Filter by account**
- **Given** an entity with transactions across multiple accounts
- **When** I call `Ledger.list_transactions(entity_id: entity.id, account_id: checking.id)`
- **Then** only transactions that have at least one posting targeting `checking.id` are returned

**Criteria Checklist:**
- [ ] `entity_id` is required (raises `ArgumentError` if missing)
- [ ] Voided transactions (`voided_at IS NOT NULL`) excluded by default; `include_voided: true` includes them
- [ ] `source_type`, `account_id`, `date_from`, `date_to` filters work
- [ ] Postings are preloaded on each transaction
- [ ] Ordered by `date` desc, then `inserted_at` desc

### US-6: Void a transaction

**Scenario: Void a posted transaction**
- **Given** a posted transaction with 2 postings (`voided_at: nil`)
- **When** I call `Ledger.void_transaction(transaction)`
- **Then** the original transaction's `voided_at` is set to the current UTC datetime
- **And** a new reversing transaction is created with `voided_at: nil`, `source_type: :system`
- **And** the reversal has equal-and-opposite postings (amounts negated, same account_ids)
- **And** both transactions share the same `correlation_id`
- **And** the net balance effect across both transactions is zero

**Scenario: Void an already-voided transaction**
- **Given** a voided transaction (`voided_at IS NOT NULL`)
- **When** I call `Ledger.void_transaction(transaction)`
- **Then** the function returns `{:error, changeset}` with an error indicating the transaction is already voided

**Criteria Checklist:**
- [ ] Original transaction `voided_at` is set to the current UTC datetime
- [ ] Reversing transaction created with negated amounts and same `account_id` values
- [ ] Both share `correlation_id`
- [ ] Reversing transaction has `source_type: :system`, `voided_at: nil`
- [ ] Two audit events emitted: `"voided"` on original, `"created"` on reversal
- [ ] Cannot void an already-voided transaction (guard on `voided_at IS NOT NULL`)
- [ ] Balance derivation correctly nets voided + reversal to zero

### US-7: Entity-scoped transaction isolation

**Scenario: Cross-entity isolation**
- **Given** entity A with transactions and entity B with transactions
- **When** I call `Ledger.list_transactions(entity_id: entity_a.id)`
- **Then** no transactions from entity B appear in the results
- **When** I call `Ledger.get_transaction!(entity_b.id, entity_a_transaction.id)`
- **Then** `Ecto.NoResultsError` is raised

**Criteria Checklist:**
- [ ] `list_transactions/1` requires `:entity_id` in opts
- [ ] `get_transaction!/2` takes `entity_id` as first argument
- [ ] No cross-entity data leakage in any query path

### US-8: Audit trail for transaction lifecycle

**Scenario: Audit events for create and void**
- **Given** a transaction is created and then voided
- **When** I query audit events for the transaction
- **Then** there are 3 audit events: `"created"` (original), `"voided"` (original), `"created"` (reversal)
- **And** each event has `entity_type: "transaction"`, correct `actor`, `channel`, and `before`/`after` snapshots

**Criteria Checklist:**
- [ ] Create emits audit event with `before: nil`, `after: snapshot`
- [ ] Void emits audit event on original with `before: posted_snapshot`, `after: voided_snapshot`
- [ ] Reversal creation emits audit event with `before: nil`, `after: reversal_snapshot`
- [ ] Snapshots include posting summaries (account_id and amount per posting)

### US-9: Split transactions

**Scenario: Three-way split**
- **Given** a checking account (USD), a groceries account (USD), and a household account (USD)
- **When** I create a transaction with 3 postings: `{checking, -150}`, `{groceries, +120}`, `{household, +30}`
- **Then** the transaction is created successfully with 3 postings
- **And** the sum of amounts is zero

**Criteria Checklist:**
- [ ] Transactions with N postings (N >= 2) are supported
- [ ] Zero-sum invariant applies across all postings, not just pairs

### US-10: Transactions spanning accounts in multiple currencies

**Scenario: Transaction spanning USD and EUR accounts**
- **Given** four accounts: `usd_checking` (USD), `usd_trading` (USD), `eur_trading` (EUR), `eur_savings` (EUR)
- **When** I create a transaction with 4 postings:
  ```elixir
  postings: [
    %{account_id: usd_checking.id, amount: Decimal.new("-100.00")},
    %{account_id: usd_trading.id,  amount: Decimal.new("100.00")},
    %{account_id: eur_trading.id,  amount: Decimal.new("-92.00")},
    %{account_id: eur_savings.id,  amount: Decimal.new("92.00")}
  ]
  ```
- **Then** the transaction is created successfully
- **And** the system joins accounts to determine effective currencies:
  `usd_checking.currency_code = "USD"`, `usd_trading.currency_code = "USD"`, `eur_trading.currency_code = "EUR"`, `eur_savings.currency_code = "EUR"`
- **And** USD postings sum to `0`; EUR postings sum to `0`
- **And** `get_account_balance(usd_checking.id)` returns `%{"USD" => Decimal.new("-100.00")}`
- **And** `get_account_balance(eur_savings.id)` returns `%{"EUR" => Decimal.new("92.00")}`
- **And** no FX conversion is applied anywhere in the ledger

**Criteria Checklist:**
- [ ] Zero-sum invariant is enforced per effective currency group (via account join), not globally across all postings
- [ ] A transaction may span accounts with different currencies — the structural invariant (no posting currency field) makes currency mismatches impossible
- [ ] `get_account_balance/2` returns balance in the account's natural currency only
- [ ] No FX conversion logic is introduced in `AurumFinance.Ledger`

---

## Edge Cases

### Empty States
- [ ] Account with no postings → `get_account_balance/2` returns `%{}` (backward compatible)
- [ ] Entity with no transactions → `list_transactions/1` returns `[]`

### Error States
- [ ] Unbalanced postings → `{:error, changeset}` with clear error on `:postings`
- [ ] Fewer than 2 postings → `{:error, changeset}` with minimum count error
- [ ] Invalid `account_id` in posting → FK constraint error; not silent success
- [ ] Invalid `entity_id` → FK constraint error
- [ ] Posting references an account belonging to a different entity → `{:error, changeset}` with error on `:account_id`; no rows persisted
- [ ] Amount of exactly zero in a posting → Allowed (valid in double-entry for memo purposes)

### Immutability Enforcement
- [ ] Posting fields cannot be updated after creation (no update API exposed)
- [ ] Transaction immutable fields (`date`, `description`, `source_type`, `entity_id`) cannot be changed
- [ ] Transaction `voided_at` is set once at void time and is never subsequently changed or cleared
- [ ] No `updated_at` column exists on `transactions` or `postings` tables

### Concurrent Access
- [ ] Two concurrent `create_transaction` calls for the same entity → Both succeed independently
- [ ] Concurrent void of the same transaction → One succeeds; one gets stale data error or already-voided error

### Boundary Conditions
- [ ] Very large `amount` values (15+ digits) → PostgreSQL `numeric` handles arbitrary precision
- [ ] Very small `amount` values (many decimal places) → Supported by `numeric`
- [ ] Transaction with many postings (e.g., 50 splits) → No artificial limit
- [ ] `description` max length: 500 characters
- [ ] `date` in the far future or far past → Allowed (no date range restriction at schema level)

### Data Integrity
- [ ] Database-level trigger prevents unbalanced postings even via direct SQL (trigger joins accounts to determine effective currencies)
- [ ] Orphaned postings (no transaction) → Prevented by FK constraint with `on_delete: :restrict`
- [ ] Posting referencing archived account → Allowed (archival is a UI concern, not a ledger constraint)

---

## UX States

The Transactions LiveView is updated from a hardcoded placeholder to a real read-only view:

- **Default view**: Lists all active (non-voided) transactions for the current entity, ordered by date descending. Each row shows: date, description, source type, number of postings, and total absolute amount.
- **Voided transactions**: Excluded by default. A toggle or filter includes them with a visual indicator.
- **Filters**: entity (implicit from session), account (dropdown), date range (from/to), source type (all/manual/import/system).
- **Transaction detail**: Optional — clicking a row shows postings (account name, amount per posting).
- **No mutation UI**: No "New Transaction", "Void", "Edit", or "Import" buttons. This view is strictly read-only.
- **Seed data**: 6 realistic transaction scenarios in `priv/repo/seeds.exs` populate the Transactions page with meaningful demo content.

Empty state: If no transactions exist for the entity, display a helpful empty state message (no forms).

---

## Implementation Tasks

### Task 01 — Domain + Data Model Foundation (Transaction, Posting, Migration, Seeds)

- **Agent**: `dev-backend-elixir-engineer`
- **Goal**: Create `Transaction` and `Posting` schemas, migrations, core `Ledger` context API, and realistic seed data.
- **Deliverables**:
  - Migration for `transactions` table:
    - `id` (UUID PK)
    - `entity_id` (UUID FK → entities, NOT NULL, indexed)
    - `date` (date, NOT NULL)
    - `description` (string, NOT NULL)
    - `source_type` (string, NOT NULL) — `manual`, `import`, `system`
    - `correlation_id` (UUID, nullable, indexed)
    - `voided_at` (utc_datetime_usec, nullable) — NULL = active; non-null = voided; set once
    - `inserted_at` (utc_datetime_usec only — no `updated_at`)
    - **No `memo` field. No `status` field. No `updated_at`.**
  - Migration indexes for transactions:
    - `index(:transactions, [:entity_id])`
    - `index(:transactions, [:entity_id, :date])` — dominant query pattern
    - `index(:transactions, [:correlation_id])` — void/correction linkage
  - Migration for `postings` table:
    - `id` (UUID PK)
    - `transaction_id` (UUID FK → transactions, NOT NULL, `on_delete: :restrict`)
    - `account_id` (UUID FK → accounts, NOT NULL)
    - `amount` (numeric, NOT NULL) — arbitrary precision decimal, no fixed scale
    - `inserted_at` (utc_datetime_usec only — no `updated_at`; postings are fully immutable)
    - **No `currency_code`. No `entity_id`. No `updated_at`.**
  - Migration indexes for postings:
    - `index(:postings, [:transaction_id])`
    - `index(:postings, [:account_id])` — for balance derivation queries
  - Database-level zero-sum constraint trigger on `postings`:
    - `DEFERRABLE INITIALLY DEFERRED` — fires at commit time, not per-row
    - Joins `accounts` via `account_id` to determine effective currency per posting
    - Groups by `account.currency_code` for the inserted row's `transaction_id`
    - Raises if any group sum is not zero
  - `AurumFinance.Ledger.Transaction` schema:
    - `Ecto.Enum` for `source_type` only (`:manual`, `:import`, `:system`)
    - `@required [:entity_id, :date, :description, :source_type]`
    - `@optional [:correlation_id, :voided_at]`
    - `changeset/2` for creation (all required fields)
    - `void_changeset/1` for setting `voided_at` only (used by void workflow)
    - `has_many :postings, Posting`
    - `belongs_to :entity, Entity`
    - Immutability guards for `entity_id`, `date`, `description`, `source_type` — reject changes on update
    - Validation: `description` max 500 chars
    - `timestamps(type: :utc_datetime_usec, updated_at: false)`
  - `AurumFinance.Ledger.Posting` schema:
    - `@required [:transaction_id, :account_id, :amount]`, `@optional []`
    - `changeset/2` with i18n validation messages
    - `belongs_to :transaction, Transaction`
    - `belongs_to :account, Account`
    - `amount` validation: required, non-nil
    - `timestamps(type: :utc_datetime_usec, updated_at: false)` — no `updated_at`
    - No `currency_code` field. No `entity_id` field.
  - `AurumFinance.Ledger` context additions:
    - `create_transaction/2` — nested posting creation, zero-sum validation (via account join), entity isolation validation, audit event. Validation order: (a) structural, (b) load all accounts in one query, (c) validate entity isolation, (d) validate zero-sum per currency group.
    - `get_transaction!/2` — entity-scoped, postings preloaded
    - `list_transactions/1` — entity-scoped, postings preloaded, filters: `source_type`, `account_id`, `date_from`, `date_to`, `include_voided` (default `false`, filters `voided_at IS NULL`)
    - `void_transaction/2` — sets `voided_at` on original, creates reversal with negated postings, links via `correlation_id`
    - Replace `get_account_balance/2` placeholder with posting-backed implementation (joins accounts and transactions)
  - Private helpers:
    - `validate_zero_sum/2` — groups postings by `account.currency_code`, validates SUM = 0 per group
    - `validate_entity_isolation/2` — validates all posting accounts have `entity_id == transaction.entity_id`
    - `validate_minimum_postings/1` — validates at least 2 postings
    - `transaction_snapshot/1` — serializes for audit events
    - `filter_query/2` clauses for transaction filters
  - Factory: `transaction_factory` and `posting_factory` in `test/support/factory.ex`
  - Fixtures: `transaction_fixture/2` in `test/support/fixtures.ex`
  - Gettext entries for new validation error messages
  - Seed data: `priv/repo/seeds.exs` — 6 realistic transaction scenarios covering:
    1. Simple expense: a single purchase posted to an expense account and a checking account
    2. Transfer between two accounts: move funds from checking to savings (same entity, both asset accounts)
    3. Credit card purchase: debit an expense account, credit a credit card liability account
    4. Credit card payment: debit the credit card liability account, credit the checking account
    5. Split transaction: a single payment distributed across multiple expense accounts (3+ postings)
    6. Voided transaction: post a transaction, then call `Ledger.void_transaction/2` to produce a void-and-reversal pair with shared `correlation_id`
- **Output file**: `llms/tasks/012_ledger_primitives/01_domain_data_model_foundation.md`

### Task 02 — Transactions LiveView: Read-Only Ledger Explorer

- **Agent**: `dev-backend-elixir-engineer`
- **Goal**: Replace the hardcoded mock `TransactionsLive` with a real read-only ledger explorer.
- **Deliverables**:
  - Remove all mutation UI (Add Transaction, Import buttons; Edit/Delete/Void actions)
  - Replace `mock_transactions/0` with real `Ledger.list_transactions/1` queries (entity-scoped, postings preloaded with `[postings: :account]`)
  - DB-backed filters: entity selector, account dropdown, date from/to, source type, include-voided toggle
  - Expandable row: clicking a transaction row shows its postings (account name, account type, amount, currency derived from `posting.account.currency_code`)
  - Rewrite `TransactionsComponents`: `tx_row/1` for real schema fields; `tx_posting_detail/1` for expanded postings
  - Update gettext files: remove stale keys (`btn_add_manual`, `btn_import`, `col_category`, `col_tags`, etc.); add new keys
  - Empty state for entity with no transactions
  - Compatible with seed data (6 scenarios including void pair and multi-currency)
- **Important**: The canonical date field is `transaction.date` (`:date` type) — NOT `occurred_at`. No `category`, `tags`, or `memo` field exists on the Transaction schema.
- **Output file**: `llms/tasks/012_ledger_primitives/02_transactions_liveview_readonly.md`

### Task 03 — Test Coverage

- **Agent**: `qa-elixir-test-author`
- **Goal**: Comprehensive test coverage for transaction/posting schemas, context API, zero-sum invariant, balance derivation, void workflow, entity scoping, and the read-only Transactions LiveView.
- **Coverage targets**:
  - Transaction changeset validations (required fields, `source_type` enum, `description` max, immutability guards, no `status`/`memo`/`updated_at`, `voided_at` nil on create)
  - Posting changeset validations (required fields, `amount` non-nil, no `currency_code`/`entity_id`/`updated_at`)
  - `create_transaction/2` — happy path (2-posting, 3+posting, multi-currency), error cases (unbalanced, cross-entity, FK violations, <2 postings), audit event
  - `get_transaction!/2` — happy path, wrong entity_id raises
  - `list_transactions/1` — entity scoping, `voided_at` default exclusion, `include_voided`, filters, ordering
  - `void_transaction/2` — `voided_at` set on original, reversal created, `correlation_id` shared, double-void rejected, audit events, balance nets to zero
  - `get_account_balance/2` — posting-backed, `as_of_date`, single currency per account, empty map for no postings, nets to zero after void
  - Database trigger — direct SQL unbalanced insert rejected
  - Entity isolation — cross-entity invisible in all query paths
  - Read-only Transactions LiveView — connected mount, real data, filters, voided toggle, empty state, no mutation buttons in DOM
- **Output file**: `llms/tasks/012_ledger_primitives/03_test_coverage.md`

### Task 04 — Security/Architecture Review + Handoff

- **Agent**: `audit-security` + `rm-release-manager`
- **Goal**: Validate the ledger primitive implementation for correctness, security, and architectural alignment.
- **Checks**:
  - Zero-sum invariant enforced at both application and database levels (DB trigger joins accounts, `DEFERRABLE INITIALLY DEFERRED`)
  - Entity-scoped queries never return cross-entity data
  - Postings are fully immutable (no update/delete paths, no `updated_at` column, no `currency_code`, no `entity_id`)
  - Transactions are immutable facts: no `updated_at`, no `memo`, no `status` enum; `voided_at` is set-once only
  - No `Repo.delete` or `Repo.update` calls targeting postings
  - Void workflow correctly sets `voided_at` and creates reversal atomically
  - Audit events include actor/channel/occurred_at/before/after; snapshots do not include sensitive data
  - Balance derivation joins accounts correctly and performs no FX conversion
  - Read-only Transactions LiveView has no mutation paths (no CSRF targets for create/edit/delete)
  - Handoff notes explain how this issue unblocks transaction write UI, import integration, and reconciliation
- **Output file**: `llms/tasks/012_ledger_primitives/04_security_architecture_handoff.md`

### Task 05 — Documentation and ADR Sync

- **Agent**: `docs-feature-documentation-author` + `tl-architect`
- **Goal**: Update documentation to reflect the implemented transaction/posting model and LiveView.
- **Checks**:
  - Update `docs/domain-model.md` to include Transaction and Posting entities with canonical fields
  - Document: no `memo`, no `status` enum, no `updated_at` on transactions; `voided_at` pattern; no `currency_code`/`entity_id`/`updated_at` on postings
  - Confirm `docs/adr/0008-ledger-schema-design.md` is updated with implementation notes
  - Note the structural decisions: no posting currency field, `voided_at` instead of `status`, no memo
  - Update `llms/project_context.md` if new project conventions are established
  - Update milestone status in project plan
- **Output file**: `llms/tasks/012_ledger_primitives/05_documentation_sync.md`

---

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Domain + Data Model Foundation (schemas, migration, context API, seeds) | PENDING | [ ] | Issues #10, #11 complete |
| 02 | Transactions LiveView: Read-Only Ledger Explorer | PENDING | [ ] | Task 01 |
| 03 | Test Coverage (schemas, context, invariants, void, LiveView) | PENDING | [ ] | Tasks 01, 02 |
| 04 | Security/Architecture Review + Handoff | PENDING | [ ] | Task 03 |
| 05 | Documentation and ADR Sync | PENDING | [ ] | Task 04 |

Tasks 02 and 03 can run in parallel after Task 01. Task 03 depends on Task 02 for LiveView test coverage.

---

## Schema and Design Assumptions

1. `transactions.id` and `postings.id` are UUID, consistent with project conventions.
2. `entity_id` on transactions is NOT NULL with FK constraint to `entities`. Entity scope on postings is derived through the parent transaction.
3. `postings` table has no `currency_code` column. Posting currency is always `account.currency_code`, derived by joining the `accounts` table via `posting.account_id`. This is a structural invariant, not a runtime validation.
4. `postings.amount` uses PostgreSQL `numeric` (arbitrary precision, no fixed scale). The application layer handles formatting.
5. `postings.transaction_id` has `on_delete: :restrict` — transactions cannot be deleted while they have postings (which is always, since we never delete transactions).
6. The database-level zero-sum trigger fires after insert on `postings`. It joins `accounts` via `posting.account_id` to determine effective currency for each posting, groups by `account.currency_code` for the inserted row's `transaction_id`, and raises if any group sum is not zero. The trigger is a `DEFERRABLE INITIALLY DEFERRED` constraint trigger — it fires at commit time, not per-row, to allow batch posting inserts within a single `Repo.transaction/1` call.
7. `Ledger.create_transaction/2` validation order: (a) structural checks on all posting attrs (required fields), (b) load each posting's account in a single query (`WHERE id IN (^account_ids)`), (c) validate `account.entity_id == transaction.entity_id` for every account, (d) group by `account.currency_code` and validate zero-sum per group. All validations happen before any insert. The database trigger is a safety net for the zero-sum invariant only; entity isolation is enforced exclusively at the application layer.
8. `get_account_balance/2` joins `postings` → `accounts` (for `currency_code`) and `postings` → `transactions` (for `transaction.date` in `as_of_date` filtering). This is a read-only query with no side effects.
9. Both `transactions` and `postings` use `timestamps(type: :utc_datetime_usec, updated_at: false)`. Neither table has an `updated_at` column. Transactions are immutable facts; the only allowed mutation is setting `voided_at` once via the void workflow.
10. `voided_at` is a nullable `utc_datetime_usec` field on `transactions`. It is `NULL` on creation. The void workflow sets it once to the current UTC datetime. It is never changed after that. There is no `status` enum; `voided_at IS NULL` means active; `voided_at IS NOT NULL` means voided.
11. The `correlation_id` for void workflows is a new UUID generated at void time, set on both the original (via `void_changeset`) and the reversal (created fresh).
12. Audit snapshots for transactions include posting summaries as `[%{account_id: uuid, amount: decimal}]`. Currency is not stored in the snapshot directly — it is derivable from the account if needed for audit review.
13. The `transactions` table has no `memo` field. No free-text annotation belongs in the ledger write model. User notes and classification labels are a future overlay concern.

---

## Open Questions

- None at this stage. Core modeling decisions are resolved by ADR-0002, ADR-0008, ADR-0004, and the Issue #11 implementation.

---

## Validation Plan

- `mix test` — all unit, context, and integration tests pass.
- `mix precommit` — format, Credo, Dialyzer, Sobelow pass with zero warnings/errors.
- Zero-sum invariant validated at both application and database levels.
- Confirm `postings` table has no `currency_code`, `entity_id`, or `updated_at` columns after migration.
- Confirm `transactions` table has no `memo`, `status`, or `updated_at` columns after migration.
- Confirm `transactions` table has `voided_at` (nullable) and no `updated_at`.
- Entity isolation test: transactions from entity A invisible to entity B.
- Balance derivation test: `get_account_balance/2` joins accounts correctly, returns account-native currency.
- Void workflow test: `voided_at` is set on original; balance nets to zero after void-and-reversal.
- Database trigger test: direct SQL insert of unbalanced postings is rejected.
- Read-only Transactions UI: page mounts, renders real transaction data, has no mutation UI.

---

## Risks and Follow-ups

- **DB trigger complexity.** The zero-sum trigger must join accounts and must handle the case where postings are inserted as a batch (all within one `Repo.transaction/1` call). A `DEFERRABLE INITIALLY DEFERRED` constraint trigger may be needed to avoid firing per-row before all postings are present. The backend engineer must verify the trigger fires at commit time, not at each row insert.
- **Account preloading in `create_transaction/2`.** Validating the zero-sum invariant requires loading each posting's account to determine effective currency. This is an N+1 risk for transactions with many postings. The implementation should load all referenced accounts in a single query (`Repo.all(from a in Account, where: a.id in ^account_ids)`) rather than per-posting.
- **Balance derivation performance.** Computed-on-read balance works for personal finance volumes. BalanceSnapshot is explicitly deferred. Monitor query performance as posting volume grows.
- **No `posting.currency_code` means audit snapshots do not self-contain currency.** Audit consumers that need to display currency alongside posted amounts must join accounts at read time. This is intentional — the ledger stores facts, not derived fields.

---

## Change Log

| Date | Item | Change | Reason |
|---|---|---|---|
| 2026-03-07 | Plan | Initial plan created via po-analyst agent | Start planning workflow for Issue #12 |
| 2026-03-07 | Plan | Currency rule applied: `posting.currency_code` as redundant-but-validated field; FX excluded from ledger | Canonical AurumFinance ledger rule |
| 2026-03-07 | Plan | Added cross-entity isolation invariant: all accounts in a transaction's postings must belong to `transaction.entity_id`; enforced in `create_transaction/2` validation step (b); error cases and test targets updated | Design clarification — entity isolation closes at write model |
| 2026-03-07 | Plan | Full structural revision: removed `posting.currency_code` entirely; posting currency is now structural (derived from `account.currency_code` via join); zero-sum invariant and balance derivation reformulated with account join; posting schema updated; US-10 rewritten; all task deliverables updated; DB trigger description updated; Risks/Follow-ups added; consistency pass against Issues #10 and #11 | Canonical model — posting currency must not be independently stored |
| 2026-03-07 | Plan | Final architectural alignment: (1) removed `updated_at` and `memo` from transactions — both are immutable ledger facts; (2) replaced `status` enum with `voided_at` nullable timestamp (set-once void marker, analogous to `archived_at` on Account); (3) explicit import/ingestion boundary — staging → approval → `create_transaction/2`; (4) added read-only Transactions LiveView with seed data (6 scenarios) to scope; (5) updated all task deliverables, acceptance criteria, edge cases, and schema assumptions throughout | Architectural decisions: immutable facts, no memo in ledger, voided_at pattern, read-only UI |
| 2026-03-07 | Plan | Added Task 05: dedicated Transactions LiveView read-only ledger explorer task (separate from backend Task 01); updated task sequence to allow Task 01 → Tasks 02+05 in parallel → Task 03 → Task 04; added canonical field name clarification (`date` not `occurred_at`); documented removal of mock data, mutation buttons, and schema-absent fields (category, tags, memo) | Split LiveView into own task for clarity; correct `occurred_at` → `date` field name |
