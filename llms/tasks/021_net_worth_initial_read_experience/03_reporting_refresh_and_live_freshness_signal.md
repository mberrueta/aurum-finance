# Task 03: Reporting Refresh API and Live Freshness Signal

## Status
- **Status**: COMPLETED
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 04

## Assigned Agent
`dev-backend-elixir-engineer` - Backend engineer for reporting APIs, PubSub integration, and async refresh wiring

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 02 output, and the approved plan before implementing the global refresh path and live freshness signal.

## Objective
Add the backend support needed for:

- one global reporting refresh action on `/reports`
- async enqueue-only behavior
- simple live freshness state updates after refresh completion, preferably via PubSub
- hub-level freshness invalidation/update only, not row-level or detailed report-coverage recomputation in the hub UI

## Inputs Required

- [x] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [x] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [x] Approved Task 02 output
- [x] `llms/constitution.md`
- [x] `llms/project_context.md`
- [x] `llms/coding_styles/elixir.md`
- [x] `lib/aurum_finance/reporting.ex`
- [x] `lib/aurum_finance/reporting/ledger_event_bridge.ex`
- [x] `lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`

## Expected Outputs

- [x] Public reporting refresh API suitable for hub use
- [x] Narrow backend signal path for live freshness updates
- [x] Documentation/comments for the refresh signal contract if needed

## Acceptance Criteria

- [x] Refresh action remains enqueue-only and does not compute inline
- [x] Backend can support the hub refresh action without introducing per-report refresh UI
- [x] Freshness update mechanism is simple and V1-appropriate, preferably via PubSub
- [x] Freshness signal semantics are limited to hub-level freshness invalidation/update rather than detailed account-level coverage semantics on `/reports`
- [x] Reload-only UX is not treated as the intended primary path
- [x] No job-history or progress-tracking UI/API is introduced
- [x] Signal semantics stay narrow and reporting-specific

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/reporting/ledger_event_bridge.ex
lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex
lib/aurum_finance_web/live/reports_live.ex
lib/aurum_finance_web/live/
```

### Constraints
- Do not invent a broad eventing framework
- Keep the contract compatible with the existing reporting refresh foundation
- This task may introduce a narrow reporting-specific PubSub signal for UI freshness updates
- That signal is an intentional bounded exception to the default synchronous cross-context communication guidance and must remain limited to reporting freshness/update signaling rather than general context integration
- The signal should support coarse hub freshness recomputation only; detailed Net Worth freshness and coverage semantics remain on `/reports/net-worth`
- Do not expand this signal into a general cross-context domain event or UI event mechanism; it is limited to reporting refresh/freshness UI updates

## Execution Instructions

### For the Agent
1. Reuse the current reporting async foundation instead of bypassing it.
2. Keep the refresh API global and simple.
3. Document the freshness signal contract clearly for the UI tasks.

### For the Human Reviewer
1. Confirm the refresh API stays within agreed scope.
2. Confirm live freshness signaling is concrete enough for UI implementation.
3. Approve before Task 04 begins.

---

## Execution Summary

### Work Performed
- Added the public hub refresh API and reporting freshness subscription entrypoint in [reporting.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting.ex).
- Added the narrow reporting-specific PubSub helper module in [pubsub.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting/pubsub.ex).
- Wired coarse freshness invalidation into [ledger_event_bridge.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting/ledger_event_bridge.ex).
- Wired refresh-completed signaling into [daily_balance_snapshot_refresh_worker.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex).
- Added backend tests for hub refresh enqueue scope and PubSub delivery in [reporting_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/reporting_test.exs), [daily_balance_snapshot_refresh_worker_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/reporting/daily_balance_snapshot_refresh_worker_test.exs), and [ledger_event_bridge_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/reporting/ledger_event_bridge_test.exs).
- Verified with targeted reporting tests and `mix precommit`.

### Outputs Created
- Public API: `AurumFinance.Reporting.enqueue_hub_refresh/1`
- Public API: `AurumFinance.Reporting.subscribe_hub_freshness/0`
- Reporting-specific PubSub topic helper: `AurumFinance.Reporting.PubSub`
- Hub refresh result shape:
  - `status`
  - `entity_count`
  - `included_account_count`
  - `requested_account_ids`
- Freshness signal contract on the reporting-specific topic:
  - `{:reporting_hub_freshness_invalidated, %{entity_id, account_ids, from_date, occurred_at}}`
  - `{:reporting_hub_freshness_refreshed, %{entity_id, account_id, refresh_status, requested_from_date, effective_from_date, refreshed_at}}`

### Assumptions Made
- The `/reports` hub can compute its own entity scope and pass explicit `entity_ids` into `enqueue_hub_refresh/1`.
- The hub should use freshness messages only as coarse re-read triggers and should not attempt to derive detailed row-level reporting state from them.
- It is acceptable in V1 for one global hub refresh to enqueue account-level snapshot jobs for the current Net Worth account scope only.

### Decisions Made
- Kept the refresh API enqueue-only by routing the hub action through the existing account-level snapshot refresh worker foundation.
- Limited the signal path to one reporting-specific topic rather than reusing ledger events directly in the UI.
- Emitted invalidation when ledger writes enqueue relevant refreshes and emitted refreshed notifications only when the worker succeeds.
- Kept the payloads metadata-rich enough for observability and deterministic UI re-reads, but not as a replacement for the actual hub report query.

### Blockers Encountered
- None in the implementation. The local Postgres environment continued to emit transient `too_many_connections` log lines during tests, but the targeted suite and `mix precommit` both passed.

### Questions for Human
- Is the explicit `entity_ids` contract for `enqueue_hub_refresh/1` acceptable for Task 04, or do you want a later convenience wrapper that internally resolves the root-visible entity scope?

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
