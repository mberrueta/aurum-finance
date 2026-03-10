# Task 04: Clearing Account Strategy

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Tasks 05, 06, 08, 10, 11, 12, 13

## Assigned Agent
`tl-architect` - Technical lead architect. Defines architecture boundaries, invariants, and implementation guardrails for ledger-safe workflows.

## Agent Invocation
Activate `tl-architect` with:

> Act as `tl-architect` following `llms/constitution.md`.
>
> Execute Task 04 from `llms/tasks/017_import_review_queue_materialization/04_clearing_account_strategy.md`.
>
> Read the full milestone plan and Task 01 output first. Define the import clearing-account strategy used to keep materialized transactions balanced without introducing FX conversion or multi-currency accounts.

## Objective
Lock down the v1 balancing strategy for imported-row materialization, including how the system resolves or creates system-managed clearing accounts in the same currency as the imported account.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Task 01 output
- [ ] `llms/tasks/012_ledger_primitives/plan.md`
- [ ] `llms/tasks/011_account_model/plan.md`
- [ ] `lib/aurum_finance/ledger.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`

## Expected Outputs

- [ ] Explicit clearing-account resolution strategy
- [ ] Account-creation or account-reuse policy for system-managed clearing accounts
- [ ] Native-currency rule confirming the clearing account matches the imported account currency
- [ ] Guidance for backend implementation and test coverage

## Acceptance Criteria

- [ ] The strategy keeps every materialized imported row balanced with two postings
- [ ] The clearing account is resolved in the same currency as the imported account
- [ ] The strategy does not imply FX conversion
- [ ] The strategy does not imply multi-currency postings inside one account
- [ ] The strategy is explicit enough for backend implementation without reopening product design

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ledger/account.ex             # Account invariants and management groups
lib/aurum_finance/ledger.ex                     # Account lookup/creation and transaction creation
llms/tasks/011_account_model/plan.md           # System-managed account model context
llms/tasks/012_ledger_primitives/plan.md       # Ledger balancing and currency invariants
```

### Patterns to Follow
- Reuse `system_managed` account concepts already present in the ledger model
- Keep ledger postings account-native and balanced
- Prefer deterministic account resolution over ad hoc runtime heuristics

### Constraints
- No implementation code in this task
- No categorization rules or reconciliation logic

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Define the clearing-account strategy and native-currency guardrails.
3. Document any setup or migration implications for later tasks.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Confirm the clearing-account semantics are acceptable for v1 reporting tradeoffs.
3. Verify the strategy remains native-currency only.
4. If approved: mark `[x]` on "Approved" and update plan.md status.
5. If rejected: add rejection reason and specific feedback.

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
# Human-only commands, if any
```
