# Task 11: Bulk Apply + Classification Display UI

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Extend `TransactionsLive` and `TransactionsComponents` to support rules application from the transactions experience: bulk apply for a date range, single-transaction apply from the expanded detail row, and per-field classification display with provenance and manual override controls.

## Inputs Required

- [x] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #21, US-13 through US-16, UX states)
- [x] `llms/tasks/019_rules_engine/04_rules_live_crud_ui.md` - Existing UI patterns and shared assumptions
- [x] `llms/tasks/019_rules_engine/09_classification_record_and_apply_apis.md` - Apply/manual API contract
- [x] `llms/constitution.md` - HEEx/i18n rules
- [x] `llms/coding_styles/elixir.md` - Elixir style guide
- [x] `lib/aurum_finance_web/live/transactions_live.ex` - LiveView to extend
- [x] `lib/aurum_finance_web/live/transactions_live.html.heex` - Transactions template
- [x] `lib/aurum_finance_web/components/transactions_components.ex` - Detail component to extend
- [x] `test/aurum_finance_web/live/transactions_live_test.exs` - Existing interaction patterns
- [x] `lib/aurum_finance/classification.ex` - Classification APIs
- [x] `lib/aurum_finance/ledger.ex` - Transaction query layer

## Expected Outputs

- [x] Updated `lib/aurum_finance_web/live/transactions_live.ex`
- [x] Updated `lib/aurum_finance_web/live/transactions_live.html.heex`
- [x] Updated `lib/aurum_finance_web/components/transactions_components.ex`
- [x] Updated gettext strings in the `transactions` and/or `rules` domains as needed

## Acceptance Criteria

- [x] Bulk apply controls exist on the transactions page and operate on the current entity/date range
- [x] Bulk apply shows loading/progress state and summary counts after completion
- [x] Single-transaction “Apply Rules” action exists in the expanded transaction detail
- [x] After single apply, the transaction detail refreshes to show current classification state
- [x] Per-field classification display shows category, tags, investment type, and notes independently
- [x] Each field shows one of the explicit states: unclassified, rule-classified, manually overridden
- [x] Rule-classified fields show provenance (scope badge, group/rule name, and timestamp if available)
- [x] Manual fields show manual badge, lock indicator, and clear-override action
- [x] Category manual entry uses a picker limited to same-entity category accounts
- [x] Tags manual entry supports free-form input within the backend constraints
- [x] No-match feedback is shown when applying rules yields no changes
- [x] Existing transaction filtering and expansion behavior remains intact
- [x] All text uses gettext and all key controls have stable DOM IDs for Task 12

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
- [x] Extended `TransactionsLive` with classification state loading, provenance lookup catalogs, manual override forms, and handlers for bulk apply, single apply, manual set, and clear override flows
- [x] Added a bulk apply status panel with ready/missing-range cues, loading state, summary counters, and failure list rendering
- [x] Rebuilt expanded transaction detail to include a classification panel with four independent field cards (`category`, `tags`, `investment_type`, `notes`)
- [x] Added per-field provenance badges, lock indicators, inline manual editors, and clear-override controls with stable DOM IDs
- [x] Extracted and merged new gettext keys in the `transactions` domain and revalidated the existing `TransactionsLive` test file

### Outputs Created
- `lib/aurum_finance_web/live/transactions_live.ex`
- `lib/aurum_finance_web/live/transactions_live.html.heex`
- `lib/aurum_finance_web/components/transactions_components.ex`
- `priv/gettext/en/LC_MESSAGES/transactions.po`
- `priv/gettext/transactions.pot`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Bulk apply requires a concrete current date range and should stay unavailable when the current preset is `all` | `Classification.classify_transactions/1` requires `date_from` and `date_to`; inventing dates in the web layer would violate the context contract |
| A cleared manual override should still render as manual provenance until automation rewrites it | Backend retains user provenance and value after `clear_manual_override/3`, so the UI needs to distinguish source from lock state |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Kept provenance resolution in the LiveView via `Classification.list_visible_rule_groups/3` and passed lookup maps into components | Calling context functions from components or adding backend resolver helpers | This preserved the current backend boundary and kept display-only logic in the web layer |
| Reused the existing expanded detail row instead of introducing a modal/editor flow | Separate slide-over/manual-edit surface | Task 11 explicitly builds on the existing expansion pattern and this kept filters and row interaction intact |
| Used `send(self(), ...)` plus `handle_info/2` for apply flows to guarantee a real intermediate loading render | Fully synchronous `handle_event/3` or new JS hooks | It keeps the implementation simple while still surfacing loading state before the backend work runs |

### Blockers Encountered
- None

### Questions for Human
1. None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

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
