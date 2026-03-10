# Task 01: `imported_files` Schema and Migration

## Status
- **Status**: IMPLEMENTED
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Tasks 02, 03, 07, 09, 11, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 01 from `llms/tasks/015_import_source_file_model/01_imported_files_schema_and_migration.md`.
>
> Read the full milestone plan first, then implement the `imported_files` schema, migration, and ingestion context APIs exactly as specified. Do not implement later tasks in this step. Do not modify `plan.md`.

## Objective
Create the durable uploaded-file/import-run model for the ingestion pipeline. This task establishes the account-scoped import container, processing lifecycle state, summary fields, and query APIs. This task must not introduce ledger mutation paths.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ledger.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`
- [ ] `lib/aurum_finance/entities.ex`
- [ ] `lib/aurum_finance/entities/entity.ex`
- [ ] `priv/repo/migrations/*create_accounts*.exs`

## Expected Outputs

- [ ] Migration for `imported_files`
- [ ] `lib/aurum_finance/ingestion/imported_file.ex`
- [ ] `lib/aurum_finance/ingestion.ex` with account-scoped APIs
- [ ] Gettext validation keys if needed

## Acceptance Criteria

- [ ] `imported_files.account_id` is required
- [ ] `imported_files` does not store redundant `entity_id`
- [ ] Fields exist per plan: `filename`, `sha256`, `format`, `status`, `row_count`, `imported_row_count`, `skipped_row_count`, `invalid_row_count`, `error_message`, `warnings`, `storage_path`, `processed_at`, timestamps
- [ ] Optional metadata fields `content_type` and `byte_size` are included if implementation chooses them
- [ ] Status values are exactly `pending`, `processing`, `complete`, `failed`
- [ ] Repeated identical `sha256` values are allowed
- [ ] Public APIs are account-scoped and use the existing context/query patterns
- [ ] No transaction or posting creation path is introduced

## Execution Summary
- Added `priv/repo/migrations/20260310123000_create_imported_files_and_rows.exs` with account-scoped `imported_files` persistence, lifecycle/status fields, summary counters, optional storage metadata, and DB indexes. The table does not store `entity_id`, and it does not enforce any uniqueness on `sha256`.
- Added `AurumFinance.Ingestion.ImportedFile` and `AurumFinance.Ingestion` with required-field changesets, i18n-backed validation messages, account-scoped listing/query APIs, scoped fetch helpers, and create/update/change functions needed by the upcoming upload/processing tasks.
- Added backend tests in `test/aurum_finance/ingestion_test.exs` covering required validations, repeated `sha256` acceptance, account-scoped querying, scoped lookup, and import summary/status updates.

## Human Review
*[Filled by human reviewer]*
