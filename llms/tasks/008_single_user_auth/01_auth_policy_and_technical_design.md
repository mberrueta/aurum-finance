# Task 01: Auth Policy and Technical Design

## Status
- **Status**: ✅ COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02

## Assigned Agent
`tl-architect` - Technical lead architect for implementation-ready sequencing and boundary decisions.

## Agent Invocation
Use `llms/agents/tl_architect.md` (`name: tl-architect`) to produce a short design note that resolves policy-level decisions for issue #8.

## Objective
Confirm and document the already-decided session model, guarding strategy, timeout semantics, and startup enforcement before implementation starts.

## Inputs Required
- [ ] `https://github.com/mberrueta/aurum-finance/issues/8` - Source requirements
- [ ] `llms/tasks/008_single_user_auth/plan.md` - Master execution plan
- [ ] `lib/aurum_finance_web/router.ex` - Current route topology
- [ ] `lib/aurum_finance_web/endpoint.ex` - Session cookie setup
- [ ] `config/runtime.exs` - Runtime env loading and startup checks
- [ ] `llms/project_context.md` - Domain and conventions

## Expected Outputs
- [ ] Auth design note at `llms/tasks/008_single_user_auth/01_design_output.md`
- [ ] Guard matrix for all routes and live sessions
- [ ] Confirmed timeout decision captured: idle-based 2h enforced by Aurum auth logic (session stored in Phoenix signed cookie)

## Acceptance Criteria
- [ ] Every issue #8 acceptance criterion maps to a concrete implementation location
- [ ] Open questions in `plan.md` are resolved or explicitly escalated to human
- [ ] Design note contains no implementation code, only decisions and boundaries

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance_web/router.ex`  
`lib/aurum_finance_web/endpoint.ex`  
`config/runtime.exs`

### Patterns to Follow
- Keep centralized route protection in plug pipelines and `live_session` `on_mount`.
- Maintain signed-cookie session strategy already used by Phoenix endpoint.

### Constraints
- No multi-user model, no roles, no OAuth.
- Must fail startup if `AURUM_ROOT_PASSWORD_HASH` missing.

## Execution Instructions
### For the Agent
1. Read all listed inputs.
2. Produce a mapping from each acceptance criterion to implementation touchpoints.
3. Capture final timeout and dev-dashboard policy decisions from the approved scope.
4. Document assumptions and unresolved questions.
5. Mark ready for Task 02.

### For the Human Reviewer
1. Verify decisions align with issue #8 exactly.
2. Confirm no extra scope was introduced.
3. Approve or reject with corrections.

---

## Execution Summary

### Work Performed
- Reviewed issue #8 requirements and finalized plan decisions.
- Analyzed current router, endpoint session configuration, and runtime config boundaries.
- Produced implementation-facing design output with guard matrix and acceptance-criteria mapping.

### Outputs Created
- `llms/tasks/008_single_user_auth/01_design_output.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Existing app LiveViews can be protected centrally via `live_session` + `on_mount` | Matches current routing topology and keeps implementation minimal |
| Controller-based login endpoints are acceptable for issue #8 | Already agreed decision and aligns with explicit route verbs |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Idle timeout is 2h and enforced by Aurum auth logic | Absolute timeout or mixed model | Finalized scope choice; least ambiguity for implementation |
| `/dev/dashboard` remains public in dev | Protect dev dashboard with same guard | Preserves current dev ergonomics per approved decision |
| Login/logout flow is controller-based (`GET/POST/DELETE`) | Login LiveView route/action flow | Cleaner HTTP semantics and already approved |

### Blockers Encountered
- None.

### Questions for Human
1. Approve Task 01 so Task 02 can begin implementation.

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
- [ ] ✅ APPROVED - Proceed to next task
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# human only
```
