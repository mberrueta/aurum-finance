# Execution Plan: Issue #15 — Import Ingestion Pipeline (Uploaded Files, Imported Rows, Async Processing, Preview)

## Metadata

- **Issue**: `https://github.com/mberrueta/aurum-finance/issues/15`
- **Created**: 2026-03-09
- **Updated**: 2026-03-10
- **Status**: PLANNED
- **Current Task**: Task 10 — Import History and Result Preview UI
- **Depends on**: Issue #10 (Entity Model) — COMPLETED, Issue #11 (Account Model) — COMPLETED, Issue #12 (Ledger Primitives) — COMPLETED, Issue #13 (Audit Trail) — IN PROGRESS

---

## Context

The project already has the core foundations needed for ingestion work:

- entity and account ownership boundaries
- immutable ledger facts and explicit account scoping
- generic audit infrastructure
- LiveView application shell and navigation

The import area, however, is still a mock UI. `ImportLive` currently shows a staged pipeline and preview table, but the data is fake and there is no ingestion context, no persisted uploaded-file model, no persisted imported rows, and no asynchronous processing pipeline.

This milestone establishes the real ingestion pipeline up to the **preview/review** stage only.

It must deliver:

- account-scoped uploaded file persistence
- immutable imported row persistence
- CSV parsing only
- normalization and exact-match row-level dedupe
- asynchronous processing through a background job
- PubSub-driven LiveView updates
- result preview and history UI
- audit coverage for import lifecycle events

This milestone must **not** create ledger transactions or postings.

---

## Objective

Implement an account-scoped, asynchronous CSV ingestion pipeline that stores uploaded files, parses and normalizes rows, detects duplicates at imported-row level, persists immutable imported rows, emits audit events, and presents preview/results in the UI without mutating the ledger.

---

## Scope

- Imports are always scoped to exactly one `Account`.
- `account_id` is mandatory for every uploaded file/import run.
- `entity` may be used in the UI only as an optional helper filter to narrow account selection.
- Upload cannot proceed unless an account is selected.
- Persist uploaded source files in `imported_files`.
- Persist parsed row evidence in `imported_rows`.
- Store files on local filesystem using a configurable base path.
- Compute and store file `sha256` as metadata only.
- Process imports asynchronously through a background job.
- Parse CSV files only in this milestone.
- Normalize canonical row data before dedupe.
- Deduplicate at imported-row level using exact matching on normalized canonical data.
- Persist row-level states (`ready`, `duplicate`, `invalid` or equivalent clearly defined row states).
- Persist import-level execution summary counts and error details.
- Publish import lifecycle updates via PubSub so `ImportLive` updates in real time.
- Show preview/results after processing completes.
- Show failure details if processing fails.
- Show import history per account.
- Emit generic audit events for upload and processing lifecycle actions.
- Add test coverage for upload, async processing, dedupe, immutable row persistence, audit integration, PubSub updates, and failure handling.

---

## Explicit Out of Scope

The following are explicitly excluded from this milestone and must remain excluded from the implementation plan:

1. **Transaction creation.**
   This milestone does not create `transactions`.

2. **Posting creation.**
   This milestone does not create `postings`.

3. **Any ledger mutation.**
   Imported rows remain upstream evidence and preview data only.

4. **Reconciliation.**
   No statement matching against ledger postings in this milestone.

5. **Categorization or rules execution.**
   No classification, rule application, or explainability layer here.

6. **Review approval that materializes into ledger facts.**
   Future milestone / future user action / future background job.

7. **File-level duplicate rejection by `sha256`.**
   Repeated or overlapping uploads are valid and expected.

8. **Fuzzy duplicate matching.**
   Dedupe in v1 is exact-match only on normalized canonical row data.

9. **OFX/QFX/PDF parsing.**
   CSV is the only supported format in this milestone.

10. **A second audit mechanism.**
    Import lifecycle auditing must use the existing generic audit model.

---

## Core Product Decisions

### D1: Import is always account-scoped

Every import targets exactly one `Account`.

Implications:

- `account_id` is mandatory on `imported_files`
- `account_id` is carried on `imported_rows`
- `entity` is derived through the selected account
- `entity_id` must not be stored redundantly on `imported_files`
- upload is blocked until an account is selected

The UI may optionally allow filtering by entity first, but only to narrow the account dropdown. The true scope boundary is the selected account.

### D2: This milestone does not create transactions

This must remain explicit across all sections of the plan.

The pipeline in this milestone does only the following:

- upload file
- store file metadata
- enqueue async processing
- parse rows
- normalize rows
- deduplicate rows
- validate rows
- persist immutable imported rows
- show preview/result summary

It does not:

- create transactions
- create postings
- mutate the ledger
- perform reconciliation
- perform categorization

### D3: File-level duplicate rejection is forbidden

`sha256` must be stored as metadata only.

It may be useful for:

- diagnostics
- support/debugging
- audit context
- investigating repeated uploads

But it must not:

- block upload
- enforce uniqueness
- act as the dedupe boundary

Overlapping and fully repeated files are valid import inputs.

### D4: Duplicate handling happens at imported-row level

The dedupe boundary is the imported row, not the uploaded file.

This supports overlapping statements such as:

- file A: March 1 to March 8
- file B: March 1 to March 18

Expected behavior:

- rows already imported previously are marked/skipped as duplicates
- genuinely new rows remain `ready` for future materialization

Because dedupe is account-scoped and async processing may run concurrently, the final implementation should rely on database-backed uniqueness guarantees in addition to application-level duplicate checks.

### D5: Imported rows are immutable evidence records

Once a file is processed and its imported rows are persisted, those rows must be treated as immutable evidence records.

They should not be silently rewritten later.

If parsing logic changes in the future, the system should create a new import run and new imported rows rather than mutating historical imported rows in place.

This immutability requirement is central to traceability and user trust.

### D6: Audit records are required

Import lifecycle actions must emit generic audit events using the existing project audit model.

At minimum, the plan must cover:

- uploaded / created
- processing_started
- processing_completed
- processing_failed

Future review/approval lifecycle events may be mentioned only as future work.

### D7: Async processing is required

Import processing must be asynchronous.

Implementation note:

- use Oban as the background job mechanism for this milestone
- enqueue one import-processing job per `imported_file`

Expected lifecycle:

1. file uploaded
2. `imported_file` persisted as `pending`
3. file stored on local filesystem
4. background job enqueued
5. job moves status to `processing`
6. job parses, normalizes, dedupes, validates, persists imported rows
7. job marks import as `complete` or `failed`

### D8: PubSub-driven UI updates are required

`ImportLive` must not rely on polling-only assumptions.

The plan should explicitly use PubSub so the UI reflects:

- `pending`
- `processing`
- `complete`
- `failed`

And once complete, the UI should show summary/preview data.

### D9: CSV-only in this milestone

Parser scope is explicitly limited to CSV.

The design should remain future-friendly, but it must not imply that OFX/QFX/PDF exist now.

---

## Architecture Notes

### High-Level Pipeline

Recommended separation of responsibilities:

- **Upload layer / LiveView**
  Accept account-scoped upload input and create the `imported_file` record.

- **File storage layer**
  Save the uploaded payload to local filesystem under a configurable base path.

- **Async job / orchestrator**
  Own the import run lifecycle and status transitions.

- **CSV parser**
  Read the file and produce canonical row candidates.

- **Row normalizer**
  Normalize canonical row fields before dedupe.

- **Fingerprint builder**
  Produce stable row identity from normalized canonical row data.

- **Duplicate detector**
  Compare row fingerprints against existing imported rows for the same account.

- **Row validator**
  Mark row candidates as `ready`, `duplicate`, or `invalid`.

- **Persistence layer**
  Store immutable `imported_rows` and update aggregate summary fields on `imported_files`.

- **PubSub notifier**
  Broadcast lifecycle changes so the LiveView reflects real-time progress.

- **Audit integration**
  Record lifecycle events through the generic audit context.

### Why This Separation Matters

This structure keeps the design reusable for future parsers:

- CSV parser is format-specific
- normalization, fingerprinting, dedupe, validation, persistence, PubSub, and audit are parser-agnostic

That makes future OFX/QFX/PDF support additive rather than a redesign.

### Async Boundary

The async boundary should be explicit:

- user request creates upload record and enqueues work
- background worker performs processing
- worker publishes PubSub updates and audit events
- UI re-renders from durable persisted state

The upload request itself should not perform full file parsing synchronously.

### Traceability Design

Traceability is first-class:

- every imported row points to one imported file
- every imported file points to one account
- every import run has timestamps, summary counts, and processing outcome
- lifecycle audit events capture the operational trail
- historical evidence remains reviewable even after later parser improvements

---

## Data Model Notes

The milestone is based on two explicit persisted concepts.

### A. `imported_files`

This represents the uploaded source file and the import run summary.

Recommended core fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Primary key |
| `account_id` | UUID FK | Yes | Mandatory target account |
| `filename` | `:string` | Yes | Original filename |
| `sha256` | `:string` | Yes | Metadata only; not a duplicate-rejection key |
| `format` | `Ecto.Enum` or `:string` | Yes | `csv` only in this milestone |
| `status` | `Ecto.Enum` | Yes | `pending`, `processing`, `complete`, `failed` |
| `row_count` | `:integer` | No | Total rows read |
| `imported_row_count` | `:integer` | No | Rows persisted as ready |
| `skipped_row_count` | `:integer` | No | Rows marked duplicate |
| `invalid_row_count` | `:integer` | No | Rows marked invalid |
| `error_message` | `:string` | No | Top-level processing failure detail |
| `warnings` | `:map` | No | Structured import-level warnings/inconsistencies for UI and debugging |
| `storage_path` | `:string` | Yes | Local filesystem path |
| `processed_at` | `:utc_datetime_usec` | No | Timestamp when processing finished (complete or failed) |
| `inserted_at` | `:utc_datetime_usec` | Yes | |
| `updated_at` | `:utc_datetime_usec` | Yes | |

Practical optional metadata:

| Field | Type | Required | Notes |
|---|---|---|---|
| `content_type` | `:string` | No | Browser-provided MIME type |
| `byte_size` | `:integer` | No | Size in bytes |

Important notes:

- `entity_id` must not be stored redundantly on `imported_files`
- entity scope is derived by joining through `account_id`
- repeated identical `sha256` values must be allowed
- `warnings` gives the UI a durable summary surface without forcing recalculation on every page load
- `processed_at` supports import-duration measurement and operational debugging
- `processed_at` is intended as a finished-processing timestamp for either `complete` or `failed`; if naming semantics are revisited during implementation, `finished_at` would be a reasonable alternative, but this plan keeps `processed_at`

### B. `imported_rows`

This represents each parsed row from a file. These are immutable evidence records and the dedupe boundary.

Recommended fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Primary key |
| `imported_file_id` | UUID FK | Yes | Belongs to uploaded file/import run |
| `account_id` | UUID FK | Yes | Carried explicitly for row-level scoping and duplicate lookup |
| `row_index` | `:integer` | Yes | Position within the source file |
| `raw_data` | `:map` | Yes | Original parsed row payload for traceability |
| canonical parsed fields | mixed | Yes/No | Whatever parsed columns are needed for review and future materialization |
| `normalized_description` | `:string` | No | Example normalized field called out explicitly |
| `posted_on` | `:date` | No | Parsed/validated posting date candidate |
| `amount` | `:decimal` | No | Parsed/validated amount candidate |
| `currency` | `:string` | No | Parsed/validated currency candidate |
| `fingerprint` | `:string` | No | Stable identity built from normalized canonical row data; required for `ready` and `duplicate`, may be `nil` only for `invalid` rows when canonicalization fails |
| `status` | `Ecto.Enum` or `:string` | Yes | `ready`, `duplicate`, `invalid` or equivalent clearly defined states |
| `skip_reason` | `:string` | No | Duplicate or other skip reason |
| `validation_error` | `:string` | No | Validation detail for invalid rows |
| `inserted_at` | `:utc_datetime_usec` | Yes | |

Important notes:

- `imported_rows` belong to `imported_file`
- they are account-scoped
- they are immutable
- they preserve traceability back to the uploaded file
- they are the substrate for future transaction materialization, but do not create transactions in this milestone
- `fingerprint` should always be present for rows that reach `ready` or `duplicate`
- `fingerprint` may be `nil` only for rows that remain `invalid` because a canonical normalized form could not be built safely

### Immutability Expectations

`imported_rows` should be treated as immutable after insert.

The plan should assume:

- no normal update path for imported rows
- no silent in-place reprocessing of historical rows
- future parser changes create new import runs and new rows

`imported_files` may update status and summary fields as part of processing lifecycle. `imported_rows` should remain evidence records once written.

---

## Normalization and Dedupe Notes

### Canonical Flow

Expected pipeline:

1. CSV parser produces canonical row candidates
2. normalizer cleans canonical row fields
3. fingerprint builder computes stable identity from normalized canonical data
4. importer/orchestrator decides whether row is `ready`, `duplicate`, or `invalid`

### Normalization Rules for V1

Normalization must happen before dedupe.

The plan should explicitly include:

- trim leading/trailing whitespace
- lowercase where appropriate
- collapse repeated internal spaces
- normalize unicode
- remove invisible/non-printable characters
- optionally remove obvious formatting noise when deterministic and safe

Examples that should normalize consistently:

- `Uber `
- ` UBER`
- `uber`

### Dedupe Strategy for V1

Use exact matching on normalized canonical row data.

Do not introduce fuzzy matching or heuristics in this milestone.

This keeps dedupe:

- deterministic
- testable
- reusable across future parsers

### Duplicate Lookup Scope

Duplicate detection should be scoped to the target account.

That means the same normalized row fingerprint may be valid in different accounts without conflict.

### Database Indexing and Concurrency Guardrails

The plan should explicitly include database indexes for duplicate lookup and concurrent insert safety.

Recommended indexes:

- `index(:imported_rows, [:account_id, :fingerprint])`
  This supports the constant duplicate lookup path used by the importer.

- partial unique index on ready rows:

```elixir
unique_index(
  :imported_rows,
  [:account_id, :fingerprint],
  where: "status = 'ready'"
)
```

This protects against two concurrent jobs inserting the same `ready` row for the same account.

If row-status naming or enum persistence requires a slightly different SQL literal, the implementation should adapt the partial-index predicate accordingly while preserving the same invariant.

---

## Workflow and UI Flow

### End-to-End User Flow

The LiveView flow for this milestone should be explicitly:

1. user opens import page
2. optional entity filter narrows accounts
3. user must select an account
4. user uploads file via drag & drop or file picker
5. system creates `imported_file` in `pending`
6. system stores file on local filesystem (configurable path)
7. background job is enqueued
8. UI receives PubSub updates
9. when complete, UI shows result summary and preview
10. when failed, UI shows error state/details

### Preview / Result Summary

After processing completes, the UI presents:

- rows read
- rows ready
- rows skipped as duplicates
- rows invalid
- import-level warnings/inconsistencies if any
- failure reason if processing fails

This remains a preview/review stage only. No transactions are created here.

### Import History List

Import history per account remains in scope.

History should show at least:

- uploaded file
- status
- timestamps
- counts summary
- ability to inspect preview/results for a given imported file

### LiveView Update Requirements

At minimum, the UI should reflect:

- `pending`
- `processing`
- `complete`
- `failed`

And when complete, it should show the persisted preview/result summary derived from the imported data.

---

## Audit and Traceability Notes

### Traceability is First-Class

The plan must emphasize:

- every imported row can be traced back to its imported file
- every imported file can be traced to account, timestamps, and processing outcome
- import lifecycle emits generic audit events
- historical import evidence remains reviewable

### Audit Event Alignment

Import workflow auditing must align with the project’s generic audit event model already used elsewhere in the codebase.

Do not invent a divergent audit mechanism.

Suggested actions to cover in the plan:

- `uploaded` / `created`
- `processing_started`
- `processing_completed`
- `processing_failed`

The concrete naming should stay consistent with existing project audit conventions when implementation starts.

Audit integration should rely on the same canonical audit context/pattern already in use for entities, accounts, and transaction lifecycle events.

---

## Acceptance Criteria

### Functional

1. Upload cannot proceed unless a target account is selected.
2. The import page may optionally filter by entity only to narrow the account dropdown.
3. A CSV upload creates an `imported_file` record in `pending`.
4. The uploaded payload is stored on local filesystem using a configurable path.
5. A background job is enqueued after upload.
6. Processing transitions the import through `pending -> processing -> complete|failed`.
7. CSV rows are parsed into canonical row candidates.
8. Canonical row data is normalized before dedupe.
9. Dedupe uses exact matching on normalized canonical row data at imported-row level.
10. Repeated and overlapping uploads for the same account are allowed.
11. Previously imported rows are marked/skipped as duplicates instead of blocking the file.
12. New rows are persisted as immutable `imported_rows`.
13. Invalid rows are persisted with row-level invalid state and validation detail.
14. No transactions or postings are created during this milestone.
15. LiveView is updated via PubSub for import lifecycle state changes.
16. After completion, the UI shows preview and summary counts.
17. After failure, the UI shows error state and failure reason.
18. Import history is viewable per account.
19. Generic audit events exist for upload and processing lifecycle transitions.
20. Duplicate lookup is backed by an account+fingerprint index.
21. Concurrent processing cannot create duplicate `ready` rows for the same account/fingerprint because the database enforces the invariant.
22. Import-level warnings can be shown from persisted `warnings` data without recomputing all warning logic on every UI load.
23. Rows in `ready` or `duplicate` state always have a fingerprint; only `invalid` rows may omit it if canonicalization fails.

### Non-Functional

1. Parser scope is explicitly CSV-only.
2. Dedupe logic is not coupled to CSV implementation details.
3. `imported_rows` are treated as immutable evidence records.
4. Audit integration uses the project’s existing generic audit model.
5. Tests use deterministic synthetic fixtures.
6. The design remains extensible for future OFX/QFX/PDF parsers.

---

## Task Breakdown

### Task 01 — `imported_files` Schema and Migration

Create the uploaded-file model and persistence layer.

Deliverables:

- schema + migration for `imported_files`
- required `account_id`
- status enum/values: `pending`, `processing`, `complete`, `failed`
- summary fields: `row_count`, `imported_row_count`, `skipped_row_count`, `invalid_row_count`
- `warnings` map field
- `processed_at` timestamp field
- storage metadata fields including `sha256`, `storage_path`
- account-scoped query APIs
- explicit absence of redundant `entity_id`

### Task 02 — `imported_rows` Schema and Migration

Create the parsed-row evidence model and persistence layer.

Deliverables:

- schema + migration for `imported_rows`
- `imported_file_id` + `account_id`
- raw payload preservation
- canonical parsed fields needed for preview/review
- `fingerprint`
- row-level status model (`ready`, `duplicate`, `invalid` or equivalent)
- immutability-oriented design notes and constraints
- explicit fingerprint presence rule for `ready` and `duplicate` rows
- duplicate lookup index on `[:account_id, :fingerprint]`
- partial unique index on `[:account_id, :fingerprint]` for `ready` rows

### Task 03 — Local File Storage Abstraction

Implement storage abstraction for uploaded payloads on local filesystem.

Deliverables:

- configurable base path
- deterministic file placement strategy
- metadata capture (`filename`, `content_type`, `byte_size`, `sha256`, `storage_path`)
- explicit confirmation that repeated `sha256` does not block upload

### Task 04 — CSV Parser Boundary

Define the parser interface and implement CSV-only parsing.

Deliverables:

- parser boundary/behavior
- CSV parser implementation plan
- canonical row candidate output shape
- format validation that rejects non-CSV in this milestone
- parser error model

### Task 05 — Row Normalization Layer

Implement parser-agnostic normalization rules.

Deliverables:

- normalization module
- whitespace/casing/unicode/invisible-character cleanup rules
- normalization examples documented in tests/spec notes

### Task 06 — Fingerprint and Duplicate Detection Layer

Implement exact-match row identity for dedupe.

Deliverables:

- fingerprint builder
- account-scoped duplicate lookup strategy
- explicit exact-match v1 policy
- no fuzzy matching
- no parser-specific dedupe branching
- database uniqueness strategy for concurrent jobs inserting `ready` rows

### Task 07 — Async Background Job Orchestration

Define and implement the background processing workflow.

Deliverables:

- job enqueue path after upload
- job lifecycle transitions on `imported_files`
- processing pipeline: parse -> normalize -> dedupe -> validate -> persist rows -> summarize
- failure handling and retry expectations

### Task 08 — PubSub Notifications for LiveView Updates

Add PubSub-driven lifecycle notifications.

Deliverables:

- event topics scoped appropriately for import updates
- notifications for `pending`, `processing`, `complete`, `failed`
- LiveView subscription/update plan

### Task 09 — Upload LiveView With Account Selection

Replace mocked flow with real upload UX.

Deliverables:

- optional entity filter helper
- required account selection
- drag & drop + file picker
- create `imported_file` in `pending`
- enqueue async job after upload
- loading/status UI states wired to persisted data

### Task 10 — Import History and Result Preview UI

Build the account-scoped preview/review UI after processing.

Deliverables:

- import history list per account
- status/timestamp display
- summary counts display
- ability to inspect results for a selected imported file
- row preview showing ready/duplicate/invalid outcomes
- error state rendering for failed imports

### Task 11 — Audit Event Integration

Wire import lifecycle into the generic audit system.

Deliverables:

- audit events for uploaded/created
- audit events for processing_started
- audit events for processing_completed
- audit events for processing_failed
- alignment with existing audit context/pattern

### Task 12 — Test Coverage

Add deterministic automated tests for the milestone.

Deliverables:

- upload flow tests
- account-selection enforcement tests
- async processing tests
- PubSub update tests
- overlapping upload dedupe tests
- immutable imported-row persistence tests
- failure handling tests
- audit integration tests

### Task 13 — Documentation and Scope Guardrails

Update planning/documentation artifacts so the milestone boundary stays clear.

Deliverables:

- explicit note that transaction creation is out of scope
- explicit note that file-level duplicate rejection is out of scope
- explicit note that CSV is the only supported format in this milestone
- follow-up notes for future materialization/review workflow milestone

---

## Risks and Open Questions

### Risks

1. **Canonical field selection for fingerprints**
   If the canonical row shape is underspecified, dedupe quality will suffer. The implementation task should lock down which normalized fields participate in the fingerprint.

2. **Async/UI race conditions**
   LiveView must read persisted state as the source of truth and treat PubSub as notification, not as the state container.

3. **Immutability vs reprocessing ergonomics**
   The plan is correct to keep imported rows immutable, but future reparsing UX will need careful design.

4. **Import volume**
   Very large CSV files may require batching considerations even if the first implementation starts with a straightforward async job.

### Open Questions

1. Which exact canonical parsed fields beyond `posted_on`, `amount`, `currency`, and normalized description should be first-class columns versus left in `raw_data`?
2. What exact warning keys should be standardized in the `warnings` map for v1 so the UI and tests can rely on a stable shape?
3. Resolved on 2026-03-10: Oban is the background job mechanism for import processing.

---

## Definition of Done

This milestone is done when all of the following are true:

- imports are account-scoped
- processing is async via background job
- LiveView updates via PubSub
- uploaded files are persisted in `imported_files`
- parsed rows are persisted in immutable `imported_rows`
- duplicate handling is row-level, not file-level
- repeated and overlapping uploads are supported
- audit events are emitted for import lifecycle transitions
- CSV is the only supported parser format
- preview/history UI is functional
- transaction creation remains explicitly out of scope and unimplemented
