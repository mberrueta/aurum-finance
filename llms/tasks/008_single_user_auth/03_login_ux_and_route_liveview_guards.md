# Task 03: Login UX and Route/LiveView Guarding

## Status
- **Status**: ✅ COMPLETED
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

### Work Performed
- Implemented controller-based login/logout flow (`GET /login`, `POST /login`, `DELETE /logout`).
- Added web auth integration module (`AurumFinanceWeb.RootAuth`) with:
  - plug-based route protection (`require_authenticated_root`, `redirect_if_root_authenticated`)
  - LiveView `on_mount` enforcement (`:ensure_authenticated`).
- Updated router with public auth scope and protected app scope.
- Added logout action in app topbar/nav shell.
- Added auth i18n domain/messages and layout logout translation key.
- Updated smoke tests to authenticate before protected LiveViews and added dedicated auth controller tests.

### Outputs Created
- `lib/aurum_finance_web/root_auth.ex`
- `lib/aurum_finance_web/controllers/auth_controller.ex`
- `lib/aurum_finance_web/controllers/auth_html.ex`
- `lib/aurum_finance_web/controllers/auth_html/login.html.heex`
- `priv/gettext/auth.pot`
- `priv/gettext/en/LC_MESSAGES/auth.po`
- `test/aurum_finance_web/controllers/auth_controller_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Idle-timeout refresh during LiveView interaction is enforced at request/mount boundaries in this slice | Session mutation from LiveView websocket events is out-of-scope for Task 03; dedicated behavior checks remain in Task 04 |
| Showing logout action on the protected app shell is sufficient to satisfy "logout button in nav" | All protected app pages use the same `Layouts.app` shell |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Controller-based login page and submit actions | LiveView login flow | Matches approved final decision in plan |
| Protect LiveViews via both plug pipeline and `live_session` `on_mount` | Plug-only protection | Meets explicit issue requirement for plug + `on_mount` coverage |
| Keep dev dashboard auth policy unchanged (no auth in dev scope) | Protect `/dev/dashboard` too | Matches approved decision |

### Blockers Encountered
- Plug integration initially failed due missing `init/1` + `call/2`; resolved by implementing plug dispatcher in `RootAuth`.

### Questions for Human
1. Approve Task 03 so Task 04 (auth test coverage expansion) can begin.

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
