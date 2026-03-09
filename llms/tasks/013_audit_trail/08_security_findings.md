# Audit Trail Security Findings

## Scope

Reviewed the v1 audit trail implementation with emphasis on:
- redaction enforcement in `AurumFinance.Audit`
- append-only / immutability guarantees for `audit_events`, `postings`, and `transactions`
- route and LiveView access control for `/audit-log`
- filter input validation and query safety
- snapshot / metadata data leakage risks
- Sobelow results relevant to audit trail code

Assumptions:
- Single-user self-hosted deployment with root-authenticated access is the intended trust model.
- Findings below are limited to the current branch implementation and current production call sites.

## Threat Model Snapshot

- Actors:
  - unauthenticated external users
  - authenticated root user
  - trusted internal application code paths
  - future internal developers adding new audit call sites
- Sensitive assets:
  - tax identifiers
  - institution account references
  - immutable ledger facts
  - operational provenance in `audit_events`
- Entry points:
  - `/audit-log` LiveView
  - audit helper APIs in `AurumFinance.Audit`
  - `Audit.Multi.append_event/4`
  - DB trigger enforcement on `audit_events`, `postings`, and `transactions`

## Findings Table

| ID | Severity | Category | Location | Risk | Evidence | Recommendation | Status |
|---|---|---|---|---|---|---|---|
| SEC-001 | Medium | Redaction | `lib/aurum_finance/audit.ex` | A future production caller could have bypassed snapshot redaction by calling a raw public insert helper directly with raw `before` / `after` data, irreversibly storing PII in append-only audit rows. | The original review found a public `Audit.create_audit_event/1`. The helper has since been removed from the public API and replaced with an internal private insert path used only by safe helpers. | Keep raw audit insertion internal-only and continue routing app code through `insert_and_log/2`, `update_and_log/3`, and `Audit.Multi.append_event/4`. | Mitigated |
| SEC-002 | Low | Data Leakage | `lib/aurum_finance/audit.ex`, `lib/aurum_finance/audit/multi.ex`, `llms/tasks/013_audit_trail/plan.md` | The `metadata` field is an unrestricted map and is stored without redaction. A future caller could persist secrets, tokens, or sensitive provenance accidentally. | `build_audit_attrs/5` and `Audit.Multi.append_event/4` copy `meta[:metadata]` directly into `audit_events`. The code and docs now explicitly warn that metadata is non-sensitive only, but there is still no enforcement. | Define a metadata allowlist/schema per audit domain, or add metadata redaction rules parallel to snapshot redaction. The current documentation-only guard is appropriate for v1 but should not be the final state once more audit domains adopt metadata. | Accepted Risk |
| SEC-003 | Low | Supply Chain / DOS | `lib/aurum_finance/audit/multi.ex` | `Audit.Multi.append_event/4` previously created a new atom with `:"audit_#{step_name}"`, which Sobelow flagged as unsafe atom interpolation. | The helper now uses a structured non-atom key `{:audit, step_name}` instead of creating dynamic atoms. | Keep the tuple-based key and avoid reintroducing dynamic atom interpolation in future Multi helpers. | Mitigated |

## Recommended Remediations

1. Treat `metadata` as a constrained field, not a free-form bag. The current warning text is a good v1 guardrail, but enforcement should follow before more audit domains start using metadata.
2. Keep the raw audit insert path internal-only so redaction bypass does not reappear through future API expansion.
3. Keep structured tuple step keys in `Audit.Multi` and avoid any future dynamic atom interpolation.

## Secure-by-Default Checklist

- Redaction in helper path: passed
  - `Audit.insert_and_log/2`, `Audit.update_and_log/3`, and `Audit.Multi.append_event/4` redact snapshots internally.
  - Known redact fields are declared in the right contexts:
    - `Entities`: `[:tax_identifier]`
    - `Ledger` accounts: `[:institution_account_ref]`
- Redacted marker consistency: passed
  - Redacted values are stored as `"[REDACTED]"`.
- DB immutability: passed
  - `audit_events_append_only`, `postings_append_only`, and `transactions_immutability` are defined in [20260308120000_harden_audit_events.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/repo/migrations/20260308120000_harden_audit_events.exs).
  - Raw SQL tests verify UPDATE/DELETE blocking and the `voided_at` lifecycle allowlist.
- Access control: passed
  - `/audit-log` is inside the authenticated browser scope and `:app` live session in [router.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/router.ex).
  - [auth_protection_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance_web/live/auth_protection_test.exs) includes `/audit-log`.
  - No write actions are exposed by `AuditLogLive`.
- Input validation / query safety: passed with minor hardening opportunity
  - `owner_entity_id` is UUID-validated in `AuditLogLive`.
  - `channel` and `date_preset` are normalized to allowlisted values.
  - Queries are parameterized Ecto queries; no SQL injection path was found.
  - `entity_type` and `action` are not explicitly allowlisted, but they remain parameterized equality filters, so this is not currently an injection issue.
- Scope reduction alignment: passed
  - No default audit events are generated for normal `transaction` or `posting` creation.
  - Transaction void actions remain audited.

## Sobelow Notes

- Relevant audit-trail finding:
  - `DOS.BinToAtom` in `lib/aurum_finance/audit/multi.ex` was mitigated by replacing dynamic atom interpolation with a tuple key
- Unrelated app-wide finding still present:
  - `Config.CSP: Missing Content-Security-Policy` in `lib/aurum_finance_web/router.ex`
  - This is broader than the audit trail feature and should be tracked separately.

## Out-of-Scope / Follow-ups

- No review was done for future audit domains not yet implemented in this branch, such as imports, rules, settings, or classification override provenance.
- No runtime pen-test or browser automation was needed because the viewer is read-only and the route/auth wiring is straightforward in the current implementation.
- If the app later introduces multi-user roles or exposes audit data through JSON APIs, access-control review should be repeated with tenant/role boundaries in scope.
