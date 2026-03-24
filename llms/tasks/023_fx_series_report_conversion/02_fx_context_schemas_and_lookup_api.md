# Task 02: FX Context, Schemas, Migration, and Lookup API

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03, Task 04, Task 05, Task 07

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for schemas, contexts, queries, and bounded read/write APIs

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 01 output, the approved spec, and current context/schema patterns before implementing the first real `AurumFinance.Fx` backend.

## Objective
Implement the core FX bounded context:

- migration(s) for `fx_series` and `fx_rate_records`
- `AurumFinance.Fx`, `AurumFinance.Fx.FxSeries`, and `AurumFinance.Fx.FxRateRecord`
- CRUD APIs, list/detail queries, delete guardrails, and filtered series queries
- report-time lookup helpers for direct/inverted latest-on-or-before selection with 4-day max staleness

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/01_fx_persistence_and_index_contract.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/helpers.ex`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] Existing context patterns in `lib/aurum_finance/*.ex`

## Expected Outputs

- [ ] Migration and schemas for FX persistence
- [ ] Public `AurumFinance.Fx` context API with `list_*`, `get_*!`, `create_*`, `update_*`, `delete_*`
- [ ] Query helpers for list-page aggregates and compatible-series filtering
- [ ] Lookup API for direct/inverted series resolution and bounded stale-rate handling
- [ ] Inline docs for important public functions

## Acceptance Criteria

- [ ] `slug` auto-generates from `AurumFinance.Helpers.slugify/1` at creation and remains immutable on edit
- [ ] `base_currency_code`, `quote_currency_code`, `source_kind`, and `provider_module` are immutable after create and enforced in backend
- [ ] `provider_module` is required only for `provider_module` series and validated against a central supported-provider list
- [ ] `to_date >= from_date` validation is enforced on create and edit
- [ ] `delete_fx_series/1` blocks deletion when any rate records exist
- [ ] List APIs expose `row_count` and `last_ingested_date` without UI-driven N+1 queries
- [ ] Compatible-series filtering supports account currency + target currency + date-range coverage rules
- [ ] Lookup returns explicit success/error tuples for found, missing, and stale rates and supports runtime inversion only
- [ ] Public non-trivial backend functions added here include `@doc` documentation

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/                    # Existing context patterns
lib/aurum_finance/helpers.ex          # slugify helper
priv/repo/migrations/                 # Migration conventions
priv/gettext/en/LC_MESSAGES/errors.po # Validation error domain
```

### Constraints
- Keep FX series global, not entity-scoped
- Do not implement provider HTTP calls or CSV ingestion in this task
- Do not persist report conversion preferences

## Execution Instructions

### For the Agent
1. Implement the migration, schemas, and context APIs from the Task 01 contract.
2. Keep filtering/query logic composable via `list_*_query/1` and private `filter_query/2` patterns where appropriate.
3. Add only the backend needed for CRUD, list/detail, delete checks, and FX lookup semantics.
4. Document any follow-up assumptions needed by Tasks 03-07.

### For the Human Reviewer
1. Confirm the bounded context is coherent and narrow.
2. Confirm list/detail and lookup contracts match the approved spec.
3. Approve before Tasks 03-05 and 07 begin.

---

## Execution Summary

### Files created

| File | Purpose |
|------|---------|
| `priv/repo/migrations/20260324130410_create_fx_series_and_rate_records.exs` | Migration: `fx_series` and `fx_rate_records` tables with indexes |
| `lib/aurum_finance/fx/fx_series.ex` | Schema with `create_changeset/2` and `update_changeset/2`, virtual fields for aggregates and `inverted?` |
| `lib/aurum_finance/fx/fx_rate_record.ex` | Schema with `changeset/2`, positive rate validation, FK + unique constraint |
| `lib/aurum_finance/fx.ex` | Context with full CRUD, list aggregates, compatible-series filter, and bounded lookup |

### Files modified

| File | Change |
|------|--------|
| `config/config.exs` | Added `fx: 3` Oban queue |

### Design decisions

1. **Immutability via separate changesets**: `FxSeries` uses `create_changeset/2` (casts identity + mutable fields) and `update_changeset/2` (casts only mutable fields). This enforces immutability of `slug`, `base_currency_code`, `quote_currency_code`, `source_kind`, and `provider_module` without runtime checks on persisted state.

2. **List aggregates via subquery join**: `list_fx_series/1` joins a grouped subquery of `fx_rate_records` to compute `row_count` and `last_ingested_date` in a single query. Virtual fields on the schema receive these values via `select_merge` + `coalesce`.

3. **Compatible-series as two queries + merge**: `list_compatible_fx_series/3` runs a direct-pair query and an inverted-pair query separately, then merges and sorts. Each result carries the virtual `inverted?` boolean via `select_merge`. This avoids complex OR + CASE expressions and keeps each query plan simple.

4. **Lookup with bounded staleness**: `lookup_fx_rate/3` finds the most recent `fx_rate_record` where `effective_date` is within `[as_of_date - 4 days, as_of_date]`. Runtime inversion applies `1 / rate_value` without touching persisted data.

5. **Delete guard**: `delete_fx_series/1` checks for existing rate records with a count query before allowing deletion. Returns `{:error, :has_records}` if any exist.

6. **Provider validation**: `FxSeries.supported_providers/0` centralizes the provider list. The create changeset validates `provider_module` against this list and enforces it is required for `:provider_module` source kind and absent for `:csv_upload`.

### Verification notes

- Migration runs cleanly (`mix ecto.migrate`)
- Compilation passes with `--warnings-as-errors`
- Formatting passes with `mix format --check-formatted`
- Tests are not included in this task (separate test task in execution plan)

## Human Review
*[Filled by human reviewer]*

