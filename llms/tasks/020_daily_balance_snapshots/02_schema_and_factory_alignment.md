# Task 02: Ledger Schema and Factory Alignment

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 01 outputs, and the referenced schema/factory files before starting implementation.

## Objective
Align existing ledger-side schemas and factories with the new data model introduced by the migration, especially explicit account timezone handling and any posting/account shape alignment required by Task 01.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/01_migration_foundation.md`
- [ ] Completed outputs from Task 01
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/ledger/account.ex`
- [ ] `lib/aurum_finance/ledger/posting.ex`
- [ ] `test/support/factory.ex`

## Expected Outputs

- [ ] Updated `AurumFinance.Ledger.Account` schema/changeset/docs with required `timezone`
- [ ] Updated account-related factories and helpers
- [ ] Any needed ledger-side schema alignment for precision/type expectations introduced by Task 01

## Acceptance Criteria

- [ ] `Account` requires explicit `timezone` on new account creation
- [ ] `Account` does not default timezone from `entity`
- [ ] Docs/comments make clear that legacy migration backfill is not final business semantics
- [ ] Factories produce valid accounts with explicit timezone
- [ ] Public functions include `@doc`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ledger/account.ex
lib/aurum_finance/ledger/posting.ex
test/support/factory.ex
```

### Constraints
- Do not add reporting schema/resolver modules here
- Do not implement projection rebuild logic yet
- Do not add reporting UI here

## Execution Instructions

### For the Agent
1. Read Task 01 results first.
2. Update `Account` and factories for explicit timezone handling.
3. Apply only ledger-side/schema-side alignment required by the migration outputs.
4. Keep implementation limited to existing ledger/factory data shape alignment.

### For the Human Reviewer
1. Confirm timezone is explicit for new accounts.
2. Confirm factories and ledger schema docs are aligned with the approved semantics.
3. Approve before Task 03 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

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
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
