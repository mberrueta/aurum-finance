# Task 02: FX Context, Schemas, Migration, and Lookup API

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
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
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

