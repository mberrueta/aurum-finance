# Task 01: Auth Policy and Technical Design

## Status
- **Status**: ⏳ PENDING
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
