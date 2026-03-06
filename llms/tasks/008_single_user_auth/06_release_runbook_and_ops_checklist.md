# Task 06: Release Runbook and Ops Checklist

## Status
- **Status**: 🔒 BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: None

## Assigned Agent
`rm-release-manager` - Release manager for deployment/readiness and rollback planning.

## Agent Invocation
Use `llms/agents/rm_release_manager.md` (`name: rm-release-manager`) to prepare release readiness and operator guidance for issue #8.

## Objective
Document operator setup steps for `AURUM_ROOT_PASSWORD_HASH`, validation checks, deployment checklist, and rollback guidance for the auth guard release.

## Inputs Required
- [ ] Task 01-05 outputs
- [ ] Runtime and auth configuration changes
- [ ] Test/audit outcomes
- [ ] Existing project docs for setup/deployment

## Expected Outputs
- [ ] Release checklist with pre-deploy and post-deploy checks
- [ ] Operator runbook for generating hash and configuring env var safely
- [ ] Rollback steps if login guard blocks expected access

## Acceptance Criteria
- [ ] Setup instructions avoid exposing plaintext passwords
- [ ] Checklist includes verification for protected routes and timeout behavior
- [ ] Rollback plan is explicit and low-risk

## Technical Notes
### Relevant Code Locations
`README.md` and setup docs (as needed)  
`config/runtime.exs`  
`lib/mix/tasks/`

### Patterns to Follow
- Keep instructions concise, executable, and secret-safe.
- Ensure runbook references actual command names implemented in Task 02.

### Constraints
- No code changes required unless docs are missing/outdated.
- Must not include real secrets in examples.

## Execution Instructions
### For the Agent
1. Build operator-safe rollout checklist.
2. Add explicit validation commands and expected results.
3. Document rollback and recovery steps.
4. Mark task complete when handoff-ready.

### For the Human Reviewer
1. Validate runbook against your deployment process.
2. Approve final issue handoff.

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
- [ ] ✅ APPROVED - Plan execution complete
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# human only
```
