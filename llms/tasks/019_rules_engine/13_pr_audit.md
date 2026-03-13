# Task 13: Final PR Audit

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 12
- **Blocks**: None

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for Elixir/Phoenix backends

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to read this task file, the spec, the execution plan, and the completed implementation/test diffs before starting the review.

## Objective
Perform a final code review of the full rules engine implementation with emphasis on correctness, regressions, security, performance, auditability, and test sufficiency before human sign-off and git operations.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full feature spec
- [ ] `llms/tasks/019_rules_engine/execution_plan.md` - Planned task sequencing and assumptions
- [ ] Completed outputs from Tasks 01 through 12
- [ ] `llms/constitution.md` - Review baseline
- [ ] `llms/project_context.md` - Domain and audit invariants
- [ ] Relevant diffs/files under `lib/`, `test/`, and `priv/repo/migrations/`

## Expected Outputs

- [ ] Review findings documented in this task file's `Execution Summary`
- [ ] Severity-ordered findings list with file references and recommended fixes
- [ ] Explicit statement if no material findings remain

## Acceptance Criteria

- [ ] Review covers schema/migration correctness for both commits
- [ ] Review covers engine determinism and fail-safe behavior
- [ ] Review covers entity scoping, authorization boundaries, and cross-entity leakage risk
- [ ] Review covers manual override correctness and audit event integrity
- [ ] Review covers LiveView regression risk in RulesLive and TransactionsLive
- [ ] Review covers test sufficiency and identifies any missing high-value cases
- [ ] Findings are severity-ordered and actionable
- [ ] If no findings remain, the review says so explicitly and notes residual risks/test gaps

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/classification/
lib/aurum_finance_web/live/rules_live.ex
lib/aurum_finance_web/live/transactions_live.ex
lib/aurum_finance_web/components/transactions_components.ex
test/aurum_finance/
test/aurum_finance_web/live/
priv/repo/migrations/
```

### Patterns to Follow
- Review as a code reviewer, not as an implementer
- Focus findings on bugs, regressions, missing tests, performance risks, and security gaps
- Keep summaries brief; findings come first

### Constraints
- Do NOT implement fixes in this task
- Do NOT perform git operations
- If the review depends on unresolved human decisions from earlier tasks, call them out explicitly

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Review the full implementation against the spec and execution plan
3. Produce severity-ordered findings with concrete file references
4. Note residual risks even if the review is clean
5. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review findings and decide whether follow-up tasks are required
2. Confirm all blocking issues are resolved or accepted with waiver
3. Only after approval should git operations or merge preparation begin

---

## Execution Summary
*[Filled by executing agent after completion]*

### Findings
- [To be filled]

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
- [ ] APPROVED - Plan complete
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
