# Task 03: Login UX and Route/LiveView Guarding

## Status
- **Status**: 🔒 BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 04

## Assigned Agent
`dev-frontend-ui-engineer` - Implements LiveView login page and protected UX flow wiring.

## Agent Invocation
Use `llms/agents/dev_frontend_ui_engineer.md` (`name: dev-frontend-ui-engineer`) to implement login UI and protection wiring per approved backend/auth design.

## Objective
Build minimal password-only login flow, add logout action in navigation, and enforce protection across all routes and LiveViews via plug and `on_mount`.

## Inputs Required
- [ ] Task 01 and Task 02 outputs
- [ ] `lib/aurum_finance_web/router.ex`
- [ ] `lib/aurum_finance_web/components/layouts.ex`
- [ ] Existing LiveViews under `lib/aurum_finance_web/live/`

## Expected Outputs
- [ ] Login LiveView + template for password-only authentication
- [ ] Router updates: anonymous route(s) + authenticated route scope(s)
- [ ] `on_mount`/plug guard integration for all current routes and LiveViews
- [ ] Logout button in nav and session clear behavior

## Acceptance Criteria
- [ ] App routes require valid session (except login/logout endpoints)
- [ ] Login page exists and validates password using backend helpers
- [ ] Logout is available in nav and terminates session
- [ ] Session is stored in Phoenix signed cookie, and idle timeout (2h) is enforced by Aurum auth logic

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance_web/router.ex`  
`lib/aurum_finance_web/components/layouts.ex`  
`lib/aurum_finance_web/live/`

### Patterns to Follow
- Use `live_session` + `on_mount` for LiveView gatekeeping.
- Preserve existing app layout patterns and IDs where possible.

### Constraints
- Keep UI minimal and focused.
- No username/OAuth/multi-user elements.

## Execution Instructions
### For the Agent
1. Implement login and logout UX with existing component patterns.
2. Update router pipelines/scopes to enforce auth globally.
3. Add `on_mount` checks for all protected LiveViews.
4. Ensure timeout is enforced consistently.
5. Document assumptions and blockers.

### For the Human Reviewer
1. Verify anonymous access is blocked across the app.
2. Verify logout exists in nav and works.
3. Approve before tests are authored.

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
