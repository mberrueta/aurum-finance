# Task 02: Backend Auth Foundation

## Status
- **Status**: 🔒 BLOCKED
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
