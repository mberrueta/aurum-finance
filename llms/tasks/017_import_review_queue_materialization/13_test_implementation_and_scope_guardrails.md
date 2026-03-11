# Task 13: Test Implementation and Scope Guardrails

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off

## Objective
Implement the agreed tests without reintroducing discarded workflow concepts.

## Guardrails
- do not add tests for row-level approval workflow
- do not add tests for duplicate override
- do not add tests for FX conversion
- keep scope on CSV preview, deletion boundary, materialization, and traceability

## Required Test Families
- ingestion-context tests for eligibility and request boundaries
- worker tests for row outcomes and run status transitions
- LiveView tests for details page actions and status rendering
- traceability tests proving imported-row to transaction linkage
- deletion tests if Task 02 enters implementation scope

## Implemented In
- `test/aurum_finance/ingestion/review_context_test.exs`
- `test/aurum_finance/ingestion/materialization_worker_test.exs`
- `test/aurum_finance/ingestion/pubsub_test.exs`
- `test/aurum_finance/ingestion/audit_integration_test.exs`
- `test/aurum_finance_web/live/import_details_live_test.exs`
- `test/aurum_finance_web/live/transactions_live_test.exs`

## Test Style Guardrails
- use factories and factory-backed helpers, never fixtures
- prefer assertions on durable statuses, transitions, and visible workflow outcomes
- assert exact failure-reason strings only where the string is intentional user-visible product behavior in v1
- keep imported-row evidence immutable in test setup; do not reintroduce approval-state helpers under another name

## Future-Out-Of-Scope Reminder
A future row note/comment feature may deserve its own tests later, but it is not part of Issue #17 and must not leak into this milestone's implementation scope.

## Decisions Closed
- no tests are added for row-level review, approval, rejection, or duplicate override
- no tests are added for FX conversion or multi-currency ledger behavior
- currency mismatch can assert the exact reason string in v1 because it is a deliberate, user-visible outcome shown in workflow surfaces
