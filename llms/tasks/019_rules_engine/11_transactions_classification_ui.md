# Task 11: Bulk Apply + Classification Display UI

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 09, Task 04
- **Blocks**: Task 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Extend `TransactionsLive` and `TransactionsComponents` to support rules application from the transactions experience: bulk apply for a date range, single-transaction apply from the expanded detail row, and per-field classification display with provenance and manual override controls.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #21, US-13 through US-16, UX states)
- [ ] `llms/tasks/019_rules_engine/04_rules_live_crud_ui.md` - Existing UI patterns and shared assumptions
- [ ] `llms/tasks/019_rules_engine/09_classification_record_and_apply_apis.md` - Apply/manual API contract
- [ ] `llms/constitution.md` - HEEx/i18n rules
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` - LiveView to extend
- [ ] `lib/aurum_finance_web/live/transactions_live.html.heex` - Transactions template
- [ ] `lib/aurum_finance_web/components/transactions_components.ex` - Detail component to extend
- [ ] `test/aurum_finance_web/live/transactions_live_test.exs` - Existing interaction patterns
- [ ] `lib/aurum_finance/classification.ex` - Classification APIs
- [ ] `lib/aurum_finance/ledger.ex` - Transaction query layer

## Expected Outputs

- [ ] Updated `lib/aurum_finance_web/live/transactions_live.ex`
- [ ] Updated `lib/aurum_finance_web/live/transactions_live.html.heex`
- [ ] Updated `lib/aurum_finance_web/components/transactions_components.ex`
- [ ] Updated gettext strings in the `transactions` and/or `rules` domains as needed

## Acceptance Criteria

- [ ] Bulk apply controls exist on the transactions page and operate on the current entity/date range
- [ ] Bulk apply shows loading/progress state and summary counts after completion
- [ ] Single-transaction “Apply Rules” action exists in the expanded transaction detail
- [ ] After single apply, the transaction detail refreshes to show current classification state
- [ ] Per-field classification display shows category, tags, investment type, and notes independently
- [ ] Each field shows one of the explicit states: unclassified, rule-classified, manually overridden
- [ ] Rule-classified fields show provenance (scope badge, group/rule name, and timestamp if available)
- [ ] Manual fields show manual badge, lock indicator, and clear-override action
- [ ] Category manual entry uses a picker limited to same-entity category accounts
- [ ] Tags manual entry supports free-form input within the backend constraints
- [ ] No-match feedback is shown when applying rules yields no changes
- [ ] Existing transaction filtering and expansion behavior remains intact
- [ ] All text uses gettext and all key controls have stable DOM IDs for Task 12

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance_web/live/transactions_live.ex
lib/aurum_finance_web/live/transactions_live.html.heex
lib/aurum_finance_web/components/transactions_components.ex
test/aurum_finance_web/live/transactions_live_test.exs
```

### Patterns to Follow
- Reuse the existing expanded detail row pattern
- Keep context access in the LiveView, not components
- Use `to_form/2` and explicit IDs for manual override forms
- Favor isolated helper functions for provenance display and field state selection
- Bulk and single apply UI should not try to pre-filter groups itself; it consumes scope-aware context/apply APIs only

### Constraints
- Do NOT move rules management UI into the transactions page
- Do NOT hide unclassified fields; they must render explicitly
- Keep the page entity-scoped and read from contexts only

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Extend transaction loading to include classification state/preloads as needed
3. Add bulk apply controls and result summary
4. Add single-transaction apply and manual override controls in the detail view
5. Add stable DOM IDs needed for LiveView testing
6. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Manually test single apply, bulk apply, and manual override flows
2. Verify unclassified/provenance/locked states are all visible and understandable
3. Verify transaction filtering and expansion still behave correctly
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
