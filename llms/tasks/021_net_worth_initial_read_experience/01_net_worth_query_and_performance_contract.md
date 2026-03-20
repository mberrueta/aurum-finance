# Task 01: Net Worth Query and Performance Contract

## Status
- **Status**: COMPLETED
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

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/execution_plan.md`
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `lib/aurum_finance/reporting.ex`
- [x] `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
- [x] `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
- [x] `lib/aurum_finance/ledger/account.ex`
- [x] `lib/aurum_finance/ledger.ex`

## Expected Outputs

- [x] Query contract for included account selection
- [x] Query contract for latest qualifying snapshot selection
- [x] Freshness-evaluation query notes for `transaction.date` and `inserted_at`
- [x] Performance/N+1 review notes and any index guidance

## Acceptance Criteria

- [x] Recommends one concrete approach for selecting the latest snapshot row per account while preserving no-history accounts
- [x] Confirms how to keep account scope canonical: `account_type`, `management_group`, `archived_at`
- [x] Identifies whether the current snapshot indexes are sufficient for V1
- [x] Identifies N+1 risks for the LiveView layer and how the backend contract should prevent them
- [x] Keeps scope narrow: no new projection table, no generic report framework
- [x] Documents any non-blocking performance concerns for later PR review

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

### Recommended Query and Performance Contract

#### Included Account Selection
- Use one canonical backend account-scope query, not iterative account fetches or LiveView-side filtering.
- Scope must remain explicit to the caller's entity boundary.
- Included accounts are exactly:
  - `account_type in [:asset, :liability]`
  - `management_group == :institution`
  - `archived_at is nil`
- This must stay aligned with `AurumFinance.Ledger.Account` semantics and existing `AurumFinance.Ledger` filters rather than introducing report-only account rules.

#### Latest Qualifying Snapshot Selection
- Start from the included-account relation and preserve every included account row.
- Join snapshots with a set-based query that returns the latest row where `snapshot_date <= as_of_date` for each account.
- Recommended query shape for V1:
  - included account scope query
  - `LEFT JOIN LATERAL` to `daily_balance_snapshots`
  - filter `snapshot_date <= ^as_of_date`
  - `ORDER BY snapshot_date DESC`
  - `LIMIT 1`
- This is the preferred shape because it keeps the derivation rule explainable and naturally preserves `no_history` rows without a second recovery pass.
- `DISTINCT ON (account_id)` is acceptable only as a fallback if the final Ecto expression becomes materially clearer without changing semantics.

#### Freshness Evaluation Notes
- Freshness must not be inferred from `snapshot_date < as_of_date` alone because valid carry-forward is part of the V1 contract.
- Carry the selected snapshot row's `computed_at` through as the freshness watermark for that account row.
- Evaluate staleness using relevant ledger facts where:
  - the transaction touches the included account
  - `transaction.date <= as_of_date`
  - `transaction.inserted_at > snapshot.computed_at`
- Prefer an `EXISTS`-style freshness probe over ledger facts instead of row-by-row helper calls.
- `no_history` remains a visibility/data-availability state and does not, by itself, make the report outdated.

#### Performance and N+1 Notes
- The backend contract must return a fully shaped report payload for the LiveView:
  - included accounts
  - selected snapshot metadata
  - coverage classification inputs
  - per-currency rollup inputs
- The LiveView must not call per-account helpers such as `latest_snapshot_date_for_account/1` or `earliest_snapshot_date_for_account/1` while rendering.
- The report path should avoid:
  - per-account snapshot lookups
  - per-account freshness probes
  - repeated account/entity lookups from templates or helper loops
- The current snapshot unique index on `[:account_id, :snapshot_date]` is sufficient for the latest-snapshot-per-account selection in V1.

#### Index Guidance
- Current V1-sufficient indexes:
  - `accounts(entity_id)`
  - `accounts(entity_id, archived_at)`
  - `daily_balance_snapshots(account_id, snapshot_date)` unique index
  - `postings(account_id)`
  - `postings(transaction_id)`
  - `transactions(entity_id, date)`
- Non-blocking follow-up guidance:
  - if the final freshness probe filters by entity and watermark often enough to show measurable cost, add `transactions(entity_id, inserted_at)`
  - do not add new projection tables or generalized reporting indexes in this task

#### Non-Blocking Performance Concerns
- The freshness probe is the likeliest place for V1 cost growth, not the latest-snapshot lookup.
- Once Task 02 implements the concrete query, validate with `EXPLAIN (ANALYZE, BUFFERS)` against representative local data before considering any extra index beyond `transactions(entity_id, inserted_at)`.

### Work Performed
- Read the approved feature plan, execution plan, constitution, and project context.
- Reviewed the current reporting, ledger, snapshot projection, tests, and relevant migrations.
- Delegated a focused read-only review to the `dev-db-performance-architect` agent and reconciled its output with the current codebase.
- Chose one concrete latest-snapshot query strategy and documented the backend contract needed by Task 02.

### Outputs Created
- Included-account query contract for Net Worth V1.
- Latest-qualifying-snapshot query contract that preserves `no_history` rows.
- Freshness-evaluation notes using `transaction.date` and `transaction.inserted_at`.
- Performance/N+1 guidance and bounded index recommendations for PR review.

### Assumptions Made
- Net Worth V1 remains scoped to the existing entity-boundary semantics already present in `AurumFinance.Ledger`.
- `daily_balance_snapshots.computed_at` is the correct persisted watermark to compare against later-inserted relevant transactions.
- No new migration is required immediately for Task 02 unless the implemented freshness query proves that `transactions(entity_id, inserted_at)` is needed.

### Decisions Made
- Recommend a set-based report query that begins from included accounts and uses `LEFT JOIN LATERAL` for latest snapshot selection.
- Keep `no_history` rows in the result set and out of totals.
- Keep freshness logic report-specific and watermark-based.
- Reject any Task 02 approach that uses per-account helper calls from the LiveView or backend loops to assemble the report.

### Blockers Encountered
- None.

### Questions for Human
- Are you comfortable treating `transactions(entity_id, inserted_at)` as a conditional follow-up index instead of an automatic in-scope addition for Task 02?
- Do you want Task 02 to treat `LEFT JOIN LATERAL` as mandatory, or acceptable-as-default with `DISTINCT ON` allowed only if Ecto composition becomes materially clearer without changing semantics?

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
