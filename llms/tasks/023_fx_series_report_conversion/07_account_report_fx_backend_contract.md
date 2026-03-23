# Task 07: Account Report FX Backend Contract

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02, Task 03
- **Blocks**: Task 08

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for reporting read models and explicit domain contracts

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Tasks 02-03 outputs, and the current reporting modules before implementing the account-scoped optional FX conversion backend.

## Objective
Implement the backend contract for the first account-scoped report with optional FX conversion:

- explicit account + `as_of_date` report input
- optional conversion input (`target_currency_code`, `fx_series_id`)
- compatible-series filtering and validation
- report payload including native and converted result data
- missing-rate behavior that preserves report generation

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/02_fx_context_schemas_and_lookup_api.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/03_provider_registry_sync_workers_and_scheduler.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] `lib/aurum_finance/reporting/net_worth.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`

## Expected Outputs

- [ ] Account-scoped reporting API
- [ ] Conversion-aware validation and compatible-series lookup wiring
- [ ] Report payload that includes native and optional converted data plus explicit conversion metadata/status
- [ ] Missing-rate result semantics that do not fail the whole report

## Acceptance Criteria

- [ ] Report scope is one account only and does not broaden into multi-account FX conversion
- [ ] Convert toggle semantics remain request-time only and are not persisted
- [ ] Compatible-series filtering respects account currency, target currency, and series date coverage
- [ ] Invalid series selection blocks report generation with explicit form-usable errors
- [ ] Runtime inversion is applied only when series direction is opposite the requested conversion
- [ ] Latest-on-or-before lookup honors a 4-day max staleness window
- [ ] Report payload includes an explicit `conversion_status` field so the UI does not have to infer whether conversion succeeded, was unavailable, or was rejected as invalid
- [ ] Report payload includes explicit FX series reference metadata such as `fx_series_id` or `fx_series_slug` when conversion is configured
- [ ] When no valid rate exists, the report still returns native data plus an explicit unavailable conversion state/message
- [ ] Public backend entrypoints are documented with `@doc`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/reporting/net_worth.ex
lib/aurum_finance/ledger/account.ex
lib/aurum_finance/fx/                       # New backend area from earlier tasks
```

### Constraints
- No automatic series choice when multiple candidates exist
- No interpolation or synthetic rates
- No persistence of user conversion preferences

## Execution Instructions

### For the Agent
1. Define and implement one explicit account-report backend contract.
2. Reuse the FX lookup APIs instead of duplicating conversion rules in reporting.
3. Keep missing-rate handling first-class and non-failing.
4. Document any route/UI assumptions needed by Task 08.

### For the Human Reviewer
1. Confirm the report contract is single-account and explicit.
2. Confirm missing-rate and inversion semantics match the approved spec.
3. Approve before Task 08 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
