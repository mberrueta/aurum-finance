# Task 05: Materialization Context API

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Define the backend API surface for eligibility queries, materialization requests, run listing, and imported-file deletion semantics if included in this milestone.

## In Scope
- account-scoped imported-row listing
- eligible-row query for UI/actionability
- materialization request entrypoint
- materialization run listing
- imported-file hard delete entrypoint if Task 02 is implemented in code during this milestone

## Explicitly Out of Scope
- approve/reject/force-approve APIs
- any review-decision query or mutation API

## Recommended Public APIs
- `list_imported_rows/1`
- `list_materializable_imported_rows/1`
- `list_import_materializations/1`
- `request_materialization/3`
- optional `delete_imported_file/2` or equivalent account-scoped delete entrypoint

## Eligibility Semantics

### `list_materializable_imported_rows/1`
Should return only rows that are:

- `ready`
- not already committed
- currency-safe for the account

That query is for “what can move now” in the UI.

### `request_materialization/3`
Should create a durable run and enqueue the worker.

The run may still consider ready rows that later end in `failed`, especially currency mismatch cases, because run outcomes and UI reporting must stay explicit.

## Error Boundaries
- no rows left to consider => localized error
- account/imported-file scope mismatch => not found or equivalent account-safe error
- delete blocked by existing materialization state => localized error if delete API exists

## Notes on Current Branch Artifacts
The branch should keep only these workflow persistence artifacts:

- `import_materializations`
- `import_row_materializations`

`import_row_reviews` and all review APIs are removed from the design and from implementation artifacts.

## Remaining Open Question
1. If Task 02 is implemented in code in this milestone, should the delete entrypoint live in `AurumFinance.Ingestion` or a narrower imported-file submodule later?
