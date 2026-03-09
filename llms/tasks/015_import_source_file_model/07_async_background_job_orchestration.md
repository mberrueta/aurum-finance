# Task 07: Async Background Job Orchestration

## Status
- **Status**: BLOCKED
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

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 01-06 outputs
- [ ] `llms/constitution.md`
- [ ] current project background job conventions

## Expected Outputs

- [ ] Background job module(s)
- [ ] Orchestrator/import service
- [ ] End-to-end async processing tests

## Acceptance Criteria

- [ ] Upload request persists `imported_file` as `pending`
- [ ] Processing runs asynchronously in a background job
- [ ] Job transitions status to `processing`
- [ ] Job persists imported rows as `ready`, `duplicate`, or `invalid`
- [ ] Job updates summary fields and `processed_at`
- [ ] Job sets final state to `complete` or `failed`
- [ ] No transactions or postings are created

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

