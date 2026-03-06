# Task 04: Auth Test Coverage

## Status
- **Status**: 🔒 BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 05

## Assigned Agent
`qa-elixir-test-author` - Designs and writes deterministic ExUnit/LiveView tests.

## Agent Invocation
Use `llms/agents/qa_elixir_test_author.md` (`name: qa-elixir-test-author`) to implement test coverage for issue #8.

## Objective
Author comprehensive tests for auth guard behavior, login/logout flow, session timeout, startup env checks, and mix hash task behavior.

## Inputs Required
- [ ] Task 01-03 outputs
- [ ] `test/` existing patterns
- [ ] Router + LiveView modules modified by Task 03
- [ ] Mix task and backend auth modules from Task 02

## Expected Outputs
- [ ] Route and LiveView protection tests (anonymous blocked)
- [ ] Login success/failure tests
- [ ] Logout and timeout behavior tests
- [ ] Runtime config/startup check tests where feasible
- [ ] Mix hash task tests

## Acceptance Criteria
- [ ] All acceptance criteria in issue #8 are covered by automated tests where technically feasible
- [ ] Tests are deterministic and sandbox-safe
- [ ] No `Process.sleep/1` usage

## Technical Notes
### Relevant Code Locations
`test/aurum_finance_web/`  
`test/aurum_finance/`  
`test/support/`

### Patterns to Follow
- Use `Phoenix.LiveViewTest` selectors and element-based assertions.
- Prefer focused tests by area (auth backend, web flow, config behavior).

### Constraints
- Keep tests independent and non-flaky.
- Avoid asserting fragile UI copy unless necessary.

## Execution Instructions
### For the Agent
1. Translate issue acceptance criteria into explicit test cases.
2. Implement tests in minimal, isolated files.
3. Verify test determinism and no timing-based waits.
4. Document any criterion that cannot be fully automated and why.

### For the Human Reviewer
1. Confirm each issue criterion has test mapping.
2. Review gaps and accepted manual checks, if any.
3. Approve before security audit.

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
