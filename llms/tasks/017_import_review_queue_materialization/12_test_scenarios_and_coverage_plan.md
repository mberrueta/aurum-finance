# Task 12: Test Scenarios and Coverage Plan

## Status
- **Status**: UPDATED
- **Approved**: [ ] Human sign-off

## Objective
Define deterministic coverage for the simplified CSV v1 workflow.

## Must-Cover Scenarios
- `ready` row is eligible and can commit
- `duplicate` row is not materializable
- `invalid` row is not materializable
- already committed row cannot commit again
- currency mismatch produces row-level `failed`
- materialization run transitions `pending -> processing -> completed|completed_with_errors|failed`
- idempotent retry behavior prevents double commit
- imported-row to transaction traceability exists after commit
- imported-file hard delete works when allowed
- imported-file hard delete is blocked when workflow state exists, if that boundary is chosen

## Remove From Coverage
- approve tests
- reject tests
- force-approve tests
- duplicate override tests

## UI Coverage Focus
- details page shows row groups/statuses
- `Materialize` availability reflects eligible rows
- delete action availability reflects deletion boundary
- results UI shows committed/skipped/failed outcomes

## Remaining Open Question
1. If deletion is blocked once any materialization run exists, should tests cover both “run exists but nothing committed” and “committed rows exist” as separate cases?
