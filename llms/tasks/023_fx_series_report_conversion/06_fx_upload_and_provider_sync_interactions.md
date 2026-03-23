# Task 06: FX Upload and Provider Sync Interactions

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
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

- [ ] CSV upload controls and validation/success state UX
- [ ] Overlap confirmation dialog/flow
- [ ] Provider sync action UX and pending/enqueued feedback
- [ ] Contextual action visibility based on source kind

## Acceptance Criteria

- [ ] Upload action only appears for `csv_upload` series
- [ ] Sync action only appears for `provider_module` series
- [ ] Overlap confirmation clearly explains override behavior and allows cancel
- [ ] Validation failures surface row/file errors clearly without partial mutation
- [ ] Successful import updates list/detail-derived state through normal reload/reassign flow
- [ ] Manual sync feedback confirms enqueue, not completion
- [ ] Empty-series detail state offers the correct CTA (`Upload CSV` or `Sync Now`)
- [ ] UI behavior stays consistent with the backend guardrails from Tasks 03-04

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
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

