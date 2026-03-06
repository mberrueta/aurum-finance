# Task 05: Security Audit and Hardening Review

## Status
- **Status**: 🔒 BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: Task 06

## Assigned Agent
`audit-security` - Security reviewer for auth, secret handling, and attack surface.

## Agent Invocation
Use `llms/agents/audit_security.md` (`name: audit-security`) to review implementation from Tasks 02-04.

## Objective
Validate that implementation satisfies security expectations for single-user password guard and does not leak secrets or introduce bypasses.

## Inputs Required
- [ ] Task 02-04 outputs
- [ ] Auth/session modules and router changes
- [ ] Runtime config changes
- [ ] Test evidence from Task 04

## Expected Outputs
- [ ] Security findings report with severity and exact file references
- [ ] Required remediation list (if any)
- [ ] Final sign-off note when no blockers remain

## Acceptance Criteria
- [ ] No anonymous route bypass remains
- [ ] No plaintext secret persistence paths identified
- [ ] Session security settings are reasonable for cookie-based auth
- [ ] Findings are either fixed or explicitly accepted by human reviewer

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance_web/router.ex`  
`lib/aurum_finance_web/` auth/session modules  
`config/runtime.exs`  
`test/` auth-related tests

### Patterns to Follow
- OWASP-style auth flow review.
- Explicitly validate logout and timeout invalidation behavior.

### Constraints
- Audit-only task; no broad refactors.
- Keep recommendations tied to issue scope.

## Execution Instructions
### For the Agent
1. Review auth flow end-to-end for bypass and secret handling.
2. Validate startup/env and hash-generation safety.
3. Produce categorized findings with remediation guidance.
4. Confirm whether implementation is safe to release.

### For the Human Reviewer
1. Review each finding and decide remediation scope.
2. Ensure blockers are resolved before approval.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- 

### Outputs Created
- 

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
|  |  |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
|  |  |  |

### Blockers Encountered
- 

### Questions for Human
1. 

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
- [ ] ✅ APPROVED - Proceed to next task
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# human only
```
