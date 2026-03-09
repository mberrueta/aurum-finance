# Privacy

Privacy boundaries, PII handling, retention, and redaction policies.

## Status

Living document for the current self-hosted single-user implementation.

## Data classes handled by the app

- Operational metadata: entity names, account names, internal labels.
- Financial-sensitive data: transaction descriptions, amounts, balances, and
  institution metadata.
- Regulated-sensitive data: tax identifiers, tax snapshots, and imported raw
  statement artifacts.

## Current privacy posture

- AurumFinance is self-hosted and assumes the operator controls the host,
  database, backups, and runtime secrets.
- The application minimizes unnecessary duplication of sensitive values in audit
  records by redacting selected snapshot fields before persistence.
- The current audit trail is operational, not exhaustive. It records meaningful
  administrative/manual actions rather than every ledger fact insert.

## Audit trail and redaction

The current audit implementation stores full `before` / `after` snapshots for
audited records, with targeted redaction applied before insert.

Current shipped redactions:

- `Entity.tax_identifier`
- `Account.institution_account_ref`

Redacted values are persisted as `\"[REDACTED]\"`.

`audit_events.metadata` is different:

- metadata is not redacted today
- metadata must contain non-sensitive values only
- do not place secrets, tokens, tax IDs, account refs, or similar data there

Future work may add metadata allowlisting or key-level redaction, but that is
not implemented in the current branch.

## Imported artifacts and evidence

- Imported raw files and row payloads are treated as high-sensitivity evidence.
- They should be retained only as needed for traceability and operator workflows.
- Support exports or debugging workflows should prefer redacted or normalized
  forms over raw artifacts whenever possible.

## Audit scope vs ledger immutability

Two different protections exist:

- audit trail: operational traceability for selected lifecycle/manual actions
- ledger immutability: database protections that prevent mutation of
  `postings`, restrict `transactions`, and keep `audit_events` append-only

This means normal `transaction` and `posting` creation are protected for
correctness even when they do not produce audit rows.
