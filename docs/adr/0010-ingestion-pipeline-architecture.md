# ADR 0010: Ingestion Pipeline Architecture

- Status: Accepted
- Date: 2026-03-05
- Updated: 2026-03-11
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: `llms/tasks/002_architecture_system_design/plan.md` and Issue #17 implementation

## Context

AurumFinance imports external financial files as durable evidence first and only
later materializes eligible rows into immutable ledger facts. The pipeline must:

1. preserve raw import evidence
2. keep duplicate and invalid rows visible without mutating the evidence
3. support async, traceable, idempotent ledger materialization
4. avoid double commit under retries or reruns
5. keep CSV v1 recovery simple when the source file is wrong

ADR-0004 still applies: imported evidence and ledger facts are immutable; later
workflow state is modeled separately. ADR-0007 still applies: `Ingestion`
depends on `Ledger`, but `Ledger` does not know about imports.

## Decision Drivers

1. Imported CSV rows are evidence and must remain durable and immutable.
2. CSV v1 should not introduce a row-level approval overlay.
3. Duplicate rows must not be manually overrideable in v1.
4. Materialization must be retry-safe, observable, and auditable.
5. Users need row-level traceability from imported evidence to ledger
   transactions.
6. Wrong CSV recovery should be operationally simple: delete and re-import.

## Decision

### 1. Pipeline Stages

The implemented ingestion flow is split into two major phases:

```text
Upload & Store
  -> Parse & Normalize
  -> Validate & Deduplicate
  -> Persist imported_rows as immutable evidence
  -> Preview / inspect imported file details
  -> Request async materialization
  -> Persist import_materialization run
  -> Worker evaluates rows and writes ledger facts
  -> Persist import_row_materializations outcomes
```

### 2. Durable Model

The ingestion context owns four primary records for CSV v1:

| Entity | Purpose |
|---|---|
| `ImportedFile` | One uploaded source file and its processing lifecycle |
| `ImportedRow` | One immutable parsed row of evidence |
| `ImportMaterialization` | One async materialization run for one imported file |
| `ImportRowMaterialization` | One durable row outcome within one run |

This replaces the earlier conceptual `ImportBatch` / mutable review overlay
model for current implementation purposes.

### 3. Imported Evidence Model

`ImportedFile` and `ImportedRow` form the immutable evidence layer.

`ImportedFile` stores:

- `account_id`
- file identity and storage metadata
- async processing status
- row counters and processing summary

`ImportedRow` stores:

- `imported_file_id`
- `account_id`
- `row_index`
- `raw_data`
- normalized evidence fields such as `description`, `posted_on`, `amount`,
  `currency`, and `fingerprint`
- row evidence status: `ready`, `duplicate`, `invalid`
- `skip_reason` or `validation_error` when applicable

Rows are never mutated into approval states. There is no `approved`,
`rejected`, or `force_approved` workflow in CSV v1.

### 4. Preview / Review Surface

The imported-file details page is the review surface for v1. It provides:

- imported file summary
- visibility into `ready`, `duplicate`, and `invalid` rows
- duplicate visibility without override controls
- materialization run history
- row-level materialization results and traceability
- hard delete action when still allowed

The user does not approve rows one by one. The review decision is effectively:

- materialize eligible rows
- or delete the imported file and re-import a corrected CSV

### 5. Eligibility Rules

CSV v1 materialization eligibility is:

- `ready` + not already committed + no currency mismatch => materializable
- `duplicate` => not materializable
- `invalid` => not materializable
- already committed => not materializable
- currency mismatch => not materializable and produces row-level `failed`

There is no manual duplicate override path in v1.

### 6. Async Materialization Model

Materialization is modeled explicitly and durably before any ledger writes:

1. user requests materialization from imported-file details
2. system creates an `ImportMaterialization` with status `pending`
3. an Oban worker processes the run asynchronously
4. the worker evaluates every imported row for that file
5. one `ImportRowMaterialization` is persisted for every evaluated row,
   including `skipped`
6. eligible rows create ledger `Transaction` facts with `source_type: :import`

Run statuses are:

- `pending`
- `processing`
- `completed`
- `completed_with_errors`
- `failed`

Row outcome statuses are:

- `committed`
- `skipped`
- `failed`

### 7. Row Outcome Policy

Every evaluated row produces a durable row outcome record.

Current outcome mapping:

- `duplicate` => `skipped`
- `invalid` => `skipped`
- already committed from a prior run => `skipped`
- currency mismatch => `failed`
- missing required ledger facts => `failed`
- valid ready row => `committed`

Counters on `ImportMaterialization` summarize the run, but they do not replace
row-level durable outcomes.

### 8. Idempotency and No-Double-Commit

Idempotency is enforced at row-materialization level:

- a row already committed in any prior run is skipped in reruns
- committed row uniqueness is anchored in durable storage
- reruns preserve traceability by recording explicit `skipped` outcomes

The system also rejects creating a new materialization run when another run for
the same imported file is already `pending` or `processing`.

### 9. Native-Currency-Only Materialization

Materialization always uses the imported account's native currency:

- `account.currency_code` is the source of truth
- `imported_row.currency` is evidence only
- no FX conversion occurs during ledger materialization

If row currency conflicts with account currency, that row fails at row level
and no ledger facts are written for it.

### 10. Clearing Account Strategy

Import materialization uses one system-managed balancing account per
`entity_id + currency_code`:

- account type: `equity`
- management group: `system_managed`
- deterministic identity and reuse
- created automatically on first use if missing

This account is used only to balance import-created transactions.

### 11. Recovery Path for Wrong CSV Files

CSV v1 recovery is intentionally simple:

1. hard delete the `ImportedFile`
2. hard delete its `ImportedRow` evidence
3. re-import the corrected CSV

Hard delete is allowed only before any materialization workflow state exists for
that imported file. If any materialization run already exists, rollback or
unmaterialize must happen through a dedicated future workflow outside Issue 17.

## Rationale

### Why remove row-level approval?

For CSV v1 it adds workflow complexity without improving correctness enough.
`ready` already expresses the system's best materializable evidence state.

### Why keep materialization separate from imported rows?

Imported rows are evidence. Materialization is operational workflow. Separating
them preserves immutability and keeps reruns, retries, and traceability clean.

### Why durable row outcomes for skipped rows too?

Without explicit skipped outcomes, reruns become harder to explain and the UI
cannot reliably show what happened to each row across runs.

### Why hard delete for wrong CSVs?

CSV is editable outside the system. For v1, delete plus re-import is simpler
and safer than introducing in-system correction or override workflows.

## Consequences

### Positive

- imported evidence remains immutable
- CSV v1 stays operationally simple
- reruns are traceable and idempotent
- duplicate rows are visible without risking double materialization
- row-to-transaction provenance is explicit and queryable
- async execution keeps the UI responsive while preserving durable workflow state

### Trade-offs

- there is no in-product correction workflow for bad CSV content
- duplicates cannot be manually overridden in v1
- classification is not part of the current materialization path
- failed runs may require future rollback/unmaterialize work for full recovery

## Implementation Notes

- `ImportedFile` and `ImportedRow` are account-scoped within an entity boundary
- materialization is asynchronous via Oban
- PubSub is notification-only; durable state lives in the database
- audit is workflow-level, not per-row approval
- future row notes/comments may be added later as informational metadata only,
  separate from materialization workflow

## Relationship to Other ADRs

- **ADR-0004:** imported evidence and ledger facts remain immutable
- **ADR-0007:** `Ingestion` orchestrates `Ledger`; dependency is one-way
- **ADR-0008:** committed rows create ledger transactions with immutable postings
- **ADR-0009:** imports are ultimately scoped through the selected target account
- **ADR-0011:** classification remains a separate concern and is not coupled to
  CSV v1 materialization workflow
