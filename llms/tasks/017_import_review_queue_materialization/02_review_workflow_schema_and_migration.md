# Task 02: Imported File Hard Delete Semantics

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Replace the removed review-workflow task with the CSV v1 deletion boundary for bad imports.

## Why This Replaced The Old Task
`import_row_reviews` is no longer part of the design. The useful v1 replacement is defining how users recover from a wrong CSV import.

## V1 Recovery Rule
If a CSV import is wrong, the supported correction path is:

1. hard delete the `imported_file`
2. hard delete all associated `imported_rows`
3. re-import the corrected CSV

No soft delete. No row-level correction workflow.

## V1 Deletion Boundary

In v1, an imported file may be hard-deleted only before any materialization workflow state exists.
If ledger facts were already materialized from that file, the user must first remove the dependent materialization outputs through a dedicated rollback/unmaterialize workflow, which is out of scope for Issue #17.

### Allowed
- imported file has no materialization workflow state

### Blocked
- any `import_materializations` record exists for the imported file

This is the strict v1 rule. It avoids ambiguous cleanup once async workflow state exists and makes rollback/unmaterialize an explicit future workflow instead of an implicit side effect of delete.

## Expected Cascade Behavior
- delete `imported_file`
- delete all `imported_rows` for that file
- delete stored source file from local storage

The delete operation should not attempt to unwind ledger writes. If any materialization state exists, deletion is blocked instead.

## Scope Boundaries
- This task does not introduce archival or soft delete
- This task does not delete materialized transactions
- This task is CSV-specific
- This task does not add a replacement table

## API/UX Implications
- The details page may show a destructive delete action only when allowed
- If blocked, the UI should explain that the file can no longer be deleted because workflow state already exists

## Locked Decision
Hard delete is blocked as soon as any materialization workflow state exists for the imported file.
