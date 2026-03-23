# Plan: Reporting Net Worth Drilldown

## Goal
Define the next Reporting slice for AurumFinance so that **Net Worth stops being an opaque number** and becomes **explainable at the account level**.

This slice focuses on **explaining the numbers already shown by Reporting** by providing a drilldown into the account-level balance snapshots and the transactions that back them.

**Core Principle**: This slice explains only values already materialized and displayed by Reporting. It does not compute missing balances, infer partial balances, or merge snapshot-backed values with newer ledger movements.

## Key Decisions
- **Account Inclusion**: Net Worth V1 includes **all `Asset` and `Liability` accounts** of the selected entity.
- **Explainability Entry Point**: Drilldown is initiated at the **account row**, not the total net worth number.
- **Reporting Foundation**: The report and drilldown use existing **Daily Balance Snapshots** as the source for balances.
- **Historical Consistency**: Drilldown transactions stop at the **snapshot date used**, even if the snapshot is outdated, to explain the *displayed* value.
- **No-Snapshot Handling**:
  - Accounts without a snapshot remain visible in the table.
  - They show a value of **0** and contribute 0 to totals for this slice.
  - They are marked with the **No snapshot** badge.
  - They are **not clickable** (not drilldown-capable).
- **Freshness Definition**: **Outdated** status reuses the already approved snapshot freshness/outdated rule from the reporting foundation (currently identified as `:refreshable_gap`).

## Status
- **Status**: READY FOR IMPLEMENTATION

---

## Project Context

### Related Entities
- `AurumFinance.Reporting.DailyBalanceSnapshot`
  - Location: `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
  - Purpose: Persisted closing balance for an account on a specific date.
- `AurumFinance.Ledger.Transaction`
  - Location: `lib/aurum_finance/ledger/transaction.ex`
  - Purpose: Financial event header.
- `AurumFinance.Ledger.Posting`
  - Location: `lib/aurum_finance/ledger/posting.ex`
  - Purpose: Individual account movement within a transaction.

### Related Features
- **Net Worth Report** (`lib/aurum_finance/reporting/net_worth.ex`, `lib/aurum_finance_web/live/net_worth_live.ex`)
  - The base report being enhanced.
- **Transactions Row Expansion** (`lib/aurum_finance_web/live/transactions_live.ex`, `lib/aurum_finance_web/components/transactions_components.ex`)
  - The UI pattern (row expansion) to be reused for the drilldown panel.

### Naming Conventions Observed
- Contexts: `AurumFinance.Reporting`, `AurumFinance.Ledger`
- LiveViews: `AurumFinanceWeb.NetWorthLive`
- Components: `AurumFinanceWeb.NetWorthComponents` (to be created)

---

## User Stories

### US-1: View Account Drilldown
As a **:viewer**, I want to click on an account in the Net Worth report so that I can see exactly which snapshot and transactions explain its balance.

### US-2: Identify Outdated Balances
As a **:viewer**, I want to see an **Outdated** badge when a balance is backed by an outdated snapshot (one that doesn't include the latest ledger facts), so I know the data might be stale.

### US-3: Explain Outdated Value
As a **:viewer**, when I drill down into an outdated balance, I want to see the transactions up to the snapshot date, so I understand the *shown* value even if it's stale.

---

## Acceptance Criteria

### US-1: View Account Drilldown

**Scenario: Open drilldown for a covered account**
- **Given** an account row in `/reports/net-worth` has a snapshot
- **When** I click on the account row
- **Then** an inline panel (row expansion) opens below the row
- **Then** the panel shows the displayed balance and the snapshot date used
- **Then** the panel shows a paginated table of transactions (20 per page)
- **Then** the transactions are ordered most recent first

**Criteria Checklist:**
- [ ] Account rows without snapshots (**No snapshot**) are NOT clickable.
- [ ] Clicking an open panel closes it.
- [ ] Opening a new panel closes any previously opened panel (single expansion).
- [ ] Transaction table shows: Date, Description, Amount.
- [ ] Transaction rows are collapsed (summed) per transaction for the selected account.

### US-2: Identify Outdated Balances

**Scenario: Visual indicators for problematic rows**
- [ ] Given an account has an **Outdated** status (backed by an outdated snapshot)
- [ ] Then the row shows an **Outdated** badge
- [ ] Given an account has no eligible snapshot
- [ ] Then the row shows a **No snapshot** badge
- [ ] Then normal rows show NO badge

### US-3: Explain Outdated Value

**Scenario: Drilldown for outdated snapshot**
- [ ] Given a row is `Outdated`
- [ ] When I open the drilldown panel
- [ ] Then the transaction list stops at the **snapshot date used**
- [ ] Then the panel shows an `Outdated` badge near the balance

---

## Functional Boundaries

### Reporting Owns
- The drilldown query shape, including collapsing postings into one row per transaction for presentation.
- The state management of the drilldown panel in `NetWorthLive`.
- Presentation of the "explained" value.

### Ledger Owns
- The source-of-truth transactions and postings (financial facts).

---

## UX / UI Contract

### Main Table Changes
- **Row Interactivity**: Only rows with drilldown capability should present as interactive.
- **Badge Simplification**: Do not add new per-row badges except for **Outdated** and **No snapshot**. Existing coverage/status presentation remains unchanged.

### Drilldown Panel (Row Expansion)
- **Single Expansion**: Only one account drilldown panel may be open at a time. Opening a new panel automatically closes the previously active one.
- **Location**: `tr` with `colspan` immediately following the account row.
- Content:
  - Header: "Balance Explanation"
  - Summary: "Balance of [Amount] as of [Snapshot Date]"
  - Badge: `Outdated` (if applicable)
  - Table:
    - Columns: Date, Description, Amount (au-mono, au-debit/au-credit).
    - Pagination: paginated, 20 per page.

---

## Query / Data Contract

### Drilldown Query
- **Input**: `account_id`, `as_of_date`.
- **Logic**:
  1. Get the same snapshot used in the main report query.
  2. Fetch transactions where:
     - `posting.account_id == account_id`
     - `transaction.date <= snapshot.snapshot_date`
     - **Transaction Eligibility**: must match the same ledger fact semantics used to build `DailyBalanceSnapshot` (including/excluding voided facts as per projection logic), so the explanation remains consistent with the displayed balance.
  3. Group by `transaction.id`.
  4. Select `transaction.date`, `transaction.description`, `sum(posting.amount) as net_amount`.
  5. Order by `transaction.date DESC`, `transaction.inserted_at DESC`.

---

## Out of Scope
- Total-level drilldown (explaining the "Net Worth" total number).
- Categories, tags, or merchants in the drilldown table.
- Ad hoc balance recomputation (only explain what is stored).
- Modal or separate page views for drilldown.
- Multi-entity consolidation.

---

## Risks and Guardrails
- **Performance**: Validate query shape and supporting indexes for account/date-bounded drilldown access. Use paginated query access with bounded result size for transaction drilldown.
- **Consistency**: The drilldown MUST stop at the snapshot date to avoid confusing the user with transactions that aren't reflected in the shown balance.
- **Complexity**: Keep the transaction table simple (3 columns) to fit within the expanded row.

---

## Quality / Completion Expectations
- [ ] **Full PR Review Pass**:
  - **Correctness**: Verify the drilldown provides paginated evidence for the snapshot-backed balance; the full result set across all pages matches the displayed balance semantics (sum of all drilldown rows = snapshot balance). Individual pages are navigable evidence, not standalone proof.
  - **Security**: Ensure no cross-entity leakage in the drilldown query. The API receives `account_id` only, but the implementation must join through account→entity ownership consistently so the isolation contract is explicit in the query shape, not implicit in the caller.
  - **Performance**: Validate query shape and indexing to prevent N+1 issues.
  - **Boundaries**: Confirm Reporting does not create parallel financial truths or mutate ledger facts.
  - **Consistency**: Confirm the drilldown transaction list correctly respects the snapshot date boundary.
- [ ] **Automated Tests**:
  - `AurumFinance.Reporting.NetWorthTest`: Verify the drilldown query correctly sums postings and respects the snapshot date boundary.
  - `AurumFinanceWeb.NetWorthLiveTest`: Verify the row expansion toggle behavior and that the panel displays the expected snapshot/transaction data.
- [ ] **ADR Synchronization**: Update or create ADRs if the final implementation formalizes new architectural patterns for reporting explainability.
- [ ] **Documentation**: Update relevant project docs, and update `README` if user-visible reporting behavior or project-level capabilities are materially affected.
- [ ] **Internationalization**: Full i18n support for all new labels, headers, and tooltips.
- [ ] **UI/UX Consistency**: Responsive design check ensures the drilldown table remains readable on mobile/tablets.

---

# Execution Plan

## Metadata
- **Spec**: `llms/tasks/022_reporting_net_worth_drilldown/plan.md`
- **Created**: 2026-03-20
- **Status**: PLANNING
- **Current Task**: N/A

## Overview
This plan implements the Net Worth drilldown feature: a row expansion panel on the Net Worth report page that explains an account's balance by showing the backing snapshot metadata and the paginated list of transactions that comprise that balance. The work spans backend query implementation, LiveView UI with row expansion, comprehensive tests, i18n, and a final PR audit.

## Technical Summary

### Codebase Impact
- **New files**: 1 (possibly `net_worth_components.ex` if component extraction is warranted)
- **Modified files**: 5-6 (`net_worth.ex`, `reporting.ex`, `net_worth_live.ex`, `net_worth_live.html.heex`, test files, pt-BR PO file)
- **Database migrations**: No (uses existing tables and indexes)
- **External dependencies**: None

### Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Drilldown query performance on large accounts | Medium | Medium | Pagination with bounded LIMIT/OFFSET; verify index usage on postings(account_id) |
| Cross-entity data leakage via account_id | Low | High | Implementation must join through account→entity ownership chain consistently; tests must cover cross-entity isolation as an architectural guardrail, not just a happy-path assumption |
| Inconsistency between snapshot and drilldown transactions | Low | High | Use snapshot_date_used as the date boundary, not as_of_date; derive transaction eligibility filter from DailyBalanceSnapshot projection code |
| Template complexity growth in net_worth_live.html.heex | Low | Low | Extract drilldown panel into component function or separate component module if needed |

## Roles

### Human Reviewer
- Approves each task before next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject/request changes on any task

### Executing Agents
| Task | Agent | Description |
|------|-------|-------------|
| 01 | `dev-backend-elixir-engineer` | Drilldown query in Reporting context |
| 02 | `qa-elixir-test-author` | Backend tests for drilldown query |
| 03 | `dev-frontend-ui-engineer` | LiveView drilldown UI with row expansion |
| 04 | `qa-elixir-test-author` | LiveView tests for drilldown behavior |
| 05 | `loc-i18n-ptbr-gettext-guardian` | Brazilian Portuguese translations |
| 06 | `audit-pr-elixir` | Full PR review and audit |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Backend Drilldown Query | PENDING | [ ] | None |
| 02 | Backend Tests | BLOCKED | [ ] | Task 01 |
| 03 | LiveView Drilldown UI | BLOCKED | [ ] | Task 01, Task 02 |
| 04 | LiveView Tests | BLOCKED | [ ] | Task 03 |
| 05 | I18n pt-BR Translations | BLOCKED | [ ] | Task 03 |
| 06 | PR Review and Audit | BLOCKED | [ ] | Task 04, Task 05 |

**Status Legend:**
- PENDING - Ready to start (dependencies met)
- IN_PROGRESS - Currently being executed
- COMPLETED - Done and approved
- BLOCKED - Waiting on dependency
- REJECTED - Needs rework
- ON_HOLD - Paused by human

## Assumptions

1. **No migration needed**: The drilldown query operates on existing `daily_balance_snapshots`, `transactions`, and `postings` tables. Existing indexes on `postings.account_id` and `transactions.date` are expected to be sufficient; Task 01 must validate the query plan and Task 06 must confirm — add index recommendation if not.
2. **Transaction eligibility**: Drilldown transaction eligibility must match the same fact eligibility used by `DailyBalanceSnapshot` projection. The exact rules (e.g., voided transaction handling) are defined in projection code — Task 01 agent must derive the filter from that source, not from assumptions in this plan.
3. **Snapshot date as boundary**: The LiveView passes `snapshot_date_used` (from the account row) as the date boundary for the drilldown query, NOT the report's `as_of_date`. This ensures the drilldown explains the displayed value.
4. **Single expansion model**: Only one drilldown panel open at a time, following the same pattern as `transactions_live.ex`. No parallel/multi-panel expansion.
5. **No new components module**: The drilldown panel can likely be implemented inline in the template or as a function component within the LiveView. A separate `NetWorthComponents` module is optional.
6. **Pagination is offset-based**: Simple page/per_page with LIMIT/OFFSET, matching the spec's "20 per page" requirement. Cursor-based pagination is not needed for V1.
7. **Badge simplification**: Do not add new per-row badges except for Outdated (maps to `:refreshable_gap`) and No snapshot (maps to `:no_history`). Existing coverage/status column presentation remains unchanged.

## Open Questions

1. **Badge placement**: Should the Outdated/No snapshot badges appear in a new column, or inline with the account name? The spec says "the row shows a badge" but doesn't specify column placement. -- Non-blocking, resolved during Task 03 (suggest inline near account name or in existing coverage column).
2. **Transaction eligibility rules**: Task 01 agent must derive the exact eligibility filter from `DailyBalanceSnapshot` projection code, not from assumptions. This is a discovery task, not an open question — the answer is in the code.

## Change Log
| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-20 | Plan | Initial creation | - |
