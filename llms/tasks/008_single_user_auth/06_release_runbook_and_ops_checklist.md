# Task 06: Release Runbook and Ops Checklist

## Status
- **Status**: ✅ COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: None

## Assigned Agent
`rm-release-manager` - Release manager for deployment/readiness and rollback planning.

## Agent Invocation
Use `llms/agents/rm_release_manager.md` (`name: rm-release-manager`) to prepare release readiness and operator guidance for issue #8.

## Objective
Document operator setup steps for `AURUM_ROOT_PASSWORD_HASH`, validation checks, deployment checklist, and rollback guidance for the auth guard release.

## Inputs Required
- [x] Task 01-05 outputs
- [x] Runtime and auth configuration changes
- [x] Test/audit outcomes
- [x] Existing project docs for setup/deployment

## Expected Outputs
- [x] Release checklist with pre-deploy and post-deploy checks
- [x] Operator runbook for generating hash and configuring env var safely
- [x] Rollback steps if login guard blocks expected access

## Acceptance Criteria
- [x] Setup instructions avoid exposing plaintext passwords
- [x] Checklist includes verification for protected routes and timeout behavior
- [x] Rollback plan is explicit and low-risk

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
Completed.

### Work Performed
- Updated deployment documentation with an auth rollout checklist tied to issue #8.
- Added operator-safe hash generation instructions for `AURUM_ROOT_PASSWORD_HASH`.
- Added explicit post-deploy auth validation steps (route protection, login/logout, throttling, timeout policy).
- Added auth-focused rollback and recovery guidance when login guard blocks expected access.
- Added secret-handling note for `AURUM_ROOT_PASSWORD_HASH`.

### Outputs Created
- `docs/deployment.md` updated with:
  - required auth runtime variable documentation
  - pre-deploy checklist
  - post-deploy verification checklist
  - auth rollback/recovery steps

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Existing `docs/security.md` threat model remains the source of truth for security boundaries. | Avoid duplicate long-form security text in deployment runbook. |
| In-memory rate limiter behavior (5/5m + 5m lockout) is sufficient to document as current operational behavior. | Matches current implemented scope and tests. |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep runbook updates inside `docs/deployment.md` instead of creating a new auth runbook file. | New standalone `docs/auth_runbook.md` | Keep operator guidance centralized and low-maintenance. |
| Document timeout as policy and enforcement source (Aurum auth logic), not as cookie-native feature. | Short wording implying signed cookies alone enforce timeout | Prevent ambiguity and match finalized architecture decision. |

### Blockers Encountered
- None.

### Questions for Human
1. None.

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
- [ ] ✅ APPROVED - Plan execution complete
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# human only
```
