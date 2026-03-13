# Task 12: LiveView Integration Tests

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04, Task 08, Task 11
- **Blocks**: Task 13

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Write end-to-end LiveView tests for the final rules and transactions workflows: rules CRUD, preview, bulk apply, single apply, provenance display, and manual override interactions.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (UI acceptance criteria and UX states)
- [ ] `llms/tasks/019_rules_engine/04_rules_live_crud_ui.md` - Rules CRUD UI contract
- [ ] `llms/tasks/019_rules_engine/08_preview_ui.md` - Preview UI contract
- [ ] `llms/tasks/019_rules_engine/11_transactions_classification_ui.md` - Transactions UI contract
- [ ] `llms/constitution.md` - Test discipline requirements
- [ ] `llms/coding_styles/elixir_tests.md` - Test style guide
- [ ] `test/aurum_finance_web/live/accounts_live_test.exs` - Modal/form test pattern reference
- [ ] `test/aurum_finance_web/live/transactions_live_test.exs` - Existing transactions pattern reference
- [ ] `lib/aurum_finance_web/live/rules_live.ex` - Rules LiveView under test
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` - Transactions LiveView under test

## Expected Outputs

- [ ] Test file: `test/aurum_finance_web/live/rules_live_test.exs`
- [ ] Updated `test/aurum_finance_web/live/transactions_live_test.exs`
- [ ] Component-level tests if needed for new classification/provenance components

## Acceptance Criteria

- [ ] RulesLive tests cover visible group listing and selection for the current entity context, including global/entity/account scoped groups
- [ ] RulesLive tests cover group create/edit/delete flows
- [ ] RulesLive tests cover scope selection in group create/edit forms
- [ ] RulesLive tests cover rule create via builder and rule edit via raw expression
- [ ] RulesLive tests cover preview form submission, loading/result/no-match states, and protected indicators
- [ ] TransactionsLive tests cover single-transaction apply from expanded detail
- [ ] TransactionsLive tests cover bulk apply for the current entity/date range
- [ ] TransactionsLive tests cover manual field override and clear-override flows
- [ ] TransactionsLive tests cover per-field provenance display for rule and manual states, including scope badges
- [ ] Tests use explicit DOM IDs added by the UI tasks
- [ ] Tests prefer `has_element?/2`, `element/2`, `render_submit/2`, and `render_change/2` over raw HTML matching where possible
- [ ] Tests run with `mix test`

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance_web/live/rules_live_test.exs
test/aurum_finance_web/live/transactions_live_test.exs
test/aurum_finance_web/components/transactions_components_test.exs
```

### Patterns to Follow
- Follow existing auth-protected LiveView test setup (`conn |> log_in_root() |> live(...)`)
- Keep tests scenario-focused and use the stable IDs introduced by the UI tasks
- Prefer asserting visible state transitions rather than internal assigns
- Add component tests only where markup complexity is easier to validate in isolation

### Constraints
- Do NOT duplicate backend/unit coverage from Tasks 03, 07, or 10
- Keep tests resilient to copy changes by prioritizing IDs and semantic selectors
- Avoid raw HTML snapshot-style assertions

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Add RulesLive integration coverage first, then extend TransactionsLive coverage
3. Reuse existing factory helpers and keep setup minimal
4. Run `mix test` and document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Run `mix test`
2. Verify the tests cover the core user journeys from the spec
3. Check that selectors rely on explicit DOM IDs rather than brittle text
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
