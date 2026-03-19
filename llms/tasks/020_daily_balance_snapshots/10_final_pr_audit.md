# Task 10: Final PR Audit

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 08, Task 09 if Task 09 is implemented
- **Blocks**: None

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for Elixir/Phoenix backends

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to read this task file, the approved plan, the execution plan, and the completed implementation/test diffs before starting the review.

## Objective
Perform the final code review for the Daily Balance Snapshots implementation with emphasis on correctness, projection semantics, migration risk, trigger coverage, test sufficiency, and scope discipline.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/execution_plan.md`
- [ ] Completed outputs from Tasks 01-08
- [ ] Completed outputs from Task 09 if implemented
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] Relevant diffs/files under `lib/`, `test/`, and `priv/repo/migrations/`

## Expected Outputs

- [ ] Final review findings documented in this file
- [ ] Severity-ordered issues, if any
- [ ] Explicit statement if no material findings remain

## Acceptance Criteria

- [ ] Review covers migration correctness and data-risk concerns
- [ ] Review covers projection semantics against the approved plan
- [ ] Review covers worker/enqueue simplicity and absence of extra workflow machinery
- [ ] Review covers ledger trigger completeness for multi-account transactions
- [ ] Review covers test sufficiency for engine, worker, and triggers
- [ ] Review calls out any scope creep into report-layer semantics or unnecessary UI work
- [ ] Findings are actionable and severity-ordered

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting/
lib/aurum_finance/ledger.ex
priv/repo/migrations/
test/aurum_finance/
lib/aurum_finance_web/live/reports_live.ex
```

### Constraints
- Do not implement fixes in this task
- Do not perform git operations
- Keep review focused on correctness, regressions, and scope discipline

## Execution Instructions

### For the Agent
1. Read the full plan and execution plan.
2. Review the complete implementation against the approved semantics.
3. Produce severity-ordered findings with concrete file references.
4. State explicitly if the result is merge-ready or not.

### For the Human Reviewer
1. Review findings and decide whether follow-up work is required.
2. Only after approval should git operations or merge preparation begin.

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
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

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
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
