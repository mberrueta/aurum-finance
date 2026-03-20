# Task 02: Net Worth Backend Read Model

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03

## Assigned Agent
`dev-backend-elixir-engineer` - Senior Elixir/Phoenix backend engineer for read models, queries, and business semantics

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 01 output, the approved plan, and existing reporting modules before implementing the report-shaped backend contract.

## Objective
Implement the Net Worth V1 backend read model on top of `daily_balance_snapshots`, including:

- included account selection
- latest snapshot `<= as_of_date` semantics
- coverage classification
- per-currency totals
- liability presentation semantics
- page-level freshness result

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/01_net_worth_query_and_performance_contract.md`
- [ ] Approved Task 01 output
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`
- [ ] `lib/aurum_finance/ledger.ex`

## Expected Outputs

- [ ] Report-specific backend module for Net Worth
- [ ] Public `AurumFinance.Reporting` API entrypoint for Net Worth reads
- [ ] Structured result contract for the Net Worth page and hub card
- [ ] `@doc`, `@spec`, and executable examples for non-trivial public functions

## Acceptance Criteria

- [ ] Uses only `daily_balance_snapshots` plus ledger/account facts already in scope
- [ ] Applies the canonical account scope: `account_type in [:asset, :liability]`, `management_group == :institution`, `archived_at is nil`
- [ ] Uses latest snapshot `<= as_of_date` per included account
- [ ] Returns `exact`, `carried_forward`, `refreshable_gap`, and `no_history`
- [ ] Excludes no-history rows from totals while keeping them visible in the result
- [ ] Returns per-currency summaries only, with no FX or consolidated global total
- [ ] Returns entity display metadata for each row so the UI can deterministically show or hide the Entity column without additional queries
- [ ] Preserves internal ledger sign semantics while presenting liabilities as positive owed amounts in report-shaped output
- [ ] Treats current business date default as `Date.utc_today()` in V1
- [ ] Keeps web shaping thin by returning a report-ready result object/map

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/reporting/
lib/aurum_finance/ledger/account.ex
lib/aurum_finance/ledger.ex
test/aurum_finance/reporting/
```

### Constraints
- Web layers must call through `AurumFinance.Reporting`
- No implicit recomputation on read
- No generic freshness framework beyond immediate need

## Execution Instructions

### For the Agent
1. Read Task 01 output before writing code.
2. Implement the smallest backend contract that satisfies the approved plan.
3. Keep query logic isolated and explainable.
4. Document assumptions, especially around freshness and liability presentation.

### For the Human Reviewer
1. Confirm the returned data contract is stable enough for UI tasks.
2. Check that freshness semantics match the approved plan.
3. Approve before Task 03 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
### Decisions Made
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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
