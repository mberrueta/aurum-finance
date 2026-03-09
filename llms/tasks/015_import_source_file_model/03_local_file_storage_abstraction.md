# Task 03: Local File Storage Abstraction

## Status
- **Status**: BLOCKED
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
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

