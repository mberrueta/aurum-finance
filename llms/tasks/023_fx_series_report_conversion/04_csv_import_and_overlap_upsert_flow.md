# Task 04: CSV Import and Overlap Upsert Flow

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
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

### Files created

| File | Purpose |
|------|---------|
| `lib/aurum_finance/fx/csv_import.ex` | Pure service module for FX CSV import: parse, overlap check, and import |

### Files modified

None.

### Public API

The module exposes three functions matching the specified contract:

- `parse/1` - validates raw CSV binary, returns `{:ok, rows}` or structured errors
- `check_overlap/2` - queries existing rate records for date overlap
- `import/2` - persists rows via atomic upsert, guards against provider-module series

### Design decisions

1. **Hand-rolled CSV field splitting with quote support**: Rather than a naive `String.split(line, ",")`, the parser handles double-quoted fields (which may contain commas) using the same recursive binary matching approach as the existing ingestion CSV parser. This handles values like `"1,234.56"` correctly.

2. **Multi-clause date parsing**: Date format resolution uses multi-clause private functions (`try_date_formats/1` and `resolve_ambiguous_slash_date/3`) instead of nested case blocks, matching the project's coding style preference for flat function heads.

3. **DD/MM/YYYY preferred for ambiguous slash dates**: When both numeric parts of a slash date are <= 12 (ambiguous between DD/MM/YYYY and MM/DD/YYYY), the parser tries DD/MM/YYYY first, falling back to MM/DD/YYYY only if DD/MM/YYYY produces an invalid date.

4. **Import computes overlap internally**: The `import/2` function calls `check_overlap/2` internally to determine the inserted vs updated count split. This is safe because the caller has already called `check_overlap` for the UI confirmation step, and the re-check is cheap.

5. **Validation errors use atoms only**: All error reasons (`:invalid_date`, `:invalid_value`, `:non_positive_value`, `:invalid_column_count`) are atoms. Translation to user-facing messages is the UI layer's responsibility.

6. **Row numbers are 1-indexed with header as row 1**: Data rows start at row number 2, since the header occupies row 1. This matches user expectations when looking at their CSV file.

### Verification notes

- Compilation passes with `mix compile --warnings-as-errors` (zero warnings)
- Formatting passes with `mix format --check-formatted`
- No migrations, no schema changes, no web-layer changes
- Tests are not included in this task (separate test task in execution plan)

## Human Review
*[Filled by human reviewer]*

