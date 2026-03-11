# Task 10: Materialization Results and Traceability UI

## Status
- **Status**: UPDATED
- **Approved**: [ ] Human sign-off

## Objective
Show durable run results and row-level traceability on the imported-file details page.

## Required UI Elements
- run summary card
- run status chip
- counts for materialized, skipped, and failed rows
- row-level status display
- transaction link or identifier for committed rows when available

The UI should be driven by durable row outcomes in `import_row_materializations`. Counters summarize those outcomes but are not a substitute for row-level state.

## Row-Level Expectations
- `committed` rows show success and traceability
- `skipped` rows explain duplicate, invalid, or already-committed reasons where available
- `failed` rows show explicit failure reasons such as currency mismatch

## Important V1 Note
Duplicate rows must appear as not materialized with no override path.

## Remaining Open Question
1. For rows skipped because they were already committed in a previous run, do we want to show the prior transaction reference directly in the row detail?
