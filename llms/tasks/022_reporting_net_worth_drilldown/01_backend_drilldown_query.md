# Task 01: Backend Drilldown Query

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 02, Task 03

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix.

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to implement the drilldown query in the Reporting context.

## Objective
Add a `drilldown_transactions/3` function to `AurumFinance.Reporting.NetWorth` that fetches paginated transactions explaining an account's snapshot balance, and expose it through the `AurumFinance.Reporting` context facade.

## Inputs Required

- [ ] `llms/tasks/022_reporting_net_worth_drilldown/plan.md` - Feature specification (Query / Data Contract section)
- [ ] `llms/constitution.md` - Project coding standards
- [ ] `llms/project_context.md` - Domain conventions
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/reporting/net_worth.ex` - Existing net worth module
- [ ] `lib/aurum_finance/reporting.ex` - Reporting context facade
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot.ex` - Snapshot schema
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Transaction schema
- [ ] `lib/aurum_finance/ledger/posting.ex` - Posting schema

## Expected Outputs

- [ ] New public function `AurumFinance.Reporting.NetWorth.drilldown_transactions/3` with `@doc` and `@spec`
- [ ] Corresponding public delegation in `AurumFinance.Reporting` context facade
- [ ] Paginated query implementation (page-based, 20 per page default)

## Acceptance Criteria

- [ ] Function signature: `drilldown_transactions(account_id, as_of_date, opts \\ [])` where opts supports `:page` (default 1) and `:per_page` (default 20)
- [ ] Returns `{:ok, %{transactions: [...], total_count: integer, page: integer, per_page: integer, total_pages: integer}}` or `{:error, reason}`
- [ ] Query fetches transactions where `posting.account_id == account_id` and `transaction.date <= as_of_date`
- [ ] Groups by transaction, returning: `transaction_id`, `date`, `description`, `net_amount` (sum of posting amounts for that account)
- [ ] Orders by `transaction.date DESC`, `transaction.inserted_at DESC`
- [ ] **Entity isolation guardrail**: Although the API signature is `drilldown_transactions(account_id, as_of_date, opts)`, the implementation must join through account→entity ownership consistently in the query shape, so that entity isolation is explicit in the query — not an implicit assumption left to the caller. This ensures the contract remains safe if the query is reused elsewhere.
- [ ] **Transaction eligibility**: Must match the same fact eligibility used by `DailyBalanceSnapshot` projection. Derive the exact filter (e.g., voided transaction handling) from projection code — do not assume.
- [ ] `@doc` with executable-style example
- [ ] Passes `mix precommit` (format, credo, dialyzer)

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/reporting/net_worth.ex          # Add drilldown function here
lib/aurum_finance/reporting.ex                     # Add facade delegation
lib/aurum_finance/ledger/transaction.ex            # Transaction schema reference
lib/aurum_finance/ledger/posting.ex                # Posting schema reference
lib/aurum_finance/reporting/daily_balance_snapshot.ex # Snapshot schema reference
```

### Patterns to Follow
- Use `import Ecto.Query, warn: false` (already imported in net_worth.ex)
- Follow the existing `get_report/2` pattern: private query builder, public function with `@doc`/`@spec`
- Use `Repo.all/1` for data, separate count query for total
- Pagination: offset/limit based on page/per_page params
- The `account_rows_query/2` in net_worth.ex shows the lateral join pattern for snapshots -- the drilldown does NOT need a lateral join, it just needs the snapshot date as a parameter

### Constraints
- The drilldown must stop at the snapshot date, NOT the as_of_date. The caller (LiveView) will pass the `snapshot_date_used` from the account row as the `as_of_date` parameter
- No N+1 queries -- single query with grouping
- Transaction eligibility must be derived from `DailyBalanceSnapshot` projection code — the drilldown filter must match exactly what the projection considers a valid fact
- Posting sign convention: positive = debit, negative = credit. Return the raw sum as `net_amount`

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Examine the projection logic in `lib/aurum_finance/reporting/projections/` to derive the exact transaction eligibility filter used by `DailyBalanceSnapshot` — replicate that filter in the drilldown query
3. Implement `drilldown_transactions/3` in `NetWorth` module
4. Add the facade delegation in `Reporting` context
5. Run `mix compile --warnings-as-errors` to verify
6. Run `mix format` and `mix credo`
7. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review the query shape for correctness against spec
2. Verify entity isolation is explicit in the query shape (joins through account→entity ownership), not just implicit via account_id parameter
3. Verify transaction eligibility filter matches DailyBalanceSnapshot projection exactly
4. Check that pagination math is correct (total_pages, offset)
5. If approved: mark `[x]` on "Approved" and update plan.md status

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
