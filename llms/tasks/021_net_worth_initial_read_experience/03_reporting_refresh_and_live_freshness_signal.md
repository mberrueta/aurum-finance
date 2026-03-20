# Task 03: Reporting Refresh API and Live Freshness Signal

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
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

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] `llms/tasks/021_net_worth_initial_read_experience/02_net_worth_backend_read_model.md`
- [ ] Approved Task 02 output
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] `lib/aurum_finance/reporting.ex`
- [ ] `lib/aurum_finance/reporting/ledger_event_bridge.ex`
- [ ] `lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`

## Expected Outputs

- [ ] Public reporting refresh API suitable for hub use
- [ ] Narrow backend signal path for live freshness updates
- [ ] Documentation/comments for the refresh signal contract if needed

## Acceptance Criteria

- [ ] Refresh action remains enqueue-only and does not compute inline
- [ ] Backend can support the hub refresh action without introducing per-report refresh UI
- [ ] Freshness update mechanism is simple and V1-appropriate, preferably via PubSub
- [ ] Freshness signal semantics are limited to hub-level freshness invalidation/update rather than detailed account-level coverage semantics on `/reports`
- [ ] Reload-only UX is not treated as the intended primary path
- [ ] No job-history or progress-tracking UI/API is introduced
- [ ] Signal semantics stay narrow and reporting-specific

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
