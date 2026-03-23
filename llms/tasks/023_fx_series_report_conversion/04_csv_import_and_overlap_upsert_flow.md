# Task 04: CSV Import and Overlap Upsert Flow

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 06

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for parsing, validation, and transactional import flows

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 02 output, and the existing CSV parser/import patterns before implementing FX CSV ingestion.

## Objective
Implement the manual-series CSV import service:

- parse and normalize date/value rows
- reject malformed/empty/headers-only/duplicate-date files atomically
- detect overlapping effective dates against existing series records
- expose a confirmation-aware import API that can upsert on `(fx_series_id, effective_date)`

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/02_fx_context_schemas_and_lookup_api.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ingestion/parsers/csv.ex`
- [ ] `lib/aurum_finance/ingestion/parser_error.ex`

## Expected Outputs

- [ ] FX CSV parser/normalizer service
- [ ] Validation result shape suitable for UI confirmation flows
- [ ] Import API for no-overlap direct import and confirmed-overlap upsert
- [ ] Guardrails preventing CSV import on provider-backed series

## Acceptance Criteria

- [ ] Supports the approved two-column schema: `date`, `value`
- [ ] Accepts the intended common date formats and normalizes to `YYYY-MM-DD`
- [ ] Normalizes values into positive `Decimal` values and rejects zero/negative rates
- [ ] Rejects entire files on any invalid row, duplicate date within file, empty file, headers-only file, or malformed CSV
- [ ] Detects overlaps against existing `fx_rate_records.effective_date` values for the series
- [ ] Exposes a confirmation path so the UI can cancel or continue with override
- [ ] Uses atomic insert/upsert semantics so partial imports are not persisted
- [ ] Rejects upload attempts against `provider_module` series at the backend boundary

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/parsers/csv.ex
lib/aurum_finance/ingestion/parser_error.ex
lib/aurum_finance/fx/                       # New backend area expected from Task 02
```

### Constraints
- No full preview UI in this task
- No heuristic rate sanity checks beyond required positivity and parsing
- Keep the import API explicit about validation vs confirmed overwrite

## Execution Instructions

### For the Agent
1. Reuse the repo's hand-rolled CSV parsing style where practical.
2. Build a clear service boundary for validate-only and import-confirmed flows.
3. Keep overlap detection and upsert semantics explicit and testable.
4. Document any assumptions the frontend task must honor.

### For the Human Reviewer
1. Confirm the import flow is atomic and understandable.
2. Confirm overlap confirmation semantics match the approved spec.
3. Approve before Task 06 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

