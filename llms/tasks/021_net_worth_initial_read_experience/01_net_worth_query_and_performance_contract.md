# Task 01: Net Worth Query and Performance Contract

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02

## Assigned Agent
`dev-db-performance-architect` - Database and query-shape specialist for Postgres, indexes, and performance-sensitive read paths

## Agent Invocation
Invoke the `dev-db-performance-architect` agent with instructions to read this task file, the approved plan, and the current reporting/ledger modules before proposing the concrete query and performance contract.

## Objective
Define the exact read-query approach for Net Worth V1 so backend implementation starts with a clear contract for:

- latest snapshot row `<= as_of_date` per included account
- no-history account preservation
- freshness-supporting query boundaries
- acceptable index usage and N+1 avoidance expectations

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/execution_plan.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- [ ] `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
- [ ] `lib/aurum_finance/ledger/account.ex`
- [ ] `lib/aurum_finance/ledger.ex`

## Expected Outputs

- [ ] Query contract for included account selection
- [ ] Query contract for latest qualifying snapshot selection
- [ ] Freshness-evaluation query notes for `transaction.date` and `inserted_at`
- [ ] Performance/N+1 review notes and any index guidance

## Acceptance Criteria

- [ ] Recommends one concrete approach for selecting the latest snapshot row per account while preserving no-history accounts
- [ ] Confirms how to keep account scope canonical: `account_type`, `management_group`, `archived_at`
- [ ] Identifies whether the current snapshot indexes are sufficient for V1
- [ ] Identifies N+1 risks for the LiveView layer and how the backend contract should prevent them
- [ ] Keeps scope narrow: no new projection table, no generic report framework
- [ ] Documents any non-blocking performance concerns for later PR review

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting/                 # Reporting context and snapshot projection
lib/aurum_finance/ledger/account.ex          # Canonical account scope fields
lib/aurum_finance_web/live/reports_live.*    # Existing reports surface to replace
test/aurum_finance/reporting/                # Existing reporting query/test patterns
```

### Constraints
- No implementation in this task
- Do not broaden the design into multi-report infrastructure
- Prefer a query shape that keeps report semantics explainable under audit

## Execution Instructions

### For the Agent
1. Read the approved plan and current reporting/account code.
2. Identify the best latest-row query strategy for V1.
3. Explicitly call out performance and N+1 risks.
4. Document the recommended backend contract the next task should implement.

### For the Human Reviewer
1. Confirm the proposed query contract is understandable and narrow.
2. Confirm performance concerns are acceptable for V1.
3. Approve before Task 02 begins.

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

