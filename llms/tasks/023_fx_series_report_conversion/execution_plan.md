# Execution Plan: FX Series and Optional Report FX Conversion

## Metadata
- **Spec**: `llms/tasks/023_fx_series_report_conversion/plan.md`
- **Created**: 2026-03-23
- **Status**: PLANNING
- **Current Task**: N/A

## Overview

This execution plan turns the approved FX Series specification into a sequential delivery path that establishes a real `AurumFinance.Fx` foundation, replaces the mock `/fx` page, adds CSV/provider ingestion flows, and introduces the first account-scoped report conversion flow. The sequence keeps the feature intentionally narrow: explicit series selection, deterministic lookup rules, async provider sync, and no generalized FX policy engine.

## Technical Summary

### Codebase Impact
- **New files**: ~18-30
- **Modified files**: ~12-22
- **Database migrations**: Yes
- **External dependencies**: `Req` likely needs to be added for provider integrations if still absent from `mix.exs`

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FX schema and lookup semantics drift from the approved spec or ADR posture | Medium | High | Start with a dedicated persistence/index contract before implementation |
| Provider jobs and scheduler create duplicate or overlapping sync work | Medium | High | Isolate provider orchestration and enforce bounded uniqueness rules before wiring UI triggers |
| CSV overlap handling becomes ambiguous or partially applied | Medium | High | Implement a single import service with explicit dry validation, overlap detection, and confirmed upsert path |
| `/fx` UI scope grows into an analytics dashboard instead of CRUD + detail | Medium | Medium | Split base CRUD/detail UI from upload/sync interactions and keep the detail surface intentionally minimal |
| Account report conversion introduces hidden automatic FX selection or multi-account semantics | Medium | High | Build an explicit account-scoped backend contract before LiveView wiring and reject invalid form states early |
| Missing-rate behavior blocks report generation or silently invents values | Medium | High | Lock the 4-day bounded lookup contract in backend task and verify with dedicated tests |
| Gettext coverage and test traceability arrive too late and cause rework | Medium | Medium | Reserve explicit i18n and QA tasks before final audits |

## Roles

### Human Reviewer
- Approves each task before the next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject or request changes on any task

### Executing Agents

| Task | Agent | Description |
|------|-------|-------------|
| 01 | `dev-db-performance-architect` | FX schema/index/query contract and migration guidance |
| 02 | `dev-backend-elixir-engineer` | `AurumFinance.Fx` schemas, migration, CRUD, list/query API, and lookup contract |
| 03 | `dev-backend-elixir-engineer` | Provider registry, Req-backed providers, sync/backfill workers, and scheduler |
| 04 | `dev-backend-elixir-engineer` | CSV parsing/import/upsert flow and manual-series ingestion rules |
| 05 | `dev-frontend-ui-engineer` | `/fx` LiveView CRUD, list, detail, and deletion UX |
| 06 | `dev-frontend-ui-engineer` | CSV upload, overlap confirmation, and provider sync interactions in the UI |
| 07 | `dev-backend-elixir-engineer` | Account-scoped report backend with optional FX conversion semantics |
| 08 | `dev-frontend-ui-engineer` | Account report LiveView and FX conversion form/result UX |
| 09 | `loc-i18n-ptbr-gettext-guardian` | Gettext coverage for `fx` and `reports` domains |
| 10 | `qa-test-scenarios` | Acceptance-criteria-to-scenario mapping and coverage traceability |
| 11 | `qa-elixir-test-author` | ExUnit, LiveView, and Oban regression suite |
| 12 | `audit-security` | Security and operational review of ingestion, scheduling, and reporting boundaries |
| 13 | `audit-pr-elixir` | Final correctness, performance, and quality-gate review |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | FX persistence and index contract | PENDING | [ ] | None |
| 02 | FX context, schemas, migration, and lookup API | BLOCKED | [ ] | Task 01 |
| 03 | Provider registry, sync workers, and scheduler | BLOCKED | [ ] | Task 02 |
| 04 | CSV import and overlap upsert flow | BLOCKED | [ ] | Task 02 |
| 05 | FX LiveView CRUD and detail UI | BLOCKED | [ ] | Task 02 |
| 06 | FX upload and provider sync interactions | BLOCKED | [ ] | Task 05, Task 03, Task 04 |
| 07 | Account report FX backend contract | BLOCKED | [ ] | Task 02, Task 03 |
| 08 | Account report FX LiveView UI | BLOCKED | [ ] | Task 07, Task 05 |
| 09 | I18n Gettext pass for FX and reports | BLOCKED | [ ] | Task 06, Task 08 |
| 10 | Test scenarios and traceability | BLOCKED | [ ] | Task 09 |
| 11 | ExUnit regression suite | BLOCKED | [ ] | Task 10 |
| 12 | Security and operational audit | BLOCKED | [ ] | Task 11 |
| 13 | Final PR review and quality gate | BLOCKED | [ ] | Task 12 |

**Status Legend:**
- `PENDING` - Ready to start
- `IN_PROGRESS` - Currently being executed
- `COMPLETED` - Done and approved
- `BLOCKED` - Waiting on dependency
- `REJECTED` - Needs rework
- `ON_HOLD` - Paused by human

## Assumptions

1. The existing `llms/tasks/023_fx_series_report_conversion/plan.md` remains the feature specification, so this implementation breakdown is stored in `execution_plan.md` rather than replacing `plan.md`.
2. The new bounded context will be named `AurumFinance.Fx`, with schemas `AurumFinance.Fx.FxSeries` and `AurumFinance.Fx.FxRateRecord`, as already aligned in the spec terminology section.
3. The first account-scoped report may be implemented as a new reporting read path/LiveView rather than extending Net Worth, because multi-account FX aggregation is explicitly out of scope.
4. Provider modules will normalize provider-specific payloads into `date` + `value` rows and the persistence layer will trust the provider on pair correctness, per the approved spec.
5. `Req` is the required HTTP client for provider integrations and may need to be added to the application dependencies if not already present locally.
6. FX sync scheduling may extend the current Oban configuration with a dedicated queue and `Oban.Plugins.Cron`, unless Task 01 documents a narrower in-repo alternative that still satisfies the approved schedule semantics.
7. Human review gates are mandatory between all tasks, even where multiple tasks touch the same area.

## Open Questions

1. Task 01 should confirm whether the first account-scoped FX-converted report should live under a new `/reports/account` surface or extend an existing report route with explicit account selection.
2. Task 01 should confirm whether an `fx` Oban queue is warranted immediately or if reusing `:reporting` keeps the initial operational footprint simpler without mixing concerns too aggressively.

## Change Log

| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-23 | Plan | Initial execution plan created | Translate the approved FX Series/report conversion spec into sequenced implementation tasks |
