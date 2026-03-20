# 021 - Net Worth Initial Read Experience

**Status**: READY FOR TECH LEAD REVIEW
**Priority**: P1
**Labels**: type:feature, area:reporting, area:product, area:liveview
**Implementation Intent**: Deliver the first real reporting read experience on top of `daily_balance_snapshots` without introducing generic report infrastructure or hidden recomputation.

---

## Objective

Implement the first usable reporting experience for AurumFinance:

- a real `/reports` hub organized by report type
- a dedicated `/reports/net-worth` page
- a ledger-explainable net worth read model backed by `daily_balance_snapshots`
- minimal but honest freshness and coverage signaling so stale or incomplete reporting data is visible early

This feature is the first consumer that validates whether the reporting foundation is fit for real product use. Success is not visual polish alone. Success is an explainable read path that produces defensible numbers, makes stale coverage obvious, and stays traceable to ledger-backed facts.

---

## Scope

In scope for this issue:

- replace the current mock `/reports` surface with a real reporting hub
- keep `/reports` focused on report types, not rebuild history
- add one real report card for Net Worth
- expose one global async reporting refresh action on `/reports`
- expose one simple global reporting freshness state on `/reports`
- add `/reports/net-worth` as the canonical Net Worth report page
- implement a reporting read service for net worth as of a requested business date
- use latest snapshot `<= as_of_date` per included account
- filter account scope to non-archived institution-managed `asset` and `liability` accounts only
- compute totals per native currency only
- classify account coverage as `exact`, `carried_forward`, `refreshable_gap`, or `no_history`
- surface freshness/outdated state for Net Worth using both business-date coverage and inserted-fact watermark semantics
- render no-history accounts visibly but exclude them from totals
- suggest refresh when data is refreshable/outdated, without triggering recomputation on read
- add backend, LiveView, and integration tests for primary semantics
- update architecture / ADR / roadmap / product docs at the end

---

## Decisions Already Locked

These are not open design questions in this plan:

- `/reports` is the reporting hub and `/reports/net-worth` is the dedicated report page.
- Refresh on `/reports` is global for reporting, async only, and enqueue-based.
- `/reports` shows only simple global freshness: `Up to date` or `Outdated`.
- Net Worth is the first canonical report and must be explainable, not a dashboard widget.
- Net Worth V1 includes only accounts where `account_type in [:asset, :liability]`, `management_group == :institution`, and `archived_at is nil`.
- Net Worth reads the latest available snapshot `<= as_of_date` for each account.
- Default Net Worth `as_of_date` is the current business date. In V1, where no richer business-calendar abstraction exists yet, implement that default with `Date.utc_today()`.
- The read path must never recompute implicitly.
- Coverage states are `exact`, `carried_forward`, `refreshable_gap`, and `no_history`.
- `no_history` rows stay visible, but are not counted into totals.
- Totals are per native currency only; no FX or consolidated total exists in V1.
- UI presentation shows liabilities as positive owed amounts in summaries and rows, while preserving internal ledger sign semantics in backend calculation logic.
- Net Worth summary math is presented as `assets - liabilities`.
- The Net Worth card on `/reports` stays compact; detailed account explanation belongs only on `/reports/net-worth`.
- Net Worth freshness must consider both `transaction.date <= as_of_date` and later-inserted relevant ledger facts.

---

## Project Context

### Related Existing Modules

- `AurumFinance.Reporting`
  - Location: `lib/aurum_finance/reporting.ex`
  - Owns the snapshot projection access and async refresh entrypoints today.
  - Currently exposes projection-level APIs only; it does not yet expose report-specific read models.

- `AurumFinance.Reporting.DailyBalanceSnapshot`
  - Location: `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
  - Canonical persisted reporting row for account/day closing balances.

- `AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1`
  - Location: `lib/aurum_finance/reporting/projections/daily_balance_snapshots/v1.ex`
  - Already provides the projection rebuild engine and forward-cumulative replacement semantics.

- `AurumFinance.Reporting.LedgerEventBridge`
  - Location: `lib/aurum_finance/reporting/ledger_event_bridge.ex`
  - Already translates ledger write notifications into async reporting refresh requests.

- `AurumFinance.Ledger.Account`
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Relevant fields and semantics:
    - `account_type`
    - `management_group`
    - `currency_code`
    - `archived_at`
    - `entity_id`
  - Existing helpers confirm the distinction between institution, category, and system-managed accounts.

- `AurumFinance.Ledger`
  - Location: `lib/aurum_finance/ledger.ex`
  - Already provides scoped account listing APIs and explicit entity boundaries.

- `AurumFinanceWeb.ReportsLive`
  - Location: `lib/aurum_finance_web/live/reports_live.ex`
  - Current state is still mock-heavy and contains the manual rebuild control introduced with the snapshot foundation.

### Current Reporting Reality

- Routing exists only for `/reports`; `/reports/net-worth` does not exist yet.
- Reporting freshness infrastructure is not yet modeled as a user-facing read concept.
- The current reports page still contains mock net worth history, mock cashflow, and mock portfolio content that should be removed rather than evolved.
- Snapshot rebuild and trigger plumbing already exist, so this plan should build a read experience on top of that instead of extending the projection pipeline first.

### Naming Conventions Observed

- Contexts stay explicit and flat: `AurumFinance.Reporting`, `AurumFinance.Ledger`, `AurumFinance.Entities`.
- Query APIs prefer `list_*` and filter opts with private `filter_query/2`.
- Async work is owned by explicit worker modules inside the context.
- LiveViews are routed directly under `AurumFinanceWeb` and use authenticated `live_session :app`.

---

## Assumptions

- The current root-authenticated app shell remains the access boundary for reporting; there is no role matrix beyond authenticated root access in this iteration.
- Net Worth V1 may support cross-entity output if that falls out naturally from the existing scoped account access patterns, without introducing new authorization layers or new entity-selection workflows.
- Snapshot rows remain the only persisted reporting source needed for V1; no new projection table is required if freshness can be evaluated from existing ledger and snapshot facts.
- Existing ledger inserts preserve immutable `inserted_at` semantics on transactions, and that timestamp is trustworthy enough to act as the persistence watermark input for V1 freshness checks.
- Multi-entity support exists at the domain level, but V1 may initially present a cross-entity view with an optional Entity column that is hidden when the scope is effectively single entity.
- We can treat the current global reporting freshness as an aggregate report-type freshness signal. For V1, that hub-level signal may be backed by the same projection-family freshness logic currently needed by Net Worth, without inventing a registry or implying that hub freshness will always equal Net Worth semantics in future iterations.
- V1 should support a simple live freshness state update after refresh completion, preferably via PubSub. Fallback-only reload/navigation semantics should not be the intended primary UX, even if a narrow implementation fallback is temporarily needed during development.

---

## Explicit Out Of Scope

Do not include these in this issue:

- FX conversion or consolidated global totals
- dashboard reuse of the Net Worth summary may follow later, but dashboard work is not part of this issue
- cashflow, portfolio allocation, or any second report type
- charts or time-series net worth history visualization
- CSV, Excel, or PDF export
- per-report refresh buttons
- rebuild history, run browsing, or job progress UI
- immutable generated report artifacts
- deep drilldown workflows from report rows into transaction detail
- account page or entity page net worth rollups
- generic report framework, report registry, or saved report definitions
- large dashboard redesign

---

## Product And UX Scope

### `/reports` Hub

The current page should stop pretending to be a finished reporting dashboard. It should become a simple reporting hub with three jobs:

- explain what reports exist
- show whether reporting data is current enough to trust
- let the user trigger a global async refresh

Recommended V1 hub content:

- page header with reporting purpose
- global freshness badge: `Up to date` or `Outdated`
- global async refresh action
- one Net Worth card with:
  - report name
  - short description
  - report status
  - as-of date used for card output
  - compact per-currency net worth summary
  - open link to `/reports/net-worth`

The hub-level freshness badge is intentionally coarse and operational. Detailed freshness and coverage semantics belong on `/reports/net-worth`, not on the hub card grid.

The existing technical rebuild form should not remain the primary user action. It may be removed, downgraded to a small internal maintenance section, or hidden behind a narrower internal affordance. The main product action is now global reporting refresh, not per-account snapshot rebuild.

### `/reports/net-worth`

This page is the canonical first reporting read experience. It should include:

- page-level as-of date selector
- page-level freshness state for that selected date
- explanatory hint when results may be stale because refreshable facts exist
- per-currency summary cards for:
  - Assets
  - Liabilities
  - Net Worth
- accounts table with:
  - Entity
  - Account
  - Type
  - Currency
  - Balance
  - Snapshot Used
  - Coverage
- visible no-history rows with a clear message and no invented zero balances

The UI goal is honest readability, not sophistication. Coverage and freshness need to be understandable by a user who wants to trust the numbers, and by a future engineer diagnosing projection lag.

---

## Architecture And Read-Model Implications

### 1. Add a report-specific read service, not a new base projection

The snapshot table already exists and is the correct persistence layer for V1. The missing piece is a report-oriented read model that can answer:

- what accounts are included
- what snapshot row was used per account
- whether that snapshot is exact, carried forward, refreshable, or absent
- what totals result per currency
- whether the overall report is outdated for the requested `as_of_date`

Recommended shape:

- keep public entrypoint in `AurumFinance.Reporting`
- delegate implementation to a focused module such as:
  - `AurumFinance.Reporting.NetWorth`
  - or `AurumFinance.Reporting.ReadModels.NetWorth`

This should return a structured result, not raw rows. A report-shaped result keeps the LiveView thin and makes backend tests carry the semantic contract.

### 2. Treat Net Worth as a read model over account scope plus latest usable snapshot

The report should join:

- included accounts
- entity context
- one latest snapshot row per account where `snapshot_date <= as_of_date`

The cleanest query is likely a subquery or windowed selection that picks the latest qualifying snapshot per account. This is appropriate here because:

- the read is explainability-sensitive
- we only have one report today
- the result needs the exact snapshot date used, not just the amount

Do not add a secondary “net worth snapshots” table yet. That would duplicate semantics before the first read path is proven.

### 3. Freshness is a report contract, not a generic platform primitive yet

Global freshness on `/reports` is intentionally simple, but Net Worth freshness is not trivial. V1 should implement a Net Worth-specific freshness evaluator that answers:

- does each included account have sufficient snapshot coverage for the requested `as_of_date`?
- do newer relevant ledger facts exist with `transaction.date <= as_of_date` that were inserted after the snapshot currently used?

This implies two distinct concepts:

- coverage gap on business date
- lag against persisted relevant facts

That logic should stay report-specific for now. Do not create a generalized freshness framework until a second report actually needs one.

### 4. Auditability and explainability remain first-class

The returned report rows should preserve enough metadata to explain each number:

- `account_id`
- `entity_id`
- `snapshot_date_used`
- `coverage`
- whether the row contributes to totals

The report does not need full transaction drilldown in V1, but it must make the derivation rule inspectable:

- “latest snapshot on or before as-of date”
- “excluded from totals because no snapshot exists”
- “marked refreshable because newer relevant ledger facts exist”

### 5. Privacy and boundary discipline

Reporting remains read-only over ledger facts and should continue to respect entity ownership boundaries. The read service must not bypass scoped account/entity semantics or introduce a convenience query that silently broadens scope beyond the current authenticated user model.

---

## Recommended Data And Query Semantics

### Included account set

The V1 report includes accounts where:

- `account_type in [:asset, :liability]`
- `management_group == :institution`
- `archived_at is nil`

This aligns with the already-implemented account model and avoids inventing a boolean that does not exist.

### As-of semantics

For each included account:

- choose the latest `daily_balance_snapshots` row where `snapshot_date <= as_of_date`
- if none exists, classify the account as `no_history`

Default page behavior:

- the initial Net Worth page load should use the current business date as the default `as_of_date`
- in V1, implement that default with `Date.utc_today()` until a richer business-calendar abstraction exists

Do not require exact same-day rows. Carry-forward is part of the agreed reporting model.

### Presentation semantics

- liability balances should be displayed in the UI as positive owed amounts
- backend logic should preserve the internal ledger sign semantics and only transform values for presentation/report shaping
- presented net worth should follow `assets - liabilities`

### Coverage classification

Recommended classification logic:

- `exact`
  - qualifying snapshot exists and `snapshot_date == as_of_date`
  - no newer relevant ledger fact with `transaction.date <= as_of_date` makes it stale

- `carried_forward`
  - qualifying snapshot exists and `snapshot_date < as_of_date`
  - no evidence of missed relevant ledger facts between `snapshot_date + 1` and `as_of_date`

- `refreshable_gap`
  - qualifying snapshot exists, but newer relevant ledger facts with `transaction.date <= as_of_date` were inserted after the used snapshot coverage, so the value is usable but stale
  - this is the main stale-data diagnostic state

- `no_history`
  - no qualifying snapshot exists for that account
  - row visible, no balance shown, excluded from totals

The key trade-off here is intentional: V1 should optimize for honest classification rather than trying to infer too much nuance from partial operational metadata.

### Freshness evaluation

Net Worth page freshness should be `Outdated` when either is true:

- any included account resolves to `refreshable_gap`
- any included account lacks current-enough projection coverage for facts with `transaction.date <= as_of_date`

Net Worth page freshness should be `Up to date` when:

- every included account is `exact`, `carried_forward`, or `no_history`
- and no newer relevant inserted ledger facts with `transaction.date <= as_of_date` would change the report

`no_history` alone should not make the report outdated. It is a data-availability state, not necessarily a stale projection state.

### Global `/reports` freshness

For V1:

- the Reports hub global freshness may be backed by the same projection-family freshness signal currently needed by Net Worth
- this is a pragmatic implementation choice for the first real report, not a permanent semantic claim that hub freshness always equals Net Worth
- if the implementation needs a concrete V1 as-of reference for that current signal, use `Date.utc_today()` as the implementation of the current business date default

This is deliberately pragmatic. It avoids a registry abstraction before more reports exist while keeping room for later report-specific hub aggregation.

---

## Trade-Offs

### Why not compute directly from ledger on read?

Because that would bypass the reporting architecture we just introduced and would hide projection correctness issues. The first consumer should validate the projection layer, not sidestep it.

### Why not add a dedicated net worth projection table now?

Because the semantics are still being proven. The right first step is a report read model over `daily_balance_snapshots`, not another persisted derivative that could duplicate bugs and make debugging harder.

### Why per-currency totals only?

Because V1 needs correctness and explainability. Any consolidated total without explicit FX policy would be misleading.

### Why keep freshness logic report-specific?

Because freshness depends on report semantics. A generic abstraction now would be speculative and likely wrong once cashflow or portfolio reports arrive.

### Why show no-history rows instead of treating them as zero?

Because “zero” is a factual claim. “No activity / no snapshot yet” is honest, auditable, and avoids silently distorting totals.

---

## Implementation Phases

### Phase 1: Replace the mock `/reports` surface with a real reporting hub

- remove mock net worth history, mock cashflow, mock portfolio sections
- keep the route at `/reports`
- add global reporting freshness badge
- add global async reporting refresh action
- add the Net Worth report card with compact per-currency summary and open link
- decide whether the existing manual snapshot rebuild control is removed or relegated to an internal maintenance section

Acceptance outcome:

- `/reports` reads as a reporting hub, not a fake dashboard
- one real report card is present and wired to `/reports/net-worth`

### Phase 2: Introduce the Net Worth read service contract

- add a report-oriented read API in `AurumFinance.Reporting`
- implement a focused Net Worth read module returning:
  - `as_of_date`
  - `freshness_status`
  - `refresh_suggested?`
  - `currency_summaries`
  - `account_rows`
  - any explanatory metadata needed by the LiveView
- keep report shaping in the backend, not in template code

Acceptance outcome:

- backend can compute a complete net worth report payload without LiveView-specific shaping

### Phase 3: Implement account scope and latest-snapshot query semantics

- resolve included account set using actual `Account` fields:
  - `account_type`
  - `management_group`
  - `archived_at`
- select latest snapshot `<= as_of_date` per account
- include entity metadata for display when needed
- preserve account rows with no matching snapshot

Acceptance outcome:

- result set contains both covered accounts and no-history accounts
- each row identifies the snapshot date used or the absence of one

### Phase 4: Implement coverage and freshness classification

- classify each account row as `exact`, `carried_forward`, `refreshable_gap`, or `no_history`
- evaluate whether newer ledger facts with `transaction.date <= as_of_date` and later `inserted_at` make the report stale
- derive page freshness and hub freshness from the report result
- surface simple refresh recommendation data

Acceptance outcome:

- stale but still renderable reports are clearly labeled
- freshness is based on facts relevant to the requested as-of date, not merely “anything new happened”

### Phase 5: Build `/reports/net-worth` LiveView

- add route under the authenticated app live session
- add page-level as-of date selection
- render per-currency summary
- render freshness and refresh suggestion
- render accounts table with agreed columns
- hide Entity column when unnecessary if the implementation can determine single-entity scope cheaply; otherwise show it consistently in V1

Acceptance outcome:

- `/reports/net-worth` is the canonical report page
- UI exposes explainable totals and row-level coverage

### Phase 6: Wire global refresh action

- expose one user-facing reporting refresh action on `/reports`
- implement it as async enqueue only
- let backend decide what projection family to refresh
- for V1, it is acceptable if the global refresh currently routes to the existing snapshot refresh foundation for the account set relevant to Net Worth

Acceptance outcome:

- hub supports a simple async refresh path without introducing progress UI or report-run history

### Phase 7: Verification and documentation

- add deterministic backend coverage for read semantics
- add LiveView coverage for hub and report page behavior
- run targeted tests, then `mix precommit`
- update required docs before handoff

Acceptance outcome:

- feature semantics are documented and test-backed

---

## Testing Strategy

### Backend read-model tests

Add tests for the Net Worth read service covering:

- included account filtering excludes:
  - archived accounts
  - `income`
  - `expense`
  - `equity`
  - system-managed accounts
- latest snapshot `<= as_of_date` is selected correctly
- exact coverage when same-day snapshot exists
- carried-forward coverage when prior snapshot exists and no relevant freshness lag exists
- no-history behavior when an included account has no snapshots
- per-currency totals exclude no-history rows
- liabilities contribute correctly to liability totals and net worth math under current ledger sign semantics
- multi-currency output returns separate summaries, not one collapsed total

### Freshness and lag tests

Add targeted tests for:

- report remains up to date when newer facts exist only after `as_of_date`
- report becomes outdated when a newer inserted ledger fact exists with `transaction.date <= as_of_date`
- `refreshable_gap` classification is assigned when snapshot coverage lags new relevant facts
- `no_history` does not by itself mark the full report outdated

### LiveView tests

For `/reports`:

- page renders the reporting hub structure, not mock sections
- global freshness badge is visible
- global refresh action is visible
- Net Worth card renders status, as-of date, compact per-currency summary, and open link

For `/reports/net-worth`:

- page renders as-of selector
- page renders summary cards by currency
- page renders freshness state
- page renders account rows including no-history rows
- page shows refresh suggestion when data is outdated

### Integration boundary tests

Add at least one integration-style test proving that:

- a ledger write can create the conditions for a `refreshable_gap`
- the report still renders using existing snapshots
- freshness/coverage expose the lag honestly

This is the most important product-confidence test in the entire feature.

---

## Risks And Edge Cases

### 1. Liability sign presentation

Ledger sign semantics are internal and fixed. The implementation must keep calculation logic aligned with ledger semantics while presenting liabilities in the UI as positive owed amounts and net worth as `assets - liabilities`. The main risk is inconsistent transformation between row display, summary display, and backend totals.

### 2. Query complexity for latest snapshot per account

Selecting one latest snapshot row per account while also keeping no-history accounts visible is more complex than simple joins. Keep the query isolated inside the read service. Do not spread this logic across LiveView and helper functions.

### 3. Refreshability detection may be easy to under-specify

The stale-data test is not just “is snapshot date older than as_of date”. Carry-forward days are legitimate. The report must distinguish between valid carry-forward and real lag caused by newer relevant inserted facts.

### 4. Multi-entity display ambiguity

If multiple entities are visible together, the Entity column becomes necessary for explainability. If only one entity is effectively in scope, hiding the column is cleaner. V1 should choose one deterministic rule and document it rather than leaving this to template heuristics.

### 5. Empty report states

If no included accounts exist at all, the report should not render a misleading empty totals table. It needs an explicit empty state explaining that Net Worth only covers non-archived institution-managed asset/liability accounts.

### 6. Archived accounts with historical snapshots

Archived accounts may still have historical snapshots. V1 scope says exclude archived accounts entirely. The read service must not accidentally pull them back in via snapshot joins.

### 7. Refresh action scope creep

There is a risk of reintroducing per-account rebuild mechanics into the product UI because that control already exists. This feature should keep the primary user action global and async, even if lower-level rebuild APIs still exist underneath.

---

## Follow-Up Work

These are likely next steps after this issue, but must not be pulled into it:

1. Compact dashboard summary cards that reuse the Net Worth read model.
2. Additional report types such as monthly cashflow.
3. Richer freshness live-updates via PubSub or polling.
4. Drilldown from a report row to supporting transactions/postings.
5. FX-aware consolidated net worth with explicit rate-policy metadata.
6. Stronger generalized reporting freshness contracts once multiple reports exist.

---

## Documentation Updates Required At The End

These updates are mandatory before calling the implementation complete:

1. Update [docs/adr/0017-reporting-and-read-model-architecture.md](/mnt/data4/matt/code/personal_stuffs/aurum-finance/docs/adr/0017-reporting-and-read-model-architecture.md)
   - document that the first production read-path consumer is Net Worth
   - record the decision to keep freshness report-specific in V1
   - record that `daily_balance_snapshots` are consumed via latest-snapshot-on-or-before semantics

2. Update [docs/architecture.md](/mnt/data4/matt/code/personal_stuffs/aurum-finance/docs/architecture.md)
   - reflect that Reporting now has a real user-facing hub and Net Worth read path
   - clarify the relationship between projection freshness and read-path honesty

3. Update [docs/roadmap.md](/mnt/data4/matt/code/personal_stuffs/aurum-finance/docs/roadmap.md)
   - mark Net Worth as started or delivered within M4 as appropriate
   - keep the milestone wording aligned with the feature’s actual implemented scope
   - clarify that this issue delivers the first real Net Worth read path
   - clarify that drilldown remains a planned Reporting M4 follow-up, not an accidentally omitted part of this issue

4. Add or update a reporting/product usage doc if needed
   - capture V1 Net Worth semantics:
     - included account scope
     - no FX
     - as-of behavior
     - coverage states
     - freshness meaning

5. Update the task artifact set in `llms/tasks/021_net_worth_initial_read_experience/` if execution notes or subtask breakdowns are created during implementation
   - keep the planning trail coherent for future contributors

---

## Summary

This issue should turn the reporting foundation into a real product surface without overbuilding:

- one honest reporting hub
- one real Net Worth report page
- one report-specific backend read model over `daily_balance_snapshots`
- one explicit freshness contract that surfaces projection lag instead of hiding it

That is the right scope now. It proves the reporting architecture under real usage, keeps the first delivery small enough to ship, and leaves room for richer report infrastructure only after a second report creates real pressure for generalization.
