# Task 10: Test Scenarios and Traceability

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 09
- **Blocks**: Task 11

## Assigned Agent
`qa-test-scenarios` - QA scenario designer for acceptance-criteria coverage and regression mapping

## Agent Invocation
Invoke the `qa-test-scenarios` agent with instructions to read this task file, the approved spec, and completed implementation tasks before producing the final scenario matrix for automated coverage.

## Objective
Translate the approved FX/report acceptance criteria into a concrete scenario map for backend, LiveView, Oban, and parser coverage so the final test-author task is narrow and auditable.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] Completed outputs from Tasks 02-09
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir_tests.md`
- [ ] Existing test patterns under `test/aurum_finance/` and `test/aurum_finance_web/live/`

## Expected Outputs

- [ ] Scenario matrix mapped to acceptance criteria and edge cases
- [ ] Recommended test layers for each scenario
- [ ] Explicit note of any residual non-automated checks for human review

## Acceptance Criteria

- [ ] Scenarios cover FX CRUD, delete guardrails, CSV upload success/failure/overlap cases, provider sync, scheduler behavior, and account-report conversion
- [ ] Scenarios cover missing-rate and no-compatible-series UX states
- [ ] Scenarios distinguish backend vs LiveView vs worker-level assertions
- [ ] Scenarios stay deterministic and sandbox-safe
- [ ] Any intentionally deferred coverage is documented explicitly

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/aurum_finance_web/live/
test/support/factory.ex
```

### Constraints
- Keep scenarios actionable for ExUnit authoring
- Avoid low-signal duplication of already-obvious smoke cases

## Execution Instructions

### For the Agent
1. Map the accepted feature behavior to test layers and scenario IDs.
2. Call out the highest-risk regressions explicitly.
3. Keep the scenario set compact but complete enough for final sign-off.

### For the Human Reviewer
1. Confirm the scenario matrix covers the approved scope and major edge cases.
2. Approve before Task 11 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

