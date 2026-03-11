# Task 13: Test Implementation and Scope Guardrails

## Status
- **Status**: UPDATED
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

## Future-Out-Of-Scope Reminder
A future row note/comment feature may deserve its own tests later, but it is not part of Issue #17 and must not leak into this milestone's implementation scope.

## Remaining Open Question
1. Do we want the first pass of tests to assert exact failure-reason strings for currency mismatch, or only assert stable error categories/statuses to reduce brittleness?
