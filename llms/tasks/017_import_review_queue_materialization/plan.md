# Execution Plan: Issue #17 — Import Review Queue and Ledger Materialization

## Metadata

- **Issue**: `https://github.com/mberrueta/aurum-finance/issues/17`
- **Created**: 2026-03-10
- **Updated**: 2026-03-10
- **Status**: PLANNED
- **Current Task**: None started
- **Depends on**: Issue #12 (Ledger Primitives) — COMPLETED, Issue #13 (Audit Trail) — IN PROGRESS, Issue #15 (Import Ingestion Pipeline) — COMPLETED

---

## Context

Issue #15 established the ingestion foundation:

- account-scoped uploaded files in `imported_files`
- immutable row evidence in `imported_rows`
- CSV parsing, normalization, and exact-match imported-row dedupe
- Oban-based async import processing
- PubSub-driven import status updates
- preview/history UI in `ImportLive` and `ImportDetailsLive`

That work intentionally stopped before touching the ledger.

The current imported-file details page already shows the persisted preview for one upload at:

- `/import/accounts/:account_id/files/:imported_file_id`

This issue is the next stage. It turns that preview into a true review queue and introduces a controlled, asynchronous materialization workflow that creates ledger transactions from approved imported rows.

This milestone must preserve the issue #15 boundary:

- `imported_rows` remain immutable evidence
- PubSub remains notification-only; LiveViews must always reload durable state
- large row sets must remain stream-friendly in LiveView

Currency boundaries from the existing ledger model also remain in force:

- every `Account` in AurumFinance is single-currency
- `account.currency_code` is the source of truth for ledger postings
- if a real-world institution supports multiple currencies, that must be modeled as separate accounts in AurumFinance rather than multi-currency postings within one account
- import remains account-scoped and therefore effectively single-currency for materialization purposes
- `imported_rows.currency` may be retained as evidence/debugging/UI context, but it is not a second source of truth for ledger writes

Even if a real-world transaction was originally performed in a foreign currency,
financial institutions typically convert the amount before it appears in the
account statement. Therefore imported rows are normally already expressed in
the account's native currency.

---

## Objective

Implement a post-ingestion review and materialization workflow that extends the existing import details page with review actions and a `Materialize` trigger, enqueues asynchronous ledger creation via Oban, broadcasts progress through PubSub, preserves end-to-end traceability from `imported_row` to created `transaction` and `postings`, and materializes imported rows only in the imported account's native currency without FX conversion.

---

## Scope

- Build on the existing `imported_files` and `imported_rows` models from issue #15.
- Extend the import details page into the first review queue UI for one imported file.
- Add a primary `Materialize` action on the imported-file details screen.
- Support async materialization through a dedicated Oban worker.
- Broadcast review/materialization lifecycle updates via PubSub.
- Keep imported-row rendering stream-based for large imports.
- Introduce durable workflow persistence for review decisions and materialization runs.
- Allow bulk approval of clearly non-duplicate rows.
- Allow explicit row-level override for duplicate candidates before materialization.
- Materialize approved rows into balanced ledger transactions/postings.
- Preserve traceability from imported rows to created ledger records.
- Add batch-level audit events for review/materialization actions.
- Add deterministic test coverage for review UI, async materialization, traceability, and failure handling.

---

## Explicit Out of Scope

The following are explicitly excluded from this milestone:

1. **Institution-specific CSV profiles or header mapping.**
   That belongs to issue #43.

2. **Parser redesign.**
   This issue must not re-implement parsing, normalization, or imported-row dedupe already delivered in issue #15.

3. **Fuzzy duplicate matching.**
   Imported-row duplicate detection remains exact-match only.

4. **Reconciliation workflow.**
   Reconciliation states and matching remain issue #18.

5. **Rules execution, categorization, or explainability.**
   Those remain in the rules issues (#19, #20, #21, #22).

6. **OFX/QFX/PDF support.**
   CSV remains the only parser format in the current pipeline.

7. **Inline synchronous ledger creation from the LiveView request.**
   Materialization must run asynchronously through Oban.

---

## Project Context

### Related Entities

- `AurumFinance.Ingestion.ImportedFile`
  - Location: `lib/aurum_finance/ingestion/imported_file.ex`
  - Relevant fields: `account_id`, `status`, `row_count`, `imported_row_count`, `skipped_row_count`, `invalid_row_count`, `warnings`, `processed_at`
  - Relevance: current import-run header and current source of truth for preview/history

- `AurumFinance.Ingestion.ImportedRow`
  - Location: `lib/aurum_finance/ingestion/imported_row.ex`
  - Relevant fields: `imported_file_id`, `account_id`, `row_index`, `posted_on`, `description`, `amount`, `currency`, `fingerprint`, `status`, `skip_reason`, `validation_error`
  - Relevance: immutable row evidence that will feed review and materialization

- `AurumFinance.Ledger.Transaction`
  - Location: `lib/aurum_finance/ledger/transaction.ex`
  - Relevant fields: `entity_id`, `date`, `description`, `source_type`, `correlation_id`
  - Relevance: target ledger header created from approved imported rows

- `AurumFinance.Ledger.Posting`
  - Location: `lib/aurum_finance/ledger/posting.ex`
  - Relevant fields: `transaction_id`, `account_id`, `amount`
  - Relevance: target ledger legs created from approved imported rows

- `AurumFinance.Ledger.Account`
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Relevant fields: `entity_id`, `currency_code`, `management_group`, `account_type`
  - Relevance: imported rows belong to one institution account; materialization also needs a counterparty account strategy to keep postings balanced

- `AurumFinance.Audit`
  - Location: `lib/aurum_finance/audit.ex`
  - Relevance: batch-level review/materialization audit must use the existing generic audit infrastructure

### Related Features

- **Import upload/history**
  - `lib/aurum_finance_web/live/import_live.ex`
  - Pattern to follow: account-scoped list, Oban enqueue after user action, PubSub refresh, stream-based LiveView lists

- **Import details preview**
  - `lib/aurum_finance_web/live/import_details_live.ex`
  - `lib/aurum_finance_web/live/import_details_live.html.heex`
  - Pattern to follow: one imported-file detail page that reloads durable state on PubSub notifications and streams imported rows into a table

- **Import async processing**
  - `lib/aurum_finance/ingestion/import_worker.ex`
  - `lib/aurum_finance/ingestion/pubsub.ex`
  - Pattern to follow: one worker per imported-file lifecycle, plus PubSub notifications scoped to account and imported-file

### Permissions Model

- Access today is authenticated-root only through the existing `:app` live session in `AurumFinanceWeb.Router`.
- Import and review remain account-scoped and therefore indirectly entity-scoped through `account_id`.
- No new role model is introduced in this milestone.

### Naming Conventions Observed

- Contexts: `AurumFinance.Ingestion`, `AurumFinance.Ledger`, `AurumFinance.Audit`
- Schemas: singular, namespaced by context
- LiveViews: `*Live` modules with route-backed pages
- Async jobs: `*Worker` modules backed by Oban
- Queries: `list_*`, `get_*!`, `*_query/1`, recursive `filter_query/2`

---

## Core Product Decisions

### D1: The existing import details page becomes the first review queue

Do not create a completely separate review surface for v1.

The existing imported-file details page should be extended so that:

- it keeps the current summary and preview role
- it adds review actions for imported rows
- it adds a prominent `Materialize` button
- it shows async materialization progress and outcomes for the same imported file

This keeps user flow compact and reuses the page that already displays persisted imported-row evidence.

### D2: Imported rows remain immutable evidence

`imported_rows` from issue #15 must continue to be treated as immutable evidence records.

This means:

- no destructive rewrite of imported-row facts
- no repurposing imported-row `status` into mutable review workflow state
- review/materialization state must live in new workflow persistence, not by mutating the original evidence semantics

### D3: Review state and materialization state are separate concerns

The workflow should distinguish:

- imported-row evidence state from issue #15 (`ready`, `duplicate`, `invalid`)
- human review decision state
- async materialization run state

Recommended persisted concepts:

- `import_row_reviews`
  - one overlay record per imported row when a human or bulk action makes a review decision
  - decisions such as `approved`, `rejected`, `force_approved`

- `import_materializations`
  - one materialization run record per imported-file trigger
  - statuses such as `pending`, `processing`, `completed`, `completed_with_errors`, `failed`

Alternative naming is acceptable, but the separation of concerns is not optional.

For v1, this plan chooses:

- `import_row_reviews` as a latest-state overlay per imported row
- workflow history captured through `audit_events` rather than append-only review rows
- top-level materialization run statuses of `pending`, `processing`, `completed`, `completed_with_errors`, and `failed`

### D4: `Materialize` is a user-triggered async action

The button on the imported-file details page should not create ledger records inline.

Expected flow:

1. user opens imported-file details page
2. user reviews rows
3. user clicks `Materialize`
4. system persists a materialization run in `pending`
5. system enqueues an Oban job
6. worker moves the run to `processing`
7. worker creates ledger transactions/postings for approved rows
8. worker marks the run `completed`, `completed_with_errors`, or `failed`
9. UI refreshes through PubSub

### D5: Bulk materialization defaults to imported rows that are safe to commit

The current imported-row statuses already separate:

- `ready`
- `duplicate`
- `invalid`

For v1:

- `invalid` rows are never materializable
- `ready` rows may be bulk-approved and materialized
- `duplicate` rows require explicit override before they can be materialized

This keeps the first version conservative and aligned with the dedupe semantics introduced in issue #15.

### D6: Materialization must preserve ledger balance through a clearing-account strategy

Each imported row only identifies one institution account and one signed amount. The ledger requires balanced postings.

Therefore, materialization must define a counterparty strategy. The recommended v1 strategy is:

- create or reuse one system-managed import clearing account per entity and currency
- each approved imported row becomes one transaction with two postings:
  - posting to the imported institution account using the row amount
  - offsetting posting to the import clearing account using the negated amount

This keeps ledger invariants intact while leaving later categorization/reclassification work to downstream issues.

The clearing account must always be resolved in the same currency as the imported account. This issue does not allow cross-currency balancing inside one materialized transaction.

### D7: The ledger write model is native-currency only

Materialization must follow the existing ledger currency contract exactly:

- every account is single-currency
- the effective posting currency is always `account.currency_code`
- materialization always uses the imported account's native currency
- materialization must not perform FX conversion
- `imported_rows.currency` is evidence only and must not override `account.currency_code`

If `imported_row.currency` is present and conflicts with `account.currency_code`, the row must be treated as invalid for materialization in v1 and skipped or failed with an explicit, durable error. It must not be converted.

### D8: Traceability is required and must be durable

After materialization, the system must be able to answer:

- which imported row created which transaction
- which materialization run created which transactions
- which rows were rejected vs approved
- whether a row was already committed

This traceability must be queryable from durable storage, not reconstructed heuristically.

### D9: Reporting conversion is separate from ledger materialization

The ledger stores native-currency facts only.

That means:

- imported transactions are written in the imported account's currency only
- no conversion to base currency or presentation currency occurs during materialization
- any future currency projection belongs to reporting/read models, not to this workflow

This issue must not introduce wording or behavior that implies multi-currency postings inside one account or FX-aware ledger materialization.

### D10: Audit should happen at review/materialization boundaries, not per normal transaction insert

Project context explicitly keeps transaction/posting creation audit narrow.

Therefore this issue should add audit at the workflow level:

- materialization requested
- row approved / rejected when durable review decisions are persisted
- materialization completed
- materialization failed

It should not introduce noisy per-transaction audit events for ordinary imported transaction creation.

---

## Architecture Notes

### High-Level Workflow

Recommended separation of responsibilities:

- **Review UI / `ImportDetailsLive`**
  - shows imported rows
  - allows row-level review decisions
  - supports bulk approval of `ready` rows
  - exposes `Materialize` button

- **Review persistence layer**
  - stores user review decisions independent from imported-row evidence

- **Materialization run layer**
  - records each async run and its counts/status/error details

- **Async worker / orchestrator**
  - fetches approved rows
  - creates ledger transactions/postings
  - marks rows/runs as committed
  - broadcasts PubSub updates

- **Traceability layer**
  - records imported-row to transaction linkage

- **Audit integration**
  - emits workflow-level events

### Why This Structure Matters

This keeps concerns clean:

- imported-row evidence stays immutable
- review workflow stays explicit and inspectable
- async runs remain restartable and observable
- transaction creation remains isolated in a background worker

The ledger stores economic facts in native account currency only.
Currency conversion, presentation currencies, or FX-aware projections
belong to reporting/read models and are explicitly outside the scope
of ledger materialization.

### Async Boundary

The async boundary should mirror issue #15:

- LiveView request persists intent and enqueues work
- worker does durable processing
- PubSub notifies the UI
- UI reloads from persisted state

This is especially important because materialization may create many transactions and may fail mid-run.

### Streaming and Large Imports

The current imported-file details page already streams `@streams.imported_rows`.

That pattern should be preserved and extended:

- keep rows rendered with LiveView streams
- add filters and counts without loading alternate giant lists into assigns unnecessarily
- if row-level review decisions need to update visible row state, re-stream the changed rows or reset the stream from durable state

---

## Data Model Notes

Issue #15 already provides `imported_files` and `imported_rows`. This milestone should add workflow persistence rather than rewriting those tables semantically.

### A. `import_row_reviews`

Represents review decisions for imported rows.

Recommended fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Primary key |
| `imported_row_id` | UUID FK | Yes | One decision overlay targets one imported row |
| `decision` | `Ecto.Enum` | Yes | `approved`, `rejected`, `force_approved` |
| `reviewed_by` | `:string` | Yes | Authenticated actor string |
| `review_reason` | `:string` | No | Optional human note or machine-set bulk rationale |
| `inserted_at` | `:utc_datetime_usec` | Yes | Decision timestamp |
| `updated_at` | `:utc_datetime_usec` | Yes | Used because v1 chooses latest-state overlay semantics rather than append-only review rows |

Important notes:

- For v1, use one latest-state overlay per imported row rather than append-only review rows.
- Review history should be captured through audit events rather than by retaining multiple review-row versions.
- `imported_rows` themselves should not absorb these mutable review decisions.

### B. `import_materializations`

Represents one async materialization request/run.

Recommended fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Primary key |
| `imported_file_id` | UUID FK | Yes | One run belongs to one imported file |
| `account_id` | UUID FK | Yes | Scope boundary copied explicitly for queryability |
| `status` | `Ecto.Enum` | Yes | `pending`, `processing`, `completed`, `completed_with_errors`, `failed` |
| `requested_by` | `:string` | Yes | Authenticated actor string |
| `rows_considered` | `:integer` | No | Candidate rows reviewed for this run |
| `rows_materialized` | `:integer` | No | Successful committed rows |
| `rows_rejected` | `:integer` | No | Explicitly rejected rows excluded from this run |
| `rows_skipped_duplicate` | `:integer` | No | Duplicate rows not force-approved |
| `rows_failed` | `:integer` | No | Rows that failed during commit |
| `error_message` | `:string` | No | Top-level failure detail |
| `started_at` | `:utc_datetime_usec` | No | Worker start time |
| `finished_at` | `:utc_datetime_usec` | No | Worker completion/failure time |
| `inserted_at` | `:utc_datetime_usec` | Yes | |
| `updated_at` | `:utc_datetime_usec` | Yes | |

Important notes:

- `completed` means all eligible rows finished without row-level failures.
- `completed_with_errors` means the run finished, but one or more rows failed during materialization or materializability validation.
- `failed` is reserved for unrecoverable run-wide failures where the run itself did not complete cleanly.

### C. `import_row_materializations`

Represents row-level traceability between imported-row evidence and created ledger facts.

Recommended fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | UUID | Yes | Primary key |
| `import_materialization_id` | UUID FK | Yes | Belongs to one run |
| `imported_row_id` | UUID FK | Yes | The source evidence row |
| `transaction_id` | UUID FK | No | Present when row was successfully committed |
| `status` | `Ecto.Enum` | Yes | `committed`, `skipped`, `failed` |
| `failure_reason` | `:string` | No | Present when row-level commit fails |
| `inserted_at` | `:utc_datetime_usec` | Yes | |

Important notes:

- Add a unique constraint that prevents the same imported row from being committed twice.
- This table is the safest place to enforce idempotency for async retries and concurrent user actions.

### D. Import Clearing Account Strategy

The plan should explicitly introduce a system-managed counterparty concept for import materialization.

Recommended behavior:

- resolve the entity through the imported account
- find or create one system-managed import clearing account for that entity and the imported account currency
- use that account as the balancing leg for all imported transactions in v1

This does not solve categorization. It solves balanced ledger creation.

### E. Currency Semantics for Imported Rows

`imported_rows.currency` may continue to exist because it is useful for:

- evidence and debugging
- import preview UI
- future views that aggregate rows from different imports

However, it is not an independent materialization input.

For v1 materialization:

- the source-of-truth currency is always `imported_row.account.currency_code`
- postings derive their effective currency from the referenced accounts, as in the rest of the ledger
- if `imported_row.currency` is present and matches `account.currency_code`, materialization may proceed
- if `imported_row.currency` is absent, materialization may still proceed using `account.currency_code`
- if `imported_row.currency` is present and does not match `account.currency_code`, the row is not materializable in v1 and must produce a failed row outcome with explicit error detail

No FX conversion, currency fallback heuristics, or mixed-currency posting behavior is allowed in this issue.

---

## Materialization and Idempotency Notes

### Row Eligibility Rules

Expected row selection logic for one run:

- `ready` rows:
  - eligible by default unless explicitly rejected

- `duplicate` rows:
  - not eligible unless explicitly `force_approved`

- `invalid` rows:
  - never eligible

- rows whose `imported_row.currency` conflicts with `account.currency_code`:
  - never eligible in v1
  - must produce an explicit failed row outcome with durable currency-mismatch detail
  - must not be converted

- already committed rows:
  - never eligible again

### Commit Semantics

For each eligible imported row, create:

1. one `transaction` with `source_type: :import`
2. one posting on the imported institution account
3. one offsetting posting on the import clearing account resolved in the same currency as the imported institution account
4. one durable linkage record from imported row to transaction

Both postings therefore remain native-currency postings derived from account references. No FX conversion occurs during commit.

### Idempotency Guardrails

The worker must be safe under retry.

Recommended protections:

- unique constraint on row-to-transaction materialization linkage
- worker always re-checks durable committed state before creating a transaction
- batch job treats already-committed rows as skipped/idempotent rather than fatal

### Partial Failure Policy

The plan chooses row-level isolation inside a batch run:

- one bad row should not necessarily roll back a large materialization run
- the run should record mixed outcomes explicitly
- top-level run statuses are:
  - `completed` when all eligible rows finish without row-level failures
  - `completed_with_errors` when the run finishes but one or more rows fail
  - `failed` only for unrecoverable run-wide failures

This policy is fixed now so schema, UI, and tests can align on one state model.

---

## Workflow and UI Flow

### End-to-End User Flow

1. user uploads and processes a CSV via issue #15 flow
2. user opens the imported-file details page
3. page shows persisted preview rows, summary counts, and review controls
4. user bulk-approves safe rows and optionally force-approves/rejects edge cases
5. user clicks `Materialize`
6. system creates a materialization run in `pending`
7. system enqueues an Oban job
8. UI receives PubSub notifications and refreshes status
9. worker creates transactions/postings for approved rows
10. UI shows run summary and row-level materialization outcomes

### Review Queue UX

The current details page should evolve to support:

- visible segmentation of `ready`, `duplicate`, and `invalid` rows
- row-level review affordances
- bulk action for safe rows
- duplicate-candidate inspection
- `Materialize` action only when there is something eligible to commit

### Duplicate Review UX

For `duplicate` imported rows, the UI should support comparing:

- incoming imported row data
- existing matched imported row evidence that explains the duplicate
- when available, the linked materialized transaction for that matched evidence

This can be delivered as a side panel, drawer, or inline expansion on the same page.

### Materialization Trigger UX

The `Materialize` button should:

- live on the imported-file details page
- show disabled state when no rows are eligible
- create a durable run record before enqueueing
- provide immediate feedback that async processing started

### Status UX

At minimum, the imported-file details page should show:

- no materialization yet
- materialization pending
- materialization processing
- materialization completed
- materialization completed with errors
- materialization failed

And once complete, it should show:

- rows materialized
- rows skipped
- rows failed
- linkable traceability to created transactions where applicable

---

## PubSub Notes

Issue #15 already publishes import lifecycle updates. This issue should mirror that pattern for materialization lifecycle updates.

Recommended events:

- `materialization_requested`
- `materialization_processing`
- `materialization_completed`
- `materialization_failed`
- optional row-review updates if the page should refresh counts immediately after review actions

Recommended topics:

- imported-file detail topic
- account-scoped import history topic if summary counts change there
- materialization-run topic if a dedicated detail component/view is introduced

As with import PubSub:

- PubSub is notification only
- LiveView must re-read persisted state after receiving an event

---

## Audit and Traceability Notes

### Required Audit Events

This issue should use the existing generic audit model for workflow actions such as:

- `materialization_requested`
- `row_reviewed`
- `materialization_completed`
- `materialization_failed`

If row-level audit becomes too noisy, batch review actions are acceptable so long as the durable row-review records remain queryable.

### Traceability Requirements

The finished system must support:

- imported-file -> materialization runs
- imported-row -> review decision
- imported-row -> materialization record
- imported-row -> transaction
- transaction -> postings

This is essential for user trust and future debugging.

---

## Acceptance Criteria

### Functional

1. The imported-file details page shows review controls in addition to preview data.
2. A visible `Materialize` button exists on the imported-file details page.
3. `Materialize` does not perform ledger creation inline; it creates a durable run and enqueues an Oban job.
4. `ready` rows can be bulk-approved for materialization.
5. `duplicate` rows require explicit override before they can be materialized.
6. `invalid` rows cannot be materialized.
7. Materialization run status transitions through `pending -> processing -> completed|completed_with_errors|failed`.
8. PubSub updates the imported-file details page when materialization status changes.
9. Large row sets continue to render through LiveView streams rather than regular assigns.
10. Approved imported rows create balanced ledger transactions/postings using `Ledger.create_transaction/2` or equivalent context-safe API.
11. Materialized transactions use `source_type: :import`.
12. Materialization always uses the imported account's native currency as defined by `account.currency_code`.
13. If `imported_row.currency` is present and conflicts with `account.currency_code`, the row produces a failed materialization outcome with explicit error detail and is not converted.
14. The clearing account used for balancing is resolved in the same currency as the imported account.
15. Every committed imported row has durable traceability to the created transaction.
16. The same imported row cannot be committed twice, even under retries or concurrent requests.
17. Materialization results are visible on the imported-file details page after the job completes.
18. Batch-level audit events are emitted for materialization lifecycle actions.
19. Review/materialization state does not corrupt the immutable evidence semantics of `imported_rows`.

### Non-Functional

1. Materialization remains account-scoped and entity-safe through existing ownership boundaries.
2. The workflow follows the same async architecture pattern already used in import processing.
3. PubSub is used as a notification channel only, not as a state store.
4. The UI remains responsive for large imports through stream-based rendering and batched durable operations.
5. The ledger write model remains native-currency only and performs no FX conversion during materialization.
6. Tests are deterministic and safe under DB sandbox execution.

---

## Task Breakdown

### Task 01 — Review and Materialization Domain Contract

Define the review/materialization lifecycle and its boundaries against issue #15.

Deliverables:

- explicit lifecycle contract for imported-row evidence vs review state vs materialization state
- approved terminology for new persisted concepts
- explicit idempotency and retry expectations
- explicit decision on batch-level vs row-level failure semantics

### Task 02 — Review Workflow Schema and Migration

Persist review decisions independently of imported-row evidence.

Deliverables:

- schema + migration for row review decisions
- account/imported-row query support
- conflict/update strategy for repeated review actions
- constraints that preserve one coherent current decision per row

### Task 03 — Materialization Run and Traceability Schemas

Persist async run state and row-to-transaction linkage.

Deliverables:

- schema + migration for materialization runs
- schema + migration for row-level materialization results/links
- unique constraints preventing double commit
- account/imported-file query APIs for run history and outcomes

### Task 04 — Clearing Account Strategy

Define the balancing-account resolution used during imported-row materialization.

Deliverables:

- deterministic clearing-account resolution rules
- system-managed account creation/reuse policy
- tests proving balanced postings per imported row

### Task 05 — Review Context API

Add context functions for review decisions and materialization orchestration.

Deliverables:

- list/query APIs for review rows
- approve/reject/force-approve APIs
- `request_materialization/2` or equivalent enqueue entry point
- clear ownership-boundary enforcement

### Task 06 — Materialization Worker and Async Orchestrator

Implement async ledger creation from approved imported rows.

Deliverables:

- dedicated Oban worker for materialization
- run lifecycle transitions
- transaction/posting creation pipeline
- retry-safe/idempotent behavior
- partial failure handling

### Task 07 — PubSub Notifications for Review and Materialization

Mirror the import async notification pattern for the new workflow.

Deliverables:

- materialization lifecycle topics/events
- imported-file detail refresh integration
- optional row-review refresh events if required by UX

### Task 08 — Import Details LiveView Review UI

Extend the existing imported-file details page into the first review queue.

Deliverables:

- `Materialize` button on the current details page
- row filters or tabs for `ready` / `duplicate` / `invalid`
- bulk approval for safe rows
- row-level approve/reject/force-approve controls
- status/progress UI for pending/processing/completed/completed_with_errors/failed materialization

### Task 09 — Duplicate Comparison UI

Support inspection of duplicate candidates before explicit override.

Deliverables:

- side-by-side comparison UI for duplicate rows
- source of matched existing record data
- test coverage for duplicate review flow

### Task 10 — Materialization Results and Traceability UI

Surface committed outcomes back on the imported-file details page.

Deliverables:

- run summary card
- row-level committed/skipped/failed indicators, with currency mismatch treated as failed
- links or identifiers for created transactions where applicable
- no-loss refresh under PubSub updates

### Task 11 — Audit Integration

Add workflow-level audit events using the existing generic audit model.

Deliverables:

- audit events for materialization requested/completed/failed
- audit coverage for review actions or durable batch review actions
- confirmation that normal imported transaction creation does not add noisy per-transaction audit

### Task 12 — Test Coverage

Add deterministic automated coverage for the new workflow.

Deliverables:

- review decision tests
- async materialization tests
- idempotency/retry tests
- LiveView tests for `Materialize` button and progress refresh
- duplicate override tests
- traceability tests from imported row to transaction/postings
- failure handling tests

### Task 13 — Documentation and Scope Guardrails

Document the boundary between issue #15, issue #17, and future import-profile work.

Deliverables:

- explicit note that issue #15 remains ingestion-only
- explicit note that issue #43 owns institution-specific CSV mapping/profile work
- explicit note that reconciliation remains separate

---

## Risks and Open Questions

### Risks

1. **Counterparty account semantics**
   The clearing-account strategy is necessary for balanced ledger creation, but it will affect downstream reporting semantics until categorization/reclassification exists.

2. **Currency mismatch handling**
   Some imported data may carry row-level currency labels that conflict with the target account. v1 correctly records those as failed row outcomes during materialization, but this may surface bank-export modeling problems that users must solve by using the right account boundary.

3. **State-model sprawl**
   If review state, materialization state, and imported-row evidence are mixed carelessly, the domain will become hard to reason about and hard to test.

4. **Retry idempotency**
   Async job retries can create duplicate transactions unless the row-to-transaction linkage has strict uniqueness guarantees.

5. **Large imported files**
   Bulk review and batch commit of large imports will stress both UI rendering and worker batching if not designed deliberately.

### Open Questions

1. Should the import clearing account be created automatically on first materialization or provisioned explicitly through setup/admin flow?
2. How much duplicate comparison data should be shown in v1 on the details page versus deferred to a more dedicated review UX later?

---

## Definition of Done

This milestone is done when all of the following are true:

- the current imported-file details page acts as the first review queue
- a `Materialize` button exists there and enqueues async work
- review decisions are persisted independently from imported-row evidence
- materialization runs are tracked durably with PubSub updates
- approved imported rows create balanced ledger transactions/postings
- materialization always writes native-currency ledger facts based on `account.currency_code`
- `imported_row.currency` is treated as evidence only and never as an independent source of truth for ledger writes
- rows whose `imported_row.currency` conflicts with `account.currency_code` produce failed row outcomes explicitly and are never converted
- duplicate rows require explicit override before commit
- invalid rows remain excluded
- traceability exists from imported rows to created transactions
- double commit is prevented under retries/concurrency
- workflow-level audit events are emitted
- issue #15 remains closed as the ingestion-only milestone it already completed
