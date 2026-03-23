# Task 03: Provider Registry, Sync Workers, and Scheduler

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 06, Task 07

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for HTTP integrations, Oban workers, and bounded orchestration

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Tasks 01-02 outputs, and the current Oban/import worker patterns before implementing provider-backed FX synchronization.

## Objective
Implement the provider-module path for FX series:

- central provider registry/behaviour
- initial providers `bcb_ptax` and `frankfurter_ecb`
- Req-based fetch/normalize layer
- backfill/sync workers and manual enqueue entrypoints
- global scheduled stale-series scan on app start and daily cadence

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/01_fx_persistence_and_index_contract.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/02_fx_context_schemas_and_lookup_api.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ingestion/import_worker.ex`
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`
- [ ] `config/config.exs`
- [ ] `config/runtime.exs`

## Expected Outputs

- [ ] Provider behaviour and supported-provider registry
- [ ] Provider implementations for `bcb_ptax` and `frankfurter_ecb`
- [ ] Sync/backfill workers with bounded uniqueness and queue selection
- [ ] Manual sync and creation-triggered backfill APIs
- [ ] Global scheduler entrypoint and config/env documentation notes

## Acceptance Criteria

- [ ] Provider list is sourced centrally and reusable by backend and UI
- [ ] Provider HTTP integrations use `Req`, not `:httpoison`, `:tesla`, or `:httpc`
- [ ] Creating a `provider_module` series enqueues initial backfill from `from_date` to `to_date || Date.utc_today()`
- [ ] Manual sync computes the next needed range from existing data or `from_date`
- [ ] Scheduler only scans `provider_module` series and skips completed past-range series
- [ ] Scheduler enqueues stale series only when coverage is behind yesterday or missing entirely
- [ ] Worker retries behave predictably for transient provider/network failures
- [ ] No per-series recurring jobs are created

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/import_worker.ex
lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex
config/config.exs
config/runtime.exs
mix.exs
```

### Constraints
- Do not add provider credentials to the database
- Do not silently auto-correct pair mismatches beyond provider normalization
- Keep scheduling bounded and operationally simple

## Execution Instructions

### For the Agent
1. Reuse existing worker/config patterns where they fit.
2. Implement a provider boundary that normalizes external responses into date/value rows.
3. Add creation-time, manual, and scheduled enqueue paths without duplicating orchestration logic.
4. Document env vars and queue/plugin changes required by the implementation.

### For the Human Reviewer
1. Confirm the provider boundary is narrow and maintainable.
2. Confirm scheduler and uniqueness semantics are operationally acceptable.
3. Approve before Task 06 and Task 07 begin.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

