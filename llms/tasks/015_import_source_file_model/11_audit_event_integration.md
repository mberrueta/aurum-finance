# Task 11: Audit Event Integration

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01, Task 02, Task 07
- **Blocks**: Tasks 12, 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 11 from `llms/tasks/015_import_source_file_model/11_audit_event_integration.md`.
>
> Read the full plan and the existing audit architecture first. Integrate import lifecycle events into the generic audit model without creating a divergent audit mechanism.

## Objective
Wire the import workflow into the existing generic audit event system for upload and processing lifecycle actions.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 01, 02, and 07 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/audit.ex`
- [ ] `lib/aurum_finance/audit/multi.ex`
- [ ] existing audited context patterns in `entities.ex` and `ledger.ex`

## Expected Outputs

- [ ] Audit integration in ingestion workflow
- [ ] Tests for lifecycle audit events

## Acceptance Criteria

- [ ] Generic audit events exist for uploaded/created
- [ ] Generic audit events exist for processing_started
- [ ] Generic audit events exist for processing_completed
- [ ] Generic audit events exist for processing_failed
- [ ] Integration uses the existing generic audit context/pattern
- [ ] No second audit mechanism is introduced

## Execution Summary
- `store_imported_file/1` now records the initial `uploaded` lifecycle event through `AurumFinance.Audit.insert_and_log/2`.
- Import status transitions continue to append generic audit events inside the existing audit context flow, while preserving the transaction ordering required by the async processor.
- Test coverage now verifies the full lifecycle sequence: `uploaded`, `processing_started`, `processing_completed`, and `processing_failed`.

## Human Review
*[Filled by human reviewer]*
