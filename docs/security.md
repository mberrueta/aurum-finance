# Security

Security posture, threat model, controls, and secure development practices.

## Authentication Model

AurumFinance is designed primarily as a **self-hosted, single-operator system**.

The application uses a minimal authentication layer consisting of:

- a single root password
- stored as a bcrypt hash (`AURUM_ROOT_PASSWORD_HASH`)
- session-based authentication using Phoenix signed cookies

This mechanism exists to prevent **unauthorized access from the network**.

### What this protects against

- anonymous access from the internet
- access from other machines on the local network
- accidental exposure of the application endpoint
- opportunistic scanning or indexing

### What this does NOT protect against

This authentication model does **not** protect against operators with host-level access.

Examples:

- a user with root access to the server
- anyone who can read or modify environment variables
- anyone who can modify the Docker configuration or runtime
- anyone with direct access to the database

This limitation is **intentional**.

AurumFinance assumes the operator controls the host environment.

## Design Philosophy

Security mechanisms in AurumFinance prioritize:

- preventing accidental exposure
- protecting network boundaries
- maintaining simplicity appropriate for a self-hosted system

This avoids introducing unnecessary complexity such as:

- multi-user identity systems
- external identity providers
- role-based access control

## Audit Trail Security Posture

The audit trail is implemented as an operational traceability layer, not as a
raw ledger-insert feed.

Current shipped audit scope includes:

- entity lifecycle changes
- account lifecycle changes
- transaction void actions

Current shipped audit scope does not include:

- normal transaction creation
- posting creation

This is intentional. Auditability and ledger correctness are separate controls.

## Immutability Controls

The branch enforces several protections at the database level:

- `audit_events` is append-only
- `postings` is append-only
- `transactions` keep core fact fields immutable and allow only the set-once
  `voided_at` lifecycle marker

These constraints protect ledger correctness even when a given operation does
not emit an `audit_events` row.

## Snapshot Redaction

Audit helpers apply snapshot redaction before insert. Current redacted fields:

- `Entity.tax_identifier`
- `Account.institution_account_ref`

Redacted values are stored as `\"[REDACTED]\"` inside audit snapshots.

## Metadata Rule

`audit_events.metadata` is intentionally free-form in v1, but it is not
redacted.

Do not store:

- secrets
- tokens
- tax IDs
- institution account references
- other sensitive identifiers

The current rule is documentation and code-comment enforced. Metadata
allowlisting/redaction remains future work.

## Audit Log Access

`/audit-log` is a root-authenticated LiveView inside the normal browser
session. The viewer is read-only:

- no write actions are exposed
- filters are parameterized and validated
- entity filtering is user-facing by entity name, while URLs continue to use
  the entity UUID internally

## Residual Risks

- Operators with host or direct database access remain trusted by design.
- Metadata sensitivity still relies on caller discipline in v1.
- A missing site-wide Content Security Policy remains an app-wide hardening gap
  outside the audit trail scope.
