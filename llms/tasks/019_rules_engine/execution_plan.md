# Execution Plan: Rules Engine (Data Model, Preview, Classification)

## Metadata
- **Spec**: `llms/tasks/019_rules_engine/plan.md`
- **Created**: 2026-03-12
- **Status**: IN_PROGRESS
- **Current Task**: 12 - LiveView Integration Tests

## Overview
Implements a three-commit rules engine feature spanning GitHub Issues #19, #20, and #21. The feature introduces a `Classification` context with unified scoped rule groups (`global`, `entity`, `account`), rules (expression-based conditions + JSONB actions), a pure-function evaluation engine with preview/dry-run, and a classification records layer with per-field manual override protection and audit trail integration.

## Technical Summary
### Codebase Impact
- **New files**: ~20 (context, 3 schemas, engine, embedded schema, migration x2, factories, tests, LiveView rewrites, components)
- **Modified files**: ~6 (factory.ex, router potentially, TransactionsLive, TransactionsComponents, gettext files; `mix.exs` only if a concrete evaluator backend is chosen in Task 05)
- **Database migrations**: Yes (2 migrations: `rule_groups` + `rules`, `classification_records`)
- **External dependencies**: Optional evaluator backend only. The DSL/compiler/validator contract is AurumFinance-owned and does not depend on a specific package.

### Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Expression DSL design locks in before engine is tested | Medium | High | Task 02 (engine) immediately follows Task 01 (schemas); iterate fast |
| Concrete evaluator backend proves unsuitable | Low | Medium | Keep a wrapper/adapter boundary so the backend can be swapped without changing the DSL contract |
| Scoped group matching/ordering drifts between engine, preview, and apply flows | Medium | High | Centralize scope selection and precedence in Task 05 and reuse it from preview/apply |
| Per-field override logic complexity in upsert | Medium | Medium | Extensive unit tests in Task 10; isolated function |
| RulesLive UI complexity (builder + raw editor + preview) | Medium | Medium | Split frontend into two tasks (CRUD UI vs preview UI) |

## Roles

### Human Reviewer
- Approves each task before next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject/request changes on any task

### Executing Agents
| Task | Agent | Description |
|------|-------|-------------|
| 01 | `dev-backend-elixir-engineer` | Migration + schemas (scoped RuleGroup, Rule, Action embedded) |
| 02 | `dev-backend-elixir-engineer` | Classification context CRUD + expression DSL compiler + scoped query contract |
| 03 | `qa-elixir-test-author` | Context CRUD tests + factory definitions |
| 04 | `dev-frontend-ui-engineer` | RulesLive rewrite: CRUD UI with condition builder + action builder |
| 05 | `dev-backend-elixir-engineer` | Classification.Engine pure-function evaluator |
| 06 | `dev-backend-elixir-engineer` | Preview API (Classification.preview_classification/1) |
| 07 | `qa-elixir-test-author` | Engine + preview tests |
| 08 | `dev-frontend-ui-engineer` | Preview UI in RulesLive (per-field preview; protected/manual diff deferred until ClassificationRecord exists) |
| 09 | `dev-backend-elixir-engineer` | ClassificationRecord schema + migration + classify/override APIs |
| 10 | `qa-elixir-test-author` | Classification record tests (bulk apply, manual override, audit) |
| 11 | `dev-frontend-ui-engineer` | Bulk apply UI + per-field classification display in TransactionsLive |
| 12 | `qa-elixir-test-author` | LiveView integration tests for RulesLive + TransactionsLive |
| 13 | `audit-pr-elixir` | Full PR audit: correctness, security, performance, test coverage |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Migration + Schemas | COMPLETED | [x] | None |
| 02 | Classification Context CRUD | COMPLETED | [x] | Task 01 |
| 03 | Context CRUD Tests | COMPLETED | [x] | Task 02 |
| 04 | RulesLive CRUD UI | COMPLETED | [x] | Task 02 |
| 05 | Classification.Engine | COMPLETED | [x] | Task 02 |
| 06 | Preview API | COMPLETED | [x] | Task 05 |
| 07 | Engine + Preview Tests | COMPLETED | [x] | Task 06 |
| 08 | Preview UI | COMPLETED | [x] | Task 06, Task 04 |
| 09 | ClassificationRecord + Apply APIs | COMPLETED | [x] | Task 05 |
| 10 | Classification Record Tests | COMPLETED | [x] | Task 09 |
| 11 | Bulk Apply + Classification Display UI | COMPLETED | [x] | Task 09, Task 04 |
| 12 | LiveView Integration Tests | COMPLETED | [ ] | Task 04, Task 08, Task 11 |
| 13 | PR Audit | BLOCKED | [ ] | Task 12 |

**Status Legend:**
- PENDING - Ready to start (dependencies met)
- IN_PROGRESS - Currently being executed
- COMPLETED - Done and approved
- BLOCKED - Waiting on dependency
- REJECTED - Needs rework
- ON_HOLD - Paused by human

## Assumptions

1. The AurumFinance DSL/compiler/validator contract is owned by the application and remains independent of the concrete evaluator backend.
2. The existing `audit_events` table and `Audit.insert_and_log/2` / `Audit.Multi.append_event/4` infrastructure is sufficient for classification audit needs -- no schema changes needed to `audit_events`.
3. `memo` is out of scope for v1 condition fields because the current `Transaction` schema does not expose it; agents must not add it implicitly.
4. The `institution_name` condition field assumes `Account.institution_name` is accessible via posting preloads (posting -> account -> institution_name). This is already the case.
5. No new routes are needed -- RulesLive already has `live "/rules", RulesLive, :index`. Additional live actions (`:new_group`, `:edit_group`, `:new_rule`, `:edit_rule`, `:preview`) may be added as modal/slideover actions on the same route.
6. The `currency_code` condition field remains in v1 and is always derived from `posting.account.currency_code` (never from a persisted posting column), consistent with project conventions.
7. `rule_groups.target_fields` is persisted as a Postgres string array (`text[]`) and modeled as `{:array, :string}` in Ecto; it is not JSONB.
8. `RuleGroup` uses a unified explicit scope model: `scope_type` in `[:global, :entity, :account]` plus nullable `entity_id` / `account_id` with valid combinations enforced by changeset and DB constraints.
9. Account-scoped groups do not redundantly store `entity_id`; account ownership is derived through `account_id`.
10. Runtime precedence for matching groups is fixed as `account > entity > global`, then `priority ASC`, then `name ASC`.
11. Factories for `rule_group`, `rule`, and `classification_record` will be added to the existing `test/support/factory.ex`.
12. The `TransactionsLive` expanded detail view already uses `expanded_transaction_id` assigns -- per-field classification display will extend this existing pattern.
13. If Task 05 uses `Excellerate` as the first backend implementation, it should be wired behind the adapter boundary; user-provided reference points to `geofflane/excellerate` release `0.3.0`.
14. Protected/manual-override preview diff is deferred until the ClassificationRecord work lands; Task 08 is limited to read-only proposed results, no-match states, and human-readable category/per-field rendering.

## Open Questions

No blocking open questions at planning time.

## Change Log
| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-12 | Plan | Initial creation | - |
| 2026-03-12 | Plan | Removed `memo` from v1 assumptions/open questions; normalized `currency_code` as derived from `posting.account.currency_code` | Align planning docs with current ledger model |
| 2026-03-12 | Plan | Normalized `target_fields` to Postgres string array (`text[]`) instead of JSONB | Remove DB/schema mismatch and simplify implementation |
| 2026-03-12 | Plan | Removed evaluator-library uncertainty from Task 02 and made the engine depend on an internal adapter boundary | Keep the DSL contract independent from `Excellerate` or any future backend |
| 2026-03-12 | Plan | Replaced entity-only rule groups with unified explicit scopes (`global`, `entity`, `account`) and deterministic scope precedence | Support reusable groups without splitting the model into multiple tables |
| 2026-03-13 | Tasks 01-05 | Marked backend/data model, CRUD, UI base, and engine work as completed; advanced current task to Preview API | Reflect implementation progress in the repo task tracker |
| 2026-03-16 | Tasks 08-09 boundary | Deferred protected/manual-override preview diff until ClassificationRecord work; narrowed Task 08 to read-only per-field preview UI | Keep the task sequence consistent with the current backend contract |
| 2026-03-16 | Task 09 | Implemented `classification_records`, apply/manual override APIs, preview integration with persisted state, and backend coverage; advanced current task to ClassificationRecord review | Reflect backend completion before QA/UI follow-up tasks |
| 2026-03-16 | Task 10 | Added Task 10 QA coverage for classification record validations, apply flows, manual overrides, audit metadata, bulk failure reporting, and deleted-rule provenance resilience; advanced current task to Task 10 review | Reflect focused backend test completion pending human sign-off |
| 2026-03-16 | Task 11 | Implemented transactions-page bulk apply controls, inline per-field classification display, provenance badges, and manual override controls; advanced current task to Task 11 review | Reflect frontend integration of classification apply/display before LiveView test expansion |
| 2026-03-17 | Task 11 | Marked Task 11 as completed/approved in the execution tracker and advanced current task to Task 12 | Align tracker state with the implemented transactions classification UI and human sign-off recorded in Task 11 |
| 2026-03-17 | Task 12 | Added LiveView integration coverage for RulesLive and TransactionsLive, validated the targeted suite, and passed `mix precommit` | Reflect Task 12 implementation completion pending human sign-off before the final PR audit |
