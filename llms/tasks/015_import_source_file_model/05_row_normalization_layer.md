# Task 05: Row Normalization Layer

## Status
- **Status**: IMPLEMENTED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02, Task 04
- **Blocks**: Tasks 06, 07, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 05 from `llms/tasks/015_import_source_file_model/05_row_normalization_layer.md`.
>
> Read the full plan and parser/row model outputs. Implement the parser-agnostic normalization layer exactly as described.

## Objective
Implement deterministic normalization of canonical row data before dedupe. This includes trimming, lowercasing where appropriate, collapsing internal whitespace, unicode normalization, and removal of invisible/non-printable characters.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 02 and 04 outputs
- [ ] `llms/constitution.md`

## Expected Outputs

- [ ] `RowNormalizer` module or equivalent
- [ ] Tests covering normalization equivalence examples

## Acceptance Criteria

- [ ] Normalization is parser-agnostic
- [ ] `Uber `, ` UBER`, and `uber` normalize consistently
- [ ] Invisible/non-printable characters are removed
- [ ] Unicode normalization is applied consistently
- [ ] This layer does not perform duplicate lookup itself

## Execution Summary
- Added [row_normalizer.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion/row_normalizer.ex) with parser-agnostic normalization for canonical row data. The normalizer trims values, applies Unicode NFC normalization, removes invisible/control characters, collapses internal whitespace, lowercases descriptive text fields, and uppercases currency fields.
- Extended [ingestion.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ingestion.ex) with `normalize_parsed_import/1` so downstream stages can normalize parser output through the context boundary.
- Added focused coverage in [row_normalizer_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ingestion/row_normalizer_test.exs), including the equivalence case for `Uber ` / ` UBER` / `uber`, invisible/non-printable cleanup, and Unicode normalization consistency.

## Human Review
*[Filled by human reviewer]*
