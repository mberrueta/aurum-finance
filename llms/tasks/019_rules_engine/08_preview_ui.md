# Task 08: RulesLive Preview UI

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06, Task 04
- **Blocks**: Task 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Extend `RulesLive` with a real preview workflow that lets the user choose a date range, run `preview_classification/1`, and inspect per-transaction/per-field proposed results, including protected fields and no-match states.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #20, Preview UX States, US-9 through US-12)
- [ ] `llms/tasks/019_rules_engine/04_rules_live_crud_ui.md` - Existing RulesLive CRUD UI baseline
- [ ] `llms/tasks/019_rules_engine/06_preview_api.md` - Preview payload contract
- [ ] `llms/constitution.md` - HEEx and i18n rules
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance_web/live/rules_live.ex` - LiveView to extend
- [ ] `lib/aurum_finance_web/components/rules_components.ex` - Components to extend
- [ ] `lib/aurum_finance_web/components/core_components.ex` - Form/input primitives
- [ ] `lib/aurum_finance_web/components/ui_components.ex` - Shared table/badge helpers
- [ ] `lib/aurum_finance/classification.ex` - Preview API

## Expected Outputs

- [ ] Updated `lib/aurum_finance_web/live/rules_live.ex`
- [ ] Updated `lib/aurum_finance_web/components/rules_components.ex`
- [ ] Updated `lib/aurum_finance_web/live/rules_live.html.heex` if the LiveView uses a separate template
- [ ] Updated gettext strings in the `rules` domain as needed

## Acceptance Criteria

- [ ] Preview controls exist on RulesLive with explicit date range inputs and a run action
- [ ] Preview calls the context API only; no repo access from the web layer
- [ ] Loading state shows while preview is running
- [ ] Preview result view shows matched transactions with per-field proposed values
- [ ] Preview result view distinguishes protected/manual-override fields from regular proposed changes
- [ ] Preview result view distinguishes transactions with no matching rules
- [ ] Result rows include enough explainability for humans: scope badge + group/rule names per proposed field
- [ ] Empty states are handled per spec: no transactions, no matches, and preview errors
- [ ] Existing CRUD UI from Task 04 remains functional
- [ ] All text uses `dgettext("rules", "...")`
- [ ] HEEx follows repository rules (`{}` interpolation, `:if`/`:for`, no legacy blocks)

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/rules_live.ex          # LiveView state/events
lib/aurum_finance_web/components/rules_components.ex
test/aurum_finance_web/live/accounts_live_test.exs # Form/modal test pattern reference
```

### Patterns to Follow
- Use explicit DOM IDs for preview form, run button, result rows, and empty states
- Follow the existing entity-scoped page pattern from RulesLive/AccountsLive while surfacing global/entity/account group visibility clearly
- Keep preview render logic in components where it improves readability
- Surface flash/error states for preview failures

### Constraints
- Do NOT implement bulk apply from this page
- Do NOT rebuild the old mock “test runner”
- Keep preview read-only; no hidden write side effects

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Add preview state to the existing RulesLive CRUD flow without regressing it
3. Build the date-range form and preview table/detail presentation
4. Add clear loading, empty, and error states
5. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Manually test preview with matching and non-matching ranges
2. Verify protected-field UI is understandable
3. Verify no create/update/apply behavior occurs from preview
4. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
