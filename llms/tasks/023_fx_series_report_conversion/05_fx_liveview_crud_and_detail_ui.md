# Task 05: FX LiveView CRUD and Detail UI

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 06, Task 08

## Assigned Agent
`dev-frontend-ui-engineer` - Phoenix LiveView frontend engineer for polished CRUD flows and responsive UX

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file, Task 02 output, the approved spec, and the current mock `/fx` page before replacing it with the real FX management UI.

## Objective
Replace the mock FX page with a real `/fx` surface that supports:

- empty and populated list states
- create/edit forms with immutable identity fields
- detail panel/page showing metadata and recent records
- contextual row actions and guarded deletion for empty series only

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/02_fx_context_schemas_and_lookup_api.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance_web/live/fx_live.ex`
- [ ] `lib/aurum_finance_web/components/layouts.ex`
- [ ] Existing LiveView/component patterns under `lib/aurum_finance_web/live/`

## Expected Outputs

- [ ] Real `FxLive` implementation or replacement LiveView(s)
- [ ] List table with required metadata and row actions
- [ ] Create/edit UX with inline validation and immutable-field handling
- [ ] Detail UI with recent records and correct empty states
- [ ] Delete confirmation flow for empty series only

## Acceptance Criteria

- [ ] `/fx` no longer renders mock-only data
- [ ] The page follows current authenticated LiveView/layout conventions
- [ ] The list shows name, pair, source, provider, date range, last ingested date, and row count
- [ ] Create/edit forms only allow editing approved mutable fields after creation
- [ ] Delete action is only exposed for empty series and blocked with clear feedback otherwise
- [ ] Detail UI shows metadata plus the latest rate records in descending date order
- [ ] Empty states and loading/saving states from the spec are represented clearly
- [ ] UI remains intentionally minimal and does not add charts or analytics dashboards

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/fx_live.ex
lib/aurum_finance_web/components/
test/aurum_finance_web/live/
priv/gettext/en/LC_MESSAGES/fx.po
```

### Constraints
- Preserve the repo's LiveView/layout conventions and IDs for testing
- Use imported `<.input>` and `<.icon>` helpers where applicable
- No inline `<script>` tags

## Execution Instructions

### For the Agent
1. Replace the mock surface with the real CRUD/detail flow.
2. Keep the UI polished but operationally simple.
3. Add stable DOM IDs for forms, buttons, tables, and row actions.
4. Leave upload/sync interaction wiring for Task 06.

### For the Human Reviewer
1. Confirm `/fx` now represents the approved management flow.
2. Confirm create/edit/delete guardrails are clear in the UI.
3. Approve before Task 06 and Task 08 begin.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

