# Task 04: CSV Parser Boundary

## Status
- **Status**: IMPLEMENTED
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
- Added the parser boundary in [parser.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/parser.ex) with explicit CSV-only support for this milestone and structured parser errors for unsupported formats and parse failures.
- Added reusable parser output structs in [canonical_row_candidate.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/canonical_row_candidate.ex), [parsed_import.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/parsed_import.ex), and [parser_error.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/parser_error.ex). The parser output contains canonical row candidates and raw row payloads only; it does not include dedupe or row-status decisions.
- Implemented the CSV parser in [csv.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/parsers/csv.ex), including quoted-field handling, header validation, canonical field extraction (`posted_on`, `description`, `amount`, `currency`), and parsing from either in-memory content or stored file paths.
- Extended [ingestion.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion.ex) with `parse_imported_file/1` and added parser-focused coverage in [parser_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ingestion/parser_test.exs).

## Human Review
*[Filled by human reviewer]*
