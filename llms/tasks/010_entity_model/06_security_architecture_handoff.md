# Task 06: Security/Architecture Review + Handoff

## Status
- **Status**: ⏳ PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: Task 07

## Assigned Agent
`audit-security` - Security review and hardening validation.

## Agent Invocation
Use `llms/agents/audit_security.md` (`name: audit-security`) to review the delivered implementation for security and traceability posture before documentation sync.

## Objective
Validate that the implementation matches required security/traceability posture: soft archive only, no hard delete, and generic audit coverage with explainability fields.

## Inputs Required
- [ ] `llms/tasks/010_entity_model/plan.md`
- [ ] Tasks 01-05 outputs
- [ ] Security-relevant code touched by #10
- [ ] `docs/security.md` (if impacted)

## Expected Outputs
- [ ] Security findings report for #10 scope
- [ ] Confirmation (or failures) for archive/audit constraints
- [ ] Risk list with severity and mitigation recommendations

## Acceptance Criteria
- [ ] Confirms no hard-delete route/path exposed
- [ ] Confirms audit shape includes actor/channel/occurred_at/before/after
- [ ] Identifies any sensitive-data leakage risks (`tax_identifier` handling)
- [ ] Provides clear pass/fail recommendation for release

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance/`  
`lib/aurum_finance_web/`  
`test/`

### Patterns to Follow
- Findings-first reporting order.
- Concrete file/line references.

### Constraints
- Keep review scoped to #10 changes.

## Execution Instructions
### For the Agent
1. Review diffs and behavior against security ACs.
2. Produce findings ordered by severity.
3. Document residual risks and recommendations.

### For the Human Reviewer
1. Validate findings and decide pass/fail.
2. Approve only when critical findings are resolved or explicitly accepted.

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
