# ADR 0014: Core Financial Domain Model

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: Architecture consolidation follow-up (post Steps 1-10 baseline)

## Context

AurumFinance already has accepted ADRs for ledger mechanics, ingestion,
classification, FX, and reconciliation. What is still missing is a single ADR
that defines the conceptual financial model across those domains in one place.

Without a canonical model, terms such as "transaction", "posting", "balance",
"event", "asset", and "liability" risk being interpreted differently by
different contexts.

This ADR defines the core financial ontology and establishes how real-world
financial events are represented in AurumFinance.

### Inputs

- ADR-0002: Ledger as internal double-entry model.
- ADR-0004: Immutable facts vs mutable classification.
- ADR-0008: Ledger schema design and invariants.
- ADR-0010: Import pipeline and source evidence traceability.
- ADR-0013: Reconciliation as workflow overlay, not fact mutation.

## Decision Drivers

1. The ledger must be the single source of truth for financial state.
2. Financial facts must be immutable and auditable.
3. Domain terms must have one canonical meaning across contexts.
4. The model must support both cash activity and future investment workflows.
5. The model must remain compatible with multi-entity and multi-currency design.

## Decision

### 1. Canonical Domain Concepts

#### Financial Event

A **Financial Event** is a real-world occurrence that changes economic
position (payment, deposit, transfer, fee, dividend, trade, correction).

In AurumFinance, each financial event is represented by one **Transaction**
containing one or more **Postings**.

#### Transaction

A **Transaction** is the immutable event container:
- scoped to one entity,
- time-stamped and descriptively labeled,
- linked to one or more postings,
- corrected by reversal/new transaction, never in-place mutation.

#### Posting

A **Posting** is the atomic debit/credit line that targets one account and
holds signed amount + currency. Postings are immutable facts.

A transaction is valid only when postings sum to zero per currency.

#### Account

An **Account** is a classification node in the chart of accounts and the holder
of position history. Accounts belong to exactly one entity and one account type
(Asset, Liability, Equity, Income, Expense).

#### Balance

A **Balance** is a derived view over postings up to a cutoff date. Balance
snapshots are performance artifacts; postings remain authoritative.

Balance is computed per currency. Cross-currency netting is never implicit and
requires explicit FX conversion policy at read/report time.

#### Asset / Liability

- **Asset** accounts represent economic resources controlled by the entity.
- **Liability** accounts represent obligations owed by the entity.

Equity, Income, and Expense complete the accounting equation representation.
In personal-finance workflows, **Equity** commonly anchors opening balances,
offset entries for structural corrections, and net-worth bridging accounts.

### 2. Representation Rules

1. Every financial event is represented as one transaction with at least two
   postings.
2. Split events are modeled as additional postings in the same transaction,
   not as a separate split entity.
3. Cross-currency events preserve original amounts/currencies and may use
   trading-account postings to preserve per-currency zero-sum invariants.
4. Classification metadata is never part of the financial fact model.
5. Reconciliation state is never part of the financial fact model.

### 3. Fact vs Overlay Separation

The core model is intentionally split:

- **Fact layer:** Entity, Account, Transaction, Posting (immutable)
- **Operational overlays:** Classification, Reconciliation, Import provenance
- **Derived layer:** Balances, analytics, projections, valuations

Overlays may change; facts do not.

### 4. Traceability Chain

For imported events, traceability is explicit:

`ImportFile/Row -> Transaction -> Postings -> Classification/Reconciliation -> Reporting`

No step may break linkability back to source evidence.

## Rationale

This model keeps accounting correctness and auditability central while allowing
workflow layers (classification, reconciliation, reporting) to evolve
independently.

It also prevents common design drift where reporting constructs or reconciliation
flags leak into core ledger semantics.

## Consequences

### Positive

- One canonical vocabulary across all finance contexts.
- Clear separation between immutable facts and mutable overlays.
- Strong foundation for investments, reporting, and tax expansion.
- Reduced ambiguity for implementation and future ADRs.

### Negative / Trade-offs

- Requires discipline to avoid "shortcut" writes outside the core model.
- Additional joins/projections are needed for workflow and analytics views.
- New features must map explicitly back to transaction/posting primitives.

### Mitigations

- Treat this ADR as a glossary + semantic source of truth for future ADRs.
- Enforce boundaries through context APIs and review checklists.
- Keep derived/reporting data explicitly non-authoritative.

## Implementation Notes

- Keep transaction/posting fields immutable after insertion.
- Model corrections as append-only reversals + replacements.
- Keep balance caches recomputable from postings.
- Prohibit workflow attributes (classification/reconciliation flags) on posting
  fact tables.
