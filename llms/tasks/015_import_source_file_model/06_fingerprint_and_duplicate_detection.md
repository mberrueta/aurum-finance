# Task 06: Fingerprint and Duplicate Detection Layer

## Status
- **Status**: DONE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02, Task 05
- **Blocks**: Tasks 07, 10, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 06 from `llms/tasks/015_import_source_file_model/06_fingerprint_and_duplicate_detection.md`.
>
> Read the full plan and the row/normalization outputs first. Implement exact-match fingerprinting and account-scoped duplicate detection without coupling it to CSV specifics.

## Objective
Implement the stable fingerprint builder and account-scoped duplicate detection strategy that supports repeated and overlapping statement uploads. This task must include the DB-backed concurrency strategy described in the plan.

## Inputs Required

- [x] `llms/tasks/015_import_source_file_model/plan.md`
- [x] Tasks 02 and 05 outputs
- [x] `llms/constitution.md`

## Expected Outputs

- [x] Fingerprint module
- [x] Duplicate detection helpers/services
- [x] Tests for exact-match dedupe and overlapping imports

## Acceptance Criteria

- [x] Fingerprints are built from normalized canonical row data
- [x] Dedupe is exact-match only
- [x] Duplicate lookup is scoped by account
- [x] Same fingerprint may exist in different accounts without conflict
- [x] DB uniqueness strategy prevents concurrent duplicate `ready` rows
- [x] No fuzzy matching is introduced

## Execution Summary
- Added `AurumFinance.Ingestion.Fingerprint` to build deterministic SHA-256 fingerprints from normalized canonical row data using a stable recursive canonical term representation.
- Exposed `Ingestion.build_fingerprint/1`, `Ingestion.list_duplicate_fingerprints/1`, and `Ingestion.duplicate_fingerprint?/2` as the parser-agnostic dedupe entry points.
- Duplicate lookup is account-scoped and checks existing `ready` imported rows only, relying on the previously-added partial unique index on `[:account_id, :fingerprint]` for concurrent insert protection.
- Added tests covering stable exact-match fingerprinting, account scoping, and overlapping imports that produce duplicate rows without blocking repeated file uploads.

## Human Review
*[Filled by human reviewer]*
