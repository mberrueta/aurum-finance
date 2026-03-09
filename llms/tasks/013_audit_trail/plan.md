# 013 — Audit Trail: Immutable Change Log for All Domain Entities

**GitHub issue**: #13
**Status**: Draft
**Blocked by**: Ledger primitives (resolved — `Ledger` context, `Transaction`, `Posting`, `Account` schemas exist on `feat/transactions-model`)

---

## Goal

Deliver a generic, append-only audit trail that records every domain write across all contexts with full before/after snapshots, redaction of sensitive fields, and a dedicated read-only audit log page. The foundation already exists: the `AurumFinance.Audit` context, `AurumFinance.Audit.AuditEvent` schema, and the `audit_events` table are implemented and wired into both the `Entities` and `Ledger` contexts. This issue completes the remaining work: hardening the existing foundation for production use (atomicity, immutability enforcement, metadata field), adding date-range filtering, and building the dedicated audit log viewer at `/audit-log`.

---

## Why This Matters

1. **Financial regulatory posture** — Personal finance data requires a verifiable record of who changed what and when. Even for a self-hosted tool, an audit trail is the foundation of trust in ledger correctness.
2. **Operational confidence** — When reconciliation discrepancies arise, the audit log is the first diagnostic tool. Without it, debugging requires git-blaming the database.
3. **Privacy accountability** — The audit trail itself must demonstrate that sensitive data (tax identifiers, institution account references) is handled with redaction, proving the system takes privacy seriously.
4. **Automation safety net** — As rules engines, import pipelines, and AI assistants gain write access, the audit trail becomes the safety net that lets the user trust automated changes.

---

## Scope — What IS Included

- Harden the existing `AuditEvent` schema with a `metadata` map field (catch-all for context-specific data that does not belong in `before`/`after`)
- Enforce database-level immutability across all financial fact tables: `audit_events` (append-only), `postings` (append-only), `transactions` (protected facts — DELETE blocked, UPDATE restricted to lifecycle fields `voided_at`/`correlation_id` only, `voided_at` set-once enforced by trigger)
- Replace `Audit.with_event/3` and `Audit.log_event/1` with the new helper API (`insert_and_log`, `update_and_log`, `archive_and_log`, `Audit.Multi.append_event`). All domain writes + audit appends become atomic. All existing callers are migrated — no backward compatibility shim.
- Add date-range filtering to `Audit.list_audit_events/1` (`:occurred_after`, `:occurred_before`)
- Build a minimal, read-only Audit Log viewer as a dedicated `AuditLogLive` accessible at `/audit-log`, with filters for entity_type, action, channel, date range, and optional entity_id
- Document redaction rules and enforce them in the shared `Audit` context

---

## Out of Scope

1. **Replay / undo / rollback from audit log** — The audit log is observational, not operational.
2. **Full-text search across before/after JSON** — Filtering is by structured fields only.
3. **Audit log export (CSV, JSON)** — Deferred to a future issue.
4. **Retention / archival policy** — No TTL or partition strategy in this issue.
5. **Real-time streaming / PubSub of audit events** — Not needed for the viewer.
6. **Per-field diff display in the UI** — The viewer shows raw before/after snapshots; a structured diff view is a future enhancement.
7. **Admin actions (delete audit records, mark as reviewed)** — The log is truly append-only; no admin write path.
8. **LiveView scope creep** — The viewer is a single filtered list. No detail slideover, no charts, no aggregation dashboards.

---

## Project Context

### Related Entities

| Entity | Location | Relevance |
|--------|----------|-----------|
| `AurumFinance.Audit.AuditEvent` | `lib/aurum_finance/audit/audit_event.ex` | The audit event schema — already exists with `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at` |
| `AurumFinance.Audit` | `lib/aurum_finance/audit.ex` | The audit context — **current**: `with_event/3`, `log_event/1`, `list_audit_events/1`, redaction logic, snapshot serialization. **Target**: replaced by `insert_and_log`, `update_and_log`, `archive_and_log`, `Audit.Multi.append_event`. |
| `AurumFinance.Entities.Entity` | `lib/aurum_finance/entities/entity.ex` | Wired to audit via `create_entity/2`, `update_entity/3`, `archive_entity/2`. Redacts `:tax_identifier`. |
| `AurumFinance.Ledger.Account` | `lib/aurum_finance/ledger/account.ex` | Wired to audit. Redacts `:institution_account_ref`. |
| `AurumFinance.Ledger.Transaction` | `lib/aurum_finance/ledger/transaction.ex` | Wired to audit via `create_transaction/2`, `void_transaction/2`. |
| `AurumFinanceWeb.AuditLogLive` | `lib/aurum_finance_web/live/audit_log_live.ex` | **Target** (does not exist yet): dedicated read-only audit log viewer at `/audit-log`. |
| `AurumFinanceWeb.TransactionsLive` | `lib/aurum_finance_web/live/transactions_live.ex` | Reference pattern for URL-driven filtered list views with `handle_params`, `push_patch`, query-string encoding. |

### Audit Infrastructure — Current State vs Target

| Layer | Current state | Target state (this issue) |
|-------|--------------|--------------------------|
| **Schema** | `audit_events` table: `id`, `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`, `inserted_at`, `updated_at` | Same fields minus `updated_at`; plus new `metadata :map` column |
| **Indexes** | `(entity_type, entity_id)`, `(action)`, `(channel)`, `(occurred_at)` | Unchanged |
| **Context API** | `with_event/3` (non-atomic), `log_event/1` (direct insert), `list_audit_events/1` (no date-range filter) | `insert_and_log/2`, `update_and_log/3`, `archive_and_log/3`, `Audit.Multi.append_event/4`; `list_audit_events/1` extended with date-range and offset |
| **Atomicity** | Non-atomic for Entities + Ledger accounts; atomic only for Ledger transaction paths | Atomic for all write paths via helper API |
| **Immutability** | Application-layer only (no update/delete functions) | Enforced at DB level via Postgres triggers: `audit_events` append-only, `postings` append-only, `transactions` protected facts (DELETE blocked, UPDATE restricted to `voided_at`/`correlation_id`) |
| **Redaction** | `redact_snapshot/2` in place; callers pass `redact_fields` | Unchanged — redaction logic stays, wired through the new helpers |
| **Integration points** | `Entities.*` via `with_event/3`; `Ledger.*` via `with_event/3` and `log_event/1` | All callers migrated to new helpers; `with_event/3` and `log_event/1` removed |
| **UI viewer** | None (does not exist) | `AuditLogLive` at `/audit-log` — read-only, filterable |

### Naming Conventions Observed

- Contexts: `AurumFinance.Entities`, `AurumFinance.Ledger`, `AurumFinance.Audit`
- Schemas: `AurumFinance.Entities.Entity`, `AurumFinance.Ledger.Account`, `AurumFinance.Audit.AuditEvent`
- Context functions: `list_*`, `get_*!`, `create_*`, `update_*`, `archive_*`, `change_*`
- Filter pattern: `filter_query/2` with multi-clause pattern matching on keyword list
- LiveViews: `*Live` (e.g., `TransactionsLive`, `SettingsLive`) — flat modules, not directories
- Audit opt type: `{:actor, String.t()} | {:channel, :web | :system | :mcp | :ai_assistant}`

### Permissions Model

- **Roles**: Single-user self-hosted app. Authentication is via `RootAuth` (passphrase-based root access).
- **Pipeline**: All app routes go through `:require_authenticated_root`.
- **Tenant isolation**: Entity-scoped for ledger data (`entity_id` required). Audit events are cross-entity (no entity_id scope on the audit table itself — the `entity_id` field on `AuditEvent` refers to the *audited* record's ID, not a tenant boundary).
- **Audit viewer access**: Root-authenticated users only (same as all app routes).

---

## Design Decisions

### D1: Enhance existing foundation, do not rebuild

The `Audit` context and `AuditEvent` schema already exist with a sound design. This issue hardens and completes them rather than starting over. The schema fields match the issue requirements almost exactly; the gap is in atomicity, immutability enforcement, metadata, and the UI viewer.

### D2: `occurred_at` (not `inserted_at`) as the canonical event timestamp

Already implemented this way. `occurred_at` is set by the caller (defaulting to `DateTime.utc_now()` in `log_event/1`), while `inserted_at` is Ecto's automatic timestamp. This separation matters because: (a) in batch imports or migrations, the event may have occurred at a different time than insertion; (b) `occurred_at` is the business-meaningful timestamp for filtering and display.

### D3: Snapshot-based audit (`before`/`after`) — not diff storage

Already implemented. Full entity snapshots are stored in `before` and `after` rather than a computed diff or a `changes` map because:

- **Easier review and debugging** — each audit record is fully self-contained; reading the log does not require replaying a chain of diffs.
- **More stable semantics over time** — diffs are inherently tied to the schema shape at the time of the write. As schemas evolve (fields added, renamed, removed), stored diffs become ambiguous or unreadable. Full snapshots age more gracefully.
- **Better compliance and audit reading** — an auditor or regulator reading the log can see the complete state before and after a change without any additional context or tooling. This is the expected format for financial audit trails.
- **No reconstruction cost** — the current state of a record does not need to be reconstructed from a diff chain.

**There is no `changes` field and no JSON diff stored.** The canonical fields are `before` (full snapshot of state before the operation, `nil` for inserts) and `after` (full snapshot after the operation, `nil` for hard deletes — soft archives still produce an `after` snapshot).

### D4: Actor as plain string (not structured)

Already implemented. The `actor` field is a plain string (`"system"`, `"person"`, `"scheduler"`). In a single-user self-hosted app, structured actor types (actor_type + actor_id) add complexity without value. If multi-user support is added later, the `actor` field can be migrated to a structured format.

### D5: Channel as enum

Already implemented. `channel` is `Ecto.Enum` with values `[:web, :system, :mcp, :ai_assistant]`. This captures *how* the change was initiated, which is critical for trust in automated pipelines.

### D6: Append-only — definition and scope

**Append-only means:**

- **Insert only** — the only permitted write operation on `audit_events` is `INSERT`.
- **No update path** — there is no `Audit.update_audit_event/2` function, and no changeset that permits updating an existing record.
- **No delete path** — there is no `Audit.delete_audit_event/1` function. Records are never removed, not even by admins.
- **No replay or edit actions in the UI** — the audit log viewer is strictly read-only. It has no "undo", "replay", "restore", "retry", or "annotate" actions.

Append-only is enforced at two layers: the application layer (no update/delete functions exist) and the database layer (see D7).

### D7: Database-level immutability for audit and ledger tables

All financial fact tables are protected at the database level via Postgres triggers. This provides defense-in-depth beyond the application layer and ensures no raw SQL access, migration bug, or future code path can silently corrupt financial history.

| Table | Protection | Allowed writes |
|-------|-----------|----------------|
| `audit_events` | Fully append-only | INSERT only |
| `postings` | Fully append-only | INSERT only |
| `transactions` | Protected facts | INSERT; UPDATE restricted to lifecycle fields only (`voided_at`, `correlation_id`); DELETE blocked |

**`audit_events` and `postings`** use a simple `BEFORE UPDATE OR DELETE` trigger that raises unconditionally.

**`transactions`** use a restricted-update trigger that:
- Blocks DELETE unconditionally
- On UPDATE: rejects any change to fact fields (`entity_id`, `date`, `description`, `source_type`, `inserted_at`)
- On UPDATE: enforces `voided_at` as set-once — once non-NULL it cannot be changed or reversed. This is the DB-level consistency rule: a transaction can be voided (NULL → non-NULL) exactly once.

**Schema note:** `transactions` has no `status` column. Void state is represented entirely by `voided_at` (NULL = active, non-NULL = voided). The set-once trigger replaces what would otherwise be a `status`/`voided_at` CHECK constraint. The application layer further enforces this via `validate_voidable/1` in `Transaction.void_changeset/2`.

### D8: `metadata` field for extensibility

Add a `:map` field for context-specific metadata that does not belong in `before`/`after` snapshots. Examples: correlation IDs, import batch references, rule engine match explanations, request IDs. This avoids polluting the snapshot fields with non-entity data.

### D9: Atomic domain write + audit append via Ecto.Multi

The current `Audit.with_event/3` performs the domain write first, then inserts the audit event as a separate `Repo.insert`. If the audit insert fails, the domain write has already committed. This must be migrated to `Ecto.Multi` (or the caller's existing `Repo.transaction` block) so both operations are atomic. The Ledger context already wraps transaction/void operations in `Repo.transaction` and calls `Audit.log_event/1` inside the transaction — this pattern is correct and should be formalized.

---

## Proposed Data Model

### `AuditEvent` schema (current + additions)

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | `:binary_id` (UUIDv4) | No | Primary key, autogenerated |
| `entity_type` | `:string` | No | Lowercase singular name of the audited schema (e.g., `"entity"`, `"account"`, `"transaction"`). Max 120 chars. |
| `entity_id` | `:binary_id` | No | UUID of the audited record |
| `action` | `:string` | No | Verb describing the operation: `"created"`, `"updated"`, `"archived"`, `"unarchived"`, `"voided"`. Max 120 chars. Not an enum — free-form to support future actions without migration. |
| `actor` | `:string` | No | Who initiated the change: `"system"`, `"person"`, `"scheduler"`, `"import_pipeline"`. Max 120 chars. |
| `channel` | `Ecto.Enum` | No | How the change was initiated: `:web`, `:system`, `:mcp`, `:ai_assistant` |
| `before` | `:map` | Yes | Full JSON snapshot of the entity state before the operation. `nil` for inserts. Sensitive fields redacted. |
| `after` | `:map` | Yes | Full JSON snapshot of the entity state after the operation. `nil` for deletes (soft-archives still have an `after` snapshot). Sensitive fields redacted. |
| `occurred_at` | `:utc_datetime_usec` | No | Business timestamp of the event. Defaults to `DateTime.utc_now()` but can be overridden for batch/import scenarios. |
| `metadata` | `:map` | Yes | **NEW FIELD.** Catch-all map for context-specific data: correlation IDs, import batch refs, rule match explanations, request trace IDs. Not displayed prominently in the viewer but available for debugging. |
| `inserted_at` | `:utc_datetime_usec` | No | Ecto automatic timestamp. Internal bookkeeping, not displayed in UI. |

> **Note:** `updated_at` is explicitly excluded from this schema. Because `audit_events` is append-only, an `updated_at` field is semantically meaningless — a record that can never be updated has no update timestamp. Ecto's `timestamps()` macro will not be used in favour of `timestamps(updated_at: false)` (or an equivalent approach) to reflect this intent at the schema level and avoid implying mutability.

### Migration changes needed

1. Add `metadata :map` column (nullable) to `audit_events`; remove `updated_at` from `audit_events`.
2. Create append-only trigger on `audit_events` (BEFORE UPDATE OR DELETE → raises).
3. Create append-only trigger on `postings` (BEFORE UPDATE OR DELETE → raises).
4. Create restricted-update + delete-protection trigger on `transactions` (BEFORE UPDATE OR DELETE): blocks DELETE unconditionally; on UPDATE, rejects changes to fact fields (`entity_id`, `date`, `description`, `source_type`, `inserted_at`) and enforces `voided_at` set-once semantics.

---

## API / Context Design

### Design goals

- **No boilerplate in domain contexts.** Each context should call a single `Audit.*` helper and get atomicity for free — it should not have to manage transactions, build snapshots, or call `log_event/1` manually.
- **No async / background job.** Audit append happens synchronously in the same DB transaction as the domain write. Reliability over throughput.
- **No `with_event/3` as the long-term API.** `with_event/3` is being replaced entirely. All current callers will be migrated to the new helpers. There is no deprecation period — the refactor includes fixing all call sites.

### `AurumFinance.Audit` — simple operation helpers

These are the canonical integration point for domain contexts that perform a single operation (insert, update, archive). Each helper opens a transaction, performs the domain write, captures before/after snapshots with redaction applied, and appends the audit event atomically. The context function calls one helper and returns its result — no transaction management in the caller.

| Helper | Replaces | Use case |
|--------|----------|----------|
| `Audit.insert_and_log(changeset, meta)` | `with_event/3` on create | Inserting a new record and logging a `"created"` event |
| `Audit.update_and_log(struct, changeset, meta)` | `with_event/3` on update | Updating an existing record and logging an `"updated"` event |
| `Audit.archive_and_log(struct, changeset, meta)` | `with_event/3` on archive | Archiving a record and logging an `"archived"` event |

The `meta` map carries: `actor`, `channel`, `entity_type`, `action` (inferred by the helper but overridable), `redact_fields`, and optional `metadata`.

### `AurumFinance.Audit.Multi` — complex operation helper

For operations that already orchestrate multiple steps (e.g., `Ledger.create_transaction` which inserts a Transaction + multiple Postings), a lower-level Multi helper is provided:

**`Audit.Multi.append_event(multi, step_name, before_snapshot, meta)`**

Appends an audit event insert as a named step in an existing `Ecto.Multi`. The `before_snapshot` is captured by the caller before the Multi is built. The `after_snapshot` is derived from the result of a named step in the Multi. This keeps the audit append atomic with the rest of the Multi pipeline without requiring the caller to manage `Repo.transaction` directly.

### `list_audit_events/1` (existing — extend filters)

Add support for:
- `{:occurred_after, DateTime.t()}` — events with `occurred_at >= value`
- `{:occurred_before, DateTime.t()}` — events with `occurred_at <= value`
- `{:offset, non_neg_integer()}` — for offset pagination in the UI

### Functions removed / not carried forward

- **`with_event/3`** — replaced by the `insert_and_log / update_and_log / archive_and_log` helpers. All current callers (`Entities.*`, `Ledger.create_account`) are migrated as part of this issue.
- **`log_event/1`** (direct internal call from Ledger transaction paths) — replaced by `Audit.Multi.append_event/4`. The Ledger paths that currently call `log_event/1` inside `Repo.transaction` are migrated to the Multi pattern.

### Redaction enforcement

Redaction is enforced inside the `Audit` helpers, not in the callers. Each domain context declares its redact list and passes it via `redact_fields:` in the `meta` map. The `Audit` helpers apply recursive key-based redaction via `redact_snapshot/2` before any snapshot is stored.

| Context | Redact fields |
|---------|---------------|
| `Entities` | `[:tax_identifier]` |
| `Ledger` (accounts) | `[:institution_account_ref]` |
| `Ledger` (transactions) | None currently |

**Rule**: Any new context that introduces sensitive fields must declare `@audit_redact_fields` and pass it in the `meta` map. This is a convention enforced by code review, not the framework.

---

## Transaction / Atomicity Strategy

### Current state (to be replaced)

| Context | Operation | Atomicity |
|---------|-----------|-----------|
| `Entities.create_entity/2` | `Audit.with_event/3` | **NOT atomic** — domain insert then audit insert as separate DB calls |
| `Entities.update_entity/3` | `Audit.with_event/3` | **NOT atomic** — same |
| `Entities.archive_entity/2` | `Audit.with_event/3` | **NOT atomic** — same |
| `Ledger.create_account/2` | `Audit.with_event/3` | **NOT atomic** — same |
| `Ledger.create_transaction/2` | `Repo.transaction` + `Audit.log_event/1` inside | **Atomic** |
| `Ledger.void_transaction/2` | `Repo.transaction` + `Audit.log_event/1` inside | **Atomic** |

### Target state

All domain writes + audit appends must be atomic. The transaction is owned by the `Audit` helper — domain contexts do not manage transactions directly.

**Simple operations → `insert_and_log / update_and_log / archive_and_log`**

The `Audit` helper opens `Repo.transaction/1`, performs the domain write, appends the audit event, and commits. The domain context calls the helper and returns its result. No transaction code in the context function.

**Complex operations → `Audit.Multi.append_event/4`**

For operations already built on `Ecto.Multi` (e.g., `Ledger.create_transaction` with multiple postings), the Multi pipeline is extended with an audit event step. The `Ecto.Multi` is run via `Repo.transaction/1` at the end, making the whole pipeline — domain writes and audit append — atomic in a single transaction.

**No async job, no fire-and-forget.** The audit append is always synchronous. If it fails, the domain write is rolled back.

### Migration plan

All current `with_event/3` call sites in `Entities` and `Ledger.create_account` are migrated to the simple helpers in this issue. All current `log_event/1` call sites inside `Repo.transaction` blocks in `Ledger` are migrated to `Audit.Multi.append_event/4`. `with_event/3` and `log_event/1` (as a direct public call) are removed.

### Failure semantics

- If the domain write fails: the transaction rolls back. The audit event is not inserted. The caller receives `{:error, changeset}`.
- If the audit insert fails: the transaction rolls back. The domain write does not persist. The caller receives `{:error, {:audit_failed, reason}}`. This is a hard failure — no domain write succeeds without its audit record.

---

## Redaction / Privacy Rules

### Fields that MUST be redacted in before/after snapshots

| Entity type | Fields | Rationale |
|-------------|--------|-----------|
| Entity | `tax_identifier` | Tax ID / government identifier |
| Account | `institution_account_ref` | Bank account number / external reference |
| (Future) Import records | Raw statement payload fragments | Financial institution statements may contain full account numbers, sort codes, or other PII that must not be stored verbatim in the audit log |

**Principle: auditability does not override privacy-by-design.** The purpose of the audit trail is to record *that* a change happened and *what kind of change it was*, not to preserve a permanent copy of the most sensitive fields. Redaction is applied at write time and is irreversible — the audit log deliberately cannot be used to reconstruct sensitive field values from before/after snapshots.

### How redaction is enforced

1. Each context declares `@audit_redact_fields` as a module attribute.
2. The redact list is passed via `redact_fields:` in the `meta` map to `Audit.insert_and_log/2`, `Audit.update_and_log/3`, `Audit.archive_and_log/3`, or `Audit.Multi.append_event/4`.
3. The `Audit` context applies recursive key-based redaction via `redact_snapshot/2` before the snapshot is stored.
4. Redaction replaces field values with `"[REDACTED]"` — the key remains visible to indicate that the field existed.
5. Redaction is applied at write time, not read time. Once stored, the audit record contains only redacted data. There is no way to recover the original value from the audit log.

### What is NOT redacted

- Entity names, types, country codes — these are classification data, not PII.
- Account names, types, currency codes — operational data.
- Transaction dates, descriptions, amounts — financial facts needed for audit trail value.
- Actor, channel, timestamps — audit metadata.

---

## Query / Viewer Requirements

### Filters for the Audit Log viewer

| Filter | Type | Behavior |
|--------|------|----------|
| Entity type | Dropdown | Options derived from distinct `entity_type` values in the database (e.g., `"entity"`, `"account"`, `"transaction"`). "All" as default. |
| Action | Dropdown | Options: "All", "created", "updated", "archived", "unarchived", "voided". |
| Channel | Dropdown | Options: "All", "web", "system", "mcp", "ai_assistant". |
| Date range | Date preset buttons + custom range | Presets: "Today", "This week", "This month", "All". Follow the pattern from `TransactionsLive`. |
| Entity ID | Optional text input | Filter by a specific record UUID. Useful for tracing the full history of a single entity. |

### Pagination

- Offset-based pagination with a fixed page size (e.g., 50 events per page).
- "Load more" button or simple prev/next pagination.
- No infinite scroll (audit logs can grow large; explicit pagination is safer).

### Display

- Each row shows: `occurred_at` (formatted), `entity_type`, `action`, `actor`, `channel`.
- Expandable row (click to expand) shows `before` and `after` snapshots as formatted JSON.
- No edit, delete, or replay actions. Purely read-only.

### Access control

- The audit viewer is accessible to any authenticated root user (same as all app routes).
- No additional permission checks needed for the single-user model.

### Route

**Decision: dedicated `/audit-log` route.**

The audit log viewer lives at `/audit-log` under the existing `:app` live session, implemented as a dedicated `AuditLogLive` module. It is not embedded within `SettingsLive`. The audit log is a distinct operational view, not a configuration screen — it deserves its own URL for direct navigation and bookmarking. Add it to the sidebar navigation (under "System" or as a peer of Settings).

---

## Classification Alignment

`audit_events` is the canonical cross-cutting audit trail for **all domain entity changes**, not only for Entities and Ledger data. Classification changes (e.g., updating category labels on transactions, reclassifying entity types, applying or overriding AI-suggested categories) are domain writes and should also be recorded in `audit_events` using a consistent naming convention.

### Convention for classification events

Classification is not part of the lifecycle of a transaction — it is a separate concern. Using `entity_type: "transaction"` with `action: "classified"` would mix structural lifecycle events (`created`, `voided`) with classification events in the same bucket, making the log harder to read and filter.

Instead, use a dedicated `entity_type` of `"transaction_classification"` for all classification-related audit events:

| entity_type | action | Meaning |
|-------------|--------|---------|
| `"transaction_classification"` | `"classified"` | Classification applied for the first time |
| `"transaction_classification"` | `"reclassified"` | An existing classification was changed |
| `"transaction_classification"` | `"manual_override"` | User explicitly overrode an automatic or AI-suggested classification |
| `"transaction_classification"` | `"rule_applied"` | A classification rule was applied automatically |

This keeps the audit log filterable by domain concern: filtering on `entity_type = "transaction"` returns only structural transaction events; filtering on `entity_type = "transaction_classification"` returns only classification history. The `entity_id` field on these records should reference the ID of the transaction being classified.

The `before` and `after` snapshots capture the classification state before and after the change, subject to the same redaction rules as other snapshots.

### Future: classification-specific explainability store

If classification later requires richer explainability metadata — such as model version, rule ID, confidence score, candidate labels, or the rationale for an AI suggestion — this data does not belong in `audit_events`. The `metadata` field can carry lightweight classification metadata (e.g., `%{model_version: "v1.2", confidence: 0.91}`) in the near term, but a domain-specific explanation store (separate table, separate context) may be justified when:

- Classification metadata is queried independently of audit events.
- The volume and shape of explanation data diverges significantly from the generic audit record model.
- Explainability is a product feature (visible to the user) rather than an internal audit artifact.

**For this issue:** do not introduce a second audit table. Use `audit_events` with classification-specific `entity_type` / `action` values. The question of a dedicated explanation store is deferred to a future classification feature spec.

---

## Rollout Order

### Phase 1 — Foundation hardening (this issue)

1. Add `metadata` column to `audit_events` table via migration.
2. Update `AuditEvent` schema to include `metadata` field.
3. Add database-level append-only enforcement (trigger or privilege revocation).
4. Implement the new `Audit` helper API (`insert_and_log`, `update_and_log`, `archive_and_log`, `Audit.Multi.append_event`). Remove `with_event/3` and direct `log_event/1` calls. Migrate all callers.
5. Add `occurred_after` and `occurred_before` filter support to `list_audit_events/1`.
6. Add offset-based pagination support to `list_audit_events/1`.
7. Tests for all of the above.

### Phase 2 — Audit log viewer UI

1. Create `AuditLogLive` LiveView with filtered list.
2. Add `/audit-log` route to router.
3. Add sidebar navigation entry.
4. Build filter form (entity_type, action, channel, date range).
5. Build event list with expandable rows showing before/after snapshots.
6. Tests for the LiveView.

### Phase 3 — Future enhancements (separate issues)

- Per-field structured diff display in expanded rows.
- CSV/JSON export of filtered audit events.
- Retention/archival policy with partitioned tables.
- Full-text search across snapshot content.

---

## Rollout Recommendation

**Option A: Start with Entities only, expand to Ledger later.**
**Option B: Introduce the shared audit foundation now, integrate with currently available contexts first.**

**Recommendation: Option B — shared foundation first, with currently available contexts.**

The reasoning:

1. **The foundation already serves both contexts.** `Entities` and `Ledger` are already wired into `Audit`. Hardening the shared `Audit` context (atomicity, immutability, metadata field) benefits all currently integrated contexts simultaneously — there is no cost to breadth here.

2. **Do not assume full Ledger write coverage.** If specific Ledger write paths remain blocked by upstream Ledger primitives work, those specific paths can be added later. The foundation hardening is independent of any individual write path integration.

3. **The shared foundation is the correct investment.** Building a narrow, Entities-only audit trail first and then generalising it later creates unnecessary rework. The generic `AuditEvent` model is already the right design. The first rollout should validate and harden it, not artificially constrain it.

4. **Sequencing that follows from this recommendation:**
   - Phase 1: Harden the shared `Audit` foundation (atomicity, DB-level immutability, `metadata` field, filter extensions). This covers all currently integrated write paths.
   - Phase 2: Build the read-only audit log viewer at `/audit-log`.
   - Future: As new write paths (import pipelines, classification, rules engine) are implemented, they integrate into the already-hardened foundation without changes to the core schema.

---

## Risks / Open Questions

### R1: Append-only enforcement mechanism

Database trigger vs. privilege revocation — both work. The trigger approach is recommended because it does not depend on database role management, but it adds a non-Ecto migration artifact. The tech lead should decide which approach fits the deployment model.

### R2: Nested transaction / savepoint risk in the new helpers

The `insert_and_log / update_and_log / archive_and_log` helpers open `Repo.transaction/1` internally. If a caller ever wraps one of these in an outer transaction, Ecto will use a savepoint. This is safe in practice but should be tested explicitly for the key call sites. The `Audit.Multi.append_event/4` path does not have this risk because the Multi is always run by the caller as a single `Repo.transaction/1`.

### R3: Snapshot size growth

Full before/after snapshots for entities with many fields (e.g., a Transaction with 20 postings) can produce large JSON blobs. For the current schema sizes this is not a concern, but as the app grows, a snapshot size limit or truncation policy may be needed.

### R4: `entity_type` values are free-form strings

There is no enum or registry of valid `entity_type` values. This means typos in context code (e.g., `"entitiy"` instead of `"entity"`) would silently create inconsistent data. Consider adding a compile-time constant or validation list.

### R5: No `metadata` usage yet

The `metadata` field is being added for extensibility, but no current code will populate it. This is intentional forward investment, but the field should have clear documentation about intended use cases to prevent it from becoming a dumping ground.

### R6: Sidebar navigation placement

The `/audit-log` route is decided. The open question is sidebar grouping: top-level entry, peer of Settings, or nested under Settings as `/settings/audit-log`. Either is acceptable; the tech lead should align with the navigation structure of adjacent features.

---

## Concrete Implementation Tasks

### Phase 1 — Foundation

- [ ] 1. **Migration: add `metadata` column** — Create migration adding `metadata :map` (nullable) to `audit_events` table.
- [ ] 2. **Migration: append-only enforcement** — Create migration adding a Postgres trigger that raises on UPDATE/DELETE of `audit_events`.
- [ ] 3. **Schema: update `AuditEvent`** — Add `field :metadata, :map`. Use `timestamps(updated_at: false)` to remove `updated_at`. Update `changeset/2` to cast `:metadata`.
- [ ] 4. **Context: implement `Audit.insert_and_log/2`, `Audit.update_and_log/3`, `Audit.archive_and_log/3`** — Each helper wraps the domain changeset + audit event insert in `Repo.transaction/1`. Captures before/after snapshots and applies redaction internally. Returns `{:ok, struct}` or `{:error, reason}`.
- [ ] 5. **Context: implement `Audit.Multi.append_event/4`** — Appends an audit event insert step to an existing `Ecto.Multi`. Takes `(multi, step_name, before_snapshot, meta)`. Derives the after snapshot from the named step's result.
- [ ] 6. **Context: remove `with_event/3` and direct `log_event/1` calls** — Delete the old functions. Migrate all callers in `Entities.*` and `Ledger.*` to the new helpers. No backward compatibility shim.
- [ ] 7. **Context: extend `list_audit_events/1` filters** — Add `filter_query/2` clauses for `{:occurred_after, DateTime.t()}`, `{:occurred_before, DateTime.t()}`, and `{:offset, non_neg_integer()}`.
- [ ] 8. **Context: expose `distinct_entity_types/0`** — Query distinct `entity_type` values from `audit_events` for the UI filter dropdown.
- [ ] 9. **Tests: foundation** — Unit tests for `AuditEvent` changeset (with metadata, without `updated_at`). Integration tests for each helper (`insert_and_log`, `update_and_log`, `archive_and_log`, `Multi.append_event`): atomicity on success, rollback on audit failure, rollback on domain failure. Tests for `with_event/3` absence (callers migrated). Tests for append-only enforcement (UPDATE/DELETE raise). Tests for new filter clauses.

### Phase 2 — UI Viewer

- [ ] 10. **LiveView: create `AuditLogLive`** — Implement mount, handle_params, render. Follow the `TransactionsLive` pattern for URL-driven filters. Assign filters form, load audit events via `Audit.list_audit_events/1`.
- [ ] 11. **Router: add `/audit-log` route** — Add `live "/audit-log", AuditLogLive, :index` under the `:app` live session.
- [ ] 12. **Navigation: add sidebar entry** — Add "Audit Log" to the sidebar navigation.
- [ ] 13. **Template: filter form** — Dropdowns for entity_type (dynamically populated via `distinct_entity_types/0`), action, channel, optional entity_id input. Date preset buttons following `TransactionsLive` pattern.
- [ ] 14. **Template: event list** — Table/list showing `occurred_at`, `entity_type`, `action`, `actor`, `channel`. Expandable rows with formatted `before`/`after` snapshots. No edit, delete, or replay actions.
- [ ] 15. **Template: pagination** — Prev/next or "Load more" controls using offset-based pagination.
- [ ] 16. **Gettext: add translations** — Add gettext entries for all UI strings (page title, filter labels, empty state, column headers).
- [ ] 17. **Tests: UI** — LiveView tests for mount, filter changes, pagination, empty state, and confirmation that no write actions are present in the rendered template.

---

## User Stories

### US-1: View audit log

As a **root-authenticated user**, I want to view a chronological list of all domain changes, so that I can verify what happened to my financial data and when.

**Acceptance Criteria:**

- **Given** the user is authenticated and navigates to `/audit-log`
- **When** the page loads
- **Then** the most recent 50 audit events are displayed, ordered by `occurred_at` descending
- **And** each row shows: timestamp, entity type, action, actor, channel
- **And** clicking a row expands it to show before/after JSON snapshots

### US-2: Filter audit log by entity type

As a **root-authenticated user**, I want to filter audit events by entity type (entity, account, transaction), so that I can focus on changes to a specific domain area.

**Acceptance Criteria:**

- **Given** the user is on the audit log page
- **When** the user selects "account" from the entity type dropdown
- **Then** only audit events with `entity_type = "account"` are displayed
- **And** the URL updates to reflect the filter (for bookmarking)

### US-3: Filter audit log by date range

As a **root-authenticated user**, I want to filter audit events by date range, so that I can investigate changes during a specific period.

**Acceptance Criteria:**

- **Given** the user is on the audit log page
- **When** the user selects "This month" date preset
- **Then** only audit events with `occurred_at` within the current month are displayed

### US-4: Filter audit log by action and channel

As a **root-authenticated user**, I want to filter by action type and channel, so that I can see all automated changes or all manual edits.

### US-5: Paginate audit log

As a **root-authenticated user**, I want to load more audit events beyond the initial page, so that I can browse the full history.

### US-6: Atomic audit recording

As **the system**, all domain writes must atomically append an audit record in the same database transaction, so that no domain change can exist without its audit trail.

### US-7: Append-only guarantee

As **the system**, audit records must never be updated or deleted, so that the audit trail is a trustworthy, immutable record.

---

## Edge Cases

### Empty States
- No audit events exist yet: Show "No audit events recorded yet." with no CTA (audit events are system-generated, not user-created).
- Filter returns no results: Show "No events match the selected filters." with a link to clear filters.

### Error States
- Database connection failure during audit viewer load: Show generic error with retry.
- Audit insert failure during domain write: Roll back the entire transaction. The domain write does not persist. Return `{:error, {:audit_failed, changeset, result}}`.

### Boundary Conditions
- Very large before/after snapshots (e.g., transaction with many postings): Accept and store. No truncation in Phase 1.
- `entity_type` values not in the current dropdown: The dropdown is dynamically populated from the database, so new entity types appear automatically.
- Clock skew between `occurred_at` and `inserted_at`: Acceptable. They serve different purposes.

---

## UX States

### Audit Log Viewer

| State | Behavior |
|-------|----------|
| **Loading** | Show skeleton rows or spinner |
| **Empty** | "No audit events recorded yet." |
| **Empty (filtered)** | "No events match the selected filters." + clear filters link |
| **Data** | Paginated list of events with expandable rows |
| **Expanded row** | Shows before/after JSON in a pre-formatted block |
| **Error** | "Failed to load audit events." with retry |

---

## Involved Roles

Based on the agent catalog structure, the following agents would be involved in implementation:

- **PO / Functional Analyst** — This spec (complete)
- **Tech Lead** — Review architectural decisions (atomicity approach, trigger vs. privileges, route placement)
- **Backend Engineer** — Tasks 1-7 (migration, schema, context hardening, tests)
- **Frontend Engineer** — Tasks 8-15 (LiveView, templates, navigation, tests)
