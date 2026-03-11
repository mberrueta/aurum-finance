# Task 10.b: Row-First Traceability UI Follow-Up

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off

## Context
Task 10 already made durable materialization outcomes visible on the imported-file details page.

That delivery is correct from a data and traceability standpoint, but the current UI is still run-first:

- imported rows appear in one main table
- each materialization run renders its own row-results table
- users must mentally correlate the same row across two different surfaces
- raw full `transaction_id` values are visible but not very usable

This becomes hard to operate once an import has many rows or multiple reruns.

## Objective
Refactor the details page into a row-first traceability surface while keeping materialization run history visible.

## UX Direction

### D1. Imported rows remain the main surface
Keep a single primary imported-rows table.

Each imported row should expose its durable materialization history inline, instead of forcing the user to scan a second repeated row table inside each run card.

### D2. Materialization runs become summary/history
Run cards should stay on the page, but as summary/history only:

- newest run first
- latest run expanded by default
- older runs collapsed by default
- summary counts, status, timestamps, requester
- no full repeated row-results table as the main UX

### D3. Transaction traceability must be more usable
Do not show a raw full UUID as the main transaction affordance.

Preferred v1 behavior:

- short transaction reference
- link if a direct transaction route exists
- otherwise readable/truncated identifier

## Expected UI Shape

### Top / History Section
- latest materialization run first
- latest run expanded
- previous failed runs collapsible and collapsed by default
- summary only

### Imported Rows Section
- one table only
- each row shows imported evidence
- each row can reveal one or more durable outcomes:
  - run label or ordinal
  - committed/skipped/failed
  - outcome reason
  - transaction reference for committed rows

## Acceptance Criteria
1. Users can inspect one imported row together with its materialization history in one place.
2. The page no longer duplicates the full row dataset inside each materialization run card.
3. Run cards remain available as summary/history.
4. Older runs are collapsed by default.
5. Transaction traceability is more usable than the current raw UUID presentation.

## Implemented
- imported rows remain the primary table on the page
- durable materialization history now renders inline per imported row
- run cards remain visible as summary/history only
- newest run stays expanded by default and older runs render collapsed
- transaction references are shown in shortened form instead of raw full UUIDs

## Constraints
- no backend contract changes
- no new schema or migration work
- no rollback/unmaterialize workflow
- no drawer or complex comparison UI unless clearly necessary
