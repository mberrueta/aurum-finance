# Domain Model

Core domain entities and relationships for AurumFinance.

## Status

Draft with baseline constraints.

## Modeling principles

- Ledger-style double-entry is the internal source of truth.
- User-facing workflows remain personal-finance oriented (expense, income, transfer, card purchase, card payment).
- Imported statement data is modeled as immutable facts.
- Classification metadata is mutable and correctable by rules and users.
- Classification manual overrides must be preserved across re-runs.
- All financial events remain traceable from source import to final classification.

## Core bounded areas

- Ledger and postings invariants.
- Ingestion and normalization.
- Rule groups and classification outcomes.
- Reconciliation state and evidence trail.
- FX/rates and tax snapshots.
- Reporting and projection derived from historical actuals.

## Multi-jurisdiction and FX constraints

- Jurisdictions are extensible and not hardcoded to one country.
- Currency pairs support multiple named rate series by jurisdiction and purpose.
- Fiscal residency determines default tax-relevant conversion series.
- Tax-relevant conversion snapshots are immutable once attached to events.
- Original amounts/currencies are always stored; conversions are read-time derivations.
