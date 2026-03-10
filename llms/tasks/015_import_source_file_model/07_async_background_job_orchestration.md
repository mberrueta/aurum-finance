# Task 07: Async Background Job Orchestration

## Status
- **Status**: DONE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01, Task 02, Task 03, Task 04, Task 05, Task 06
- **Blocks**: Tasks 08, 10, 11, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 07 from `llms/tasks/015_import_source_file_model/07_async_background_job_orchestration.md`.
>
> Read the full plan and all prior backend tasks first. Implement the asynchronous import orchestration end-to-end, but do not build the final LiveView UI in this step.

## Objective
Implement the asynchronous processing workflow that transitions imports through `pending`, `processing`, `complete`, or `failed`, parses CSV, normalizes rows, detects duplicates, validates rows, persists immutable imported rows, and updates import summaries.

## Inputs Required

- [x] `llms/tasks/015_import_source_file_model/plan.md`
- [x] Tasks 01-06 outputs
- [x] `llms/constitution.md`
- [x] current project background job conventions

## Expected Outputs

- [x] Background job module(s)
- [x] Orchestrator/import service
- [x] End-to-end async processing tests

## Acceptance Criteria

- [x] Upload request persists `imported_file` as `pending`
- [x] Processing runs asynchronously in a background job
- [x] Job transitions status to `processing`
- [x] Job persists imported rows as `ready`, `duplicate`, or `invalid`
- [x] Job updates summary fields and `processed_at`
- [x] Job sets final state to `complete` or `failed`
- [x] No transactions or postings are created

## Execution Summary
- Added Oban to the project, configured queue `:imports`, and created the `oban_jobs` migration.
- Added `AurumFinance.Ingestion.ImportWorker` as the Oban worker and kept `AurumFinance.Ingestion.ImportProcessor` as the synchronous orchestration service used by the worker.
- Added `Ingestion.enqueue_import_processing/1` as the single context entrypoint for job enqueueing through Oban.
- The processor now claims pending/failed imports, transitions them to `processing`, parses CSV, normalizes rows with account context, computes batch duplicate lookups by fingerprint, persists immutable `imported_rows`, and finalizes import summaries.
- Duplicate handling is chunk-based and account-scoped: existing ready fingerprints are loaded in one batch per chunk, while same-run duplicates are tracked in memory to avoid N+1 lookup behavior.
- Unexpected parser/runtime failures now mark the import as `failed` with `error_message` and `processed_at`, while successful runs finish as `complete` with summary counters populated.
- Added end-to-end async coverage for successful processing and parser failure paths using Oban's manual testing mode and queue draining helpers.

## Human Review
*[Filled by human reviewer]*
