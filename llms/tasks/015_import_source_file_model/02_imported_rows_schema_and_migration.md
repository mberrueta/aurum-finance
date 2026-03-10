# Task 02: `imported_rows` Schema and Migration

## Status
- **Status**: IMPLEMENTED
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
- Added `imported_rows` to `priv/repo/migrations/20260310123000_create_imported_files_and_rows.exs` so `imported_files` and `imported_rows` are created together in a single migration file. The migration includes the required `[:account_id, :fingerprint]` lookup index and the partial unique index for `ready` rows.
- Added `AurumFinance.Ingestion.ImportedRow` with immutable-evidence-oriented shape: `updated_at: false`, required traceability fields, canonical preview fields, row-level statuses `:ready | :duplicate | :invalid`, and changeset validation that requires `fingerprint` for `ready` and `duplicate` rows while allowing it to be nil for `invalid` rows.
- Extended `AurumFinance.Ingestion` with row query and creation APIs and expanded `test/aurum_finance/ingestion_test.exs` to cover required row validations, account-scoped row listing, fingerprint rules, and DB-backed duplicate protection for `ready` rows.

## Human Review
*[Filled by human reviewer]*
