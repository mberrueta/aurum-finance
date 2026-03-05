# ADR 0005: Multi-Jurisdiction FX Model with Named Rate Series and Immutable Tax Snapshots

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

AurumFinance is designed for users with financial accounts and obligations spanning
multiple countries and currencies. Users may hold accounts in different countries
while being fiscally resident in another — each jurisdiction has its own official
exchange rate conventions and tax reporting authorities.

e.g. a person paying taxes in Chile who has investment accounts in Peru.

Existing tools handle this inadequately:
- Actual Budget has no multi-currency support at all.
- Firefly III supports multi-currency but not multiple named rate series per pair.
- GnuCash's Trading Accounts model handles ledger balance across currencies correctly,
  but does not model jurisdiction-specific rate types or fiscal residency.

## Decision Drivers

1. A single currency pair can have multiple simultaneous, legally distinct rates
   (e.g., an official tax authority rate, a market rate, a parallel market rate)
   — the system must support all of them.
2. Tax-relevant conversions must use the legally mandated rate for the user's fiscal residency.
3. Tax-relevant rate snapshots must be immutable once recorded — retroactive rate updates
   must not modify historical tax events.
4. Fiscal residency determines tax rate defaults and is independent of where accounts are held.
5. The model must be extensible to any jurisdiction and rate type without schema changes.

## Decision

### Core ledger rule

Every posting carries its **original currency and original amount** — immutable, same
as transaction facts. Converted values are **always derived on read**, never stored as
the source of truth.

### Named rate series per currency pair

A currency pair supports **N named rate types**, each scoped to a jurisdiction and purpose:

| Rate type (illustrative) | Jurisdiction | Purpose | Source |
|---|---|---|---|
| `official_tax` | any | Official tax authority rate for reporting | Central bank / tax authority |
| `market` | any | Market or interbank rate | Exchange / broker data |
| `parallel` | any | Parallel or informal market rate (reference only) | Informal trackers |
| `crypto` | any | Crypto/stablecoin rate on exchanges (reference only) | Exchange APIs |

e.g. for a user paying taxes in Chile: `sii_official` (CLP/USD, Servicio de Impuestos Internos reference).
e.g. for a user paying taxes in Peru: `sunat_official` (PEN/USD, SUNAT reference rate).

This list is **illustrative**. The data model must support arbitrary named rate types
per currency pair per jurisdiction — not a hardcoded enum. New jurisdictions and rate
types must be addable without schema changes.

### Fiscal residency — tax rate defaults

Each user configures a **country of fiscal residency**. This drives which rate type
is used by default for tax-relevant event snapshots:

| Fiscal residency | Default tax rate type | Authority |
|---|---|---|
| any country | user-configured `official_tax` rate for that jurisdiction | Local tax authority |

e.g. a user paying taxes in Chile configures `sii_official` as their default tax rate type.
e.g. a user paying taxes in Peru configures `sunat_official` as their default tax rate type.

The mapping from fiscal residency to default rate type is **user-configurable** — there
is no hardcoded list of countries or rate types.

**Fiscal residency ≠ where accounts are held.** A user paying taxes in Chile with
investment accounts in Peru has fiscal residency in Chile. All tax snapshots default
to the Chilean official rate regardless of which country the account is in. This is
non-negotiable for correct multi-jurisdiction tax tracking.

### Immutable tax snapshots

For any tax-relevant event (asset sale, dividend, income, FX gain):
- The fiscal-residency rate at the time of the event is recorded as an immutable snapshot.
- The event is flagged as tax-relevant with the rate snapshot used.
- This snapshot is **never retroactively modified** even if the rate series is updated later.

### FX transaction recording

Every cross-currency transaction records:
- Source amount + source currency (immutable)
- Target amount + target currency (immutable)
- Rate type used (e.g., `official_tax`, `market`, or any user-defined rate type name)
- Rate value at time of transaction
- Rate source and timestamp

### Reporting views

Users choose which rate type to use as the display base for any report or portfolio view:
- *"Show my net worth in USD at market rate"*
- *"Show my tax liability in local currency at official tax rate"*
- *"Show monthly expenses in my home currency"*

The system converts on read using the selected rate type and date. The ledger stores originals only.

## Rationale

GnuCash's Trading Accounts model is the strongest available reference for maintaining
ledger balance invariants across currencies. AurumFinance extends that foundation with
jurisdiction-aware named rate series and fiscal-residency-driven tax defaults — concerns
that GnuCash does not address.

The real-world cases that must work without hacks:
- CLP ↔ USD at official tax rate (tax events for a Chile-resident user)
- PEN ↔ USD at market rate (investment transactions for a Peru account)
- Positions in a foreign broker, viewed from the user's fiscal residency rate
- Multi-broker positions across different countries in different currencies
- Portfolio valuation in any named rate type at any historical date
- A single user with accounts in multiple countries and fiscal residency in another
  (e.g. pays taxes in Chile, has investments in Peru and accounts in a third country)

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
- **Superseded by ADR-0009:** Fiscal residency (`fiscal_residency_country_code`) and default tax rate type (`default_tax_rate_type`) are columns on the `Entity` table, not on a user profile. There is no user profile in AurumFinance — authentication is a root password guard at the edge.
