# Execution Plan: Issue #17 — CSV Import Preview and Ledger Materialization

## Metadata
- **Issue**: `https://github.com/mberrueta/aurum-finance/issues/17`
- **Created**: 2026-03-10
- **Updated**: 2026-03-11
- **Status**: COMPLETED
- **Completed Tasks**: 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13
- **Next Task**: none
- **Depends on**: Issue #12 completed, Issue #13 in progress, Issue #15 completed

## Context
Issue #15 already delivers:

- `imported_files` as durable uploaded-file records
- `imported_rows` as immutable row evidence
- CSV parsing, normalization, and exact-match duplicate detection
- import preview/history UI
- Oban-based async import processing

Issue #17 now adds the next step for CSV only:

- imported-file preview remains the primary screen
- users can inspect `ready`, `duplicate`, and `invalid` rows
- users can request async ledger materialization for eligible rows
- users can hard delete a bad imported CSV and re-import a corrected file

This milestone does not add a row-level human review overlay. For CSV v1, the correct recovery path for a bad import is delete plus re-import, not per-row approval or rejection.

## Objective
Turn the imported-file details page into a practical CSV v1 review surface that supports:

- visibility into imported-row evidence
- async materialization runs
- row-level materialization outcomes and traceability
- hard delete of incorrect CSV imports before or instead of materialization

## Scope
- Keep `imported_rows` immutable.
- Keep the imported-file details page as the main workflow surface.
- Keep `import_materializations` and `import_row_materializations`.
- Add async materialization request and run tracking.
- Show row-level outcomes: `committed`, `skipped`, `failed`.
- Preserve no-double-commit guarantees.
- Preserve native-currency-only ledger writes.
- Add explicit CSV hard delete semantics as the v1 correction path.

## Explicit Out of Scope
- `import_row_reviews`
- manual row approval, rejection, or duplicate override
- PDF or non-CSV correction workflows
- FX conversion or multi-currency ledger posting
- fuzzy duplicate matching
- categorization or reconciliation workflows
- future row notes/comments implementation

## Core Decisions

### D1. No row-review overlay in CSV v1
`import_row_reviews` is removed from the design.

Reasoning:

- `ready` rows are implicitly the safe default
- `duplicate` rows are not materializable in v1
- `invalid` rows are not materializable in v1
- if the CSV itself is wrong, the fix is deleting the import and re-importing the corrected file

### D2. Imported rows stay immutable evidence
`imported_rows` continue to store only parsed evidence:

- `ready`
- `duplicate`
- `invalid`

No mutable approval workflow state is added to rows.

### D3. Review queue means preview plus actionability
In v1, the “review queue” is the imported-file details page showing:

- imported file summary
- row segmentation by `ready` / `duplicate` / `invalid`
- materialization availability
- materialization run history and results
- delete-import action when allowed

### D4. CSV correction path is hard delete plus re-import
If the imported CSV is wrong, the supported v1 recovery path is:

1. hard delete the `imported_file`
2. hard delete its `imported_rows`
3. re-import the corrected CSV

No soft delete and no row-level correction workflow are introduced here.

In v1, an imported file may be hard-deleted only before any materialization workflow state exists.
If ledger facts were already materialized from that file, the user must first remove the dependent materialization outputs through a dedicated rollback/unmaterialize workflow, which is out of scope for Issue #17.

### D5. Materialization remains async and durable
Materialization is still:

- user-triggered from the imported-file details page
- persisted first in `import_materializations`
- executed asynchronously via Oban
- reflected back to the UI via PubSub notifications

### D6. Keep row-level traceability and idempotency
`import_row_materializations` remains required for:

- row-to-run linkage
- row-to-transaction linkage
- row-level failure detail
- no double commit under retry or concurrent requests

### D7. Native-currency-only materialization remains unchanged
The ledger contract remains:

- every account is single-currency
- `account.currency_code` is the only source of truth for posting currency
- `imported_row.currency` is evidence only
- no FX conversion is allowed during materialization

If `imported_row.currency` conflicts with `account.currency_code`, that row must end as row-level `failed` during materialization.

## Row Eligibility Rules

### Materializable by default
- `ready`
- not already committed
- no currency mismatch

### Never materializable in v1
- `duplicate`
- `invalid`
- already committed rows

### Special case
- currency mismatch rows are not materializable, but when included in a materialization run they must produce a durable row-level `failed` outcome rather than being silently ignored

## Durable Data Model

### Existing evidence tables kept
- `imported_files`
- `imported_rows`

### New workflow tables kept
- `import_materializations`
- `import_row_materializations`

### Removed from scope
- `import_row_reviews`

## Workflow Summary
1. User uploads CSV through the existing import flow.
2. System parses and stores immutable imported-row evidence.
3. User opens imported-file details.
4. User inspects `ready`, `duplicate`, and `invalid` rows.
5. If the CSV is wrong, user deletes the imported file and re-imports.
6. If the CSV is acceptable, user requests materialization.
7. System creates a `pending` run and enqueues the worker.
8. Worker evaluates each relevant row:
   - `ready` and currency-safe rows can commit
   - `duplicate` rows are skipped
   - `invalid` rows are skipped
   - currency mismatch rows are marked `failed`
   - already committed rows are skipped/idempotent
9. UI reloads durable state after PubSub notifications.

## Acceptance Criteria

### Functional
1. The imported-file details page shows imported-row evidence grouped by `ready`, `duplicate`, and `invalid`.
2. The page exposes a `Materialize` action for eligible rows.
3. The page exposes a delete-import action when the import is still deletable under the chosen boundary.
4. Materialization requests create durable run state before async execution.
5. Materialization requests are rejected when another run for the same imported file is already `pending` or `processing`.
6. Materialization requests only consider rows that are truly materializable under the v1 eligibility rules.
7. Run statuses support `pending`, `processing`, `completed`, `completed_with_errors`, and `failed`.
8. Row outcomes support `committed`, `skipped`, and `failed`.
9. Duplicate rows have visibility but no override path.
10. Currency mismatch rows never create ledger postings and are recorded as row-level `failed`.
11. Committed rows cannot be committed twice.
12. Imported-row to transaction traceability is queryable from durable storage and visible from the imported-file details page.
13. Deleting a bad CSV removes the imported file and its imported rows without introducing soft delete.

### Non-Functional
1. `imported_rows` remain immutable evidence.
2. PubSub is notification-only.
3. Large row sets remain stream-friendly in LiveView.
4. No FX conversion is introduced.
5. The plan remains CSV-specific and does not expand into broader correction workflows.

## Task Breakdown

### Task 01 — Review and Materialization Domain Contract
Define the simplified v1 boundary: immutable evidence, run tracking, row outcomes, idempotency, and native-currency-only rules.

### Task 02 — Imported File Hard Delete Semantics
Define when an imported CSV can be hard deleted, what cascades, and what is blocked once materialization exists.

### Task 03 — Materialization Run and Traceability Schemas
Define durable schemas for `import_materializations` and `import_row_materializations`.

### Task 04 — Clearing Account Strategy
Define the balancing-account strategy for import materialization.

### Task 05 — Materialization Context API
Define account-scoped APIs for eligible-row queries, materialization requests, run listing, and imported-file deletion entrypoints if included.

### Task 06 — Materialization Worker and Async Orchestrator
Implement the async worker, run transitions, row outcome recording, and idempotent ledger creation.

### Task 07 — PubSub Notifications for Materialization
Keep only materialization lifecycle PubSub notifications, plus any delete-triggered refresh needed for the UI.

### Task 08 — Import Details Review Queue UI
Update the details page to show row evidence, materialize action, delete action, and run status/results.

### Task 09 — Duplicate Visibility UI
Repurpose duplicate UX away from override controls and toward simple inspection of why a row was classified as duplicate.

### Task 10 — Materialization Results and Traceability UI
Show run summary and row-level committed/skipped/failed outcomes with transaction linkage where available.

### Task 11 — Audit Event Integration
Keep workflow-level audit for materialization lifecycle and decide whether imported-file hard delete should also be audited narrowly.

### Task 12 — Test Scenarios and Coverage Plan
Define deterministic coverage for eligibility, idempotency, traceability, hard delete semantics, and status transitions.

### Task 13 — Test Implementation and Scope Guardrails
Implement the agreed tests and document scope boundaries against future import/comment workflows.

## Risks
1. Hard delete after partial materialization can become ambiguous unless the allowed/deletion boundary is explicit.
2. Currency mismatch handling can confuse users if the UI does not explain why a `ready` row later failed.
3. Duplicate visibility must stay informative enough even without an override workflow.
4. Async retries can still create double-commit risk unless uniqueness stays anchored in durable row materialization records.

## Open Questions
- none blocking for Issue #17 v1 design

## Future Note
A future row note/comment feature may make sense for ambiguous descriptions such as broker activity, crypto rows, or merchant labels like `BUY IN MARKET`. That would be informational metadata only, separate from review/materialization workflow, and is out of scope for Issue #17.

## Definition of Done
- The imported-file details page is the CSV v1 review surface.
- No row-level approval workflow exists.
- `import_materializations` and `import_row_materializations` are the only new workflow tables in scope.
- The system can request and track async materialization runs.
- The system records row-level committed/skipped/failed outcomes durably.
- Currency mismatch rows fail explicitly without FX conversion.
- Duplicate rows are visible but not overrideable.
- Bad CSV imports can be corrected through hard delete plus re-import under explicit boundary rules.
- Traceability and no-double-commit guarantees are in place.
- Deterministic tests and scope guardrails are documented and aligned with implementation.
