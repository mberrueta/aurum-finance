# Task 08: Account Report FX LiveView UI

## Status
- **Status**: COMPLETE
- **Approved**: [x] Human sign-off
- **Blocked by**: Task 07, Task 05
- **Blocks**: Task 09

## Assigned Agent
`dev-frontend-ui-engineer` - Phoenix LiveView frontend engineer for report forms, result states, and responsive UX

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Tasks 05 and 07 outputs, and current reporting LiveView patterns before implementing the account-report conversion UI.

## Objective
Implement the UI for generating a single-account report with optional FX conversion:

- account selector + `as_of_date`
- conversion toggle and conditional fields
- compatible-series empty/error states
- result rendering for native amount, converted amount, rate date, and unavailable-conversion messaging

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/05_fx_liveview_crud_and_detail_ui.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/07_account_report_fx_backend_contract.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] Existing reporting LiveViews under `lib/aurum_finance_web/live/`

## Expected Outputs

- [ ] New or updated account-report LiveView
- [ ] Conditional conversion form UX
- [ ] Result view showing native and optional converted outputs
- [ ] Invalid-selection, no-compatible-series, and missing-rate states

## Acceptance Criteria

- [ ] Convert toggle defaults to OFF
- [ ] `target_currency_code` and `fx_series_id` fields only appear when conversion is enabled
- [ ] Target currency equal to the account currency is rejected clearly
- [ ] Compatible-series dropdown reflects backend filter rules and shows a clear empty state when none exist
- [ ] Changing `as_of_date`, account, or target currency revalidates series compatibility
- [ ] Valid conversion shows native amount, converted amount, target currency, selected series reference, and rate date used
- [ ] Missing-rate state still renders the report and displays the approved unavailable message
- [ ] The report form, convert toggle, target currency select, FX series select, submit button, result container, and unavailable-conversion message/banner expose stable DOM IDs for LiveView testing
- [ ] UI does not imply any persisted conversion preference

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/reports_live.ex
lib/aurum_finance_web/live/net_worth_live.ex
lib/aurum_finance_web/components/
priv/gettext/en/LC_MESSAGES/reports.po
```

### Constraints
- Preserve existing authenticated reporting patterns
- Add explicit DOM IDs for key form and result elements
- Avoid broadening the reporting hub into a generalized FX dashboard

## Execution Instructions

### For the Agent
1. Follow the repo's report-form patterns for `as_of_date` handling and LiveView state.
2. Make conversion fields conditional, clear, and testable.
3. Ensure unavailable-rate behavior is visible without breaking the page.
4. Document any text/i18n additions for Task 09.

### For the Human Reviewer
1. Confirm the account-report UX is explicit and not overloaded.
2. Confirm invalid, empty, and unavailable-conversion states are clear.
3. Approve before Task 09 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
