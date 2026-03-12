# Task 09: Final Audit and Quality Gate

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06, Task 08
- **Blocks**: None (final task)

## Assigned Agent
`backend-engineer-agent` - Elixir backend implementation specialist

## Agent Invocation
```
Act as a backend engineer agent following llms/constitution.md.

Execute Task 09 from llms/tasks/018_reconciliation_status/09_final_audit.md

Read these files before starting:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/018_reconciliation_status/plan.md (full spec for checklist verification)
```

## Objective
Run the full quality gate (`mix precommit`) and verify that all acceptance criteria from the spec are met. Fix any remaining warnings, formatting issues, or test failures. Generate a coverage report for the new code.

## Inputs Required

- [ ] All outputs from Tasks 01-08 (the full implementation)
- [ ] `llms/tasks/018_reconciliation_status/plan.md` - Full spec for verification

## Expected Outputs

- [ ] `mix precommit` passes with zero warnings/errors
- [ ] `mix test` passes with zero failures
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes (or documented exceptions)
- [ ] `mix dialyzer` passes (or documented exceptions)
- [ ] `mix sobelow --config .sobelow-conf` passes
- [ ] Coverage report generated via `mix coveralls.html` (if practical)
- [ ] Summary of spec coverage: which acceptance criteria are met and how

## Acceptance Criteria

- [ ] `mix precommit` exits 0
- [ ] `mix test` exits 0 with all tests passing
- [ ] No debug prints or log noise in committed code
- [ ] All new public functions have `@doc` and `@spec`
- [ ] All validation messages use i18n (`dgettext`)
- [ ] HEEx templates use `{}` interpolation (no `<%= %>`)
- [ ] No hardcoded secrets or salts
- [ ] Migration is reversible
- [ ] Existing tests still pass (no regressions)

## Technical Notes

### Commands to Run
```bash
mix format
mix credo --strict
mix dialyzer
mix sobelow --config .sobelow-conf
mix test
mix precommit
mix coveralls.html  # optional, for coverage report
```

### Common Issues to Fix
- Missing `@doc` on public functions
- Missing i18n on validation messages
- Unused aliases or imports
- Format violations
- Credo warnings (long functions, complex conditions)
- Dialyzer type mismatches

### Constraints
- Do NOT introduce new dependencies
- Do NOT modify unrelated code
- Fix only issues in the files created/modified by Tasks 01-08
- If a Credo or Dialyzer warning requires a significant code change, document it for human review rather than making a potentially risky change

## Execution Instructions

### For the Agent
1. Run `mix format` and fix any formatting issues
2. Run `mix credo --strict` and fix warnings
3. Run `mix dialyzer` and fix type errors
4. Run `mix sobelow --config .sobelow-conf` and address any findings
5. Run `mix test` and fix any failures
6. Run `mix precommit` and verify it passes
7. Review all new/modified files for:
   - Missing `@doc`/`@spec`
   - Hardcoded strings (should use dgettext)
   - Debug prints or unnecessary Logger calls
   - `<%= %>` in HEEx (should use `{}`)
8. Generate coverage report if practical
9. Create a spec coverage matrix in the Execution Summary

### For the Human Reviewer
After agent completes:
1. Review the spec coverage matrix
2. Verify `mix precommit` passes
3. Verify no regressions in existing tests
4. Review coverage report (if generated)
5. Do a final manual walkthrough in the browser
6. Decide if the feature is ready for PR
7. If approved: mark `[x]` on "Approved", update plan.md status to COMPLETED
8. If rejected: identify specific issues for rework

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created

### Spec Coverage Matrix

| User Story | Acceptance Criteria | Covered By | Status |
|------------|-------------------|------------|--------|
| US-1 | Session creation | | |
| US-2 | View unreconciled | | |
| US-3 | Bulk mark cleared | | |
| US-4 | Statement balance | | |
| US-5 | Finalize | | |
| US-6 | Void guard | | |
| US-7 | Session history | | |
| US-8 | Un-clear | | |

### Quality Gate Results

| Check | Result | Notes |
|-------|--------|-------|
| `mix format` | | |
| `mix credo --strict` | | |
| `mix dialyzer` | | |
| `mix sobelow` | | |
| `mix test` | | |
| `mix precommit` | | |

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Feature complete, ready for PR
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# After approval, human creates the commit and PR
```
