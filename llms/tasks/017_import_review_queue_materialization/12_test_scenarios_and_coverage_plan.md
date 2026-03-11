# Task 12: Test Scenarios and Coverage Plan

## Status
- **Status**: COMPLETED
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

## Covered In
- `test/aurum_finance/ingestion/review_context_test.exs`
  - eligibility query coverage
  - request boundary coverage
  - delete boundary coverage
- `test/aurum_finance/ingestion/materialization_worker_test.exs`
  - mixed row outcomes
  - run status transitions
  - idempotent rerun behavior
  - committed row traceability
- `test/aurum_finance/ingestion/pubsub_test.exs`
  - materialization lifecycle notifications
- `test/aurum_finance/ingestion/audit_integration_test.exs`
  - workflow audit coverage
  - narrow imported-file delete audit coverage
- `test/aurum_finance_web/live/import_details_live_test.exs`
  - details page actions
  - duplicate visibility
  - row-level results and traceability rendering
  - delete action rendering and behavior

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

## Decisions Closed
- deletion is blocked once any materialization workflow state exists
- tests cover the chosen v1 boundary directly; no second delete case is required for a hypothetical rollback workflow that is out of scope
