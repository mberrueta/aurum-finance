# ADR 0016: Investment Tracking Model

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: Architecture consolidation follow-up (post Steps 1-10 baseline)

## Context

Investment tracking introduces domain concerns beyond simple cash movements:
positions, lots, cost basis, realized/unrealized gains, and market valuation.

Without an explicit model, systems often mix accounting facts with valuation
snapshots, causing audit drift and inconsistent gain calculations.

This ADR defines how AurumFinance models investments while preserving ledger
integrity and compatibility with multi-currency FX decisions.

### Inputs

- ADR-0002 / ADR-0008: Ledger transaction/posting invariants.
- ADR-0005 / ADR-0012: FX rate model and historical conversion policies.
- ADR-0014: Core financial domain model.
- ADR-0015: Account model and instrument association.

## Decision Drivers

1. Investment accounting events must remain represented in the ledger.
2. Market valuation must be separated from accounting facts.
3. Cost basis and lot tracking must be explicit and reproducible.
4. Gains must be derivable at event-time and valuation-time with FX context.
5. The model must support future instrument classes without redesign.

## Decision

### 1. Separation of Concerns

Investment architecture is split into three layers:

1. **Ledger event layer (authoritative facts):**
   buys, sells, dividends, fees, transfers as transactions/postings.
2. **Holdings state layer (derived operational model):**
   positions/lots computed from ledger events.
3. **Valuation layer (market data + FX):**
   unrealized values derived on read from price history and rate lookup.

No valuation figure is treated as a ledger fact.

### 2. Core Investment Concepts

#### Instrument

Reference identity for a tradable asset (ticker/symbol/ISIN/provider symbol)
with instrument class (equity, ETF, bond, fund, crypto, cash-equivalent, etc.).

Canonical identity key is:
- ISIN when available; otherwise
- `(ticker_or_symbol, venue_or_exchange, quote_currency)` as composite identity.

Provider-specific symbols are aliases mapped to the canonical key and are never
the sole long-term identity anchor.

#### Position

Derived quantity held for `(entity, account, instrument)` at a point in time.
Position quantity is computed from lot movements and corporate actions.

#### Lot

A lot represents a quantity acquired at a specific acquisition event with:
- acquired quantity,
- acquisition unit cost,
- acquisition date/time,
- acquisition currency,
- remaining quantity.

Disposals consume lots according to configured lot-relief policy.

### 2.1 Corporate Actions

Corporate actions are represented as event-sourced transformations, not manual
position rewrites:

- **Split / reverse split:** represented as quantity/ratio adjustment events
  that transform existing lot quantities and per-unit basis while preserving
  total lot cost basis.
- **Dividend reinvestment (DRIP):** represented as dividend income event plus
  reinvestment acquisition event that creates a new lot (or lot increment by
  policy).
- **Spin-off:** represented as parent-asset adjustment plus child-instrument lot
  creation with explicit cost-basis allocation rule.

All corporate actions must remain traceable to ledger-linked event references.

### 3. Cost Basis and Gain Rules

Default lot relief policy is explicit and configurable per entity/account:
- FIFO (default)
- Specific identification (when provided)

Derived measures:
- **Realized gain/loss:** recognized on disposal from disposed lot cost basis.
- **Unrealized gain/loss:** mark-to-market difference between current valuation
  and remaining lot basis.

Both must include conversion context when report currency differs from lot or
instrument market currency.

### 4. Price History Model

Price history is maintained as append-only time series by instrument and price
source. It is non-authoritative relative to ledger facts.

Valuation requests select:
- pricing date/time policy,
- price source policy,
- FX policy (from ADR-0012).

Missing price data results in explicit partial/unavailable valuation outcomes.

### 5. Relationship to Ledger and FX

1. Every investment event must map to transaction/posting facts.
2. Holdings are derived from those events; no independent mutable position truth.
3. FX conversion for basis/gains/valuations uses explicit lookup strategy and
   rate type selection.
4. Tax-related gains may create immutable tax snapshots (ADR-0012).

## Rationale

This design preserves auditability while enabling sophisticated portfolio
analytics. It avoids the common anti-pattern of storing mutable "current
positions" as authoritative facts divorced from event history.

## Consequences

### Positive

- Clean separation between accounting events and valuation analytics.
- Reproducible realized gain calculations via explicit lot logic.
- Consistent integration with existing FX/tax snapshot architecture.
- Extensible to new instrument classes and market data providers.

### Negative / Trade-offs

- Derived holdings and gain pipelines add computational complexity.
- Lot relief policy choices create user-facing complexity.
- Valuations depend on price/FX data coverage quality.

### Mitigations

- Persist derived snapshots for performance but keep them recomputable.
- Expose lot relief policy and valuation metadata in reports.
- Surface missing-price/missing-rate states explicitly to users.

## Implementation Notes

- Represent investment cash/fees/dividends as normal ledger postings.
- Keep lot and position derivation deterministic from ledger event history.
- Keep price history append-only and source-attributed.
- Ensure valuation outputs carry metadata: price source, rate type, as-of time.
