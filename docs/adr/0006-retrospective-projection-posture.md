# ADR 0006: Retrospective + Projection Product Posture (Non-Envelope Budgeting)

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

Personal finance tools broadly fall into two camps:

1. **Forward budgeting (envelope/zero-sum):** Users pre-assign every dollar of income
   to a category before spending. YNAB and Actual Budget are examples. This model
   requires active setup and maintenance by the user.

2. **Retrospective + projection:** Users import what happened; the system classifies,
   detects patterns, and projects forward from actuals. No pre-assignment required.

AurumFinance targets users with complex financial situations across multiple countries,
currencies, accounts, and brokers. These users import historical statements — they are
not managing a single-currency household budget where envelope assignment is natural.

## Decision Drivers

1. Users import bank and broker statements after the fact — pre-assignment contradicts
   the import-first workflow.
2. Multi-currency and multi-entity complexity makes envelope assignment impractical.
3. The system should provide value from the first import with zero configuration.
4. Projection and anomaly detection should derive from actuals, not from user intentions.

## Decision

AurumFinance is **retrospective and projection-based**:

- Users never pre-assign income to categories.
- The system learns patterns from imported actuals.
- Projections and alerts are derived from what actually happened, not from budgets.

**Envelope/zero-sum budgeting is explicitly out of scope.**

### What the system provides from actuals (no user setup required)

**Historical cashflow analysis**
- Income vs expenses by category and period
- Net worth evolution over time
- Per-entity and per-account breakdowns

**Automatic recurring detection**
The system detects recurring items from history — the user never declares them manually:
- Recurring income: salary, rent income, fixed-income payments, dividends
- Recurring expenses: utilities, subscriptions, insurance, loan payments

**Next-month projection**
Based on historical averages and known commitments:
- *"Based on Oct–Jan, energy typically costs ~$100/month"*
- *"Your salary hit on the 3rd every month — not yet seen this month"*
- *"You have a recurring payment that usually appears around the 15th"*

**Tax awareness**
- Track tax-relevant events (asset sales, dividends, interest, FX gains)
- Estimate tax exposure using the fiscally-relevant rate
- Surface what to reserve for upcoming tax obligations

**Anomaly alerts**
- *"Transport spend is 40% above your 3-month average this month"*
- *"Expected recurring debit for energy not seen yet — 5 days overdue"*
- *"This transaction looks like a duplicate of one imported last week"*

### What AurumFinance is not

- Not a forward budgeting tool — no pre-assignment of income to categories.
- Not a spending coach instructing users how to allocate future money.
- Not a household budget manager for single-currency, single-country use cases.

## Rationale

Actual Budget validates that envelope budgeting is a coherent product with strong
UX appeal for its target user. However, AurumFinance's target user imports historical
statements across multiple currencies, countries, and brokers. Asking them to
pre-assign income contradicts the import-first, low-friction posture and the
multi-currency reality.

The retrospective posture also enables the system to deliver value from the first
import with zero upfront configuration — which is a strong differentiator.

## Consequences

### Positive
- Zero-configuration value from first import.
- No ongoing user maintenance required to keep the system useful.
- Projections are grounded in evidence (actuals), not in user intentions that may not match reality.
- Product direction is clear and scoped — no hybrid that tries to do both.

### Negative / Trade-offs
- Does not serve users who specifically want to do forward budgeting (envelope/YNAB-style).
- Recurring detection requires sufficient history — a new user with one month of data
  gets limited projection value initially.

### Mitigations
- Document clearly in onboarding that the tool is import-first and retrospective.
- Recurring detection can use configurable minimum history thresholds with fallbacks.
- Users who want forward budgeting are explicitly out of scope — do not build a hybrid
  that dilutes the product direction.

## Implementation Notes

- Reporting layer operates entirely on imported and classified transaction data.
- Recurring pattern detection is a background analysis job, not a user-declared entity.
- Projection output is always labelled with its evidence base (date range, transaction count used).
- Anomaly thresholds are derived from historical data (e.g., rolling 3-month average), not from user-set limits.
