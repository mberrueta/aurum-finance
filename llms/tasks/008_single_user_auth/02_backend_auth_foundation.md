# Task 02: Backend Auth Foundation

## Status
- **Status**: ✅ COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03

## Assigned Agent
`dev-backend-elixir-engineer` - Implements backend auth/session primitives and runtime safeguards.

## Agent Invocation
Use `llms/agents/dev_backend_elixir_engineer.md` (`name: dev-backend-elixir-engineer`) to implement backend pieces from Task 01 decisions.

## Objective
Implement bcrypt verification, auth/session helper layer, runtime env enforcement for `AURUM_ROOT_PASSWORD_HASH`, and password hash generation mix task.

## Inputs Required
- [ ] `llms/tasks/008_single_user_auth/01_auth_policy_and_technical_design.md`
- [ ] `llms/tasks/008_single_user_auth/01_design_output.md`
- [ ] `config/runtime.exs`
- [ ] `mix.exs`
- [ ] Existing web/auth support modules under `lib/aurum_finance_web/`

## Expected Outputs
- [ ] Auth helper module(s) for verify/login/logout/session-check operations
- [ ] Runtime startup check enforcing `AURUM_ROOT_PASSWORD_HASH`
- [ ] `mix aurum.gen_password_hash <password>` task returning hash only
- [ ] Unit tests for helper module(s) and mix task behavior

## Acceptance Criteria
- [ ] Password verification uses bcrypt against `AURUM_ROOT_PASSWORD_HASH`
- [ ] App boot fails when `AURUM_ROOT_PASSWORD_HASH` is absent
- [ ] Plain-text password is never persisted in source/config defaults
- [ ] Mix task outputs hash only (no extra prose)

## Technical Notes
### Relevant Code Locations
`config/runtime.exs`  
`mix.exs`  
`lib/aurum_finance_web/`  
`lib/mix/tasks/`

### Patterns to Follow
- Use env-driven runtime config for secrets.
- Keep pure verification logic testable outside LiveView.

### Constraints
- No database-backed users.
- No username field.

## Execution Instructions
### For the Agent
1. Implement auth backend primitives and runtime validation.
2. Add bcrypt dependency if missing.
3. Implement mix task for offline hash generation.
4. Add focused tests for backend behavior.
5. Document assumptions and blockers.

### For the Human Reviewer
1. Verify issue criteria related to hash generation and startup checks.
2. Confirm no plaintext secret handling was introduced.
3. Approve before Task 03 starts.

---

## Execution Summary

### Work Performed
- Added backend auth module `AurumFinance.Auth` with bcrypt verification, session helpers, idle-timeout validation, and configuration guard.
- Added startup enforcement in `AurumFinance.Application.start/2` via `AurumFinance.Auth.ensure_configured!/0`.
- Wired runtime config to read `AURUM_ROOT_PASSWORD_HASH` from environment when present.
- Added mix task `mix aurum.gen_password_hash <password>` that outputs bcrypt hash only.
- Added focused unit tests for auth logic and mix task behavior.
- Added `bcrypt_elixir` dependency.

### Outputs Created
- `lib/aurum_finance/auth.ex`
- `lib/mix/tasks/aurum.gen_password_hash.ex`
- `test/aurum_finance/auth_test.exs`
- `test/mix/tasks/aurum.gen_password_hash_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Startup enforcement at `Application.start/2` satisfies "app refuses to start" while avoiding unrelated mix-task breakage | Keeps strict startup guarantee without forcing env var for every development command |
| Runtime config should source `AURUM_ROOT_PASSWORD_HASH` from env only, without hardcoded fallback | Aligns with security requirement to avoid plaintext/default password material |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Enforce missing hash on app start (not unconditional runtime raise) | Raising in `runtime.exs` for every command | Better developer ergonomics while still meeting startup refusal requirement |
| Keep session timeout logic in `AurumFinance.Auth.validate_session/2` | Relying on cookie signing/storage behavior | Matches finalized decision: timeout enforced by Aurum auth logic |
| Mix task outputs hash only via `Mix.shell().info/1` | Verbose output with labels | Requirement asks for hash-only output suitable for shell piping |

### Blockers Encountered
- `mix format` failed in sandbox due Mix.PubSub socket permissions; resolved by running with approved escalated execution.

### Questions for Human
1. Approve Task 02 so Task 03 (login UX + route/LiveView guarding) can begin.

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
