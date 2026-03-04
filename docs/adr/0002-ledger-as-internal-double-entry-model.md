# ADR 0002: Ledger as Internal Double-Entry Model with Personal-Finance UX Mapping

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

AurumFinance must balance two competing needs: internal accounting correctness
(double-entry invariants, balanced postings, auditability) and a UX that feels
natural for non-accountants managing personal finances.

Existing tools resolve this differently:
- GnuCash exposes full double-entry to the user — powerful but steep learning curve.
- Firefly III uses double-entry internally while keeping the UX personal-finance oriented.
- Actual Budget does not use double-entry at all — simpler but limits correctness guarantees.

## Decision Drivers

1. Correctness: prevent balance drift, double-counted transfers, and untraceable discrepancies.
2. Usability: users should think in personal-finance terms (expense, income, transfer), not debits/credits.
3. Auditability: every financial event must be traceable from source import to final posting.
4. Real-world coverage: support liabilities (credit cards), multi-currency, and investment accounts without ad-hoc hacks.

## Decision

AurumFinance will use **double-entry as the internal correctness model** while
exposing only personal-finance-oriented concepts in the UX.

The internal ledger always maintains balanced postings. The user-facing layer maps
simple concepts to posting pairs transparently:

| UX concept | Internal posting model |
|---|---|
| Expense | Asset/Liability → Expense Category |
| Income | Income Category → Asset |
| Transfer | Asset Account A → Asset Account B |
| Credit card purchase | Credit Card (Liability) → Expense Category |
| Credit card payment | Bank Account (Asset) → Credit Card (Liability) |

## Rationale

Firefly III validates that this is a proven approach: internal double-entry is invisible
to the user but prevents the class of bugs (transfer double-counting, unbalanced accounts)
that plague single-entry personal finance tools.

GnuCash validates the correctness model itself and is the canonical reference for
account hierarchy, posting splits, and reconciliation semantics.

## Consequences

### Positive
- All balances and net worth calculations are provably consistent.
- Transfers between accounts are never double-counted.
- Full audit trail from source import to final posting is inherent to the model.
- Multi-currency and investment accounts fit naturally into the posting model.

### Negative / Trade-offs
- Internal complexity: the persistence layer must maintain posting invariants.
- Feature work must think in terms of posting pairs, even when the UX hides them.

### Mitigations
- Keep the posting model internal; never expose raw debit/credit terminology in the UI.
- Provide account-type-aware helpers that construct correct postings from UX-level inputs.

## Implementation Notes

- Account types: Asset, Liability, Equity, Income, Expense — standard double-entry chart of accounts.
- Every transaction produces exactly N posting pairs summing to zero per currency.
- Reconciliation and reporting operate on postings, not raw transaction records.
