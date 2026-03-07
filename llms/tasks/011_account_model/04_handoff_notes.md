# Task 04 Handoff Notes

## What Issue #11 Delivered

Issue #11 established the account foundation for the ledger-first model:

- `AurumFinance.Ledger.Account` schema with:
  - `entity_id`
  - `account_type`
  - `operational_subtype`
  - `management_group`
  - `currency_code`
  - institution metadata
  - `archived_at`
- `AurumFinance.Ledger` context with:
  - scoped listing APIs
  - create/update/archive/unarchive
  - changeset/form helper
  - placeholder `get_account_balance/2`
- `AurumFinanceWeb.AccountsLive` with:
  - institution/category/system-managed management surfaces
  - entity selection
  - create/edit/archive/unarchive flows
  - right-sidebar form shell
- tests covering:
  - schema validation
  - lifecycle
  - audit events
  - management-group filtering
  - LiveView CRUD flows

## How The Ledger Context Is Structured For Expansion

The current `AurumFinance.Ledger` context is intentionally narrow:

- account schema and query filters are already entity-scoped
- audit integration is centralized through `AurumFinance.Audit.with_event/3`
- public list APIs already accept keyword opts for future composability
- `management_group` is explicit, so downstream UI/query code does not need heuristics

This means future ledger work can expand the same context rather than creating parallel account abstractions.

## Downstream Issues Now Unblocked

### Transactions

A future transaction issue can now rely on:

- canonical `account_id` targets
- entity ownership boundary via `account.entity_id`
- immutable `account_type` semantics for posting validation
- archive-aware account selection in UI

Expected rule:
- a transaction/posting write path must reject accounts from different entities unless the feature is explicitly modeled as a cross-entity operation.

### Postings

A future posting issue can now rely on:

- `Account.normal_balance/1` for debit/credit interpretation
- `currency_code` on the account for native-currency behavior
- `management_group` only as a management concern, not posting semantics

Expected rule:
- postings must derive financial meaning from `account_type`, never from `management_group`.

### Balance Derivation

`Ledger.get_account_balance/2` is currently a placeholder returning `%{}`.

When postings exist, replace it with:

- an entity-safe query over postings for one account
- grouped aggregation by currency code
- optional `:as_of_date` cutoff
- no denormalized `balance` column on `accounts`

Expected return shape remains:

```elixir
%{
  "USD" => Decimal.new("123.45"),
  "CLP" => Decimal.new("98000")
}
```

## Entity Scoping Expectations For Downstream Models

Downstream models must preserve the ownership contract from Issue #10 and ADR-0009:

- every ledger-owned row must carry `entity_id` directly or inherit it through a constrained parent
- public list/query APIs must require explicit entity scope
- write paths must not allow implicit cross-entity mutations
- cross-entity reads must be explicit and read-only

Recommended discipline for future work:

1. bake `entity_id` filtering into lower-level query builders early
2. prefer scoped getters such as `get_account!(entity_id, account_id)` when a UI or API already has entity context
3. add adversarial tests that submit an ID from another entity and expect rejection

## Current Security Review Follow-Up

The scoping review finding was fixed during follow-up:

- `Ledger.get_account!/2` is now entity-scoped
- `AccountsLive` resolves edit/archive/unarchive targets through the selected entity scope
- a negative LiveView test now covers forged cross-entity IDs

Recommended follow-up before transaction/posting work grows:

1. keep public retrieval APIs scoped by entity unless there is a strong internal-only justification
2. preserve negative tests for forged cross-entity IDs when adding new ledger UI/event handlers
3. apply the same pattern to future transaction/posting retrieval paths
