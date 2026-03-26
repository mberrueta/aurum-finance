# Task 03: Provider Registry, Sync Workers, and Scheduler

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
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

### Files Created
- `lib/aurum_finance/fx/provider.ex` -- Behaviour + central registry mapping `"bcb_ptax"` and `"frankfurter_ecb"` to their modules. Exposes `providers/0` and `fetch_rates/4`.
- `lib/aurum_finance/fx/providers/bcb_ptax.ex` -- BCB PTAX provider using `Req`. Fetches `cotacaoVenda` selling rates from the public API. Derives the non-BRL currency code from the series pair. No auth needed.
- `lib/aurum_finance/fx/providers/frankfurter_ecb.ex` -- Frankfurter/ECB provider using `Req`. Fetches daily rates from the public Frankfurter API. No auth needed.
- `lib/aurum_finance/fx/sync_worker.ex` -- Oban worker on `:fx` queue, `max_attempts: 5`, uniqueness on `(fx_series_id, from_date, to_date)` with 60s period. Loads series, delegates to provider, calls `upsert_rate_records/2`. Exposes `new_job/3`.
- `lib/aurum_finance/fx/global_sync_scheduler.ex` -- GenServer that runs an immediate scan on init and daily thereafter. Queries all `provider_module` series where `to_date IS NULL OR to_date >= yesterday`, computes max effective_date per series, enqueues sync for stale ones via `Oban.insert_all/1`.

### Files Modified
- `lib/aurum_finance/fx.ex` -- Added `upsert_rate_records/2` (bulk upsert via `Repo.insert_all` with `ON CONFLICT`), `enqueue_fx_sync/1` (manual sync entrypoint computing range from max existing date), and updated `create_fx_series/1` to enqueue backfill for `provider_module` series on creation.
- `lib/aurum_finance/application.ex` -- Added `GlobalSyncScheduler` to supervision tree, gated by `:start_fx_global_sync_scheduler` config (defaults to `true`).
- `config/config.exs` -- Added `fx: 3` queue to Oban config.
- `config/test.exs` -- Disabled `GlobalSyncScheduler` in test env.
- `mix.exs` -- Added `{:req, "~> 0.5"}` dependency.

### Design Decisions
- **GenServer over Oban.Plugins.Cron**: The project does not currently configure `Oban.Plugins.Cron`. A GenServer with `Process.send_after/3` keeps scheduling self-contained. Documented in module doc.
- **No per-series recurring jobs**: The scheduler scans all eligible series centrally, avoiding per-series cron entries.
- **Sync uniqueness**: 60-second deduplication window prevents concurrent enqueue races while allowing re-enqueue for different date ranges.
- **BCB PTAX currency derivation**: The provider uses whichever currency in the pair is not "BRL" to query the BCB API, with a fallback to `base_currency_code` for non-BRL pairs.

### Env Vars
- No new env vars required. BCB PTAX and Frankfurter APIs are public (no auth).

### Verification
- `mix compile --warnings-as-errors` passes cleanly.

### Prerequisite Note
This implementation was built on top of Task 02 outputs (fx.ex, fx_series.ex, fx_rate_record.ex, migration). Those files were extracted from commit `ae7de16` into this worktree since the branch diverged before that commit was applied.

## Human Review
*[Filled by human reviewer]*

