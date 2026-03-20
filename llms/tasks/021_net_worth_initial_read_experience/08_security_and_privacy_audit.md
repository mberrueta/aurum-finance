# Task 08: Security and Privacy Audit

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 07
- **Blocks**: Task 09

## Assigned Agent
`audit-security` - Security reviewer for authorization, input validation, OWASP-style risks, secrets hygiene, and PII/privacy handling

## Agent Invocation
Invoke the `audit-security` agent with instructions to read this task file, the approved plan, and the completed implementation/docs outputs before auditing the feature.

## Objective
Run a focused security and privacy review of the new reporting read path, including refresh actions, date input handling, scope boundaries, and documentation claims.

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] Approved outputs from Tasks 02-07
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] Relevant code changes in `lib/aurum_finance/` and `lib/aurum_finance_web/`
- [ ] Relevant test coverage from Task 06

## Expected Outputs

- [ ] Security findings report
- [ ] Privacy/scope boundary review notes
- [ ] Recommended fixes or explicit “no findings” conclusion

## Acceptance Criteria

- [ ] Reviews input validation for date/refresh parameters
- [ ] Reviews reporting scope boundaries and entity exposure
- [ ] Reviews refresh action for abuse, authorization, and hidden escalation risks
- [ ] Reviews docs for privacy or security claims that do not match implementation
- [ ] Produces clear findings ordered by severity, or an explicit no-findings result

## Technical Notes

### Constraints
- Focus on real security/privacy risks, not style issues
- Treat reporting scope and hidden data exposure as first-class concerns

## Execution Instructions

### For the Agent
1. Audit the implemented feature, not the spec in isolation.
2. Focus on authorization, input handling, scope leakage, and privacy implications.
3. Produce a concise findings report suitable for the final PR review task.

### For the Human Reviewer
1. Review findings and decide whether fixes are required before Task 09.
2. If findings require code changes, stop and create a rework step before final review.
3. Approve before Task 09 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Findings
### Assumptions Made
### Decisions Made
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

