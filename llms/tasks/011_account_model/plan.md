# Execution Plan: Issue #11 - Account Model (bank/broker/credit/cash + currency)

## Metadata

- **Issue**: `https://github.com/mberrueta/aurum-finance/issues/11`
- **Created**: 2026-03-06
- **Updated**: 2026-03-06
- **Status**: PLANNED
- **Depends on**: Issue #10 (Entity Model) — COMPLETED

---

## Overview

Issue #11 delivers the Account model — the primary container for all financial
activity in AurumFinance. Accounts are entity-scoped (one entity owns its
complete chart of accounts), carry a primary currency, and belong to a two-
dimension classification system (accounting type + operational subtype) per
ADR-0015. Balances are derived from postings on read — no denormalized balance
field is stored.

Internally, `Account` remains the canonical ledger account abstraction. That
includes institution-backed operational accounts, category accounts
(`income`/`expense`), and system-managed accounts required by ledger mechanics.
The product/UI layer may present these subsets in separate views so the web
experience matches personal-finance mental models without changing ledger
semantics.

This plan is aligned with:

- **ADR-0008**: Ledger schema design (accounts, transactions, postings, balances)
- **ADR-0009**: Multi-entity ownership model (`entity_id` scoping discipline)
- **ADR-0015**: Account model and financial instrument types (dual classification)
- **ADR-0002**: Double-entry internal model (account type normal balance convention)
- **Issue #10 ownership contract**: `llms/tasks/010_entity_model/04_ownership_boundary_contract_output.md`

---

## Scope Restatement (Issue-Driven)

- Introduce the `Account` schema in the `AurumFinance.Ledger` context, entity-scoped.
- Implement the two-dimension classification model: `account_type` + `operational_subtype`.
- Support institution metadata (institution name, masked account reference) as optional attributes.
- Deliver `AurumFinance.Ledger` context CRUD APIs for accounts.
- Deliver Accounts management LiveView with separate management surfaces for
  institution-backed accounts, category accounts, and system-managed accounts.
- Enforce the archive posture via `archived_at` (consistent with entity model, see §Terminology Alignment).
- Balance computation is declared as derived-from-postings (no denormalized balance field).
  The actual posting model does not exist yet in M1; this issue establishes the architectural
  commitment and a placeholder query that returns an empty map — to be filled when
  transactions/postings are introduced.
- Audit events for account create/update/archive via the generic `AurumFinance.Audit` infrastructure
  from Issue #10.

**Explicitly out of scope for this issue:**

- Parent/child account tree (`parent_account_id`) — deferred to a follow-up issue.
- `is_placeholder` flag — deferred alongside account tree.
- Trading accounts (system-managed Equity accounts for FX balancing) — follows transaction model.
- Instrument profile for brokerage/crypto accounts — deferred to Issue #27 (Holdings).
- Balance snapshot caching (`BalanceSnapshot` schema) — deferred to performance optimization phase.
- Actual posting/balance computation (no `postings` table yet) — commitment is architectural.

---

## Acceptance Criteria Mapping

| Issue Criterion | Plan Delivery |
|---|---|
| Account schema: id, entity_id, name, type, currency, institution, account_number_last4, active, notes | `AurumFinance.Ledger.Account` schema with canonical fields — see §Canonical Domain Decisions for field alignment against ADR-0008/0015 |
| Account types map to correct normal balance (debit/credit) | `account_type` field (asset/liability/equity/income/expense); normal balance derived helper in schema |
| Currency is ISO 4217 code | `currency_code` field, string, validated format; stored as uppercase ISO 4217 (e.g. `"USD"`, `"BRL"`) |
| Accounts CRUD LiveView (list, new, edit, archive) | `AurumFinanceWeb.AccountsLive` with entity-scoped management flows presented in separate sections/tabs for institution-backed, category, and system-managed accounts |
| Account balance computed from postings (no denormalized balance field) | No `balance` column; `Ledger.get_account_balance/2` derived from postings; returns empty map until postings exist |
| Multi-currency accounts supported | `currency_code` per account; balance derivation is multi-currency-aware (map of currency → amount) |

---

## Canonical Domain Decisions

### Account classification: two orthogonal dimensions (ADR-0015)

Issue #11 uses a flat `type` enum (checking/savings/credit/investment/cash/crypto).
ADR-0015 defines two separate dimensions. **Both dimensions must be implemented.**

**Dimension 1 — Accounting type** (required, drives double-entry semantics):

| Value | Normal balance | Double-entry role |
|---|---|---|
| `asset` | Debit | Increases with debit (+), decreases with credit (−) |
| `liability` | Credit | Increases with credit (−), decreases with debit (+) |
| `equity` | Credit | Increases with credit (−), decreases with debit (+) |
| `income` | Credit | Increases with credit (−) |
| `expense` | Debit | Increases with debit (+) |

**Dimension 2 — Operational subtype** (required for asset/liability accounts; nil for income/expense/equity):

| Value | Maps to issue `type` | Accounting type |
|---|---|---|
| `bank_checking` | checking | asset |
| `bank_savings` | savings | asset |
| `cash` | cash | asset |
| `brokerage_cash` | investment | asset |
| `brokerage_securities` | investment | asset |
| `crypto_wallet` | crypto | asset |
| `credit_card` | credit | liability |
| `loan` | — | liability |
| `other_asset` | — | asset |
| `other_liability` | — | liability |

UX implications:
- Users pick `operational_subtype` as the primary concept (the "type" they recognize).
- `account_type` is automatically derived from the subtype (see derivation map above)
  and stored explicitly. It is not user-selectable from the form.
- Income, Expense, and Equity root accounts are created with `account_type` directly
  (no operational subtype) — these are structural/system accounts.
- The web layer does not need to present the entire chart of accounts in one mixed
  CRUD surface. Institution-backed accounts, category accounts, and system-managed
  accounts may be managed in distinct tabs/sections while still using the same
  canonical `Account` model underneath.

### Account fields (canonical, aligned with ADR-0008/0015)

| Field | Type | Required | Mutability | Notes |
|---|---|---|---|---|
| `id` | UUID | Yes | Immutable | |
| `entity_id` | UUID (FK → entities) | Yes | Immutable | NOT NULL, indexed |
| `name` | string | Yes | Mutable | 2–160 chars |
| `account_type` | enum | Yes | Immutable | asset/liability/equity/income/expense |
| `operational_subtype` | enum | Conditional | Immutable | Required for asset/liability; nil for income/expense/equity |
| `currency_code` | string | Yes | Immutable | ISO 4217, stored uppercase |
| `institution_name` | string | No | Mutable | Optional; aids import cross-checking |
| `institution_account_ref` | string | No | Mutable | Free string (last 4, IBAN, code); replaces `account_number_last4` in issue text |
| `notes` | string | No | Mutable | |
| `archived_at` | utc_datetime_usec | No | Mutable | NULL = active; soft-archive posture |
| `inserted_at` | utc_datetime_usec | — | Immutable | |
| `updated_at` | utc_datetime_usec | — | Auto | |

**Field name notes:**
- `institution_account_ref` is preferred over `account_number_last4`. The issue uses `account_number_last4`
  but ADR-0008 specifies `institution_account_number` as a free string — it is not always
  last-4 digits (may be IBAN, code, full account number). The field stores whatever reference
  the user provides for identification. Implementation should use `institution_account_ref`.
- `account_type` and `operational_subtype` are `Ecto.Enum` fields.
- `currency_code` is immutable once set (changing currency would invalidate all existing postings).
- `account_type` is immutable once set (changing type would violate double-entry invariants).

### Archive model

- Primary mechanism: `archived_at` timestamp (consistent with Entity model from Issue #10).
- **Deviation from ADR-0008**: ADR-0008 specifies `is_active` (boolean) for accounts.
  We adopt `archived_at` instead for lifecycle consistency with the entity model:
  - `archived_at: nil` → active
  - `archived_at: <timestamp>` → archived
  - This preserves a temporal trace of when archiving occurred.
  - ADR-0008 should be updated to reflect this decision (see Task 06 documentation sync).
- Unarchive (`archived_at` → nil) must be supported (consistent with entity unarchive pattern).
- Archived accounts are hidden from default list views; explicit toggle to include them.

### Balance derivation

- No `balance` column on accounts. Balance is always derived from postings.
- `Ledger.get_account_balance(account_id, opts \\ [])` returns `%{currency_code => Decimal.t()}`.
- Until `postings` table exists, this function returns `%{}` (empty map).
- `as_of_date` option supported in the function signature from day one (even if trivially
  implemented now), to align with ADR-0008's balance derivation design.

### Audit events

- Account create/update/archive/unarchive emit `AuditEvent` records via `AurumFinance.Audit.with_event/3`.
- `entity_type` = `"account"`.
- `actor` and `channel` accepted as opts, same pattern as entities context.
- `institution_account_ref` should be treated as potentially sensitive — include in audit snapshots
  but do NOT log to application logger.

### Context location

- Schema: `AurumFinance.Ledger.Account` (`lib/aurum_finance/ledger/account.ex`)
- Context: `AurumFinance.Ledger` (`lib/aurum_finance/ledger.ex`)
- This introduces the `AurumFinance.Ledger` context. It will expand in future issues to include
  transactions, postings, and balance snapshots. Start with accounts only.

### UI presentation model

- `Account` remains the single canonical ledger entity.
- The initial Accounts area should not be implemented as one flat mixed CRUD over
  the full chart of accounts.
- Instead, the intended UI direction is separate views/tabs for:
  - institution-backed accounts (bank, broker, wallet, credit card, loan, cash)
  - category accounts (income and expense ledger accounts), which may be created
    manually in the Accounts area or generated automatically by later
    categorization workflows
  - system-managed accounts (opening balance, trading/FX, and similar technical accounts)
- This separation is a presentation concern only. It does not introduce a new
  domain entity and does not weaken ledger-first or double-entry semantics.

---

## Project Context and ADR Alignment

### Related entities

- `AurumFinance.Entities.Entity` (`lib/aurum_finance/entities/entity.ex`)
  - Account's ownership boundary via `entity_id`.
  - `entity_id` must be NOT NULL with FK constraint.
- `AurumFinance.Audit.AuditEvent` (`lib/aurum_finance/audit/audit_event.ex`)
  - Reused for account lifecycle events.
  - Same `entity_type`/`entity_id`/`action`/`actor`/`channel`/`before`/`after`/`occurred_at` shape.

### Existing patterns to follow

From `AurumFinance.Entities` context:
- `@required` and `@optional` field lists in schema.
- `filter_query/2` private multi-clause function for composable filtering.
- `list_accounts/1` accepts `opts` keyword list.
- `Audit.with_event/3` for transactional audit emission.
- `change_account/2` for form changeset helper.
- `archive_account/1` and `unarchive_account/1` (matching `archive_entity/1`/`unarchive_entity/1`).

From `AurumFinanceWeb` LiveViews (entities CRUD):
- `<.form for={@form}>` and `<.input>` patterns.
- HEEx `{}` interpolation with `:if`/`:for` attributes (no `<%= %>`).
- Stable DOM IDs for testability.
- Archive toggle (show archived via `include_archived` filter opt).

### Permissions model

- Single-operator application; no per-entity access control.
- Accounts CRUD is behind the standard authenticated plug (`:require_authenticated`).
- Entity scope is enforced at context API level, not at auth level.

### Naming conventions

| What | Convention | Source |
|---|---|---|
| Context module | `AurumFinance.Ledger` | ADR-0007 |
| Schema module | `AurumFinance.Ledger.Account` | ADR-0007 |
| Context functions | `list_accounts/1`, `get_account!/1`, `create_account/2`, `update_account/3`, `archive_account/2`, `unarchive_account/2`, `change_account/2` | Mirrors entities API |
| LiveView module | `AurumFinanceWeb.AccountsLive` | Mirrors `EntitiesLive` |
| Route path | `/accounts` | To be placed in authenticated pipeline |

---

## Terminology Alignment

| Issue / ADR-0008 Term | Canonical Term (this plan) | Reason |
|---|---|---|
| `type: checking/savings/credit/...` (flat enum) | `account_type` + `operational_subtype` (two fields) | ADR-0015 defines orthogonal dimensions; flat enum conflates accounting semantics with operational behavior |
| `active` (boolean) | `archived_at` (timestamp, nil = active) | Consistency with entity model from Issue #10; preserves temporal audit trace |
| `is_active` (ADR-0008) | `archived_at` | Same reason — deliberate deviation from ADR-0008 in favor of project lifecycle consistency |
| `institution` | `institution_name` | ADR-0008 canonical field name |
| `account_number_last4` | `institution_account_ref` | ADR-0008 uses free string (not always last 4); rename avoids false specificity |
| `currency` | `currency_code` | ADR-0008 canonical field name; aligned with posting/transaction currency fields |
| `investment` (type) | `brokerage_cash` or `brokerage_securities` (subtype) | ADR-0015 splits investment concept into cash and securities subtypes |

---

## Implementation Tasks

### Task 01 — Domain + Data Model Foundation

- **Agent**: `dev-backend-elixir-engineer`
- **Goal**: Introduce `AurumFinance.Ledger` context and `Account` schema/migration.
- **Deliverables**:
  - Migration for `accounts` table with canonical fields:
    - `id` (UUID PK)
    - `entity_id` (UUID FK → entities, NOT NULL, indexed)
    - `name` (string, NOT NULL)
    - `account_type` (string enum: asset/liability/equity/income/expense, NOT NULL, immutable)
    - `operational_subtype` (string enum, nullable — nil for income/expense/equity)
    - `currency_code` (string, NOT NULL, immutable)
    - `institution_name` (string, nullable)
    - `institution_account_ref` (string, nullable)
    - `notes` (text, nullable)
    - `archived_at` (utc_datetime_usec, nullable)
    - `inserted_at` / `updated_at` (utc_datetime_usec)
  - Migration indexes:
    - `index(:accounts, [:entity_id])` — base FK index
    - `index(:accounts, [:entity_id, :archived_at])` — composite index for the dominant
      query pattern (`WHERE entity_id = ? AND archived_at IS NULL`); covers list, dashboards,
      and reporting without a full accounts scan per entity
  - `AurumFinance.Ledger.Account` schema with:
    - `Ecto.Enum` for `account_type` and `operational_subtype`
    - `@required` / `@optional` lists
    - `changeset/2` with i18n validation messages (`dgettext("errors", ...)`)
    - `currency_code` validated with both `validate_length(:currency_code, is: 3)` and
      `validate_format(:currency_code, ~r/^[A-Z]{3}$/)` — ISO 4217 is the PK natural key
      used by the FX system; strict 3-uppercase-letter enforcement prevents silent mismatches
    - `normal_balance/1` helper returning `:debit` or `:credit` for a given account_type
    - `operational_subtypes_for_type/1` helper returning valid subtypes for an account_type
  - `AurumFinance.Ledger` context with:
    - `list_accounts/1` (entity-scoped, opts: `entity_id`, `include_archived`, `account_type`, `operational_subtype`)
    - `get_account!/1`
    - `create_account/2` (attrs, opts) — with audit event
    - `update_account/3` (account, attrs, opts) — with audit event
    - `archive_account/2` (account, opts) — sets `archived_at`
    - `unarchive_account/2` (account, opts) — clears `archived_at`
    - `change_account/2` — form helper
    - `get_account_balance/2` — returns `%{}` (placeholder until postings exist)
  - Entity scoping: all list/query functions require `entity_id` in opts.
  - No hard-delete path.
- **Output file**: `llms/tasks/011_account_model/01_domain_data_model_foundation.md`

### Task 02 — Accounts CRUD LiveView

- **Agent**: `dev-frontend-ui-engineer`
- **Goal**: Ship account management UI in the authenticated app shell with
  distinct management surfaces for the main account subsets.
- **Deliverables**:
  - `AurumFinanceWeb.AccountsLive` route and navigation entry.
  - Accounts area structure:
    - Separate tabs/sections for `Institution`, `Category`, and `System-managed`.
    - All tabs remain backed by the same `Account` domain model and
      entity-scoped context APIs.
  - Institution view behavior:
    - Scoped to current entity (entity selection context required in socket assigns).
    - Show active accounts by default.
    - Explicit toggle to include archived accounts.
    - Focus on institution-backed operational accounts.
  - Create/edit form:
    - `operational_subtype` as primary user-facing type selector.
    - `account_type` auto-derived from selected subtype (not user-editable).
    - `currency_code` selector (ISO 4217).
    - `institution_name` and `institution_account_ref` as optional fields.
    - Immutable field guard: `account_type` and `currency_code` are read-only after creation.
  - Category view behavior:
    - Manage income/expense accounts separately from institution-backed accounts.
    - Expose category accounts as ledger accounts, not as mere labels/metadata.
    - Support manually created category accounts in this issue while remaining
      compatible with later automatic category-account creation by categorization
      workflows.
  - System-managed view behavior:
    - Keep technical/system accounts separated and de-emphasized from normal workflows.
    - Include archive visibility rules appropriate for advanced/technical accounts.
  - Archive action wired to `archive_account/2` (no delete UI).
  - Unarchive action available on archived accounts.
  - Stable DOM IDs for testability.
- **Output file**: `llms/tasks/011_account_model/02_accounts_crud_liveview.md`

### Task 03 — Test Coverage

- **Agent**: `qa-elixir-test-author`
- **Goal**: Cover account model, archive behavior, entity scoping, and audit events.
- **Coverage targets**:
  - Account changeset validations:
    - required fields (name, account_type, currency_code, entity_id)
    - valid `account_type` enum values
    - valid `operational_subtype` values per account_type
    - `currency_code`: `validate_length(is: 3)` + `validate_format(~r/^[A-Z]{3}$/)`
    - name length constraints
  - `archive_account/2` sets `archived_at` and does not delete.
  - `unarchive_account/2` clears `archived_at`.
  - No hard-delete function/path exists in context.
  - Entity scoping: create accounts in Entity A, query from Entity B perspective → no leakage.
  - Audit events emitted with expected shape for create/update/archive/unarchive.
  - `get_account_balance/2` returns empty map (no postings yet).
  - `normal_balance/1` returns `:debit` for asset/expense, `:credit` for liability/equity/income.
  - LiveView tests for list/new/edit/archive interactions via stable DOM IDs.
- **Output file**: `llms/tasks/011_account_model/03_test_coverage.md`

### Task 04 — Security/Architecture Review + Handoff

- **Agent**: `audit-security` + `rm-release-manager`
- **Goal**: Validate entity-scoping discipline and prepare operator-facing documentation.
- **Checks**:
  - Entity-scoped queries never return cross-entity data.
  - `institution_account_ref` does not appear in application logs or flash messages.
  - Soft archive only — no hard-delete paths.
  - Audit events include actor/channel/occurred_at/before/after.
  - Handoff notes explain how this issue unblocks transaction/posting work in future M1 issues.
- **Output file**: `llms/tasks/011_account_model/04_security_architecture_handoff.md`

### Task 05 — Documentation and ADR Sync

- **Agent**: `docs-feature-documentation-author` + `tl-architect`
- **Goal**: Update documentation to reflect the implemented account model.
- **Checks**:
  - Update `docs/domain-model.md` to include Account entity with canonical fields.
  - Update `docs/adr/0008-ledger-schema-design.md` to document the `archived_at` deviation
    from `is_active` (deliberate, with rationale).
  - Confirm `docs/adr/0015-account-model-and-instrument-types.md` is consistent with implementation.
  - Update `llms/project_context.md` if any project conventions are established by this issue.
  - Confirm `llms/tasks/000_project_plan.md` milestone status for M1 account work.
- **Output file**: `llms/tasks/011_account_model/05_documentation_sync.md`

---

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Domain + Data Model Foundation | PENDING | [ ] | Issue #10 complete |
| 02 | Accounts CRUD LiveView | PENDING | [ ] | Task 01 |
| 03 | Test Coverage | PENDING | [ ] | Tasks 01, 02 |
| 04 | Security/Architecture Review + Handoff | PENDING | [ ] | Task 03 |
| 05 | Documentation and ADR Sync | PENDING | [ ] | Task 04 |

---

## Schema and Design Assumptions

1. `accounts.id` is UUID, consistent with project conventions.
2. `entity_id` is NOT NULL with a FK constraint to `entities` and is part of all
   composite indexes on the accounts table.
3. `account_type` and `currency_code` are immutable after creation — changing either would
   invalidate existing postings. Changesets enforce this via `validate_change` guards.
4. `operational_subtype` is immutable after creation for the same reason (it influences
   posting interpretation and reporting category derivation).
5. `institution_account_ref` is a free string (not validated as last-4 digits or any specific format).
6. Balance computation returns a multi-currency map `%{String.t() => Decimal.t()}`, never a
   single scalar — aligned with ADR-0008's per-currency balance model.
7. The `AurumFinance.Ledger` context is introduced by this issue and will expand iteratively.
   No pre-emptive scaffolding for future ledger entities (transactions, postings) in this issue.

---

## Open Questions

- None at this stage. All key modeling decisions are resolved by ADR-0008, ADR-0015,
  ADR-0009, and the Issue #10 ownership boundary contract.

---

## Validation Plan

- `mix test` — all unit, context, and LiveView tests pass.
- `mix precommit` — format, Credo, Dialyzer, Sobelow, docs pass with zero warnings/errors.
- Multi-entity isolation test: verified no cross-entity leakage in `list_accounts/1`.
- Audit events verified: shape matches generic `AuditEvent` model from Issue #10.

---

## Change Log

| Date | Item | Change | Reason |
|---|---|---|---|
| 2026-03-06 | Plan | Initial plan created via po-analyst agent | Start planning workflow for Issue #11 |
| 2026-03-06 | Plan | Added composite index `[:entity_id, :archived_at]`; tightened `currency_code` validation to `validate_length(is: 3)` + `validate_format(~r/^[A-Z]{3}$/)` | Human review feedback |
