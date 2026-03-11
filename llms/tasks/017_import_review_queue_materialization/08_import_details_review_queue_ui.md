# Task 08: Import Details Review Queue UI

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off

## Objective
Turn the imported-file details page into the CSV v1 review surface without row-level approval controls.

## Page Responsibilities
- show imported-file summary
- show `ready`, `duplicate`, and `invalid` rows
- show materialization run status/history
- show `Materialize` action
- show delete-import action when allowed

## Remove From The UI
- bulk approve buttons
- row approve/reject controls
- duplicate override controls

## Required Behaviors
- `Materialize` is disabled when there is nothing eligible
- duplicates remain visible for inspection but are not actionable
- invalid rows surface their validation reasons
- if deletion is blocked, explain why
- use stream-based row rendering for large files

## UI Copy Guidance
- describe the page as a preview/review surface for CSV imports
- explain that wrong CSV files should be deleted and re-imported
- explain that duplicates are skipped in v1 rather than manually overridden

## Remaining Open Question
1. Should the delete action live in the header beside `Materialize`, or inside a secondary destructive-actions section to reduce accidental clicks?
