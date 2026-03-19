# Task 02: Ledger Schema and Factory Alignment

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off
- **Blocked by**: None
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

### Work Performed
- Updated `AurumFinance.Ledger.Account` so `timezone` is part of the schema, required attributes, and account changeset documentation
- Updated ledger-side account creation paths to propagate explicit timezone values instead of relying on defaults or entity-derived behavior
- Updated `test/support/factory.ex` account factories/helpers so test accounts always include explicit timezone values
- Updated `AurumFinance.Ledger.Posting` documentation to reflect the normalized `decimal(20, 4)` persistence shape introduced by Task 01
- Verified the aligned ledger/factory shape against the existing suite and `mix precommit`

### Outputs Created
- `lib/aurum_finance/ledger/account.ex`
- `lib/aurum_finance/ledger/posting.ex`
- `test/support/factory.ex`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Explicit timezone remains an account-owned attribute rather than an entity-derived default | The task and plan both require explicit account timezone handling and explicitly reject deriving it from entity data |
| Test/default helper timezones may use a deterministic literal value | Factories need one stable valid timezone to generate accounts, but that helper default does not alter production account semantics |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Require `timezone` at the `Account` changeset boundary | Infer timezone from `entity`, keep it optional, or add a schema default | Task 02 requires explicit timezone on account creation and no entity-derived fallback |
| Keep posting precision alignment as documentation/code-shape work in Task 02 | Add extra ledger precision logic unrelated to the migration | Task 02 is limited to schema/factory alignment after the Task 01 migration already changed persistence |
| Fix account-producing factories and helper callsites immediately | Leave downstream tests and helpers to fail until later tasks | Factory alignment is part of Task 02 acceptance and keeps later tasks focused on reporting work |

### Blockers Encountered
- None after Task 01 approval; implementation completed and validated
- Task 01's original wording mentions compatibility backfill language for `accounts.timezone`, but the approved implementation intentionally fails fast instead of backfilling. Review Task 01 against the implemented migration, not the earlier placeholder wording.

### Questions for Human
1. None

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
