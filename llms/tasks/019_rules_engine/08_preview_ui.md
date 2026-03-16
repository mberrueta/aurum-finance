# Task 08: RulesLive Preview UI

## Status
- **Status**: COMPLETE
- **Approved**: [x] Human sign-off
- **Blocked by**: ~~Task 06, Task 04~~
- **Blocks**: Task 12

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView

## Agent Invocation
Invoke the `dev-frontend-ui-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Extend `RulesLive` with a real preview workflow that lets the user choose a date range, run `preview_classification/1`, and inspect per-transaction/per-field proposed results and no-match states.

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
- [ ] Preview result view aggregates engine output into one display card per classification field
- [ ] Category proposals are rendered as account names rather than raw UUIDs
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
- Protected/manual-override diff is deferred until the `ClassificationRecord` task because the current preview API has no existing-classification input yet

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
2. Verify category values are readable account names and duplicate field proposals collapse into one field card
3. Verify no create/update/apply behavior occurs from preview
4. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
Completed on 2026-03-14.

### Work Performed
- Added five preview-related assigns to `mount/3`: `preview_date_from`, `preview_date_to`, `preview_results`, `preview_loading`, `preview_error`
- Added `change_preview_params` and `run_preview` `handle_event` clauses for the preview form; `run_preview` validates the date range with `with/else` and dispatches `send(self(), {:run_preview, ...})` to avoid blocking the event loop
- Added `handle_info({:run_preview, ...}, socket)` calling `Classification.preview_classification/1` with a `rescue` clause that surfaces errors as a flash-style message in `preview_error` assign
- Added `maybe_reset_preview/2` to clear stale results when the entity context changes in `handle_params`
- Added private helpers `current_entity_id/1`, `default_preview_date_from/0`, `default_preview_date_to/0`, `validate_preview_date_range/2` to `rules_live.ex`
- Added a full "Preview classification" section to `rules_live.html.heex` containing: date-range form with `phx-disable-with` on the run button, loading spinner state, error callout state, empty-transactions state, and the result list rendering `preview_result_row`
- Added `preview_result_row/1`, `proposed_change_cell/1`, `change_status_badge/1`, and `scope_badge/1` components to `rules_components.ex` with `@doc` strings
- Added per-field preview aggregation so duplicate engine changes for the same classification field render as one field card with supporting explainability lines
- Added category-account lookup rendering so category proposals display account names instead of UUIDs
- Added private helpers for the new components: `change_status_badge_class/1`, `change_status_label/1`, `field_label/1`, `format_proposed_value/3`, `format_posting_amount/1`, `account_name/1`, `summarize_proposed_changes/1`
- Added `alias Decimal` to `rules_components.ex` for amount formatting
- Added all new user-facing strings to `priv/gettext/en/LC_MESSAGES/rules.po`

### Outputs Created
| File | Action |
|------|--------|
| `lib/aurum_finance_web/live/rules_live.ex` | Modified — preview assigns, events, handle_info, helpers |
| `lib/aurum_finance_web/live/rules_live.html.heex` | Modified — added preview section above guidance |
| `lib/aurum_finance_web/components/rules_components.ex` | Modified — added four new public components and supporting privates |
| `priv/gettext/en/LC_MESSAGES/rules.po` | Modified — added all new preview translation strings |

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Preview state is cleared when the entity context changes but not when the account filter changes | The entity is the scope boundary for `preview_classification/1`; the account filter only affects group visibility in the CRUD pane, not the preview |
| Default preview range is first-of-current-month to today | A natural starting window; user can change it immediately |
| `Engine.Result` structs are passed directly as the `result` attr — no intermediate DTO | Task 06 execution summary confirmed `Engine.Result` already satisfies all UI data needs |
| Protected/manual-override diff is deferred to the ClassificationRecord task | `preview_classification/1` does not yet load existing classification state, so this task stays focused on read-only proposed results, category-name rendering, and per-field aggregation |
| `proposed_changes` in results where `no_match?` is true are still empty (`[]`), so the "no proposed changes" sub-state applies only when matched but no field proposals exist | Consistent with engine behavior: if no rules match, `proposed_changes` stays empty |
| Postings without a preloaded account show amount only (no account name pill text) | Engine preloads are added by `preview_classification/1`; the component handles `nil` account gracefully |
| `phx-change="change_preview_params"` is used to sync date inputs into assigns so the run button's `phx-disable-with` text shows the current loading state cleanly | Without sync the form value and assign could drift; keeping them in sync is low cost |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Preview runs via `send(self(), {:run_preview, ...})` from `handle_event` | Running synchronously inside `handle_event` | Async dispatch allows LiveView to render the loading state before the DB query runs, making the spinner visible |
| `rescue` on `handle_info` to catch any unexpected errors from `preview_classification/1` | Flash on error only | Preview is read-only and the page should remain usable even if the engine throws unexpectedly |
| Result rows use numeric index IDs (`preview-row-0`, `preview-row-1`, …) rather than transaction UUIDs | Using transaction IDs | The results list is transient (not a stream), so index-based IDs are simpler and stable within a single preview run |
| Proposed-change cells shown in a 4-column grid (sm:2-col, lg:4-col) | Table layout | Cards per field are easier to scan and avoid a wide overflowing table |
| `scope_badge/1` is a new public component in `RulesComponents` | Inline badge rendering in `proposed_change_cell` | Keeps the cell template readable and the scope coloring logic reusable |

### Blockers Encountered
- None

### Questions for Human
1. Should `preview_results` be cleared when the user navigates away from the page (e.g., on the next `mount`)? Currently it clears on entity change but not on full navigation. This is acceptable since `mount` reinitialises all preview assigns to `nil`.
2. Should transactions that have **all** fields proposed (full coverage across all four fields) get a distinct visual treatment to make them easy to identify as "fully classified"?

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
