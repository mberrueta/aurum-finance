# Task 10: Import History and Result Preview UI

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02, Task 06, Task 07, Task 08, Task 09
- **Blocks**: Tasks 12, 13

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements UI components, Tailwind styling, LiveView hooks, and responsive accessible interfaces.

## Agent Invocation
Activate `dev-frontend-ui-engineer` with:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 10 from `llms/tasks/015_import_source_file_model/10_import_history_and_result_preview_ui.md`.
>
> Read the full plan and all prerequisite outputs. Build the account-scoped history and preview/result UI for completed and failed imports.

## Objective
Implement the import history list and result preview/review UI per account. This task covers summary counts, row preview, warnings display, and inspectability of a selected imported file. This remains a preview stage only.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 02, 06, 07, 08, and 09 outputs
- [ ] `ImportLive` and related UI components

## Expected Outputs

- [ ] Updated `ImportLive` and/or related templates/components
- [ ] LiveView tests for history and result inspection

## Acceptance Criteria

- [ ] History is shown per account
- [ ] History shows uploaded file, status, timestamps, and summary counts
- [ ] User can inspect a selected imported file
- [ ] Completed imports show rows read/ready/duplicates/invalid and warnings
- [ ] Failed imports show error details
- [ ] UI clearly remains preview/review only and does not create transactions

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*

