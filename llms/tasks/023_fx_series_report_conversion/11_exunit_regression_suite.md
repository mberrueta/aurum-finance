# Task 11: ExUnit Regression Suite

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 10
- **Blocks**: Task 12

## Assigned Agent
`qa-elixir-test-author` - QA-driven ExUnit author for backend, LiveView, and worker coverage

## Agent Invocation
Invoke the `qa-elixir-test-author` agent with instructions to read this task file, Task 10 scenario outputs, and completed implementation tasks before writing the final regression suite.

## Objective
Add deterministic automated coverage for the FX context, CSV parser/import service, provider sync workers/scheduler behavior, `/fx` LiveView flows, and account-report FX conversion flows.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/10_test_scenarios_and_traceability.md`
- [ ] Completed outputs from Tasks 02-09
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] `test/support/factory.ex`

## Expected Outputs

- [ ] Backend tests for context, lookup, import, and report conversion semantics
- [ ] Worker/Oban tests for provider sync and scheduler behavior
- [ ] LiveView tests for `/fx` and the account-report conversion UI
- [ ] Any required factory/test-support additions

## Acceptance Criteria

- [ ] Tests cover series creation/edit/delete guardrails and list/detail aggregates
- [ ] Tests cover CSV happy path, invalid file rejection, overlap confirmation, and provider-series upload rejection
- [ ] Tests cover manual sync enqueue and global stale-series scan behavior
- [ ] Tests cover direct and inverted lookup plus stale-rate handling
- [ ] Tests cover account-report conversion success, invalid selection, no-compatible-series, and missing-rate-unavailable behavior
- [ ] Tests use stable DOM IDs and outcome-focused assertions
- [ ] Tests are deterministic, DB-sandbox-safe, and avoid timing flakiness
- [ ] `mix test` and `mix precommit` are run before completion

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/aurum_finance_web/live/
test/support/factory.ex
```

### Constraints
- Prefer factories over fixtures
- Keep tests high-signal and aligned to Task 10 scenario mapping
- Avoid raw HTML assertions when stable selectors are available

## Execution Instructions

### For the Agent
1. Follow the approved scenario matrix.
2. Add only the test support truly required by the implemented feature.
3. Run `mix test` and `mix precommit`, then document any remaining gaps.

### For the Human Reviewer
1. Confirm high-signal coverage of the approved feature scope.
2. Confirm quality gates were run cleanly.
3. Approve before Task 12 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

