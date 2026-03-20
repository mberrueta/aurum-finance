# Task 09: Final PR Review and Quality Gate

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 08
- **Blocks**: None (final task)

## Assigned Agent
`audit-pr-elixir` - Staff-level Elixir/Phoenix PR reviewer for correctness, performance, logging, test coverage, and maintainability

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to read this task file, the approved plan, all prior task outputs, and the final implementation diff before performing a full PR-style review.

## Objective
Perform the final PR-level review for the Net Worth feature, explicitly covering:

- correctness and regression risk
- performance and query shape
- N+1 risks
- unused code / dead branches / obsolete mock remnants
- test coverage sufficiency
- documentation completeness
- final quality gate readiness before human PR creation

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/execution_plan.md`
- [ ] Approved outputs from Tasks 01-08
- [ ] Final implementation diff / changed files
- [ ] Test outputs and coverage notes from Task 06
- [ ] Documentation updates from Task 07
- [ ] Security findings from Task 08

## Expected Outputs

- [ ] PR review report with findings ordered by severity
- [ ] Explicit review of performance and N+1 risk
- [ ] Explicit review of unused code / leftover mock paths
- [ ] Coverage adequacy assessment
- [ ] Final go/no-go recommendation for human PR creation

## Acceptance Criteria

- [ ] Reviews correctness of latest-snapshot and freshness semantics
- [ ] Reviews performance characteristics of the report query path
- [ ] Reviews N+1 risk in LiveViews and backend access patterns
- [ ] Reviews whether mock/obsolete reporting code was fully removed or intentionally retained
- [ ] Reviews whether docs and ADR updates match shipped behavior
- [ ] Reviews whether test coverage is sufficient for the changed risk surface
- [ ] Calls out any remaining PR blockers clearly, or states explicitly that no findings were identified

## Technical Notes

### Review Focus
- Query count and repeated backend calls from LiveView lifecycle
- Unnecessary preloads or missing preloads
- Freshness-state correctness under stale-but-renderable conditions
- Coherence between backend liability math and UI presentation
- Residual dead code from the prior mock `/reports` experience

## Execution Instructions

### For the Agent
1. Review the feature as if it were an incoming PR.
2. Prioritize findings, not summaries.
3. Cover security, performance, N+1, unused code, and coverage explicitly.
4. Provide a concise go/no-go recommendation for the human reviewer.

### For the Human Reviewer
1. Read findings first and decide whether rework is needed.
2. Confirm quality gates are satisfied, including coverage expectations.
3. If approved, proceed with human git workflow and PR creation.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Findings
### Coverage Assessment
### Performance / N+1 Review
### Unused Code Review
### Documentation Review
### Go / No-Go Recommendation
### Questions for Human
### Ready for Closure
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Feature complete, ready for PR
- [ ] REJECTED - See feedback below

### Feedback

