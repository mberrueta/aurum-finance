# Task 06: Fingerprint and Duplicate Detection Layer

## Status
- **Status**: BLOCKED
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

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 02 and 05 outputs
- [ ] `llms/constitution.md`

## Expected Outputs

- [ ] Fingerprint module
- [ ] Duplicate detection helpers/services
- [ ] Tests for exact-match dedupe and overlapping imports

## Acceptance Criteria

- [ ] Fingerprints are built from normalized canonical row data
- [ ] Dedupe is exact-match only
- [ ] Duplicate lookup is scoped by account
- [ ] Same fingerprint may exist in different accounts without conflict
- [ ] DB uniqueness strategy prevents concurrent duplicate `ready` rows
- [ ] No fuzzy matching is introduced

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

