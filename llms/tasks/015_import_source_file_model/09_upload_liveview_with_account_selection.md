# Task 09: Upload LiveView With Account Selection

## Status
- **Status**: DONE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01, Task 03, Task 08
- **Blocks**: Tasks 10, 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements UI components, Tailwind styling, LiveView hooks, and responsive accessible interfaces.

## Agent Invocation
Activate `dev-frontend-ui-engineer` with:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 09 from `llms/tasks/015_import_source_file_model/09_upload_liveview_with_account_selection.md`.
>
> Read the full plan and prior task outputs first. Replace the mocked import entry flow with a real account-scoped upload UI, but do not implement full result inspection in this step.

## Objective
Build the account-scoped import entry experience: optional entity filter, required account selection, drag-and-drop/file-picker upload, and pending-state handoff to async processing.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 01, 03, and 08 outputs
- [ ] `lib/aurum_finance_web/live/import_live.ex`
- [ ] `lib/aurum_finance_web/router.ex`
- [ ] relevant UI component patterns in `lib/aurum_finance_web/components/`

## Expected Outputs

- [ ] Updated `ImportLive`
- [ ] Any new/import-specific UI component support if needed
- [ ] LiveView tests for account selection and upload entry flow

## Acceptance Criteria

- [ ] Upload cannot proceed without account selection
- [ ] Entity filter, if present, only narrows account choices
- [ ] Drag & drop and file-picker both remain in scope
- [ ] Upload creates `imported_file` in `pending`
- [ ] Async job is enqueued after upload
- [ ] UI reflects pending/processing state via persisted data and PubSub notifications

## Execution Summary
- Replaced the mocked import wizard in `ImportLive` with a real account-scoped upload flow.
- Added entity and account selectors, keeping entity as an optional helper filter and account as the required upload scope.
- Added drag-and-drop plus file-picker upload using LiveView uploads with CSV-only acceptance.
- Wired uploads to `Ingestion.store_imported_file/1` and `Ingestion.enqueue_import_processing/1`.
- Added account-scoped import history that reloads from persisted state and reacts to PubSub notifications.
- Added LiveView coverage for account selection enforcement, upload enqueueing, and PubSub-driven status refresh.

## Human Review
*[Filled by human reviewer]*
