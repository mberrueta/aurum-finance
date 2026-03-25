# Task 06: FX Upload and Provider Sync Interactions

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 05, Task 03, Task 04
- **Blocks**: Task 09

## Assigned Agent
`dev-frontend-ui-engineer` - Phoenix LiveView frontend engineer for async interaction flows and accessible stateful UX

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Tasks 03-05 outputs, and the approved UX states before wiring upload and sync interactions onto the real FX UI.

## Objective
Implement the interaction layer for:

- CSV upload on manual series only
- overlap confirmation and cancel/continue flow
- provider-series manual sync action
- in-page success/error/pending states tied to backend enqueue/import contracts

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/03_provider_registry_sync_workers_and_scheduler.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/04_csv_import_and_overlap_upsert_flow.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/05_fx_liveview_crud_and_detail_ui.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`

## Expected Outputs

- [x] CSV upload controls and validation/success state UX
- [x] Overlap confirmation dialog/flow (deferred by product decision; current behavior is direct import without modal)
- [x] Provider sync action UX and pending/enqueued feedback
- [x] Contextual action visibility based on source kind

## Acceptance Criteria

- [x] Upload action only appears for `csv_upload` series
- [x] Sync action only appears for `provider_module` series
- [x] Overlap confirmation requirement explicitly waived for now (no modal; best-effort direct import)
- [x] Validation failures surface row/file errors clearly without partial mutation
- [x] Successful import updates list/detail-derived state through normal reload/reassign flow
- [x] Manual sync feedback confirms enqueue, not completion
- [x] Empty-series detail state offers the correct CTA (`Upload CSV` or `Sync Now`)
- [x] UI behavior stays consistent with the backend guardrails from Tasks 03-04

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/fx_live.ex
lib/aurum_finance_web/components/
assets/js/app.js
```

### Constraints
- No generalized upload manager or progress dashboard
- Prefer simple LiveView state and dialogs over heavier JS
- Keep behavior test-friendly with stable IDs and explicit states

## Execution Instructions

### For the Agent
1. Wire the approved backend APIs into the FX UI.
2. Keep overlap confirmation and sync feedback explicit.
3. Ensure source-kind-specific actions are impossible to trigger from the wrong UI state.
4. Document any remaining UX caveats for the test and i18n tasks.

### For the Human Reviewer
1. Confirm upload and sync flows are understandable and bounded.
2. Confirm overlap/cancel semantics match the spec.
3. Approve before Task 09 begins.

---

## Execution Summary
Implemented on `FxLive`:

- CSV upload enabled for `csv_upload` series in detail view with `live_file_input` + submit action.
- CSV import path wired to `AurumFinance.Fx.CsvImport.parse/1` and `AurumFinance.Fx.CsvImport.import/2`.
- Import success updates list/detail state in-place and refreshes records.
- Validation/import errors surface in UI with explicit reasons.
- Provider series keeps `Sync Now` / `Refresh Sync Status` interactions with enqueue-oriented feedback.

Decision recorded:

- Overlap confirmation modal is intentionally deferred by product decision.
- Current UX uses direct import behavior without confirmation step.

## Human Review
- Approved to close Task 06 without overlap modal for now.
