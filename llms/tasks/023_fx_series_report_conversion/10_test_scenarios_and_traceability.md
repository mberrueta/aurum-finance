# Task 10: Test Scenarios and Traceability

## Status
- **Status**: COMPLETE
- **Approved**: [x] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 11

## Assigned Agent
`qa-test-scenarios` - QA scenario designer for acceptance-criteria coverage and regression mapping

## Agent Invocation
Invoke the `qa-test-scenarios` agent with instructions to read this task file, the approved spec, and completed implementation tasks before producing the final scenario matrix for automated coverage.

## Objective
Translate the approved FX/report acceptance criteria into a concrete scenario map for backend, LiveView, Oban, and parser coverage so the final test-author task is narrow and auditable.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] Completed outputs from Tasks 02-09
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] Existing test patterns under `test/aurum_finance/` and `test/aurum_finance_web/live/`

## Expected Outputs

- [ ] Scenario matrix mapped to acceptance criteria and edge cases
- [ ] Recommended test layers for each scenario
- [ ] Explicit note of any residual non-automated checks for human review

## Acceptance Criteria

- [ ] Scenarios cover FX CRUD, delete guardrails, CSV upload success/failure/overlap cases, provider sync, scheduler behavior, and account-report conversion
- [ ] Scenarios cover missing-rate and no-compatible-series UX states
- [ ] Scenarios distinguish backend vs LiveView vs worker-level assertions
- [ ] Scenarios stay deterministic and sandbox-safe
- [ ] Any intentionally deferred coverage is documented explicitly

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/aurum_finance_web/live/
test/support/factory.ex
```

### Constraints
- Keep scenarios actionable for ExUnit authoring
- Avoid low-signal duplication of already-obvious smoke cases

## Execution Instructions

### For the Agent
1. Map the accepted feature behavior to test layers and scenario IDs.
2. Call out the highest-risk regressions explicitly.
3. Keep the scenario set compact but complete enough for final sign-off.

### For the Human Reviewer
1. Confirm the scenario matrix covers the approved scope and major edge cases.
2. Approve before Task 11 begins.

---

## Execution Summary
### Scope & Assumptions

- Scope covers the FX/report work delivered across Tasks 02-09:
  - FX series CRUD and detail UI
  - FX CSV import
  - FX provider sync and worker behavior
  - scheduler/refresh behavior where applicable
  - account report conversion backend contract
  - saved account reports dashboard and create/edit flow
- The app is effectively single-operator/global for saved account reports.
- Scenarios below are designed for deterministic ExUnit authoring under SQL Sandbox.
- This matrix defines what must be covered; it does not require every scenario to land in the same test file.

### Risk Areas

- FX compatibility can fail structurally or at read time; those must not be conflated.
- CSV overlap and duplicate-date handling can corrupt rate history if regression slips in.
- Provider sync and worker flows are async and need explicit enqueue/retry/state coverage.
- Saved account reports persist definitions only; regressions must not start persisting rendered values.
- Dashboard behavior can drift from detail-page behavior if read-time report derivation is not tested at both layers.
- Invalid saved definitions must degrade visibly, not crash the page.

### Scenario Matrix

| ID | Priority | Layer | Area | Scenario | Preconditions | Steps | Expected Result | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FX-CTX-001 | P0 | Integration | Validation/DB | Create FX series with valid provider or CSV configuration | Entity/account data not required | Create series with valid currencies, date range, source kind | Series persists with normalized fields and expected defaults | Context/API coverage |
| FX-CTX-002 | P0 | Integration | Validation | Reject invalid FX series attrs | None | Submit missing/invalid currency codes, invalid date range, invalid provider config | Changeset errors are returned through `errors`/domain messages | Deterministic changeset assertions |
| FX-CTX-003 | P0 | Integration | DB | Delete guard blocks removal when rate rows exist | Series with `fx_rate_records` exists | Attempt delete | Returns `{:error, :has_records}` or equivalent blocked result | Protects historical rate integrity |
| FX-CTX-004 | P1 | Integration | DB | Delete succeeds when series has no rates | Empty series exists | Delete series | Series is removed cleanly | Complements guardrail path |
| FX-CSV-001 | P0 | Integration | Parser | CSV upload imports valid rows into an empty series | CSV-upload series exists | Import valid CSV with ordered dates and values | Rates persist, date bounds update, row count matches | Existing `csv_import_test` pattern |
| FX-CSV-002 | P0 | Integration | Parser | Reject malformed CSV content | CSV-upload series exists | Upload malformed header/body | Returns parse/import error without partial writes | No partial persistence |
| FX-CSV-003 | P0 | Integration | Parser | Reject duplicate dates inside the same file | CSV-upload series exists | Upload CSV containing same date twice | Returns duplicate-date error, no import applied | Deterministic parser scenario |
| FX-CSV-004 | P0 | Integration | DB | Reject overlapping import against existing stored rates | Series already has stored range | Upload CSV overlapping an existing date | Import is blocked with overlap/duplicate feedback | Historical integrity regression risk |
| FX-CSV-005 | P1 | Integration | DB | Allow non-overlapping append/prepend imports | Series has existing rates | Upload valid CSV before or after stored range without overlap | Import succeeds and merged range is correct | Boundary behavior |
| FX-SYNC-001 | P0 | Unit/Integration | Worker | Provider sync enqueues only for provider-backed series | Provider series and CSV series exist | Trigger sync entrypoint for each | Provider series enqueues; CSV series is rejected safely | Keep enqueue semantics explicit |
| FX-SYNC-002 | P0 | Integration | Jobs | Sync worker stores fetched rows and updates sync tracking on success | Provider series exists, provider mocked | Perform worker with deterministic provider payload | Rates persist, sync state becomes success/ok, tracking metadata updates | No external network |
| FX-SYNC-003 | P0 | Integration | Jobs | Sync worker records failure/retry state on provider failure | Provider series exists, provider mocked to fail | Perform worker on failing fetch | Worker returns retry/failure outcome and tracking state updates with error | Retry path must be observable |
| FX-SYNC-004 | P1 | Integration | Jobs | Sync worker handles already-up-to-date/no-op range safely | Provider series with complete coverage exists | Trigger sync with no missing range | No duplicate rates, status remains coherent | Idempotency coverage |
| FX-SYNC-005 | P1 | Unit | Observability | Sync comments/status helpers map states consistently | Deterministic sync state map | Evaluate helper/output for queued/running/ok/retrying/failed/stopped/not_applicable | Badge/comment copy and states stay aligned | Protects UI status drift |
| FX-SCHED-001 | P1 | Integration | Jobs | Scheduler enqueues sync only for eligible provider series | Mixed series set exists | Run scheduler tick/entrypoint | Eligible provider series enqueue once; CSV/non-eligible series do not | Sandbox-safe job assertion |
| FX-SCHED-002 | P1 | Integration | Jobs | Scheduler is idempotent for the same due set | Eligible provider series exist | Invoke scheduler twice for same due state | Duplicate work is prevented or safely coalesced per current contract | Document actual dedup rule in final test authoring |
| FX-LV-001 | P0 | LiveView | UI | FX index lists series, source kind, and sync status | Seed provider and CSV series | Open `/fx` | Series rows and stable action IDs render | Existing `fx_live_test` patterns |
| FX-LV-002 | P0 | LiveView | UI | Create FX series from LiveView form | No series required | Submit valid create form | Success flash, series visible, persisted values correct | Covers create UI path |
| FX-LV-003 | P1 | LiveView | Validation | FX form shows validation errors for invalid attrs | None | Submit invalid create/edit form | Stable form IDs remain, errors render without crash | Avoid raw HTML assertions where possible |
| FX-LV-004 | P1 | LiveView | UI | Detail page shows sync status and refresh action behavior | Provider series exists | Open detail, refresh sync status | Status section updates and remains readable for each state | Read-only UI coverage |
| REP-CTX-001 | P0 | Integration | Validation | Saved account report accepts native definition | Account exists | Create/update with account only | Definition persists with nil target currency/fx series/date | Persists config only |
| REP-CTX-002 | P0 | Integration | Validation | Saved account report accepts converted definition | Account and compatible series exist | Create/update with target currency + fx series | Definition persists and preloads account/entity scope | Structural compatibility path |
| REP-CTX-003 | P0 | Integration | Validation | Reject partial conversion config | Account exists | Submit target currency without series; submit series without target currency | Changeset errors returned on missing pair | Explicit invariant coverage |
| REP-CTX-004 | P0 | Integration | Validation | Reject same-currency conversion | Account currency equals target currency | Submit converted definition with same target currency | Changeset error on `target_currency_code` | High-signal domain rule |
| REP-CTX-005 | P0 | Integration | Validation | Reject structurally incompatible FX series | Account and non-compatible series exist | Submit converted definition with incompatible series | Changeset error on `fx_series_id` | Uses compatibility list contract |
| REP-CTX-006 | P1 | Integration | Read model | Allow duplicate saved account reports | Account exists | Create same definition twice | Two separate records persist | No uniqueness constraint in v1 |
| REP-CTX-007 | P1 | Integration | Query | Dashboard listing is deterministic by derived label | Multiple accounts/entities exist | List saved account reports | Output is alphabetized by derived label | Net Worth stays separate at UI layer |
| REP-READ-001 | P0 | Integration | Reporting | Preview native saved account report with live date | Account snapshot exists, no pinned date | Preview definition | Returns report with `live? = true` and current effective date | No persisted rendered result |
| REP-READ-002 | P0 | Integration | Reporting | Preview converted saved account report with pinned date | Account snapshot + compatible rate for pinned date exist | Preview definition | Converted amount, series reference, and effective pinned date are returned | Core derived-report path |
| REP-READ-003 | P0 | Integration | Reporting | Missing rate for pinned date returns unavailable conversion but keeps native report | Snapshot exists, compatible series exists, rate missing for date | Preview definition | Native side still available; conversion state is unavailable | Must not fail whole report |
| REP-READ-004 | P0 | Integration | Reporting | Invalid persisted definition degrades safely at runtime | Saved definition points to removed/incompatible series or missing account context | Preview/list for dashboard | Error tuple or invalid card state, not crash | Runtime failure behavior from plan |
| REP-LV-001 | P0 | LiveView | UI | Dashboard shows built-in Net Worth first and saved account reports after it | Net Worth data + multiple saved reports exist | Open `/reports` | Net Worth card renders first; saved cards follow in deterministic order | Core dashboard traceability |
| REP-LV-002 | P0 | LiveView | UI | Dashboard shows multiple saved account reports together | Multiple definitions exist | Open `/reports` | Cards render concurrently; duplicates remain visible | Prevent regression back to one-off form mindset |
| REP-LV-003 | P0 | LiveView | UI | New saved account report page shows native-by-default form | Accounts exist | Open `/reports/account-reports/new` | Convert toggle off by default; target currency and series fields hidden | Stable DOM IDs required |
| REP-LV-004 | P0 | LiveView | Validation | Turning conversion on reveals conditional fields and revalidates compatibility | Accounts + series exist | Select account/date, enable conversion, pick target currency | Compatible series list updates without page breakage | Dynamic UX coverage |
| REP-LV-005 | P0 | LiveView | Validation | No-compatible-series state is rendered clearly | Account exists, no compatible series for target/date | Enable conversion and choose target | Empty-state message/banner renders and submit path stays understandable | Explicit acceptance criterion |
| REP-LV-006 | P0 | LiveView | Validation | Same-currency conversion is rejected clearly in the form | Account exists | Enable conversion and choose same currency | Form error is shown on target currency | UI mirrors backend rule |
| REP-LV-007 | P0 | LiveView | UI | Save native saved account report and redirect/show on dashboard | Account snapshot exists | Submit native form | Persisted definition appears on dashboard card | Create flow |
| REP-LV-008 | P0 | LiveView | UI | Save converted saved account report and render converted result | Snapshot + compatible rate exist | Submit converted form | Detail preview shows converted amount, as-of date, and FX slug badge | End-to-end LiveView path |
| REP-LV-009 | P0 | LiveView | UI | Missing-rate state remains visible without crashing detail page | Snapshot exists, no rate for date | Open saved converted definition | Detail page shows unavailable conversion state and keeps native side coherent | Explicit unavailable UX |
| REP-LV-010 | P1 | LiveView | UI | Edit existing saved account report | Saved definition exists | Open detail page, change fields, save | Definition updates and preview/dashboard reflect new config | Create/edit parity |
| REP-LV-011 | P1 | LiveView | UI | Delete existing saved account report | Saved definition exists | Delete from detail page | Definition removed and user returns to dashboard | Destructive flow |
| REP-LV-012 | P1 | LiveView | UI | Invalid persisted definition renders clear unavailable state on dashboard/detail | Definition exists but is non-runnable | Open dashboard/detail | Invalid banner/card state is shown, edit path remains available | Runtime degradation path |
| I18N-001 | P1 | Integration | I18n | New FX/report strings use correct gettext domains | Feature code exists | Review/render representative flows | FX copy comes from `fx`, report copy from `reports`, validation from `errors` | Low-cost regression guard |
| I18N-002 | P2 | Manual | I18n | PT catalogs do not break UI fallback behavior | PT locale catalogs present | Render representative screens under PT locale | Strings resolve or safely fall back without missing-key crashes | Human review check |

### Acceptance Criteria

- Given a valid provider-backed FX series, when the operator creates or edits it, then the series persists and the UI shows a stable detail/status surface.
- Given a CSV-backed FX series, when the operator uploads valid non-overlapping rows, then rates are imported without duplicate or overlap corruption.
- Given malformed, duplicate-date, or overlapping CSV input, when import is attempted, then the operation fails deterministically and no partial rate set is persisted.
- Given a provider sync request, when the worker succeeds, then fetched rates persist and sync tracking shows a successful state.
- Given a provider sync request, when the provider fails, then retry/failure behavior is explicit and observable without corrupting rates.
- Given a scheduler tick, when eligible provider series exist, then only eligible series are enqueued and duplicate scheduling behavior stays deterministic.
- Given a native saved account report definition, when it is previewed, then the report is derived at read time using the effective date and no rendered result is persisted.
- Given a converted saved account report definition, when a compatible series and rate exist, then the preview returns converted amount, target currency, series reference, and effective date.
- Given a converted saved account report definition, when no usable rate exists for the effective date, then the report remains readable and conversion is shown as unavailable instead of failing the whole page.
- Given a partial or same-currency conversion request, when the definition is validated, then the operator sees clear errors and the invalid definition is not persisted.
- Given a target currency/date with no compatible series, when conversion is enabled in the LiveView form, then the UI shows a clear empty state and revalidates when account/date/target changes.
- Given multiple saved account reports, when the dashboard loads, then Net Worth appears first and saved reports follow in deterministic alphabetical order by derived label.
- Given an invalid persisted saved definition, when the dashboard or detail page loads, then the screen renders an invalid/unavailable state and still allows editing to restore validity.

### Regression Checklist

- Net Worth card still renders even when saved account reports are empty.
- Saved account reports remain global records, not per-user records.
- Dashboard does not regress back into a single one-off account report generator flow.
- `pinned_as_of_date = nil` still behaves as live/current-date at read time.
- `pinned_as_of_date != nil` still behaves as a fixed-date saved view.
- No rendered balance, converted amount, freshness snapshot, or display label is persisted in `saved_account_reports`.
- FX delete guard continues blocking deletes when rate rows exist.
- CSV upload remains sandbox-safe and deterministic with no network dependency.
- Provider sync tests remain fully mocked and do not reach external APIs.
- Reconciliation/import/rules UI regressions from shared badge refactors are covered separately and not silently conflated with FX/report work.

### Residual Manual Checks

- Visual review of `/reports` card density and responsive wrapping after multiple saved reports exist.
- PT-BR copy review for newly added report strings and short status labels.
- Quick operator walk-through for the “create on `/fx`, consume on `/reports/account-reports/*`” workflow clarity.

### Out of Scope

- Browser-level E2E outside LiveViewTest.
- Performance/load testing for large FX catalogs or very large dashboard counts.
- Background auto-refresh beyond the current explicit refresh/load semantics.
- Generic dashboard personalization or widget-layout behavior.
- Unrelated reconciliation/import feature expansion beyond shared regression awareness.

## Human Review
*[Filled by human reviewer]*
