# Domain Model

Core domain entities and relationships for AurumFinance.

## Status

Consolidated Phase 2 domain model baseline (Steps 1-7 complete). All planned
bounded contexts are defined at conceptual level with entities, relationships,
and invariants. Reporting/projection internals remain deferred to M4 planning.

## Modeling principles

- Ledger-style double-entry is the internal source of truth.
- User-facing workflows remain personal-finance oriented (expense, income, transfer, card purchase, card payment).
- Imported statement data is modeled as immutable facts.
- Classification metadata is mutable and correctable by rules and users.
- Classification manual overrides must be preserved across re-runs.
- All financial events remain traceable from source import to final classification.

## Context Map

AurumFinance is partitioned into seven bounded contexts organized in a tiered
dependency structure. Authentication is handled at the edge via a root password
plug — there is no user/accounts context. See ADR-0007 for the full rationale.

### Tier Overview

```
Tier 0 — Foundation (no domain dependencies)
  Entities         — Multi-entity ownership model

Tier 1 — Core Domain (depends on Tier 0 only)
  Ledger           — Accounts, transactions, postings, balances
  ExchangeRates    — FX rate series, rate records, tax snapshots

Tier 2 — Orchestration (depends on Tier 0 + Tier 1)
  Classification   — Rules engine, classification layer, audit
  Ingestion        — Import pipeline, file tracking, deduplication
  Reconciliation   — Statement matching, reconciliation workflow

Tier 3 — Analytics (depends on Tier 0 + Tier 1 + Tier 2, read-only)
  Reporting        — Retrospective analysis, projections, anomalies
```

### Context Map Diagram

```mermaid
graph TD
    subgraph "Tier 0 — Foundation"
        ENT[Entities]
    end

    subgraph "Tier 1 — Core Domain"
        LED[Ledger]
        FX[ExchangeRates]
    end

    subgraph "Tier 2 — Orchestration"
        CLS[Classification]
        ING[Ingestion]
        REC[Reconciliation]
    end

    subgraph "Tier 3 — Analytics"
        RPT[Reporting]
    end

    LED -->|entity-scoped| ENT
    FX -->|fiscal residency| ENT

    CLS -->|classifies transactions| LED
    CLS -->|entity-scoped| ENT
    ING -->|provides import evidence| REC
    ING -->|entity-scoped| ENT
    REC -->|operates on postings| LED
    REC -->|matches imports| ING
    REC -->|entity-scoped| ENT

    RPT -->|reads postings| LED
    RPT -->|converts amounts| FX
    RPT -->|reads classifications| CLS
    RPT -->|entity-scoped| ENT
```

### Context Responsibilities Summary

| Context | Owns | Key Invariants | Entity Scope |
|---------|------|---------------|--------------|
| **Entities** | Entity | Tenant boundary for all financial data; fiscal residency fields are columns on Entity; no user model | N/A (defines the boundary) |
| **Ledger** | Account, Transaction, Posting (implemented), BalanceSnapshot (deferred) | Account and transaction reads require explicit entity scope; posting currency is derived from the joined account; balances are derived from postings on read | Entity-scoped |
| **ExchangeRates** | RateSeries, RateRecord, TaxRateSnapshot, Currency | Tax snapshots immutable; rate types are string keys; arbitrary jurisdictions | Mixed (rates global, snapshots entity-scoped) |
| **Classification** | RuleGroup, Rule, Condition, Action, ClassificationRecord, ClassificationAuditLog (deferred) | Multiple groups fire per txn; first match wins per group; manual overrides protected | Mixed (rules global, outcomes entity-scoped) |
| **Ingestion** | ImportedFile, ImportedRow, ImportMaterialization, ImportRowMaterialization | Account-scoped async ingestion; immutable evidence plus async materialization and durable row outcomes | Account-scoped within an entity |
| **Reconciliation** | ReconciliationSession, MatchResult, Discrepancy | State machine: unreconciled -> cleared -> reconciled; corrections reset state | Entity-scoped |
| **Reporting** | RecurringPattern, Projection, AnomalyAlert | Read-only over primary data; projections labeled with evidence base | Entity-scoped (+ cross-entity) |

### Dependency Rules

1. Dependencies flow strictly downward through tiers.
2. A Tier N context may depend on any Tier 0..N-1 context.
3. No context depends on a context in the same tier (exception: Ingestion depends on Classification, both Tier 2 — this is permitted because Ingestion orchestrates Classification as a downstream step, not a bidirectional dependency).
4. The web layer (`AurumFinanceWeb`) depends on all contexts but no context depends on the web layer.
5. Cross-context communication uses synchronous function calls through public APIs.

### Milestone Alignment

| Milestone | Contexts Built |
|-----------|---------------|
| M1 — Core Ledger | Entities, Ledger, ExchangeRates (currency basics only), Auth (edge plug) |
| M2 — Import Pipeline | Ingestion, Reconciliation |
| M3 — Rules Engine | Classification |
| M4 — Reporting | Reporting |
| M5 — Investments | Extensions to Ledger (instrument types, holdings) |
| M6 — Tax Awareness | ExchangeRates (full rate series, tax snapshots) |
| M7 — AI + MCP | Cross-cutting; no new context expected |

## Core bounded areas

This section defines the conceptual entities and relationships for each
bounded context. It is intentionally implementation-free (no schemas/migrations).

## Domain Entity Relationship Overview

```mermaid
erDiagram
    ENTITY ||--o{ ACCOUNT : owns
    ENTITY ||--o{ TRANSACTION : owns
    TRANSACTION ||--|{ POSTING : has
    ACCOUNT ||--o{ POSTING : receives
    ACCOUNT ||--o{ BALANCE_SNAPSHOT : caches

    ENTITY ||--o{ IMPORTED_FILE : owns_via_account
    ACCOUNT ||--o{ IMPORTED_FILE : targets
    IMPORTED_FILE ||--|{ IMPORTED_ROW : contains
    IMPORTED_FILE ||--o{ IMPORT_MATERIALIZATION : materializes_via
    IMPORTED_ROW ||--o{ IMPORT_ROW_MATERIALIZATION : evaluates_as
    IMPORT_MATERIALIZATION ||--|{ IMPORT_ROW_MATERIALIZATION : contains
    TRANSACTION ||--o{ IMPORT_ROW_MATERIALIZATION : traced_from

    RULE_GROUP ||--|{ RULE : contains
    RULE ||--|{ CONDITION : has
    RULE ||--|{ ACTION : has
    TRANSACTION ||--o| CLASSIFICATION_RECORD : classified_by
    TRANSACTION ||--o{ CLASSIFICATION_AUDIT_LOG : classification_history

    RATE_SERIES ||--o{ RATE_RECORD : has
    FX_INGESTION_BATCH ||--o{ RATE_RECORD : loads
    ENTITY ||--o{ TAX_RATE_SNAPSHOT : owns

    ENTITY ||--o{ RECONCILIATION_SESSION : owns
    ACCOUNT ||--o{ RECONCILIATION_SESSION : reconciles
    RECONCILIATION_SESSION ||--o{ MATCH_RESULT : proposes_or_accepts
    RECONCILIATION_SESSION ||--o{ DISCREPANCY : tracks
    POSTING ||--o{ MATCH_RESULT : candidate_for
    POSTING ||--o{ RECONCILIATION_AUDIT_LOG : reconciliation_history
```

## Lifecycle Summaries

| Domain Area | Primary Lifecycle |
|-------------|-------------------|
| **Ledger transaction** | created -> posted -> voided (with reversing transaction) |
| **Import file** | pending -> processing -> complete or failed |
| **Classification field** | rule-assigned/user-assigned -> optionally manually overridden -> optionally re-opened for rules |
| **FX snapshot** | created at tax event -> immutable forever |
| **Reconciliation state** | unreconciled -> cleared -> reconciled; corrections reopen to cleared |

### Ledger and Postings

The ledger context (`AurumFinance.Ledger`) is the system of record for all
financial positions. See ADR-0008 for the full design rationale.

#### Entities

| Entity | Description | Key Fields |
|--------|-------------|------------|
| **Account** | Canonical internal ledger account abstraction. Covers institution-backed accounts, category accounts, and system-managed accounts within one entity boundary. | `entity_id`, `account_type` (Asset/Liability/Equity/Income/Expense), `operational_subtype`, `management_group`, `name`, `currency_code`, `institution_name`, `institution_account_ref`, `notes`, `archived_at` |
| **Transaction** | A single real-world financial event grouping one or more postings. Immutable after creation except for the set-once void marker. | `id`, `entity_id`, `date`, `description`, `source_type` (`manual` / `import` / `system`), `correlation_id`, `voided_at`, `inserted_at` |
| **Posting** | A single debit or credit line within a transaction, targeting one account. Fully immutable after creation. | `id`, `transaction_id`, `account_id`, `amount` (signed decimal; positive = debit, negative = credit), `inserted_at` |
| **BalanceSnapshot** | Deferred optimization for cached non-authoritative balances. Not implemented. | `account_id`, `as_of_date`, `currency_code`, `balance`, `posting_count`, `computed_at` |

#### Relationships

- Entity 1--* Account (entity-scoped)
- Entity 1--* Transaction (entity-scoped)
- Transaction 1--+ Posting (at least two per transaction)
- Posting *--1 Account (each posting targets one account)

#### Current Implementation Scope

The current implemented Ledger scope includes:

- account CRUD and account lifecycle
- transaction creation with nested postings
- entity-scoped transaction reads and filtering
- posting-backed balance derivation
- void-and-reverse correction flow
- read-only Transactions LiveView

The following Ledger concepts remain deferred:

- `parent_account_id`
- `is_placeholder`
- `BalanceSnapshot`
- automatic trading-account workflows for FX abstractions
- write UI for manual transaction entry/voiding

Accounts use the standard five accounting types:

- Asset
- Liability
- Equity
- Income
- Expense

Not every account corresponds to a bank, broker, or other institution-backed
container. Income/expense categories are also accounts in the ledger model, and
some accounts are system-managed for technical balancing and lifecycle support.
Category accounts may be created manually or introduced automatically by later
categorization workflows; in both cases they remain first-class ledger accounts.

`management_group` is an explicit management/presentation classification used to
support separate account-management surfaces. It does not replace ledger
semantics: `account_type` still carries accounting meaning and
`operational_subtype` still carries operational/institution meaning.

Account lifecycle uses `archived_at` rather than a boolean active flag:

- `archived_at == nil` means active
- `archived_at != nil` means archived

The public account and transaction retrieval/listing APIs are entity-scoped.
Public list APIs require explicit `entity_id`, and public retrieval uses the
scoped forms `get_account!(entity_id, account_id)` and
`get_transaction!(entity_id, transaction_id)`.

#### Splits

There is no separate "split" entity. A split is simply a transaction with more
than two postings. Example: a grocery receipt divided between "Groceries" and
"Household" creates three postings (one credit to the source account, two debits
to the expense categories).

#### Transaction and Posting Notes

- `Transaction` has **no** `memo` field.
  Notes and annotations belong in a future overlay/classification layer.
- `Transaction` has **no** `status` field.
  `voided_at == nil` means active; `voided_at != nil` means voided.
- `Transaction` has **no** `updated_at`.
  Core facts are immutable and the only allowed mutation is setting `voided_at`
  once through the void workflow.
- `Posting` has **no** `currency_code`.
  Currency is structural and always derived from `posting.account.currency_code`.
- `Posting` has **no** `entity_id`.
  Entity scope is structural and always derived from the parent transaction.
- `Posting` has **no** `updated_at`.
  Postings are append-only immutable facts.

#### Key Invariants

1. **Zero-sum per currency per transaction:** The sum of all posting amounts
   grouped by effective currency within a transaction must equal zero. Effective
   currency is `account.currency_code`, obtained through the posting's account
   join. Enforced in the application layer during transaction creation.
2. **Posting immutability:** Once created, a posting's amount and
   account cannot be changed. Corrections use void-and-reverse.
3. **Fact immutability:** Transaction `entity_id`, `date`, `description`, and
   `source_type` are write-once; postings are fully immutable (ADR-0004).
4. **Entity isolation:** All posting accounts referenced by a transaction must
   belong to the same entity as `transaction.entity_id`.
5. **Minimum posting count:** A transaction must contain at least two postings.

#### Balance Derivation

`AurumFinance.Ledger.get_account_balance/2` is now implemented as a read-time
aggregation over postings joined to accounts and transactions.

Current behavior:

- no denormalized balance field on accounts
- balances are derived from postings on read
- supports `as_of_date` filtering via `transaction.date`
- returns `%{}` when an account has no postings
- returns exactly one currency key for a single account because an account has
  exactly one `currency_code`
- performs no FX conversion

#### Corrections and Voids

The ledger never modifies or deletes existing transactions or postings. A
**void** sets the original transaction's `voided_at` timestamp and creates a
reversing transaction with equal-and-opposite postings. The original and
reversal share a `correlation_id`. A **correction** is a void followed by a new
transaction with corrected postings. Both the original and reversal remain in
the ledger permanently for audit purposes.

#### UX Mapping

Users interact with five personal-finance concepts that map to posting patterns:

| UX Concept | Source Account Type | Target Account Type |
|------------|--------------------|--------------------|
| Expense | Asset or Liability | Expense |
| Income | Income | Asset |
| Transfer | Asset | Asset |
| Credit card purchase | Liability | Expense |
| Credit card payment | Asset | Liability |

Cross-currency transactions are supported when each currency group balances
independently. Higher-level FX/trading-account UX abstractions remain deferred.

The UI may expose different subsets of the same canonical `Account` model
depending on workflow. Institution-backed accounts, category accounts, and
technical/system-managed accounts can be presented in separate views without
changing the ledger model. In implementation, these views are backed by the
explicit `management_group` field rather than temporary query heuristics.

### Multi-Entity Ownership Model

The Entities context (`AurumFinance.Entities`) is the Tier 0 foundation that
defines the tenant boundary for all financial data. See ADR-0009 for the full
design rationale.

#### What is an Entity?

An entity is a legal/fiscal ownership unit — a distinct set of books. Examples:
"Personal", "My LLC", "Family Trust", "Side Project". One operator manages all
entities on the instance.

#### Domain Objects

| Domain Object | Description | Key Fields |
|---------------|-------------|------------|
| **Entity** | A legal/fiscal ownership unit; the tenant boundary for all financial data. | `name`, `type` (individual/legal_entity/trust/other), `country_code`, `tax_identifier` (optional), `fiscal_residency_country_code` (write-default from `country_code` when omitted), `default_tax_rate_type` (optional), `notes` (optional), `archived_at` (soft archive) |

#### Relationships

- Entity 1--* Account (entity-scoped, via Ledger)
- Entity 1--* Transaction (entity-scoped, via Ledger)
- Entity attributes (entity_name, entity_type, entity_country_code) are referenceable as Condition fields in Classification (no foreign key; resolved at evaluation time)
- Entity 1--* ImportedFile (entity-scoped via the target account, in Ingestion)
- Entity 1--* ReconciliationSession (entity-scoped, via Reconciliation)
- Entity 1--* TaxRateSnapshot (entity-scoped, via ExchangeRates)

#### Isolation Strategy

All entity-scoped data uses an `entity_id` foreign key column. No schema-level
or database-level separation. Every entity-scoped context function accepts an
entity as the first parameter and filters by `entity_id`.

#### Authentication Is Orthogonal

There is no user model, no `EntityMembership`, no per-entity access control.
Authentication is a root password check at the Phoenix router edge (ADR-0007).
Entity selection is a UI-level concept (session/socket state), not a data
access boundary.

#### Entity-Scoped vs Global Data

| Scope | Data | Rationale |
|-------|------|-----------|
| **Entity-scoped** | Account, Transaction, Posting, BalanceSnapshot, ClassificationRecord, ClassificationAuditLog, ImportedFile, ImportedRow, ReconciliationSession, MatchResult, Discrepancy, TaxRateSnapshot, RecurringPattern, Projection, AnomalyAlert | Financial data belongs to exactly one entity. In the current implementation, Account, Transaction, Posting, ImportedFile, and ImportedRow already use this boundary. |
| **Global** | Currency, RateSeries, RateRecord, RuleGroup, Rule, Condition, Action | Currencies, exchange rates, and classification rules are shared across entities |

#### Cross-Entity Transfers

Modeled as two correlated transactions — one in each entity — linked by a
shared `correlation_id` (UUID). Each transaction independently satisfies the
zero-sum invariant (ADR-0008). Both are created atomically in a single database
transaction.

#### Cross-Entity Reporting

A read-only aggregation pattern in the Reporting context. Queries across
multiple entities with `WHERE entity_id IN (...)`, aggregates results, and
converts to a single display currency via ExchangeRates. No data is created
or moved.

#### Fiscal Residency per Entity

Fiscal residency is a property of the entity, not the instance. Different
entities can have different fiscal residencies (e.g., "Personal" in Chile,
"My LLC" in Peru). When a tax-relevant event occurs, the entity's
`default_tax_rate_type` determines which rate series to snapshot (ADR-0005).
Existing tax snapshots are immutable regardless of fiscal residency changes.

#### Key Invariants

1. **Every instance has at least one entity.** Created during initial setup.
2. **Entity names are unique** within the instance.
3. **Entities cannot be deleted** — only archived via `archived_at`.
4. **One fiscal residency per entity** — fiscal residency fields
   (`fiscal_residency_country_code`, `default_tax_rate_type`) are columns
   directly on the Entity table; there is no separate fiscal residency record.
5. **No user-entity relationship exists.** The operator owns all entities.
6. **Entity lifecycle changes are audited** via append-only generic
   `audit_events` entries. The current implementation audits operationally
   meaningful lifecycle changes, not every ledger fact insert.

### Audit Trail

The audit context (`AurumFinance.Audit`) is a cross-cutting operational
traceability layer. It is implemented, but intentionally narrower than the
conceptual classification and ingestion audit domains described elsewhere in
this document.

#### Current v1 audit scope

The current implementation records audit events for:

- entity lifecycle changes
- account lifecycle changes
- transaction void actions
- other explicit operational/manual actions that opt into the audit helpers

The current implementation does not record audit events for:

- normal transaction creation
- posting creation
- future classification/import/settings/rules provenance domains that are still deferred

This distinction is intentional:

- `audit_events` provide operational traceability
- transaction/posting immutability protections preserve ledger correctness

#### AuditEvent

`AurumFinance.Audit.AuditEvent` is the generic append-only record used by the
audit trail.

| Field | Meaning |
|-------|---------|
| `id` | UUID primary key |
| `entity_type` | Lowercase singular domain label such as `entity`, `account`, or `transaction` |
| `entity_id` | UUID of the audited record |
| `action` | Verb such as `created`, `updated`, `archived`, `unarchived`, or `voided` |
| `actor` | Simple string label describing who triggered the change |
| `channel` | `web`, `system`, `mcp`, or `ai_assistant` |
| `before` | Full redacted snapshot before the change, or `nil` |
| `after` | Full redacted snapshot after the change, or `nil` |
| `metadata` | Optional non-sensitive operational metadata |
| `occurred_at` | Domain timestamp for when the change happened |
| `inserted_at` | DB insert timestamp |

Notes:

- `AuditEvent` has no `updated_at`.
- `before` and `after` store full snapshots, not diffs.
- `metadata` is not redacted. Do not store secrets, tokens, tax IDs, account
  refs, or other sensitive values there.

#### Audit helper API

The implemented public audit entry points are:

- `insert_and_log/2`
- `update_and_log/3`
- `archive_and_log/3`
- `Audit.Multi.append_event/4`
- `list_audit_events/1`
- `distinct_entity_types/0`

There is no public raw audit insert API. Domain code is expected to use the
redaction-aware helpers so snapshots and metadata handling stay centralized.

#### Redaction and immutability

The audit helpers serialize full snapshots and apply field-level redaction
before insert. Current redact conventions include:

- `Entity.tax_identifier`
- `Account.institution_account_ref`

At the database level:

- `audit_events` is append-only
- `postings` is append-only
- `transactions` protect immutable fact fields and allow only the set-once
  `voided_at` lifecycle marker

These protections remain in place even when normal transaction/posting creates
do not emit audit events.

#### Audit log viewer

The current UI exposes a read-only `/audit-log` LiveView for operational events.
It supports filtering by:

- audited `entity_type`
- action
- channel
- owner `Entity`
- date preset

The owner-entity filter is user-facing by entity name and stored internally as
an entity UUID in the URL query.

### Ingestion and Normalization

The Ingestion context (`AurumFinance.Ingestion`) manages the import pipeline
from uploaded source file to immutable evidence and, in CSV v1, async durable
materialization into ledger transactions.

#### Pipeline Overview

Data flows through two durable phases:

```
Upload & Store --> Parse & Extract --> Normalize & Validate --> Deduplicate
                                                                       |
                                                                       v
                                                         Persist immutable evidence
                                                         imported_files + imported_rows
                                                                       |
                                                                       v
                                                         Request async materialization
                                                                       |
                                                                       v
                                                         Persist runs and row outcomes
                                              import_materializations + import_row_materializations
```

Preview and inspection are rendered from immutable evidence. Materialization is
modeled separately as workflow state and row outcomes, preserving evidence
immutability while allowing async, idempotent ledger writes.

#### Domain Objects

| Domain Object | Description | Key Fields |
|---------------|-------------|------------|
| **ImportedFile** | One uploaded source file plus async processing lifecycle and summary. | `account_id`, `filename`, `sha256`, `format`, `status`, `row_count`, `imported_row_count`, `skipped_row_count`, `invalid_row_count`, `error_message`, `warnings`, `storage_path`, `processed_at` |
| **ImportedRow** | One immutable parsed row from the file, persisted as evidence and preview data. | `imported_file_id`, `account_id`, `row_index`, `raw_data`, `description`, `normalized_description`, `posted_on`, `amount`, `currency`, `fingerprint`, `status`, `skip_reason`, `validation_error` |
| **ImportMaterialization** | One async ledger materialization run for one imported file. | `imported_file_id`, `account_id`, `status`, `requested_by`, `rows_considered`, `rows_materialized`, `rows_skipped_duplicate`, `rows_failed`, `error_message`, `started_at`, `finished_at` |
| **ImportRowMaterialization** | One durable row-level materialization outcome. | `import_materialization_id`, `imported_row_id`, `transaction_id`, `status`, `outcome_reason`, `inserted_at` |

#### Relationships

- Account 1--* ImportedFile (target account for the import)
- ImportedFile 1--+ ImportedRow (one file contains many persisted row evidences)
- ImportedRow belongs to one account explicitly for account-scoped dedupe and review
- ImportedFile 1--* ImportMaterialization
- ImportMaterialization 1--* ImportRowMaterialization
- ImportedRow 1--* ImportRowMaterialization
- ImportRowMaterialization optionally links to one committed Transaction

#### ImportedFile Status Lifecycle

```
:pending --> :processing --> :complete
                    |
                    v
                 :failed
```

#### Deduplication Strategy

- **Fingerprint:** stable hash of normalized canonical row data.
- **Scope:** Per account. Rows in different accounts do not deduplicate against each other.
- **File-level check:** `sha256` is stored as metadata only and does not block repeated uploads.
- **Conflict resolution:** duplicate rows are persisted as `duplicate`; new rows are persisted as `ready`; invalid rows are persisted as `invalid`.

#### Preview / Review State

Preview is rendered from persisted `imported_files` and `imported_rows`.
History and detail pages survive page reloads and browser disconnects because
the source of truth is durable state, with LiveView updates driven by PubSub.

CSV v1 does not introduce row-level approval or duplicate override. The user
either materializes eligible rows or deletes the imported file and re-imports a
corrected CSV.

#### Materialization Model

Materialization is async and durable:

- one `ImportMaterialization` is created before worker execution
- one `ImportRowMaterialization` is stored for every evaluated row, including
  `skipped`
- row outcomes are `committed`, `skipped`, or `failed`
- run outcomes are `pending`, `processing`, `completed`,
  `completed_with_errors`, or `failed`

Eligibility is determined directly from imported-row evidence:

- `ready` + not already committed + no currency mismatch => materializable
- `duplicate` => skipped
- `invalid` => skipped
- already committed => skipped
- currency mismatch => failed

Committed rows create ledger transactions with `source_type: :import` and keep
row-to-transaction traceability through `ImportRowMaterialization.transaction_id`.

#### Format Extensibility

New file formats are added by implementing a `FormatAdapter` behaviour with
three callbacks: `detect/1` (can this adapter handle the file?), `parse/1`
(convert to raw row maps), and `column_mapping/1` (map source columns to
normalized fields). Built-in adapters include CSV (with configurable column
mapping), OFX/QFX, and QIF. Adding a new adapter requires no changes to the
pipeline stages.

#### Key Invariants

1. **Raw data preservation:** `ImportedRow.raw_data` is immutable — original
   file data is never modified.
2. **Repeated uploads are allowed:** same file imported twice may create a new `imported_file`, but row-level dedupe prevents duplicate `ready` evidence.
3. **No row-review overlay:** imported rows never become approved/rejected workflow records.
4. **Full provenance:** file -> imported row -> row outcome -> transaction for committed rows.
5. **Native-currency-only materialization:** `account.currency_code` is the only posting currency source of truth; no FX conversion occurs in ingestion materialization.

### Rule Groups and Classification Outcomes

The Classification context (`AurumFinance.Classification`) implements the
grouped rules engine and manages the mutable classification layer. See
ADR-0011 for the full design rationale and ADR-0003 for the engine model.

#### Engine Model

Rules are organized into independent groups. Each group represents a
classification dimension (e.g., expense category, account tags, investment
type). Multiple groups can match the same transaction simultaneously. Within
a group, rules are evaluated in priority order — the first matching rule wins
(controlled by `stop_processing`, which defaults to true).

#### Domain Objects

| Domain Object | Description | Key Fields |
|---------------|-------------|------------|
| **RuleGroup** | An independent classification dimension. Declares which fields it is responsible for. Global — no entity ownership, no ordering (groups run in parallel). | `name`, `description`, `target_fields` (JSON list), `is_active` |
| **Rule** | A single condition-action pair within a group. | `rule_group_id`, `name`, `description`, `position`, `is_active`, `stop_processing` |
| **Condition** | A single condition on a rule. Rules match when ALL conditions match (AND logic). | `rule_id`, `field`, `operator`, `value`, `negate` |
| **Action** | A single field assignment when a rule matches. | `rule_id`, `field`, `operation`, `value` |
| **ClassificationRecord** | The classification state for a transaction. One record per transaction. Per-field provenance and override tracking. | `transaction_id`, `entity_id`, `category`, `category_classified_by`, `category_manually_overridden`, `tags`, `tags_classified_by`, `tags_manually_overridden`, `investment_type`, `investment_type_classified_by`, `investment_type_manually_overridden`, `notes`, `notes_classified_by`, `notes_manually_overridden` |
| **ClassificationAuditLog** | Append-only log of every classification change. | `transaction_id`, `entity_id`, `field`, `old_value`, `new_value`, `source`, `rule_group_id`, `rule_id`, `occurred_at` |

#### Relationships

- RuleGroup 1--+ Rule (ordered by position)
- Rule 1--* Condition (AND-composed)
- Rule 1--+ Action (field assignments)
- Transaction 1--0..1 ClassificationRecord (one classification per txn)
- Transaction 1--* ClassificationAuditLog (append-only history)

#### Condition Operators

Conditions reference transaction/posting fact fields (`description`, `amount`,
`abs_amount`, `date`, `source_type`, joined account currency, `account_name`,
`account_type`) and entity/account attributes
(`entity_name`, `entity_slug`, `entity_type`, `entity_country_code`,
`institution_name`).

Supported operators: `equals`, `contains`, `starts_with`, `ends_with`,
`matches_regex`, `greater_than`, `less_than`, `greater_than_or_equal`,
`less_than_or_equal`, `is_empty`, `is_not_empty`.

AND composition within a rule. OR logic is achieved by creating multiple
rules with the same actions in the same group.

#### Action Operations

Actions target classification fields: `category`, `tags`, `investment_type`,
`notes`.

Operations: `set` (replace value), `add` (add to list, for tags), `remove`
(remove from list, for tags), `append` (append text, for notes).

Actions are structured field assignments only — no arbitrary code.

#### Classification Provenance

Each classification field on ClassificationRecord has a companion
`*_classified_by` field (JSON) recording the source:
- Rule-based: `{source: "rule", rule_group_id: "...", rule_id: "...", classified_at: "..."}`
- User-based: `{source: "user", classified_at: "..."}`

And a `*_manually_overridden` boolean flag.

#### Manual Override Protection

Fields with `manually_overridden: true` are skipped by rule evaluation.
Users can clear the override to allow rules to re-apply. This protects
intentional user corrections from being silently overwritten by automation
(ADR-0004).

#### Rule Versioning

Rules are mutable — no versioning at the schema level. Historical
classifications reference rules by ID. The audit log records what changed,
when, and which rule was responsible. If a rule changes, past audit records
reflect the old rule's identity (by ID), not its current state. Changing a
rule does not automatically re-classify existing transactions.

#### Evaluation Performance

Rules are evaluated in-process (no job queue). For bulk imports, the pipeline
batches transactions and passes them to `classify_transactions/1`. Rule
groups and rules are loaded once per batch. Evaluation complexity is O(N *
G * R * C) — well within in-process bounds for personal finance volumes.

#### Key Invariants

1. **Multiple groups fire per transaction** — each group produces its output
   independently (ADR-0003).
2. **First match wins within a group** — controlled by `stop_processing`
   (default true).
3. **Manual overrides are protected** — fields with
   `manually_overridden: true` are skipped by rules (ADR-0004).
4. **Every change is audited** — ClassificationAuditLog records field, old
   value, new value, source, group, rule, and timestamp.
5. **Actions cannot modify facts** — rules only write to classification
   fields, never to Transaction or Posting fields.

### FX/rates and tax snapshots

The ExchangeRates context (`AurumFinance.ExchangeRates`) stores named FX rate
series, time-based rate records, and immutable tax snapshots. See ADR-0012 for
full design rationale and ADR-0005 for baseline FX posture.

#### Domain Objects

| Domain Object | Description | Key Fields |
|---------------|-------------|------------|
| **RateSeries** | Identity of a named FX series for a currency pair, purpose, and jurisdiction. | `base_currency_code`, `quote_currency_code`, `rate_type`, `jurisdiction_code`, `display_name`, `source_system`, `is_active` |
| **RateRecord** | A single append-only point in time for a RateSeries. | `rate_series_id`, `effective_at`, `rate_value`, `source_reference`, `fetched_at`, `ingestion_batch_id`, `quality_flag` |
| **TaxRateSnapshot** | Immutable snapshot of the FX rate used for a tax-relevant event. Entity-scoped. | `entity_id`, `tax_event_type`, `tax_event_reference`, `base_currency_code`, `quote_currency_code`, `rate_type`, `jurisdiction_code`, `rate_value`, `effective_at`, `source_reference`, `snapped_at` |
| **FxIngestionBatch** | Batch metadata for historical or periodic rate imports. | `source_system`, `source_payload_hash`, `status`, `started_at`, `completed_at`, `total_records`, `inserted_records`, `skipped_records`, `error_records` |

#### Relationships

- RateSeries 1--* RateRecord (append-only time series)
- FxIngestionBatch 1--* RateRecord (optional batch linkage)
- Entity 1--* TaxRateSnapshot (entity-scoped tax evidence)
- TaxRateSnapshot *--1 RateSeries (logical source identity; snapshot stores
  copied values and metadata for immutability)

#### Series Identity and Scope

Series identity is a composite natural key:

`(base_currency_code, quote_currency_code, rate_type, jurisdiction_code)`

- `rate_type` is a string key (not enum) to support arbitrary named series.
- `jurisdiction_code` may be a country code or `global`.
- Rates are global data; snapshots are entity-scoped.

#### Lookup Semantics

ExchangeRates provides deterministic rate lookup by pair/type/jurisdiction/date.
Caller-selected strategies:

- `:exact` — exact timestamp match required.
- `:latest_on_or_before` — nearest prior rate.
- `:latest_available` — most recent rate.

For tax workflows, jurisdiction defaults from entity fiscal residency and
`default_tax_rate_type` (ADR-0009), unless explicitly overridden.

#### Missing Rate Handling

Lookup returns explicit outcomes:
- `{:ok, rate_record}`
- `{:error, :series_not_found}`
- `{:error, :rate_not_found}`
- `{:error, :stale_rate}` (when staleness bounds are violated)

Tax snapshots fail closed on missing required rates. Reporting flows may present
"conversion unavailable" depending on caller policy.

#### Tax Snapshot Lifecycle

1. A tax-relevant event requests rate lookup using entity defaults or explicit
   rate selection.
2. Resolved rate metadata and value are copied into TaxRateSnapshot.
3. Snapshot is write-once and never modified, even if RateSeries receives later
   corrections.
4. Reports and tax exports read snapshots as historical facts.

#### Key Invariants

1. **Original ledger amounts remain immutable** — conversions are read-time
   derivatives.
2. **Tax snapshots are immutable** and unique per tax event reference.
3. **Rate history is append-only** — corrections add new records.
4. **No implicit interpolation** — lookup policy is explicit and caller-driven.
5. **Series identity is extensible** — no hardcoded jurisdiction/rate enums.

### Reconciliation state and evidence trail

The Reconciliation context (`AurumFinance.Reconciliation`) validates ledger
postings against imported statement evidence through explicit sessions, matching
results, and discrepancy records. See ADR-0013 for full design rationale.

#### Domain Objects

| Domain Object | Description | Key Fields |
|---------------|-------------|------------|
| **ReconciliationSession** | A statement-period reconciliation run for one account and entity. | `entity_id`, `account_id`, `statement_identifier`, `opened_at`, `closed_at`, `opening_balance`, `closing_balance_expected`, `closing_balance_computed`, `status`, `notes` |
| **MatchResult** | Candidate or accepted mapping between a statement line and a posting. | `entity_id`, `reconciliation_session_id`, `statement_row_reference`, `posting_id`, `match_status`, `confidence_score`, `score_breakdown`, `matched_by`, `matched_at` |
| **Discrepancy** | Persistent mismatch or gap discovered during reconciliation. | `entity_id`, `reconciliation_session_id`, `discrepancy_type`, `severity`, `statement_row_reference`, `posting_id`, `details`, `status`, `raised_at`, `resolved_at`, `resolved_by` |
| **ReconciliationAuditLog** | Append-only log of state transitions and reconciliation actions. | `entity_id`, `reconciliation_session_id`, `posting_id`, `from_state`, `to_state`, `reason`, `actor`, `occurred_at` |

#### Relationships

- Entity 1--* ReconciliationSession
- Account 1--* ReconciliationSession
- ReconciliationSession 1--* MatchResult
- ReconciliationSession 1--* Discrepancy
- Posting 1--* MatchResult (across sessions over time)
- Posting 1--* ReconciliationAuditLog
- ImportedRow 0..1--* MatchResult via `statement_row_reference`

#### Posting Reconciliation State Machine

States:
- `unreconciled` (default)
- `cleared`
- `reconciled`

Transitions:

- `unreconciled -> cleared`: auto-match or manual clear.
- `cleared -> reconciled`: explicit user confirmation in an open session.
- `reconciled -> cleared`: correction/reopen event with reason.
- `cleared -> unreconciled`: candidate rejected/unmatched.

Direct `reconciled -> unreconciled` is not allowed.

#### Matching Strategy

Statement-to-posting matching is scored using:
- amount exactness,
- date proximity,
- description similarity,
- institution reference equality (when available),
- account/entity scope consistency.

Auto-matching can promote to `cleared` only. `reconciled` always requires an
explicit user action.

#### Discrepancy Lifecycle

1. During session processing, unmatched or conflicting evidence creates
   Discrepancy records.
2. Discrepancies are classified by type (`missing_posting`,
   `unmatched_statement_line`, `amount_mismatch`, `date_mismatch`,
   `duplicate_match`, `balance_gap`) and severity.
3. Users resolve discrepancies through matching, correction, or documented
   override.
4. Resolved discrepancies remain stored for audit.

Critical discrepancies block session closure.

#### Correction Impact

If a reconciled posting is corrected (void + replacement in Ledger), the
original posting is reopened to `cleared`, prior MatchResult entries are marked
`superseded`, and a new discrepancy is raised until replacement reconciliation
is confirmed.

#### Key Invariants

1. **Reconciliation never mutates posting facts** — it tracks workflow state
   and evidence overlays.
2. **Accepted matching is one-to-one** within a session (row-to-posting and
   posting-to-row).
3. **`reconciled` requires explicit confirmation** — never auto-set by import.
4. **All transitions are auditable** via append-only logs.
5. **Critical discrepancies block close** until resolved.

### Reporting and projection

The Reporting context (`AurumFinance.Reporting`) is a read-only analytics layer
built from ledger facts and classification overlays via derived read models.
See ADR-0017 for reporting architecture and ADR-0006 for product posture
(retrospective + projection, not envelope budgeting).

#### Reporting Model Principles

1. Reporting data is derived; it is never authoritative over ledger facts.
2. Historical actuals and forward projections are represented as distinct
   datasets with explicit labeling.
3. Report outputs preserve drilldown linkage back to transactions/postings.
4. FX conversion behavior is explicit (rate type, jurisdiction, strategy, as-of).

#### Conceptual Read Models

- Balance timelines by account/entity.
- Period aggregates (cashflow, category, counterpart dimensions).
- Net worth snapshots.
- Portfolio valuation snapshots (for investment-capable accounts).
- Projection views (recurring-derived forecasts, scenario overlays).

#### Reporting Invariants

1. No reporting view may mutate ledger, classification, or reconciliation facts.
2. Rebuilding read models from facts must produce deterministic results for the
   same input and conversion policy.
3. Missing FX/price data must surface as explicit incomplete/unavailable states,
   not silent interpolation.

## Multi-jurisdiction and FX constraints

- Jurisdictions are extensible and not hardcoded to one country.
- Currency pairs support multiple named rate series by jurisdiction and purpose.
- Fiscal residency determines default tax-relevant conversion series.
- Tax-relevant conversion snapshots are immutable once attached to events.
- Original amounts/currencies are always stored; conversions are read-time derivations.
