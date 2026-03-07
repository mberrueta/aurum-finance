# ADR 0015: Account Model and Financial Instrument Types

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: Architecture consolidation follow-up (post Steps 1-10 baseline)

## Context

Accounts are the primary containers for all financial activity in AurumFinance.
They determine posting interpretation, balance derivation, reconciliation scope,
and future investment/liability expansion.

Existing ADRs define ledger invariants and multi-entity scope but do not yet
provide one canonical account taxonomy and instrument-alignment model.

This ADR defines account categories, instrument types, ownership relationships,
currency behavior, and institution associations.

### Inputs

- ADR-0008: Ledger schema and account tree fundamentals.
- ADR-0009: Multi-entity ownership boundary.
- ADR-0013: Reconciliation session/account scope.
- ADR-0014: Core financial domain model.

## Decision Drivers

1. Accounts must support both current personal-finance workflows and future
   investment/liability capabilities.
2. Account modeling must preserve double-entry invariants without introducing
   product-specific hacks.
3. Institution-linked and manual/offline accounts must coexist cleanly.
4. Multi-currency and cross-currency transactions must remain first-class.
5. Reconciliation must operate at account boundary with clear semantics.

## Decision

### 1. Account Identity and Scope

Each account:
- belongs to exactly one `entity_id`,
- has one accounting type (`asset`, `liability`, `equity`, `income`, `expense`),
- has one functional currency code,
- may optionally link to institution metadata,
- may optionally declare an instrument profile (see below).

### 2. Account Classifications

Two orthogonal dimensions are defined:

1. **Accounting type** (required): Asset/Liability/Equity/Income/Expense.
2. **Operational subtype** (required for asset/liability accounts):
   - `bank_checking`
   - `bank_savings`
   - `cash`
   - `brokerage_cash`
   - `brokerage_securities`
   - `crypto_wallet`
   - `credit_card`
   - `loan`
   - `other_asset`
   - `other_liability`

Operational subtypes do not change accounting semantics; they drive workflow,
integration, and reporting behavior.

### 2b. Management Group

Accounts also carry an explicit `management_group` used for account-management
surfaces and query simplification:

- `institution`
- `category`
- `system_managed`

This field is not a ledger semantic replacement. It complements the canonical
ledger fields:
- `account_type` keeps accounting meaning
- `operational_subtype` keeps operational meaning
- `management_group` keeps management/presentation grouping

### 2a. Presentation Model Clarification

The canonical internal model remains a single `Account` entity and taxonomy.
This does not require one mixed UX presentation of the full chart of accounts.

The web/UI layer may present separate management views for:
- institution-backed accounts,
- category accounts (`income` / `expense`),
- system-managed accounts.

Category accounts may be created manually by operators or generated
automatically by later categorization workflows. Their creation path does not
change their status as canonical ledger accounts.

This is a presentation concern only. It does not alter ledger semantics,
account ownership, reconciliation boundaries, or double-entry behavior.

### 3. Institution Relationship Model

An account may include institution references:
- institution name
- external account identifier (masked/reference form)
- provider/account metadata

These references are attributes, not ownership boundaries. Ownership is always
`entity_id`.

Institution linkage is optional so manual/offline accounts are fully supported.

### 4. Currency Rules

Each account has a declared primary currency. Postings to that account normally
use the same currency.

Cross-currency flows are represented through transaction posting sets that
preserve original currencies and maintain per-currency balancing (trading
account mechanism from ADR-0008/ADR-0005).

### 5. Instrument Type Association

Accounts that hold financial instruments (brokerage/crypto, and future
extensions) expose an instrument profile:

- instrument universe allowed in the account
- lot-tracking capability flag
- valuation source preference (price feed policy)

This profile configures downstream investment logic but does not alter ledger
fact structure.

### 6. Reconciliation Scope

Reconciliation sessions are account-scoped (`entity_id + account_id +
statement_identifier`). Matching/discrepancies are evaluated within this scope.

## Rationale

Separating accounting type from operational subtype prevents overloading one
field with conflicting concerns while keeping the model extensible.

Adding a formal instrument profile now avoids ad-hoc account flags later when
investments are introduced.

## Consequences

### Positive

- Canonical, extensible account taxonomy.
- Clear relationship between accounts, institutions, and entities.
- Better readiness for investments and complex liabilities.
- Reconciliation boundary remains explicit and stable.

### Negative / Trade-offs

- Additional classification fields increase model surface area.
- Requires governance to avoid uncontrolled subtype proliferation.
- UX must clearly explain subtype meaning to users.

### Mitigations

- Keep subtype catalog curated through ADR-backed changes.
- Validate subtype/account-type compatibility at boundary APIs.
- Keep institution linkage optional and non-authoritative.

## Implementation Notes

- Store accounting type and operational subtype as separate attributes.
- Keep institution metadata as optional fields/associated records.
- Ensure reconciliation queries are always account-scoped.
- Treat instrument profile as configuration metadata, not a ledger fact.
