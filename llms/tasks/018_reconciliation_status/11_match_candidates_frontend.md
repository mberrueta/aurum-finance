# Task 11: Reconciliation Candidate-Inspection UI

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 10
- **Blocks**: Task 12, Task 13

## Assigned Agent
`dev-frontend-ui-engineer` - Phoenix LiveView frontend engineer for interactive, accessible reconciliation UI

## Agent Invocation
```text
Act as dev-frontend-ui-engineer following llms/constitution.md.

Execute Task 11 from llms/tasks/018_reconciliation_status/11_match_candidates_frontend.md

Read these files before starting:
- llms/constitution.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md
- llms/tasks/018_reconciliation_status/10_match_candidates_backend.md
- lib/aurum_finance_web/live/reconciliation_live.ex
- lib/aurum_finance_web/live/reconciliation_live.html.heex
- lib/aurum_finance_web/components/reconciliation_components.ex
- lib/aurum_finance/reconciliation.ex
```

## Objective
Add a comparison workflow to the reconciliation screen so the user can click a posting and inspect likely imported statement rows for that posting, ranked by score and explained by signals such as amount, date, and description similarity.

## Inputs Required

- [ ] Task 10 output: backend candidate API
- [ ] Current reconciliation LiveView and components
- [ ] Existing page layout, callouts, and table patterns already used in reconciliation

## Expected Outputs

- [ ] `lib/aurum_finance_web/live/reconciliation_live.ex`
- [ ] `lib/aurum_finance_web/live/reconciliation_live.html.heex`
- [ ] `lib/aurum_finance_web/components/reconciliation_components.ex`
- [ ] Gettext updates if new copy is introduced

## Acceptance Criteria

- [ ] User can click a posting row, or a dedicated compare action in the row, to inspect candidates
- [ ] Selected posting is visually obvious in the table
- [ ] Candidate list appears in a dedicated comparison panel on the same page
- [ ] Panel shows the selected posting summary
- [ ] Panel shows imported-row candidates ordered by backend score
- [ ] Each candidate displays at least: date, description, amount, score/confidence, and reasons/badges
- [ ] Empty state is shown when no candidates are found
- [ ] UI makes clear this is assistance, not automatic reconciliation
- [ ] No clearing/reconciliation action is triggered by viewing candidates
- [ ] Interaction works in both active and completed session views as read-only inspection
- [ ] Component and DOM IDs are explicit and test-friendly
- [ ] HEEx follows repo rules (`{}` interpolation, `:if`, `:for`, no `<%= %>` blocks in new code)
- [ ] Layout remains responsive and readable on desktop and mobile

## Technical Notes

### UX Direction

- Keep the postings table as the primary surface.
- Add a secondary comparison surface:
  - right-side panel on desktop, stacked section below on smaller screens, or
  - a drawer/slideover if that integrates better with current layout
- The comparison panel should explain why a candidate is likely:
  - `Exact amount`
  - `Same day`
  - `Near date`
  - `Description match`

### Suggested LiveView State

- `selected_posting_for_match`
- `match_candidates`
- `match_candidates_loading?` only if needed

### Suggested Events

- `inspect_posting_matches`
- `clear_posting_match_inspection`

### Constraints

- Do not add JavaScript hooks unless the LiveView cannot reasonably handle the interaction
- Do not introduce auto-clear or acceptance actions in this task
- Keep all data loading behind `AurumFinance.Reconciliation`

## Execution Instructions

### For the Agent
1. Read Task 10 first and use its result shape directly
2. Implement the selection and inspection workflow in LiveView
3. Keep the panel explanatory, not magical
4. Add IDs needed by Task 12 tests
5. Run `mix compile --warnings-as-errors`
6. Document any UI tradeoffs

### For the Human Reviewer
1. Verify the interaction is obvious and low-friction
2. Verify the panel helps comparison without implying automatic certainty
3. Verify the selected posting and candidates are easy to parse
4. Verify the UI stays coherent in both empty and populated states

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
