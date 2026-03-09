# Task 02: `imported_rows` Schema and Migration

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Tasks 05, 06, 07, 10, 11, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 02 from `llms/tasks/015_import_source_file_model/02_imported_rows_schema_and_migration.md`.
>
> Read the full milestone plan and Task 01 outputs first. Implement the `imported_rows` schema, migration, immutability-oriented persistence shape, and required indexes exactly as specified. Do not implement parser/orchestration logic in this step.

## Objective
Create the immutable imported-row evidence model that stores parsed row results, row-level status, fingerprint data, and traceability back to the uploaded file. This task also establishes the database indexes that make duplicate lookup fast and safe under concurrency.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Task 01 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ledger/account.ex`

## Expected Outputs

- [ ] Migration for `imported_rows`
- [ ] `lib/aurum_finance/ingestion/imported_row.ex`
- [ ] Ingestion context additions for row queries if needed

## Acceptance Criteria

- [ ] `imported_rows.imported_file_id` and `account_id` are required
- [ ] `raw_data` is stored for traceability
- [ ] Canonical parsed fields needed for preview/review are present
- [ ] Row statuses are `ready`, `duplicate`, `invalid` or exact equivalent approved in the plan
- [ ] `fingerprint` is required for `ready` and `duplicate`
- [ ] `fingerprint` may be `nil` only for `invalid` rows when canonicalization fails
- [ ] Rows are treated as immutable evidence records by design
- [ ] Index exists on `[:account_id, :fingerprint]`
- [ ] Partial unique index exists on `[:account_id, :fingerprint]` for `ready` rows

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

