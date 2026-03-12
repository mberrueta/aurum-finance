# Execution Plan: Reconciliation Status Workflow

## Metadata
- **Spec**: `llms/tasks/018_reconciliation_status/plan.md` (original spec preserved below)
- **Created**: 2026-03-11
- **Status**: PLANNING
- **Current Task**: N/A

## Overview

Implements the reconciliation status workflow as an overlay on the immutable postings table. Creates a new `AurumFinance.Reconciliation` context with three tables (`reconciliation_sessions`, `posting_reconciliation_states`, `reconciliation_audit_logs`), a full session lifecycle (create, clear postings, finalize), and replaces the existing mock ReconciliationLive with a real data-driven workflow. Also integrates a void guard into `Ledger.void_transaction/2` to protect reconciled postings.

## Technical Summary

### Codebase Impact
- **New files**: ~12 (context, 3 schemas, migration, updated LiveView, updated components, factories, tests)
- **Modified files**: ~4 (Ledger context void guard, factory.ex, router for new routes, ReconciliationLive + components)
- **Database migrations**: Yes (1 migration with 3 tables, indexes, constraints, 1 append-only trigger)
- **External dependencies**: None

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LEFT JOIN performance on large posting sets | Low | Medium | Add proper indexes on overlay table; pagination in LiveView |
| Void guard regression (Ledger context modification) | Medium | High | Thorough test coverage for void with cleared/reconciled/no-overlay postings |
| Append-only trigger on audit logs blocking test cleanup | Low | Low | Use `Ecto.Adapters.SQL.Sandbox` -- triggers run within sandbox transactions that roll back |
| Partial uniqueness constraint on active sessions | Low | Medium | Test the partial index explicitly; handle constraint error in context |

## Roles

### Human Reviewer
- Approves each task before next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject/request changes on any task

### Executing Agents

| Task | Agent | Description |
|------|-------|-------------|
| 01 | `backend-engineer-agent` | Database migration: 3 tables, indexes, constraints, triggers |
| 02 | `backend-engineer-agent` | Ecto schemas for all 3 reconciliation tables |
| 03 | `backend-engineer-agent` | Reconciliation context with full API |
| 04 | `backend-engineer-agent` | Void guard integration in Ledger context |
| 05 | `backend-engineer-agent` | Test factories for reconciliation schemas |
| 06 | `backend-engineer-agent` | Context-level tests for Reconciliation + void guard |
| 07 | `liveview-frontend-agent` | LiveView and components rewrite for real data |
| 08 | `liveview-frontend-agent` | LiveView integration tests |
| 09 | `backend-engineer-agent` | Final audit: precommit, coverage, cleanup |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Migration: tables, indexes, triggers | PENDING | [ ] | None |
| 02 | Ecto schemas (3 new schemas) | PENDING | [ ] | Task 01 |
| 03 | Reconciliation context API | PENDING | [ ] | Task 02 |
| 04 | Ledger void guard integration | PENDING | [ ] | Task 03 |
| 05 | Test factories | PENDING | [ ] | Task 02 |
| 06 | Context tests | PENDING | [ ] | Task 03, 04, 05 |
| 07 | LiveView + components rewrite | PENDING | [ ] | Task 03 |
| 08 | LiveView integration tests | PENDING | [ ] | Task 07, 05 |
| 09 | Final audit (precommit, coverage) | PENDING | [ ] | Task 06, 08 |

**Status Legend:**
- PENDING - Ready to start (dependencies met)
- IN_PROGRESS - Currently being executed
- COMPLETED - Done and approved
- BLOCKED - Waiting on dependency
- REJECTED - Needs rework
- ON_HOLD - Paused by human

## Assumptions

1. The migration timestamp will use the next available slot after `20260310214609` (the latest existing migration).
2. The `reconciliation_session_id` FK on `posting_reconciliation_states` is nullable as specified (cleared postings outside a session are theoretically possible but not used in v1).
3. The existing `ReconciliationLive` and `ReconciliationComponents` will be fully rewritten (not incrementally patched), since they contain only mock data.
4. The `ReconciliationAuditLog` is a domain-specific audit trail separate from the generic `AuditEvent` system. The generic `Audit.insert_and_log` helpers are used for session create/complete events, while the domain-specific `reconciliation_audit_logs` table captures per-posting state transitions.
5. Entity scope enforcement follows the existing pattern: `require_entity_scope!/2` private helper in the context.
6. The partial unique index for "one active session per account" uses `WHERE completed_at IS NULL` on `(account_id)`.
7. Router adds `live "/reconciliation/:session_id", ReconciliationLive, :show` for session detail deep-linking. Both `:index` (session list) and `:show` (session detail) are handled in `ReconciliationLive` via `handle_params/3`.
8. The `format_money` helper already exists in `UiComponents` and will be reused.

## Open Questions

1. ~~Should the router add `live "/reconciliation/:session_id", ReconciliationLive, :show`?~~ **RESOLVED 2026-03-11**: Yes — `:show` action with `session_id` param. Affects Task 07.
2. ~~Should the `reconciliation_audit_logs` append-only trigger be added in this migration?~~ **RESOLVED 2026-03-11**: Yes — append-only trigger confirmed on `reconciliation_audit_logs` only (not on `reconciliation_sessions` or `posting_reconciliation_states`). Affects Task 01.

## Change Log

| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-11 | Plan | Initial creation | - |

---
---

# Original Spec (Preserved Below — Historical Reference Only)

> ⚠️ **PRECEDENCE RULE**: This section is preserved for traceability. It reflects the initial draft before the architectural decision was made.
>
> **If any statement below conflicts with the Execution Plan or the accepted ADR above, the Execution Plan and ADRs win — always.**
>
> Specifically, the following items in this section are superseded and must NOT be followed:
> - Any mention of adding `reconciliation_status` as a field on `Posting` or the `postings` table
> - Any mention of modifying the `postings_append_only_trigger`
> - "Consider adding an append-only trigger on `reconciliation_audit_logs`" → **Decided: trigger IS added (confirmed)**
> - Option A references (if any remain) → **Decided: Option B (overlay table) is the accepted approach**

---

# 018 - Reconciliation Status Workflow

**GitHub Issue**: #18
**Status**: READY FOR IMPLEMENTATION
**Priority**: P1
**Labels**: type:feature, area:ledger, area:ingestion
**Architectural Decision**: Confirmed -- Overlay table (see ADR below)

---

## Architectural Decision Record

**Decision**: Separate overlay table (`posting_reconciliation_states`) for reconciliation status.
**Date**: 2026-03-11
**Decided by**: Team (architect/user)
**Status**: Accepted

### Context

The issue requests that `Posting` gets a `reconciliation_status` field. However, the `postings` table is protected by a DB-level append-only trigger (`postings_append_only_trigger` in migration `20260308120000_harden_audit_events.exs`) that blocks ALL updates and deletes. This is a deliberate, foundational design choice: postings are immutable ledger facts.

### Decision

Reconciliation status is modeled as a **workflow overlay** in a separate `posting_reconciliation_states` table, not as a column on `postings`. A new `AurumFinance.Reconciliation` context owns all reconciliation schemas and logic.

### Rationale

- Preserves 100% immutability of the postings fact table -- no trigger modifications required
- Aligns with existing project ADRs that mandate separating workflow state from fact data
- Provides a better foundation for future capabilities: audit trail of state transitions, session reopen, corrections, and eventual statement-line matching
- Reconciliation state is inherently session-scoped, which maps naturally to a separate table with a `reconciliation_session_id` foreign key

### Trade-off Accepted

Queries that need to derive a posting's reconciliation status require a LEFT JOIN to `posting_reconciliation_states`. Rollup queries (e.g., cleared balance) are slightly more complex. This is the correct trade-off for a ledger-first application where fact immutability is a core invariant.

---

## Project Context

### Related Entities (Existing -- Read Only, Not Modified)

- `AurumFinance.Ledger.Posting` - The immutable posting leg. Reconciliation status is derived by joining to the overlay table.
  - Location: `lib/aurum_finance/ledger/posting.ex`
  - Key fields: `id`, `transaction_id`, `account_id`, `amount`
  - DB constraint: **fully append-only** (trigger blocks ALL updates and deletes)
  - No `updated_at` column (only `inserted_at`)
  - **This schema is NOT modified by this feature**

- `AurumFinance.Ledger.Transaction` - Parent transaction header
  - Location: `lib/aurum_finance/ledger/transaction.ex`
  - Key fields: `id`, `entity_id`, `date`, `description`, `source_type`, `voided_at`, `correlation_id`
  - DB constraint: only `voided_at` and `correlation_id` may be updated; all other columns immutable
  - Entity scoped via `entity_id`

- `AurumFinance.Ledger.Account` - The account being reconciled
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Key fields: `id`, `entity_id`, `name`, `account_type`, `operational_subtype`, `management_group`, `currency_code`
  - Reconciliation is meaningful primarily for `:institution` management group accounts

- `AurumFinance.Entities.Entity` - Ownership boundary
  - Location: `lib/aurum_finance/entities/entity.ex`
  - All ledger data is entity-scoped

- `AurumFinance.Audit` - Audit trail context
  - Location: `lib/aurum_finance/audit.ex`
  - Helpers: `insert_and_log/2`, `update_and_log/3`, `Multi.append_event/4`

### New Entities (This Feature)

- `AurumFinance.Reconciliation` - **New context** owning all reconciliation logic
  - Location: `lib/aurum_finance/reconciliation.ex`

- `AurumFinance.Reconciliation.ReconciliationSession` - Session header
  - Location: `lib/aurum_finance/reconciliation/reconciliation_session.ex`
  - Table: `reconciliation_sessions`
  - Fields: `id`, `account_id`, `entity_id`, `statement_date`, `statement_balance`, `completed_at`, `inserted_at`, `updated_at`

- `AurumFinance.Reconciliation.PostingReconciliationState` - Workflow overlay for posting status
  - Location: `lib/aurum_finance/reconciliation/posting_reconciliation_state.ex`
  - Table: `posting_reconciliation_states`
  - Fields: `id`, `entity_id`, `posting_id`, `reconciliation_session_id` (nullable -- cleared postings belong to a session; for future flexibility), `status` (`:cleared` | `:reconciled`), `reason`, `inserted_at`, `updated_at`
  - Semantic rule: absence of an active record for a posting => `:unreconciled`

- `AurumFinance.Reconciliation.ReconciliationAuditLog` - Transition traceability
  - Location: `lib/aurum_finance/reconciliation/reconciliation_audit_log.ex`
  - Table: `reconciliation_audit_logs`
  - Fields: `id`, `posting_reconciliation_state_id`, `reconciliation_session_id`, `from_status`, `to_status`, `actor`, `channel`, `occurred_at`, `metadata` (map), `inserted_at`
  - Append-only (no updates or deletes)

### Related Features

- **ReconciliationLive** (`lib/aurum_finance_web/live/reconciliation_live.ex`)
  - Currently a mock/placeholder with hardcoded data
  - Has existing component module: `lib/aurum_finance_web/components/reconciliation_components.ex`
  - Components already define state variants: `:reconciled`, `:cleared`, `:unreconciled`
  - Route: `live "/reconciliation", ReconciliationLive, :index`

- **AccountsLive** (`lib/aurum_finance_web/live/accounts_live.ex`)
  - Pattern to follow: entity selector, tab switching, stream-based lists, slideover forms
  - Uses `Ledger.list_accounts_by_management_group/2` with entity scope

- **TransactionsLive** (`lib/aurum_finance_web/live/transactions_live.ex`)
  - Shows transactions with postings, entity-scoped
  - Pattern for listing/filtering transactions

### Auth & Permissions Model

- **Single-user root auth**: No role-based access control. Auth is binary (authenticated root or not).
- **Auth plug**: `AurumFinanceWeb.RootAuth` with `:require_authenticated_root` pipeline
- **LiveView on_mount**: `{AurumFinanceWeb.RootAuth, :ensure_authenticated}`
- **Scope**: `current_scope: %{root: true}` assigned to socket
- **Entity isolation**: All ledger queries require explicit `entity_id` parameter (enforced via `require_entity_scope!/2`)

### Naming Conventions Observed

- **Contexts**: `AurumFinance.Ledger`, `AurumFinance.Entities`, `AurumFinance.Audit`, `AurumFinance.Ingestion`
- **Schemas**: `AurumFinance.Ledger.Account`, `AurumFinance.Ledger.Transaction`, `AurumFinance.Ledger.Posting`
- **LiveViews**: `AurumFinanceWeb.ReconciliationLive` (flat, not nested in directories)
- **Components**: `AurumFinanceWeb.ReconciliationComponents` (separate module per feature)
- **Context functions**: `list_*`, `get_*!`, `create_*`, `update_*`, `archive_*`, `change_*`
- **Filter pattern**: `list_*` accepts `opts` keyword list, dispatches to private `filter_query/2`
- **Audit pattern**: context functions accept `[audit_opt()]` and call `Audit.insert_and_log/2` etc.
- **Ecto enums**: `Ecto.Enum, values: @some_list` with module attribute for the values list
- **Factories**: `AurumFinance.Factory` in `test/support/factory.ex`, uses `insert/2` and `insert_entity/1`, `insert_account/2` helpers
- **i18n**: `dgettext("domain", "key")` pattern, error messages via `dgettext("errors", "error_...")`

---

## Data Model: Overlay Design

### Deriving Reconciliation Status for a Posting

A posting's effective reconciliation status is determined by its presence (or absence) in the `posting_reconciliation_states` table:

| `posting_reconciliation_states` record | Effective status |
|----------------------------------------|------------------|
| No record exists for `posting_id` | `:unreconciled` |
| Record exists with `status: :cleared` | `:cleared` |
| Record exists with `status: :reconciled` | `:reconciled` |

### State Machine (Overlay Transitions)

```
(no record)  -- mark cleared -->  insert record with status: :cleared
:cleared     -- un-clear     -->  delete record (returns to no-record = unreconciled)
:cleared     -- finalize     -->  update record status to :reconciled
:reconciled  -- (terminal)   -->  no transitions allowed
```

Each transition is recorded in `reconciliation_audit_logs` for traceability.

### Cleared Balance Derivation

The cleared balance for an account is computed by joining `postings` to `posting_reconciliation_states` where `status IN (:cleared, :reconciled)` and the posting's parent transaction is not voided:

```
SELECT SUM(p.amount)
FROM postings p
INNER JOIN posting_reconciliation_states prs ON prs.posting_id = p.id
INNER JOIN transactions t ON t.id = p.transaction_id
WHERE p.account_id = ?
  AND prs.status IN ('cleared', 'reconciled')
  AND t.voided_at IS NULL
```

---

## User Stories

### US-1: Start a Reconciliation Session

As an **authenticated root user**, I want to create a new reconciliation session for a specific account and statement date, so that I can begin comparing my ledger postings against my bank statement.

### US-2: View Unreconciled Postings

As an **authenticated root user**, I want to see all unreconciled postings for the selected account within the reconciliation session, so that I can identify which transactions match my bank statement.

### US-3: Bulk-Mark Postings as Cleared

As an **authenticated root user**, I want to select multiple unreconciled postings and mark them as cleared in bulk, so that I can efficiently work through a bank statement.

### US-4: Enter Statement Balance

As an **authenticated root user**, I want to enter the statement balance and statement date for my reconciliation session, so that the system can compare the cleared balance against the statement balance.

### US-5: Finalize Reconciliation

As an **authenticated root user**, I want to finalize ("reconcile") a session, which locks all cleared postings as reconciled and records the session as completed, so that reconciled data is protected from further modification.

### US-6: Prevent Modification of Reconciled Postings

As an **authenticated root user**, I want the system to prevent voiding transactions that contain reconciled postings, so that previously reconciled data remains intact and trustworthy.

### US-7: View Reconciliation Session History

As an **authenticated root user**, I want to see a list of past reconciliation sessions for an account, so that I can review when reconciliation was last performed and what the statement balances were.

### US-8: Un-clear a Posting Before Finalization

As an **authenticated root user**, I want to un-clear a posting (revert from cleared to unreconciled) before the session is finalized, so that I can correct mistakes during the reconciliation process.

---

## Acceptance Criteria

### US-1: Start a Reconciliation Session

**Scenario: Happy path -- create new session**
- **Given** I am on the Reconciliation page and have selected an entity with at least one institution account
- **When** I click "New Session", select an account, enter a statement date and statement balance
- **Then** a `ReconciliationSession` is created with `completed_at: nil`, and I see the list of unreconciled postings for that account

**Criteria Checklist:**
- [ ] Session form requires: account selection (entity-scoped, institution accounts only), statement_date (date), statement_balance (decimal)
- [ ] Session is created with `completed_at: nil`
- [ ] Only one active (non-completed) session per account at a time
- [ ] On success: navigate to session detail view showing unreconciled postings
- [ ] On validation error: inline form errors displayed
- [ ] Audit event emitted: `entity_type: "reconciliation_session"`, `action: "created"`

**Scenario: Attempt to create session for account with active session**
- **Given** account "Checking" already has an in-progress reconciliation session
- **When** I try to create a new session for "Checking"
- **Then** I see an error: "An active reconciliation session already exists for this account"

### US-2: View Unreconciled Postings

**Scenario: List postings for reconciliation**
- **Given** I have an active reconciliation session for account "Checking"
- **When** I view the session
- **Then** I see all postings for that account that have no record in `posting_reconciliation_states` (i.e., unreconciled), ordered by transaction date descending
- **And** each row shows: transaction date, description, amount, current reconciliation status badge

**Criteria Checklist:**
- [ ] Unreconciled postings are those with no corresponding row in `posting_reconciliation_states` (LEFT JOIN where overlay is NULL)
- [ ] List is scoped to the session's account and entity
- [ ] Voided transactions are excluded (JOIN to transactions, filter `voided_at IS NULL`)
- [ ] Each posting displays its parent transaction's date and description
- [ ] Running "cleared balance" is displayed (sum of all postings with overlay status `:cleared` or `:reconciled` for the account)
- [ ] "Difference" is displayed (statement_balance - cleared_balance) to help the user identify remaining items

### US-3: Bulk-Mark Postings as Cleared

**Scenario: Select and clear multiple postings**
- **Given** I am in an active reconciliation session with 10 unreconciled postings visible
- **When** I select 3 postings using checkboxes and click "Mark Cleared"
- **Then** for each selected posting, a `PostingReconciliationState` record is inserted with `status: :cleared` and `reconciliation_session_id` set to the current session
- **And** a `ReconciliationAuditLog` entry is created for each transition (from_status: nil, to_status: :cleared)
- **And** the cleared balance updates to reflect the newly cleared amounts
- **And** the difference (statement_balance - cleared_balance) updates

**Criteria Checklist:**
- [ ] Checkbox selection with "select all" toggle
- [ ] Bulk action button "Mark Cleared" is enabled only when at least one posting is selected
- [ ] Inserts to `posting_reconciliation_states` are atomic (all or none within the bulk action via `Ecto.Multi`)
- [ ] Postings that already have an overlay record (cleared or reconciled) cannot be selected for clearing
- [ ] Cleared balance recalculates after the operation
- [ ] UI updates via LiveView without full page reload

### US-4: Enter Statement Balance

**Scenario: Statement balance comparison**
- **Given** I have a reconciliation session with `statement_balance: 5000.00` and postings with overlay status `:cleared` or `:reconciled` summing to 4850.00
- **When** I view the session detail
- **Then** I see: Statement Balance = 5000.00, Cleared Balance = 4850.00, Difference = 150.00
- **And** the difference is highlighted in a warning color when non-zero

**Criteria Checklist:**
- [ ] Statement balance is set during session creation and can be edited before finalization
- [ ] Cleared balance is derived on read by joining `postings` to `posting_reconciliation_states` where status IN (`:cleared`, `:reconciled`) for that account, excluding voided transactions
- [ ] Difference = statement_balance - cleared_balance (using the account's currency)
- [ ] Difference of zero is shown with a success indicator

### US-5: Finalize Reconciliation

**Scenario: Successful finalization**
- **Given** I have a reconciliation session where the difference is zero (statement_balance == cleared_balance)
- **When** I click "Reconcile"
- **Then** all `PostingReconciliationState` records for this session with `status: :cleared` are updated to `status: :reconciled`
- **And** `ReconciliationAuditLog` entries are created for each transition (from_status: :cleared, to_status: :reconciled)
- **And** the session's `completed_at` is set to the current timestamp
- **And** I see a success message: "Reconciliation completed successfully"

**Scenario: Attempt to finalize with non-zero difference**
- **Given** the difference between statement_balance and cleared_balance is non-zero
- **When** I click "Reconcile"
- **Then** I see a confirmation dialog: "The difference is [amount]. Are you sure you want to reconcile?"
- **And** if I confirm, the reconciliation proceeds (to allow for known discrepancies)

**Criteria Checklist:**
- [ ] All cleared-to-reconciled transitions happen atomically in a single `Ecto.Multi` transaction
- [ ] Session `completed_at` is set in the same transaction
- [ ] Audit event emitted: `entity_type: "reconciliation_session"`, `action: "completed"`
- [ ] Completed sessions are read-only in the UI
- [ ] If difference is zero, finalize without extra confirmation
- [ ] If difference is non-zero, require explicit confirmation

### US-6: Prevent Modification of Reconciled Postings

**Scenario: Block void of transaction with reconciled postings**
- **Given** transaction "Groceries" has a posting in account "Checking", and that posting has a `PostingReconciliationState` record with `status: :reconciled`
- **When** I attempt to void transaction "Groceries"
- **Then** the void fails with error: "Cannot void transaction: contains reconciled postings"

**Criteria Checklist:**
- [ ] `Ledger.void_transaction/2` queries `posting_reconciliation_states` for all postings on the transaction and checks for any with `status: :reconciled`
- [ ] The check is performed in the Ledger context (calling into the Reconciliation context for the query), not just in the UI
- [ ] Error is a clear, user-facing message
- [ ] Postings with overlay status `:cleared` (but not yet `:reconciled`) can still have their transaction voided; in that case, the corresponding `PostingReconciliationState` records are deleted (un-cleared) as part of the void operation

### US-7: View Reconciliation Session History

**Scenario: Browse past sessions**
- **Given** I have completed 3 reconciliation sessions for account "Checking"
- **When** I view the Reconciliation page with "Checking" selected
- **Then** I see a list of sessions ordered by `statement_date` descending, showing: statement_date, statement_balance, completed_at, status

**Criteria Checklist:**
- [ ] Sessions list is entity-scoped
- [ ] Can filter by account
- [ ] Active (in-progress) sessions appear at the top with a distinct badge
- [ ] Completed sessions show their completion timestamp

### US-8: Un-clear a Posting Before Finalization

**Scenario: Revert cleared posting to unreconciled**
- **Given** I have a posting with a `PostingReconciliationState` record with `status: :cleared` in an active session
- **When** I click "Un-clear" on that posting
- **Then** the `PostingReconciliationState` record is deleted (returning the posting to unreconciled -- no overlay record)
- **And** a `ReconciliationAuditLog` entry is created (from_status: :cleared, to_status: nil)
- **And** the cleared balance and difference update

**Criteria Checklist:**
- [ ] Only postings with overlay status `:cleared` can be un-cleared (not `:reconciled`)
- [ ] Un-clearing is only allowed within an active (non-completed) session
- [ ] Cleared balance recalculates after the operation

---

## Edge Cases

### Empty States

- [ ] No reconciliation sessions exist for any account -> Show "No reconciliation sessions yet" with CTA to create one
- [ ] Selected account has no unreconciled postings (all have overlay records) -> Show "All postings for this account are reconciled" with session summary
- [ ] No institution accounts exist -> Show message: "Create an institution account first to begin reconciliation"

### Error States

- [ ] Network failure during bulk clear -> Atomic rollback of `Ecto.Multi`, show retry option, preserve selection state
- [ ] Concurrent session conflict -> Only one active session per account; reject creation with clear message
- [ ] Statement balance validation -> Must be a valid decimal number; show inline error for non-numeric input

### Permission Denied

- [ ] Unauthenticated user -> Redirect to `/login` with flash (existing pattern)

### Concurrent Access

- [ ] This is a single-user app, so concurrent access is not a primary concern
- [ ] However, if the user has multiple browser tabs, the DB-level unique constraints on `posting_reconciliation_states.posting_id` ensure no duplicate overlay records

### Boundary Conditions

- [ ] Maximum postings in a reconciliation view: no hard limit, but pagination or virtual scrolling should be considered for accounts with 1000+ unreconciled postings
- [ ] Statement balance precision: should match the account's currency decimal precision
- [ ] Zero-amount postings: should be visible and clearable
- [ ] Voided transactions: postings belonging to voided transactions should be excluded from the reconciliation view
- [ ] Postings across multiple currencies: reconciliation is per-account, and accounts have a single `currency_code`, so this is naturally scoped

### Data Integrity

- [ ] Existing postings (created before this feature) have no overlay record, so they are implicitly `:unreconciled` -- no backfill migration needed
- [ ] `posting_reconciliation_states.posting_id` should have a UNIQUE constraint to prevent duplicate overlay records for the same posting
- [ ] Once a `PostingReconciliationState` record reaches `status: :reconciled`, it cannot be updated or deleted (enforced in the Reconciliation context and optionally via DB trigger on the overlay table)
- [ ] State transitions: see "State Machine (Overlay Transitions)" section above
- [ ] Deleting a `PostingReconciliationState` record with `status: :cleared` is the mechanism for un-clearing (returns to implicit unreconciled)

### DB Trigger Interaction

- [ ] The `postings_append_only_trigger` is NOT modified -- postings remain fully immutable
- [ ] The new `posting_reconciliation_states` table is standard CRUD (insert, update, delete allowed)
- [ ] ~~Consider adding an append-only trigger on `reconciliation_audit_logs`~~ **Decided in execution plan: append-only trigger is required on `reconciliation_audit_logs` (matches `audit_events` pattern)**
- [ ] ~~Consider adding a trigger or CHECK constraint on `posting_reconciliation_states`~~ **Decided in execution plan: DB protection against unreconcile transitions is required (`posting_reconciliation_states_no_unreconcile_trigger`)**

---

## UX States

### Reconciliation Page (Session List)

| State | Behavior |
|-------|----------|
| **Loading** | Show skeleton for session list |
| **Empty (no sessions)** | Show empty state with "New Session" CTA |
| **Empty (no institution accounts)** | Show message directing user to create an account first |
| **Has sessions** | Show list with active sessions at top, completed below |

### Reconciliation Session Detail

| State | Behavior |
|-------|----------|
| **Loading** | Show skeleton for postings table |
| **Active session, has unreconciled** | Show postings table with checkboxes, bulk actions, balance summary |
| **Active session, all cleared** | Show postings table, highlight "Reconcile" button, show difference |
| **Active session, difference is zero** | Show success indicator on difference, enable "Reconcile" button prominently |
| **Completed session** | Read-only view: no checkboxes, no actions, show completion details |
| **Error during bulk action** | Show error flash, preserve current state |

### Balance Summary Panel

| State | Behavior |
|-------|----------|
| **Difference is zero** | Green/success badge: "Balanced" |
| **Difference is non-zero** | Warning/amber badge showing the difference amount |
| **No cleared postings** | Show statement balance and "0.00" for cleared balance |

---

## Schema Design

### `reconciliation_sessions` table

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `account_id` | `binary_id` | FK to `accounts`, NOT NULL |
| `entity_id` | `binary_id` | FK to `entities`, NOT NULL (denormalized for query convenience) |
| `statement_date` | `date` | NOT NULL |
| `statement_balance` | `decimal` | NOT NULL |
| `completed_at` | `utc_datetime_usec` | nullable (NULL = in progress, non-NULL = completed) |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |
| `updated_at` | `utc_datetime_usec` | NOT NULL |

Indexes: `(entity_id)`, `(account_id)`, `(account_id, completed_at)` partial index for active session uniqueness.

### `posting_reconciliation_states` table

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `entity_id` | `binary_id` | FK to `entities`, NOT NULL |
| `posting_id` | `binary_id` | FK to `postings`, NOT NULL, UNIQUE |
| `reconciliation_session_id` | `binary_id` | FK to `reconciliation_sessions`, nullable |
| `status` | `string` (Ecto.Enum) | NOT NULL, values: `[:cleared, :reconciled]` |
| `reason` | `string` | nullable (optional note for why a posting was cleared/reconciled) |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |
| `updated_at` | `utc_datetime_usec` | NOT NULL |

Indexes: `(posting_id)` unique, `(entity_id)`, `(reconciliation_session_id)`, `(entity_id, status)`.

Note: The enum values are `[:cleared, :reconciled]` only. There is no `:unreconciled` value stored -- absence of a record is the unreconciled state.

### `reconciliation_audit_logs` table

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `binary_id` | PK |
| `posting_reconciliation_state_id` | `binary_id` | FK to `posting_reconciliation_states`, nullable (nullable because record may have been deleted on un-clear) |
| `reconciliation_session_id` | `binary_id` | FK to `reconciliation_sessions`, NOT NULL |
| `posting_id` | `binary_id` | FK to `postings`, NOT NULL (denormalized for querying after state record deletion) |
| `from_status` | `string` | nullable (nil = was unreconciled / no record) |
| `to_status` | `string` | nullable (nil = un-cleared / record deleted) |
| `actor` | `string` | NOT NULL |
| `channel` | `string` | NOT NULL |
| `occurred_at` | `utc_datetime_usec` | NOT NULL |
| `metadata` | `map` | nullable |
| `inserted_at` | `utc_datetime_usec` | NOT NULL |

Append-only (no `updated_at`). Consider a DB trigger to enforce append-only, matching the `audit_events` pattern.

---

## Context API Shape (Suggested)

The following functions are suggested names based on project conventions. The tech lead owns the final API design.

**New context: `AurumFinance.Reconciliation`**

Session lifecycle:
- `list_reconciliation_sessions(opts)` -- with `entity_id`, `account_id` filters
- `get_reconciliation_session!(entity_id, session_id)`
- `create_reconciliation_session(attrs, opts)` -- validates one active session per account
- `update_reconciliation_session(session, attrs, opts)` -- for editing statement_balance before completion
- `complete_reconciliation_session(session, opts)` -- atomically: transitions all cleared overlay records to reconciled, sets `completed_at`, logs audit entries
- `change_reconciliation_session(session, attrs)` -- for form handling

Posting reconciliation state:
- `list_postings_for_reconciliation(account_id, opts)` -- returns postings LEFT JOINed with overlay, entity-scoped, excludes voided transactions
- `get_posting_reconciliation_status(posting_id)` -- returns `:unreconciled`, `:cleared`, or `:reconciled`
- `mark_postings_cleared(posting_ids, session_id, opts)` -- bulk insert into `posting_reconciliation_states`, log transitions
- `mark_postings_uncleared(posting_ids, session_id, opts)` -- delete overlay records for cleared postings, log transitions
- `posting_has_reconciled_status?(posting_id)` -- fast check for void guard
- `any_posting_reconciled?(posting_ids)` -- batch check for void guard

Balance derivation:
- `get_cleared_balance(account_id, opts)` -- sum of amounts from postings with overlay status `:cleared` or `:reconciled`

**Cross-context integration with `AurumFinance.Ledger`:**
- `Ledger.void_transaction/2` gains a pre-check: calls `Reconciliation.any_posting_reconciled?(posting_ids)` and rejects the void if true
- When voiding a transaction whose postings have `:cleared` overlay records, the void operation also deletes those overlay records (cascading un-clear)

---

## Out of Scope

Explicitly excluded from this feature:

1. **Automatic matching / confidence scoring** -- The mock UI shows match confidence percentages. Automatic statement-to-ledger matching is a separate feature (likely tied to statement import parsing). This spec covers manual reconciliation only.

2. **Statement line import** -- Importing bank statement CSV/OFX lines and comparing them against ledger postings is a separate ingestion feature. This spec assumes the user visually compares their statement with the ledger postings displayed.

3. **Partial reconciliation / split matching** -- One statement line matching multiple postings or vice versa is deferred.

4. **Reconciliation reports / export** -- Generating a reconciliation report PDF or export is deferred.

5. **Multi-currency reconciliation within a single session** -- Accounts have a single currency, so this is naturally scoped. Cross-currency reconciliation is out of scope.

6. **Balance assertions** -- Recording and enforcing expected balances at specific dates (beyond statement_balance on the session) is deferred.

7. **Undo completed reconciliation** -- Once a session is completed and postings are reconciled, there is no "undo" workflow. If a mistake is found, the user would need to create adjusting entries. (The overlay model provides a future path for reopening sessions, but that is explicitly out of scope for v1.)

---

## Involved Roles

Note: The `claude/.claude/agents/agent_catalog.md` file was not found in the repository. The following are recommended based on the nature of the work:

- **Tech Lead / Architect** -- Review migration strategy, approve final context API design, confirm overlay table constraints
- **Backend Developer** -- Implement new Reconciliation context, schemas, migration, state machine enforcement, void guard integration
- **Frontend Developer** -- Implement LiveView reconciliation workflow, replace mock data with real queries
- **QA / Test** -- Validate state transitions, overlay integrity, void guard, edge cases

---

## Summary of Changes

| Area | What Changes |
|------|-------------|
| **New context** | `AurumFinance.Reconciliation` with session lifecycle and overlay state management |
| **New schema** | `AurumFinance.Reconciliation.ReconciliationSession` |
| **New schema** | `AurumFinance.Reconciliation.PostingReconciliationState` (overlay table) |
| **New schema** | `AurumFinance.Reconciliation.ReconciliationAuditLog` (transition traceability) |
| **New migration** | Create `reconciliation_sessions`, `posting_reconciliation_states`, `reconciliation_audit_logs` tables with indexes and constraints |
| **Modified context** | `AurumFinance.Ledger` -- `void_transaction/2` gains reconciled-posting guard (calls into Reconciliation context) |
| **NOT modified** | `AurumFinance.Ledger.Posting` schema -- no changes, remains fully immutable |
| **NOT modified** | `postings_append_only_trigger` -- no trigger changes |
| **Modified LiveView** | `AurumFinanceWeb.ReconciliationLive` replaces mock data with real workflow |
| **Modified components** | `AurumFinanceWeb.ReconciliationComponents` updated for real data structures |
| **New factories** | `reconciliation_session_factory`, `posting_reconciliation_state_factory` in `AurumFinance.Factory` |
| **Tests** | Context tests for state machine, void guard, session lifecycle; LiveView tests for reconciliation workflow |
