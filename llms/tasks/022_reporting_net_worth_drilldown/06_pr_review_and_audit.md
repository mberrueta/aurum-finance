# Task 06: PR Review and Audit

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 04, Task 05
- **Blocks**: None

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for Elixir/Phoenix backends.

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to perform a full PR review of all changes in the feature branch.

## Objective
Perform a comprehensive review of all drilldown changes: correctness, security (cross-entity leakage), performance (query shape, indexes), test coverage, and boundary compliance (Reporting does not create parallel financial truths).

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/plan.md` - Feature specification (Quality / Completion Expectations)
- [ ] `llms/constitution.md` - Quality gates
- [ ] All modified files in the feature branch (via `git diff main...HEAD`)
- [ ] Test results from `mix test`
- [ ] Output from `mix precommit`

## Expected Outputs

- [ ] Written review with findings organized by severity (blocking, warning, note)
- [ ] Specific actionable feedback for any issues found
- [ ] Confirmation that quality checklist items are met

## Acceptance Criteria

- [ ] **Correctness**: Drilldown provides paginated evidence for the snapshot-backed balance; the full result set across all pages matches the displayed balance semantics (sum of all drilldown rows = snapshot balance). Individual pages are navigable evidence, not standalone proof. Date boundary respected.
- [ ] **Security**: Entity isolation is explicit in the query shape (joins through account→entity ownership), not just implicit via account_id parameter. Cross-entity test exists as architectural guardrail.
- [ ] **Performance**: Query uses appropriate indexes; no N+1; pagination is bounded
- [ ] **Boundaries**: Reporting reads only -- no mutation of ledger facts, no parallel balance computation
- [ ] **Consistency**: Drilldown transaction list respects snapshot date boundary
- [ ] **Test coverage**: Both backend and LiveView tests cover happy paths and edge cases
- [ ] **I18n**: All strings internationalized
- [ ] **Style**: Passes `mix precommit` (format, credo, dialyzer, sobelow)
- [ ] Review document created with clear pass/fail assessment

## Technical Notes

### Review Checklist (from spec)
1. Verify the drilldown provides paginated evidence for the snapshot-backed balance (full result set sum = snapshot balance)
2. Verify entity isolation is explicit in query shape (not just implicit via account_id); confirm architectural guardrail test exists with two distinct entities
3. Validate query shape and indexing to prevent N+1 issues
4. Confirm Reporting does not create parallel financial truths or mutate ledger facts
5. Confirm the drilldown transaction list correctly respects the snapshot date boundary

### Performance Concerns
- The drilldown query joins postings and transactions with grouping -- verify the query plan uses existing indexes
- Check if a composite index on `(account_id, date)` for postings or transactions would help
- Pagination must use bounded LIMIT/OFFSET, not unbounded fetches

## Execution Instructions

### For the Agent
1. Run `git diff main...HEAD --stat` to see all changed files
2. Review each changed file against the spec and constitution
3. Run `mix test` and `mix precommit`
4. Write findings document
5. Classify each finding as: BLOCKING (must fix), WARNING (should fix), NOTE (consider)

### For the Human Reviewer
After agent completes:
1. Review the audit findings
2. Decide which blocking items need additional tasks
3. If no blocking issues: mark `[x]` on "Approved" and consider the feature complete
4. If blocking issues exist: create follow-up fix tasks or send back to relevant task agents
5. Final decision: create PR or request rework

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
