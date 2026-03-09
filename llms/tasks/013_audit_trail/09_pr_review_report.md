# Audit Trail PR Review Report

**Branch**: `feat/audit-model` vs `main`
**Reviewer**: Staff-level Elixir PR reviewer (agent: audit-pr-elixir)
**Date**: 2026-03-09
**Diff stats**: 51 files changed, +6349 / -505

---

## Overall Assessment: APPROVE

This is a well-executed, production-quality audit trail implementation. The code is clean, the architecture follows the plan precisely, the test suite is comprehensive and deterministic, and all quality gates pass. No blockers or must-fix issues were found.

---

## Summary

- Replaces the non-atomic `with_event/3` and direct `log_event/1` APIs with three atomic helpers (`insert_and_log/2`, `update_and_log/3`, `archive_and_log/3`) and a Multi helper (`Audit.Multi.append_event/4`).
- Adds database-level immutability enforcement via Postgres triggers for `audit_events` (append-only), `postings` (append-only), and `transactions` (protected facts with set-once `voided_at`).
- Extends `list_audit_events/1` with date-range filters (`occurred_after`, `occurred_before`) and offset-based pagination.
- Introduces a read-only `/audit-log` LiveView with filters for entity type, action, channel, owner entity, and date presets. Expandable rows show before/after snapshots.
- Extracts a shared `FilterQuery` module for the compact `?q=key:value` URL filter format, adopted by the audit log and existing LiveViews.
- 199 tests pass with 0 failures and 0 warnings. Dialyzer, Credo, and formatter all pass clean.

## Risk Assessment: LOW

- This is a green-field feature addition with no breaking changes to existing user-facing behavior.
- The `with_event/3` removal is a breaking API change, but it is fully contained within this branch and all callers are migrated.
- The Postgres triggers are irreversible by design but the migration includes a clean `down/0` path.
- The only raw SQL is in triggers (migration) and raw SQL tests -- both are correct and well-scoped.

---

## Strengths

1. **Atomic guarantees are real and tested.** Every audited write path uses `Repo.transaction/1` internally. Tests verify rollback on both domain failure and audit failure with actual database assertions (not just changeset checks).

2. **DB-level immutability is solid.** The three Postgres triggers (audit_events, postings, transactions) are well-crafted. The transactions trigger correctly uses allowlist semantics (only `voided_at` and `correlation_id` may change) and enforces set-once for `voided_at`. The test suite validates all of this via raw SQL.

3. **Clean API design.** Domain contexts (`Entities`, `Ledger`) have zero boilerplate -- each write function is a single call to an Audit helper. The `meta` map pattern is consistent and well-typed. The `serializer` function allows domain-specific snapshot control without coupling the Audit module to domain schemas.

4. **Redaction is enforced at the right boundary.** Redaction happens inside the Audit helpers, not in callers. The `redact_fields` meta key pattern is consistent across both `Entities` and `Ledger`. The recursive `do_redact/2` handles nested maps and preserves key names.

5. **LiveView follows existing patterns.** The `AuditLogLive` uses URL-driven state via `handle_params`, `push_patch`, and the shared `FilterQuery` module. Input validation is thorough (UUID validation for entity IDs, channel allowlisting, date preset normalization). No write actions exist in the template.

6. **Comprehensive test coverage.** 49 named scenarios (S01-S49) cover schema validation, helper API success/failure/rollback, Multi flows, raw SQL immutability enforcement, caller migration verification, LiveView mount/filter/pagination/empty states/read-only invariant, and URL hydration. Tests are deterministic (unique names via `System.unique_integer`).

7. **Good gettext coverage.** Every user-visible string in the audit log view uses `dgettext("audit_log", ...)`. The PO/POT files are complete and translations are present for English.

---

## Issues Found

### BLOCKER

None.

### MAJOR

None.

### MINOR

**M1: `Jason.encode!/1` in `pretty_snapshot/2` could raise on unusual data**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/audit_log_live.ex`, line 312, `defp pretty_snapshot/1`
- **Why it matters**: If an audit event has a `before` or `after` snapshot containing non-JSON-serializable data (e.g., an invalid UTF-8 binary from a future bug), `Jason.encode!/1` would raise and crash the LiveView process. Since this is a read path on data already persisted, a crash here is disproportionate.
- **Suggested fix**: Wrap in a try/rescue or use `Jason.encode/2` with a fallback to `inspect/1`. Low urgency since all current write paths produce clean maps, but worth hardening defensively.

**M2: `owner_entity_id` filter uses JSON path extraction without index support**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/audit.ex`, lines 429-441, `filter_query/2` for `:owner_entity_id`
- **Why it matters**: The `COALESCE((?->>'entity_id'), (?->>'entity_id'))` fragment scans the `before` and `after` JSONB columns for every row. There is no GIN index on these columns. As the audit log grows, this filter will become slow.
- **Suggested fix**: For v1 with a small dataset this is acceptable. When the table grows past ~10k rows, consider adding a GIN index on `after` or extracting `owner_entity_id` as a materialized column. Document this as a known performance limitation.

**M3: `Entities.list_entities()` called on every `handle_params` invocation**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance_web/live/audit_log_live.ex`, line 37
- **Why it matters**: Every filter change or pagination triggers `handle_params`, which calls both `Entities.list_entities()` and `Audit.distinct_entity_types()` to populate dropdown options. These rarely change during a session. In a self-hosted single-user app with a small entity count this is negligible, but it is unnecessary work.
- **Suggested fix**: Move entity and entity-type-option loading to `mount/3` and only reload them when the LiveView mounts. The event list loading in `handle_params` is correct and should stay. Low priority.

### NITS

**N1: Unused `require Logger` in `audit.ex`**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/audit.ex`, line 21
- **Why it matters**: `Logger` is required but never used in the module. Credo did not flag it, but it is dead code.
- **Suggested fix**: Remove `require Logger` unless structured audit logging is planned for a near-term follow-up.

**N2: The `entity_snapshot/1` function is duplicated across test files and production code**

- **Where**: `test/aurum_finance/audit_test.exs`, `test/aurum_finance/audit/multi_test.exs`, `lib/aurum_finance/entities.ex`
- **Why it matters**: The same entity snapshot shape is defined in three places. If the Entity schema gains a field, all three must be updated.
- **Suggested fix**: Consider extracting a shared test helper or using the production `entity_snapshot/1` in tests via a test-only export. Not blocking -- the duplication is small and intentional for test isolation.

**N3: `filter_management_group/2` in `ledger.ex` appears unused after refactor**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex`, lines 645-655
- **Why it matters**: The private `filter_management_group/2` function is still called from `filter_query/2` at line 677, so it is actually used. Ignore -- upon re-reading, this is correct.

**N4: `insert_transaction/2` in `ledger.ex` appears to be dead code**

- **Where**: `/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex`, lines 915-919
- **Why it matters**: `insert_transaction/2` uses `Repo.insert` directly. It is called only from `insert_reversal_transaction/2` (line 955). The main creation path uses `persist_transaction/2` which uses `Ecto.Multi`. This is pre-existing code, not introduced by this PR, but worth noting.

---

## Security Findings Status

| Finding ID | Status | Notes |
|-----------|--------|-------|
| SEC-001 (Redaction bypass via raw public insert) | **Mitigated** | `insert_audit_event/1` is private. All public paths go through redaction-aware helpers. Verified: no `create_audit_event` public function exists. |
| SEC-002 (Metadata not redacted) | **Accepted risk** | Documented in code comments and plan. No sensitive data stored in metadata in v1. Future enhancement tracked. |
| SEC-003 (Dynamic atom interpolation in Multi) | **Mitigated** | `Audit.Multi.append_event/4` uses `{:audit, step_name}` tuple key. No dynamic atom creation. |

All three security findings from Task 08 are resolved or explicitly accepted with documented rationale.

---

## Checklist Compliance

### Constitution Rules

| Rule | Status | Evidence |
|------|--------|----------|
| Tests for executable logic changes | PASS | 199 tests, 0 failures. Coverage spans schema, context, Multi, LiveView, immutability. |
| `mix test` zero warnings/errors | PASS | Clean run, 0 failures, no warnings. |
| `mix precommit` passes | PASS | Dialyzer 0 errors, Credo no issues, formatter clean. |
| Context `list_*` with `opts` keyword list | PASS | `list_audit_events/1` accepts opts. |
| `filter_query/2` multi-clause pattern matching | PASS | Both `Audit` and `Entities` use the pattern. |
| `{:ok, _}` / `{:error, _}` return tuples | PASS | All write functions return standard tuples. |
| Web layer calls through contexts | PASS | `AuditLogLive` calls `Audit.list_audit_events/1` and `Audit.distinct_entity_types/0`. |
| `@required` / `@optional` / `changeset/2` pattern | PASS | `AuditEvent` declares both and casts from them. |
| Validation messages use `dgettext("errors", ...)` | PASS | All changeset validations use gettext. |
| HEEx uses `{}` interpolation, `:if`/`:for` attrs | PASS | Template verified -- no `<%= %>` blocks. |
| No secrets hardcoded | PASS | No credentials, salts, or tokens in source. |
| No debug prints | PASS | No `IO.inspect`, `IO.puts`, or `dbg` calls. |
| Migration reversible | PASS | `down/0` drops all triggers and reverts schema changes. |
| `@doc` on public functions | PASS | All public functions in `Audit`, `Audit.Multi`, `FilterQuery` have `@doc`. |
| `@spec` on public functions | PASS | Specs present on all public functions. |

### Acceptance Criteria (Task 09)

| Criterion | Status |
|-----------|--------|
| Design decisions D1-D9 correctly implemented | PASS |
| `with_event/3` and `log_event/1` fully removed | PASS -- zero references in `lib/` |
| All audited domain writes produce atomic audit events | PASS |
| Append-only enforcement (trigger + no app-level update/delete) | PASS |
| Redaction applied inside Audit helpers | PASS |
| Date-range and offset filters work correctly | PASS -- tested in S22-S24 |
| `distinct_entity_types/0` returns correct data | PASS -- tested in S25 |
| No N+1 queries | PASS -- single query per page load |
| Pagination prevents unbounded result sets | PASS -- `@page_size + 1` fetch pattern |
| LiveView tests cover mount, filters, pagination, empty states, read-only invariant | PASS -- S35-S49 |
| No dead code from migration | PASS (minor: `insert_transaction/2` is pre-existing) |

---

## Test Coverage Notes

**Covered well:**
- Schema changeset validation (S01-S05)
- Helper API success, domain failure, audit failure paths (S06-S12)
- Multi append_event success, prior-step failure, audit failure paths (S13-S15, S26-S34)
- Raw SQL immutability enforcement for all three tables (S16-S19)
- Legacy API removal verification (S20)
- Caller migration correctness (S21)
- Query filter and pagination correctness (S22-S25)
- LiveView mount, auth, filtering, URL hydration, pagination, expandable rows, empty states, read-only invariant (S35-S49)

**Suggested additions (not blocking):**
- A test verifying that the `metadata` field round-trips correctly through `insert_and_log` (currently tested in S06 and S13 but only for a simple map -- a nested metadata map test would add confidence).
- A test for the `default_snapshot/1` function with nested struct handling (e.g., a struct containing a DateTime, a Decimal, and a nested struct).
- An integration test that exercises `Ledger.archive_account/2` and verifies the audit event has `institution_account_ref` redacted.

## Observability Notes

- No structured logging was added for audit events. This is acceptable for v1 since the audit events table itself serves as the observability layer.
- The `require Logger` in `audit.ex` suggests logging was considered but not implemented. If structured logging for audit operations is desired (e.g., for alerting on audit failures), it can be added in a follow-up.
- No telemetry events are emitted. For a self-hosted single-user app this is fine. If monitoring audit append latency becomes important, adding `Telemetry.execute` around the transaction would be the right approach.

---

## Suggested PR Description

```markdown
## Summary

Completes the audit trail feature (Issue #13): hardened foundation, atomic write helpers, database-level immutability, and a read-only audit log viewer.

### Changes

- **Schema**: Added `metadata` map column to `audit_events`; removed `updated_at` (append-only tables do not update).
- **Immutability**: Postgres triggers enforce append-only on `audit_events` and `postings`; protected-fact semantics on `transactions` (set-once `voided_at`, immutable fact fields).
- **Context API**: Replaced `with_event/3` and `log_event/1` with `insert_and_log/2`, `update_and_log/3`, `archive_and_log/3`, and `Audit.Multi.append_event/4`. All audited writes are now atomic.
- **Filters**: Extended `list_audit_events/1` with `occurred_after`, `occurred_before`, and `offset` support.
- **LiveView**: New `/audit-log` route with filters (entity type, action, channel, owner entity, date presets), expandable before/after snapshot rows, and offset pagination.
- **Shared helper**: Extracted `FilterQuery` module for compact URL filter encoding/decoding, adopted by audit log and existing LiveViews.

### Migration Notes

- Run `mix ecto.migrate` to apply the `20260308120000_harden_audit_events` migration.
- The migration adds Postgres triggers -- `mix ecto.rollback` will drop them cleanly.
- **Breaking**: `Audit.with_event/3` and `Audit.log_event/1` are removed. All callers migrated.

### Test Plan

- 199 tests, 0 failures
- `mix precommit` passes (Dialyzer, Credo, formatter, Sobelow)
- Schema tests: S01-S05
- Helper API tests: S06-S15
- Multi tests: S26-S34
- Immutability tests: S16-S19
- Caller migration tests: S20-S21
- Query tests: S22-S25
- LiveView tests: S35-S49
```

---

## Merge Recommendation: APPROVE

This is a high-quality feature implementation with strong test coverage, correct atomicity guarantees, database-level immutability enforcement, and clean architecture. The minor issues identified (M1-M3, N1-N2) are all low-risk and can be addressed in follow-up work without blocking the merge.
