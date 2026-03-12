# Task 12: Candidate Matching Tests

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 10, Task 11
- **Blocks**: Task 13

## Assigned Agent
`qa-elixir-test-author` - QA-focused ExUnit and LiveView test author for deterministic backend and UI coverage

## Agent Invocation
```text
Act as qa-elixir-test-author following llms/constitution.md.

Execute Task 12 from llms/tasks/018_reconciliation_status/12_match_candidates_tests.md

Read these files before starting:
- llms/constitution.md
- llms/coding_styles/elixir_tests.md
- llms/tasks/018_reconciliation_status/10_match_candidates_backend.md
- llms/tasks/018_reconciliation_status/11_match_candidates_frontend.md
- test/support/factory.ex
- test/aurum_finance/reconciliation_test.exs
- test/aurum_finance_web/live/reconciliation_live_test.exs
```

## Objective
Add deterministic backend and LiveView tests for the candidate-matching workflow, covering ranking, scope boundaries, empty states, and the interactive comparison panel.

## Inputs Required

- [ ] Task 10 output
- [ ] Task 11 output
- [ ] Existing factories and reconciliation tests

## Expected Outputs

- [ ] Updates to `test/aurum_finance/reconciliation_test.exs`
- [ ] Updates to `test/aurum_finance_web/live/reconciliation_live_test.exs`
- [ ] Factory additions/adjustments only if strictly needed

## Acceptance Criteria

- [ ] Backend tests cover exact-amount + same-day ranking above weaker matches
- [ ] Backend tests cover qualitative match-band classification (`exact`, `near`, `weak`, `below threshold`) as a stable contract
- [ ] Backend tests cover the normalized public score contract in the range `0.0..1.0`
- [ ] Backend tests cover near-date / close-amount candidates being included
- [ ] Backend tests cover out-of-window / out-of-scope imported rows being excluded
- [ ] Backend tests cover entity/account isolation
- [ ] Backend tests cover rows with partial metadata (for example nil description) without crashing
- [ ] Backend tests cover that strong description similarity alone does not promote a weak amount/date candidate into a strong match band
- [ ] Backend tests cover that a candidate with stronger amount/date evidence ranks above another candidate with stronger description similarity but weaker core evidence
- [ ] LiveView tests cover selecting a posting and rendering the comparison panel
- [ ] LiveView tests cover the empty-candidate state
- [ ] LiveView tests use stable element IDs/selectors, not brittle raw-HTML assertions
- [ ] No timing-based sleeps; tests remain deterministic under sandbox
- [ ] Test names describe user-visible outcomes clearly

## Technical Notes

### Scenario Minimums

1. Exact amount + same day candidate ranks first.
2. Same account but wrong day beyond window is excluded.
3. Same date but very different amount is excluded or ranked below threshold.
4. Imported rows from a different account/entity are never shown.
5. Clicking a posting in the UI shows its candidate panel.
6. Clicking another posting refreshes the panel to the new candidate set.
7. No candidates produces a clear empty state.
8. A better amount/date candidate outranks a better-description-only candidate.

### Constraints

- Use factories, not ad hoc fixtures
- Prefer extending existing reconciliation tests rather than creating fragmented new files unless the split adds real clarity
- Keep the assertions outcome-focused

## Execution Instructions

### For the Agent
1. Read the task outputs from 10 and 11
2. Add backend coverage first, then UI coverage
3. Keep scenarios isolated and deterministic
4. Run targeted tests, then relevant broader tests
5. Record any gaps that remain for future auto-rec work

### For the Human Reviewer
1. Verify ranking assertions are meaningful and not overfit to implementation trivia
2. Verify scope isolation is covered
3. Verify LiveView tests use the new explicit IDs
4. Verify no sleeps or nondeterministic expectations were introduced

---

## Execution Summary

### Work Performed
- Extended `test/aurum_finance/reconciliation_test.exs` with deterministic
  backend coverage for candidate retrieval, ranking, score normalization,
  match-band classification, scope isolation, nil-description handling, and the
  operator acceptance flow.
- Extended `test/aurum_finance_web/live/reconciliation_live_test.exs` with
  interaction coverage for opening the candidate panel, empty candidate states,
  switching inspected postings, and accepting a candidate to clear the posting.
- Kept the tests factory-driven and sandbox-safe without timing-based
  synchronization.

### Outputs Created
- Updated `test/aurum_finance/reconciliation_test.exs`
- Updated `test/aurum_finance_web/live/reconciliation_live_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Task 12 could be closed using the test coverage added while implementing Tasks 10 and 11 plus the later accept-candidate flow | The acceptance criteria are about outcome coverage, not when the tests were authored |
| Acceptance-flow coverage belongs in this task even though it extends the original inspection-only UI work | It is part of the same candidate-matching workflow and exercises the same backend contract |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Extend the existing reconciliation test files instead of creating new fragmented files | New dedicated test files for matcher-only behavior | The current test files already own the reconciliation backend and LiveView workflow, so the added coverage stays easier to navigate there |
| Keep assertions centered on stable IDs, state transitions, and returned contracts | Raw HTML snapshots or brittle text-only assertions | Matches the project LiveView testing style and reduces churn from non-semantic markup changes |
| Test that stronger amount/date evidence outranks stronger description-only evidence | Rely on indirect score assertions only | This directly protects the intended product heuristic from future regressions |

### Blockers Encountered
- None

### Questions for Human
- None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
