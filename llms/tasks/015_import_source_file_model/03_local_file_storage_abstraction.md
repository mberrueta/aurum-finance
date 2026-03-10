# Task 03: Local File Storage Abstraction

## Status
- **Status**: IMPLEMENTED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Tasks 04, 07, 09, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 03 from `llms/tasks/015_import_source_file_model/03_local_file_storage_abstraction.md`.
>
> Read the milestone plan and Task 01 outputs first. Implement only the local filesystem storage abstraction and metadata capture needed by the import flow.

## Objective
Provide a local filesystem storage abstraction for uploaded CSV payloads with configurable base path, deterministic storage location, and metadata capture. This task must not add file-level duplicate rejection.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Task 01 outputs
- [ ] `llms/constitution.md`
- [ ] `config/runtime.exs`
- [ ] existing file/storage patterns in the repo, if any

## Expected Outputs

- [ ] Storage module(s) under `lib/aurum_finance/ingestion/`
- [ ] Configuration notes and required env vars if applicable
- [ ] Tests for storage and metadata capture

## Acceptance Criteria

- [ ] Files are stored under a configurable base path
- [ ] Storage path is persisted into `imported_files.storage_path`
- [ ] Metadata capture includes `filename`, `content_type`, `byte_size`, `sha256`, `storage_path` as applicable
- [ ] Repeated identical `sha256` values do not block upload
- [ ] No parser logic or dedupe logic is added here

## Execution Summary
- Added [local_file_storage.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/local_file_storage.ex) with configurable local filesystem storage, deterministic path layout under a configured base path, metadata capture (`filename`, `content_type`, `byte_size`, `sha256`, `storage_path`), and support for both in-memory `:content` and temp-file `:source_path` inputs.
- Extended [ingestion.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion.ex) with `store_imported_file/1`, which stores the payload on disk, persists the captured metadata into `imported_files`, defaults new records to `status: :pending`, and explicitly does not reject repeated `sha256` values.
- Added storage configuration in [config.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/config/config.exs), [test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/config/test.exs), and [runtime.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/config/runtime.exs). Production now requires `AURUM_INGESTION_STORAGE_PATH`.
- Added tests in [local_file_storage_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ingestion/local_file_storage_test.exs) and expanded [ingestion_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ingestion_test.exs) to cover on-disk storage, metadata capture, source-path ingestion, persisted `storage_path`, and repeated identical payloads not being blocked.

## Human Review
*[Filled by human reviewer]*
