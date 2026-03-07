# Task 04: Security/Architecture Review + Handoff

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 05

## Assigned Agent
`audit-security` - Security reviewer for features and code changes. Analyzes authentication, authorization, input validation, secrets management, OWASP risks, and PII safety.

## Agent Invocation
Activate the `audit-security` agent with the following prompt:

> Act as `audit-security` following `llms/constitution.md`.
>
> Execute Task 04 from `llms/tasks/011_account_model/04_security_architecture_handoff.md`.
>
> Read all inputs listed in the task. Perform a security review of the Account model implementation focusing on entity scoping discipline, PII handling (institution_account_ref), audit completeness, and soft-archive integrity. Then produce handoff notes for downstream issues.

## Objective
Validate that the Account model implementation meets security requirements (entity-scoped data isolation, PII redaction, no hard-delete paths, complete audit trails) and produce handoff notes documenting how this issue unblocks future transaction/posting work in M1.

## Inputs Required

- [ ] `llms/tasks/011_account_model/plan.md` - Master plan with security-relevant decisions
- [ ] `llms/constitution.md` - Security and configuration hygiene rules
- [ ] `llms/tasks/010_entity_model/04_ownership_boundary_contract_output.md` - Entity ownership boundary contract
- [ ] `lib/aurum_finance/ledger.ex` - Context API (from Task 01) -- verify entity scoping, audit integration, no delete paths
- [ ] `lib/aurum_finance/ledger/account.ex` - Schema (from Task 01) -- verify field types, constraints
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - LiveView (from Task 02) -- verify no PII in flash, entity scoping in UI
- [ ] `lib/aurum_finance_web/components/accounts_components.ex` - Components (from Task 02) -- verify no PII exposure
- [ ] `test/aurum_finance/ledger_test.exs` - Context tests (from Task 03) -- verify scoping tests exist
- [ ] `test/aurum_finance_web/live/accounts_live_test.exs` - LiveView tests (from Task 03) -- verify coverage
- [ ] `priv/repo/migrations/*_create_accounts.exs` - Migration (from Task 01) -- verify FK constraints, indexes
- [ ] `docs/adr/0009-multi-entity-ownership-model.md` - Entity ownership ADR
- [ ] `docs/adr/0018-financial-data-security-boundaries.md` - Security boundaries ADR

## Expected Outputs

- [ ] **Security review report**: Section in "Execution Summary" below with findings organized by category
- [ ] **Handoff notes**: `llms/tasks/011_account_model/04_handoff_notes.md` (separate file documenting downstream unblock)

### Security Review Categories

1. **Entity scoping discipline**
   - All query functions enforce `entity_id` scope
   - No path allows cross-entity data access
   - FK constraint exists on `accounts.entity_id`
   - Index covers entity-scoped queries

2. **PII handling**
   - `institution_account_ref` is redacted in audit snapshots
   - `institution_account_ref` does not appear in application logs
   - `institution_account_ref` does not appear in flash messages
   - `institution_account_ref` does not appear in error messages returned to browser

3. **Soft archive integrity**
   - No hard-delete function in context or schema
   - No `Repo.delete` calls anywhere in ledger context
   - Archive only sets `archived_at` timestamp
   - Unarchive only clears `archived_at` to nil

4. **Audit completeness**
   - Create/update/archive/unarchive all emit audit events
   - Audit events include: `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`
   - `actor` and `channel` are passed from LiveView to context

5. **Input validation**
   - `currency_code` format validation prevents injection
   - Ecto.Enum restricts `account_type` and `operational_subtype` to valid values
   - Name length constrained (2-160)
   - No raw SQL or string interpolation in queries

### Handoff Notes Content

The handoff document should cover:
- What this issue delivered (schema, context, UI, tests)
- How `AurumFinance.Ledger` context is structured for expansion
- What downstream issues can now proceed (transactions, postings, balance derivation)
- How `get_account_balance/2` placeholder should be replaced when postings exist
- Entity scoping expectations for downstream models

## Acceptance Criteria

- [ ] Security review covers all 5 categories listed above
- [ ] Each category has a PASS/FAIL/WARN status
- [ ] Any FAIL or WARN findings include specific file paths and line references
- [ ] Any FAIL findings include remediation recommendations
- [ ] Handoff notes file created at `llms/tasks/011_account_model/04_handoff_notes.md`
- [ ] Handoff notes explain how transactions/postings should integrate with the Ledger context
- [ ] No critical (FAIL) security findings remain unaddressed

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex                            # Primary review target: context API
lib/aurum_finance/ledger/account.ex                    # Primary review target: schema
lib/aurum_finance_web/live/accounts_live.ex            # Review: PII in UI, entity scoping
lib/aurum_finance_web/components/accounts_components.ex # Review: PII in components
priv/repo/migrations/*_create_accounts.exs             # Review: DB constraints
test/aurum_finance/ledger_test.exs                     # Verify: scoping tests exist
lib/aurum_finance/audit.ex                             # Reference: audit infrastructure
docs/adr/0018-financial-data-security-boundaries.md    # Reference: security ADR
```

### Review Checklist Guidance

**Entity scoping verification**:
- Search for all `Repo.all`, `Repo.get`, `Repo.one` calls in `ledger.ex`
- Verify each query includes `entity_id` filter
- Verify `get_account!/1` is acceptable as a non-scoped lookup (used internally after entity context is established)
- Check if any query path could bypass entity filtering

**PII audit**:
- Search for `institution_account_ref` across all source files
- Verify it appears in `@audit_redact_fields`
- Verify it does not appear in `Logger.*` calls
- Verify it does not appear in `put_flash` calls
- Verify it is not interpolated into error messages

**Hard-delete check**:
- Search for `Repo.delete` in `lib/aurum_finance/ledger.ex`
- Search for `delete_account` function names
- Verify no route or event handler triggers deletion

### Constraints
- This is a review-only task -- no code changes
- Findings are documented, not fixed (fixes go to a follow-up task if needed)
- The review should be thorough but proportionate to the feature scope

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Systematically review each security category
3. For each category, provide PASS/FAIL/WARN with evidence (file paths, line numbers)
4. Create `llms/tasks/011_account_model/04_handoff_notes.md` with downstream integration guidance
5. Document all findings in "Execution Summary"
6. If any FAIL findings exist, clearly mark them with remediation steps

### For the Human Reviewer
After agent completes:
1. Review security findings for completeness
2. Assess any WARN findings for acceptable risk
3. Decide if any FAIL findings require a follow-up fix task before proceeding
4. Review handoff notes for accuracy and completeness
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason (e.g., critical finding requires fix before proceeding)

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files/artifacts created]

### Security Findings

| Category | Status | Details |
|----------|--------|---------|
| Entity scoping | PASS/FAIL/WARN | [Evidence] |
| PII handling | PASS/FAIL/WARN | [Evidence] |
| Soft archive integrity | PASS/FAIL/WARN | [Evidence] |
| Audit completeness | PASS/FAIL/WARN | [Evidence] |
| Input validation | PASS/FAIL/WARN | [Evidence] |

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| | |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| | | |

### Blockers Encountered
- [Blocker] - Resolution: [How resolved or "Needs human input"]

### Questions for Human
1. [Question needing human input]

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
