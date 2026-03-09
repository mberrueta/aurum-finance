# Task 04: CSV Parser Boundary

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Tasks 05, 07, 10, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 04 from `llms/tasks/015_import_source_file_model/04_csv_parser_boundary.md`.
>
> Read the full plan and the prior storage/model tasks. Implement the CSV parser boundary and CSV-only parser output shape. Do not implement dedupe or async orchestration in this step.

## Objective
Define the parser abstraction and implement CSV as the only supported parser for this milestone. The parser must produce canonical row candidates that later stages can normalize, fingerprint, validate, and persist.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 01 and 03 outputs
- [ ] `llms/constitution.md`

## Expected Outputs

- [ ] Parser behavior/interface
- [ ] CSV parser module(s)
- [ ] Parsed-import/canonical-row structs or equivalent
- [ ] Parser-focused tests

## Acceptance Criteria

- [ ] Parser scope is explicitly CSV-only
- [ ] Unsupported formats are rejected clearly
- [ ] CSV parser produces canonical row candidates, not dedupe decisions
- [ ] Parser output remains reusable by future OFX/QFX/PDF implementations
- [ ] No fuzzy matching or parser-specific dedupe logic is introduced

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

