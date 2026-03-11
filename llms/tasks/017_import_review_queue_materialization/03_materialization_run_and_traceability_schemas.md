# Task 03: Materialization Run and Traceability Schemas

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Define the durable schemas for async run tracking and row-level traceability.

## In Scope
- `import_materializations`
- `import_row_materializations`

## Explicitly Out of Scope
- `import_row_reviews`
- any schema that stores manual row approval state

## `import_materializations`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Primary key |
| `imported_file_id` | UUID FK | One run belongs to one imported file |
| `account_id` | UUID FK | Explicit scope boundary |
| `status` | enum | `pending`, `processing`, `completed`, `completed_with_errors`, `failed` |
| `requested_by` | string | Actor identifier |
| `rows_considered` | integer | Rows evaluated by the run |
| `rows_materialized` | integer | Rows committed successfully |
| `rows_skipped_duplicate` | integer | Duplicate rows skipped by policy |
| `rows_failed` | integer | Row-level failures such as currency mismatch |
| `error_message` | string | Run-wide failure detail when needed |
| `started_at` | utc datetime | Worker start time |
| `finished_at` | utc datetime | Worker completion time |

Notes:

- `rows_rejected` is removed.
- `completed_with_errors` stays because row-level `failed` outcomes are part of the design.

## `import_row_materializations`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | Primary key |
| `import_materialization_id` | UUID FK | Belongs to one run |
| `imported_row_id` | UUID FK | Source evidence row |
| `transaction_id` | UUID FK nullable | Present only when committed |
| `status` | enum | `committed`, `skipped`, `failed` |
| `outcome_reason` | string nullable | Reason for `skipped` or `failed` outcomes |

## Constraints and Indexes
- unique committed guard on `imported_row_id` so one row cannot commit twice
- unique optional guard on `transaction_id` so one row outcome cannot point to multiple transactions
- indexes by `imported_file_id`, `account_id`, and run `status`

## Queryability Expectations
- list runs by account or imported file
- fetch row outcomes for one run
- answer “did this row already commit?”
- answer “which transaction did this row create?”

No query in this task depends on a review overlay join.

## Locked Decision
Reruns record explicit `skipped` row outcomes for duplicates, invalid rows, and already committed rows.

Counters summarize the run, but do not replace row-level durable outcomes.
