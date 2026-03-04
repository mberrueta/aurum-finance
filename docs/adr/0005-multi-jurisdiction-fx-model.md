# ADR 0005: Multi-Jurisdiction FX Model with Named Rate Series and Immutable Tax Snapshots

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

AurumFinance is designed for users with financial accounts and obligations spanning
multiple countries and currencies. A common target case is a user living in Brazil
with accounts in Argentina and the United States — each jurisdiction has its own
official exchange rate conventions and tax reporting authorities.

Existing tools handle this inadequately:
- Actual Budget has no multi-currency support at all.
- Firefly III supports multi-currency but not multiple named rate series per pair.
- GnuCash's Trading Accounts model handles ledger balance across currencies correctly,
  but does not model jurisdiction-specific rate types or fiscal residency.

## Decision Drivers

1. A single currency pair (e.g., ARS/USD) has multiple simultaneous, legally distinct
   rates (official AFIP rate, MEP, CCL, blue) — the system must support all of them.
2. Tax-relevant conversions must use the legally mandated rate for the user's fiscal residency.
3. Tax-relevant rate snapshots must be immutable once recorded — retroactive rate updates
   must not modify historical tax events.
4. Fiscal residency determines tax rate defaults and is independent of where accounts are held.
5. The model must be extensible to new jurisdictions and rate types without schema changes.

## Decision

### Core ledger rule

Every posting carries its **original currency and original amount** — immutable, same
as transaction facts. Converted values are **always derived on read**, never stored as
the source of truth.

### Named rate series per currency pair

A currency pair supports **N named rate types**, each scoped to a jurisdiction and purpose:

| Rate type | Jurisdiction | Purpose | Source |
|---|---|---|---|
| `ptax` | 🇧🇷 Brazil | Tax reporting — Receita Federal reference rate | Banco Central do Brasil |
| `official_afip` | 🇦🇷 Argentina | Tax reporting — AFIP/ARCA legal rate | AFIP/ARCA published rates |
| `mep` | 🇦🇷 Argentina | Market rate via AL30/GD30 bond arbitrage | Exchange / broker data |
| `ccl` | 🇦🇷 Argentina | Contado con liquidación — offshore rate | Exchange / broker data |
| `blue` | 🇦🇷 Argentina | Informal parallel market (reference only) | Informal trackers |
| `irs_yearly` | 🇺🇸 USA | IRS yearly average rate for FBAR/FATCA | IRS published tables |
| `crypto` | any | USDT/fiat rate on exchanges (reference only) | Exchange APIs |

This list is **illustrative**. The data model must support arbitrary named rate types
per currency pair per jurisdiction — not a hardcoded enum. New jurisdictions and rate
types must be addable without schema changes.

### Fiscal residency — tax rate defaults

Each user configures a **country of fiscal residency**. This drives which rate type
is used by default for tax-relevant event snapshots:

| Fiscal residency | Default tax rate type | Authority |
|---|---|---|
| 🇧🇷 Brazil | `ptax` | Receita Federal |
| 🇦🇷 Argentina | `official_afip` | AFIP / ARCA |
| 🇺🇸 USA | `irs_yearly` | IRS |
| other | user-configurable | — |

**Fiscal residency ≠ where accounts are held.** A user living in Brazil with accounts
in Argentina and the US has fiscal residency in Brazil. All tax snapshots default to
PTAX regardless of which country the account is in. This is non-negotiable for
correct multi-jurisdiction tax tracking.

### Immutable tax snapshots

For any tax-relevant event (asset sale, dividend, income, FX gain):
- The fiscal-residency rate at the time of the event is recorded as an immutable snapshot.
- The event is flagged as tax-relevant with the rate snapshot used.
- This snapshot is **never retroactively modified** even if the rate series is updated later.

### FX transaction recording

Every cross-currency transaction records:
- Source amount + source currency (immutable)
- Target amount + target currency (immutable)
- Rate type used (e.g., `official_afip`, `mep`, `ptax`)
- Rate value at time of transaction
- Rate source and timestamp

### Reporting views

Users choose which rate type to use as the display base for any report or portfolio view:
- *"Show my net worth in USD MEP"*
- *"Show my tax liability in USD AFIP"*
- *"Show monthly expenses in ARS"*

The system converts on read using the selected rate type and date. The ledger stores originals only.

## Rationale

GnuCash's Trading Accounts model is the strongest available reference for maintaining
ledger balance invariants across currencies. AurumFinance extends that foundation with
jurisdiction-aware named rate series and fiscal-residency-driven tax defaults — concerns
that GnuCash does not address.

The real-world cases that must work without hacks:
- BRL ↔ USD at PTAX rate (Receita Federal tax events for a Brazil resident)
- ARS ↔ USD at official AFIP rate (tax events for Argentina resident)
- ARS ↔ USD at MEP or CCL rate (investment transactions)
- USD positions in a US broker, viewed from a Brazil fiscal residency (PTAX conversion)
- Multi-broker positions across BR/AR/US in different currencies
- Portfolio valuation in any named rate type at any historical date
- A single user with accounts in 3 countries and fiscal residency in a 4th

## Consequences

### Positive
- Any jurisdiction and rate type can be added without schema changes.
- Tax-relevant events carry legally defensible, immutable rate snapshots.
- Users can view any report in any rate context without data mutation.
- The model is correct for the hardest real-world cases from day one.

### Negative / Trade-offs
- Rate ingestion pipeline must support multiple external sources per pair.
- Reporting queries require a rate-lookup join on read.
- UX must make the active rate type visible and selectable.

### Mitigations
- Rate series are stored as a generic `(currency_pair, rate_type, date, value, source)` table.
- Reporting layer abstracts rate resolution; callers specify rate type and date only.

## Implementation Notes

- `fx_rate_series` table: `(currency_from, currency_to, rate_type, jurisdiction, date, value, source, fetched_at)`.
- `rate_type` is a string key — no enum constraint in schema.
- Tax snapshot columns on tax-relevant events: `tax_rate_type`, `tax_rate_value`, `tax_rate_date`, `tax_rate_source` — write-once.
- User profile carries `fiscal_residency` (country code) and `default_tax_rate_type` (derived or overridden).
